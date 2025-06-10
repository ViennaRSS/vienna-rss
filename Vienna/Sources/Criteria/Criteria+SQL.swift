//
//  Criteria+SQL.swift
//  Vienna
//
//  Copyright 2023 Tassilo Karge
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

@objc
protocol SQLConversion {
    @objc(toSQLForDatabase:)
    func toSQL(database: Database) -> String
}

@objc
extension CriteriaTree: SQLConversion {
    func toSQL(database: Database) -> String {

        let sqlOperator: String
        let noneConditionPrefix: String
        switch condition {
        case .any:
            noneConditionPrefix = ""
            sqlOperator = "OR"
        case .none:
            noneConditionPrefix = "NOT "
            sqlOperator = "AND NOT"
        case .invalid, .all:
            noneConditionPrefix = ""
            sqlOperator = "AND"
        }

        return noneConditionPrefix + criteriaTree.map { crit in
            if let crit = crit as? CriteriaTree {
                return "( \(crit.toSQL(database: database)) )"
            } else if let crit = crit as? Criteria {
                return crit.toSQL(database: database)
            } else {
                fatalError("faulty criteria type \(type(of: crit))")
            }
        }.joined(separator: " \(sqlOperator) ")
    }
}

@objc
extension Criteria: SQLConversion {
    func toSQL(database: Database) -> String {
        guard let databaseField = database.field(byName: field), let sqlField = databaseField.sqlField else {
            fatalError("Criteria field \(field) does not have an associated database field")
        }

        let sqlFieldName = "\"\(sqlField)\""
        switch databaseField.type {
        case .flag:
            return flagSqlString(sqlFieldName: sqlFieldName)
        case .date:
            return dateSqlString(sqlFieldName: sqlFieldName)
        case .folder:
            return folderSqlString(sqlFieldName: sqlFieldName, database: database)
        case .integer:
            return integerSqlString(sqlFieldName: sqlFieldName)
        case .string:
            if databaseField.name == MA_Field_Text {
                // Special case for searching the text field: We always include the title field in the search
                // TODO: decide how to migrate this now that we allow nested criteria
                return "(\(stringSqlString(sqlFieldName: sqlFieldName)) OR \(Criteria(field: MA_Field_Subject, operatorType: operatorType, value: value).toSQL(database: database)))"
            } else {
                return stringSqlString(sqlFieldName: sqlFieldName)
            }
        @unknown default:
            fatalError("unimplemented criteria field type \(databaseField.type)")
        }
    }

    func dateSqlString(sqlFieldName: String) -> String {
        let startOfToday = Calendar.current.startOfDay(for: Date())

        let startDate: Date?
        if value == DateOffset.today.rawValue {
            startDate = startOfToday
        } else if value == DateOffset.yesterday.rawValue {
            startDate = Calendar.current.date(byAdding: .day, value: -1, to: startOfToday)
        } else if value == DateOffset.lastWeek.rawValue {
            startDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: startOfToday)
        } else {
            // Check for the pattern for date with unit criteria
            let datePatternRegex = try? NSRegularExpression(pattern: "^([0-9]+) (.+)$")
            let datePatternMatch = datePatternRegex?.firstMatch(in: value, range: NSRange(location: 0, length: value.utf16.count))
            if let datePatternMatch = datePatternMatch {
                guard let valueRange = Range(datePatternMatch.range(at: 1), in: value),
                      let amount = Int(value[valueRange]),
                      let unitRange = Range(datePatternMatch.range(at: 2), in: value),
                      let unit = DateUnit(rawValue: String(value[unitRange]))
                else {
                      fatalError("Malformed date predicate value: \(value)")
                }

                startDate = Calendar.current.date(byAdding: unit.calendarComponent, value: -amount, to: Date())
            } else {
                fatalError("Unknown value \(value) for date field")
            }
        }

        let startOfDayToEndOfDay = DateComponents(calendar: Calendar.current, day: 1, second: -1)
        guard let startOfDay = startDate, let endOfDay = Calendar.current.date(byAdding: startOfDayToEndOfDay, to: startOfDay) else {
            fatalError("Start of day or end of day date calculation for \(value) failed")
        }

        let endOfDayInterval = Int64(endOfDay.timeIntervalSince1970)
        let startOfDayInterval = Int64(startOfDay.timeIntervalSince1970)

        switch operatorType {
        case .equalTo:
            return "\(sqlFieldName) >= \(startOfDayInterval) AND \(sqlFieldName) <= \(endOfDayInterval)"
        case .before:
            return "\(sqlFieldName) < \(startOfDayInterval)"
        case .after:
            return "\(sqlFieldName) > \(endOfDayInterval)"
        case .onOrBefore:
            return "\(sqlFieldName) <= \(endOfDayInterval)"
        case .onOrAfter:
            return "\(sqlFieldName) >= \(startOfDayInterval)"
        default:
            fatalError("Illegal operator \(operatorType) for date field")
        }
    }

    func flagSqlString(sqlFieldName: String) -> String {
        guard operatorType == .equalTo || operatorType == .notEqualTo else {
            fatalError("Operator type \(operatorType) not applicable to flag field \(sqlFieldName)")
        }
        let sqlValue: String
        if value == "Yes" { sqlValue = "1" } else { sqlValue = "0" }
        let sqlOperator = standardSqlOperator()
        return "\(sqlFieldName) \(sqlOperator) \(sqlValue)"
    }

    func folderSqlString(sqlFieldName: String, database: Database) -> String {
        // trim extra spaces added by predicate editor's formatting
        let cleanedValue = String(value.drop { $0 == " " })
        let folder = database.folder(fromName: cleanedValue)
        let scope: QueryScope
        switch operatorType {
        case .under:
            scope = [.subFolders, .inclusive]
        case .notUnder:
            scope = .subFolders
        case .equalTo:
            scope = .inclusive
        case .notEqualTo:
            scope = []
        default:
            fatalError("Operator type \(operatorType) not applicable to folder field \(sqlFieldName)")
        }
        return database.sqlScope(for: folder, flags: scope, field: sqlFieldName)
    }

    func integerSqlString(sqlFieldName: String) -> String {
        return "\(sqlFieldName) \(standardSqlOperator()) \(value)"
    }

    func stringSqlString(sqlFieldName: String) -> String {
        let sqlOperator: String
        switch operatorType {
        case .contains:
            sqlOperator = "LIKE '%%%@%%'"
        case .containsNot:
            sqlOperator = "NOT LIKE '%%%@%%'"
        default:
            sqlOperator = "\(standardSqlOperator()) '%@'"
        }
        let formattedOperator = String(format: sqlOperator, value)
        return "\(sqlFieldName) \(formattedOperator)"
    }

    func standardSqlOperator() -> String {
        switch operatorType {
        case .equalTo:
            return "="
        case .notEqualTo:
            return "<>"
        case .lessThan:
            return "<"
        case .greaterThan:
            return ">"
        case .lessThanOrEqualTo:
            return "<="
        case .greaterThanOrEqualTo:
            return ">="
        default:
            fatalError("No standard sql operator for type \(operatorType)")
        }
    }

}
