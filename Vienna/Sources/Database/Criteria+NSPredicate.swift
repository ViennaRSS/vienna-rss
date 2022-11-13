//
//  Criteria+NSPredicate.swift
//  Vienna
//
//  Copyright 2022 Tassilo Karge
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
extension CriteriaTree {

    public convenience init?(predicate: NSPredicate) {
        self.init()
        guard let compound = predicate as? NSCompoundPredicate else {
            return nil
        }
        for subPredicate in compound.subpredicates {
            let criteriaElement: (NSObjectProtocol & CriteriaElement)?
            if let subCompound = subPredicate as? NSCompoundPredicate {
                criteriaElement = CriteriaTree(predicate: subCompound)
            } else if let basicPredicate = subPredicate as? NSComparisonPredicate {
                criteriaElement = Criteria(predicate: basicPredicate)
            } else {
                criteriaElement = nil
            }
            if let criteriaElement = criteriaElement {
                self.criteriaTree.append(criteriaElement)
            } else {
                NSLog("Subpredicate \(subPredicate) of compound predicate \(self) is corrupted")
            }
        }
    }

    var predicate: NSPredicate {
        return buildPredicate()
    }

    private func buildPredicate() -> NSPredicate {

        let type: NSCompoundPredicate.LogicalType
        switch condition {
        case .MA_CritCondition_Any:
            type = .or
        case .MA_CritCondition_None:
            type = .not
        case .MA_CritCondition_All, .MA_CritCondition_Invalid:
            type = .and
        @unknown default:
            fatalError("Unknown condition in CriteriaTree \(self)")
        }

        let subPredicates = self.criteriaTree.map { $0.predicate }

        return NSCompoundPredicate(type: type, subpredicates: subPredicates)
    }
}

@objc
extension Criteria {

    public convenience init?(predicate: NSPredicate) {
        self.init()
        guard let comparison = predicate as? NSComparisonPredicate else {
            return nil
        }

        self.field = comparison.leftExpression.constantValue as? String ?? comparison.leftExpression.keyPath
        self.value = comparison.rightExpression.constantValue as? String ?? comparison.rightExpression.keyPath

        let criteriaOperator: CriteriaOperator
        switch field {
        case MA_Field_Folder:
            switch comparison.predicateOperatorType {
            case .notEqualTo:
                criteriaOperator = .MA_CritOper_IsNot
            default:
                criteriaOperator = .MA_CritOper_Is
            }
        case MA_Field_Subject, MA_Field_Author, MA_Field_Text:
            switch comparison.predicateOperatorType {
            case .contains:
                criteriaOperator = .MA_CritOper_Contains
            case .notEqualTo:
                criteriaOperator = .MA_CritOper_IsNot
            default:
                criteriaOperator = .MA_CritOper_Is
            }
        case MA_Field_Date:
            switch comparison.predicateOperatorType {
            case .lessThan:
                criteriaOperator = .MA_CritOper_IsBefore
            case .lessThanOrEqualTo:
                criteriaOperator = .MA_CritOper_IsOnOrBefore
            case .greaterThan:
                criteriaOperator = .MA_CritOper_IsAfter
            case .greaterThanOrEqualTo:
                criteriaOperator = .MA_CritOper_IsOnOrAfter
            default:
                criteriaOperator = .MA_CritOper_Is
            }
        case MA_Field_Read, MA_Field_Flagged, MA_Field_HasEnclosure, MA_Field_Deleted:
            criteriaOperator = .MA_CritOper_Is
        default:
            NSLog("Unknown field \(field), will default to \"=\" operator!")
            criteriaOperator = .MA_CritOper_Is
        }
        //TODO implement all available / valid types

        self.operator = criteriaOperator
    }

    var predicate: NSPredicate {
        return buildPredicate()
    }

    private func buildPredicate() -> NSPredicate {

        let left = NSExpression(forConstantValue: self.field)
        let right = NSExpression(forConstantValue: self.value)

        let type: NSComparisonPredicate.Operator
        switch self.operator {
        case .MA_CritOper_Is:
            type = .equalTo
        case .MA_CritOper_IsNot:
            type = .notEqualTo
        case .MA_CritOper_IsLessThan:
            type = .lessThan
        case .MA_CritOper_IsGreaterThan:
            type = .greaterThan
        case .MA_CritOper_IsLessThanOrEqual:
            type = .lessThanOrEqualTo
        case .MA_CritOper_IsGreaterThanOrEqual:
            type = .greaterThanOrEqualTo
        case .MA_CritOper_Contains:
            type = .contains
        case .MA_CritOper_NotContains:
            type = .contains // special case: negated later
        case .MA_CritOper_IsBefore:
            type = .lessThan
        case .MA_CritOper_IsAfter:
            type = .greaterThan
        case .MA_CritOper_IsOnOrBefore:
            type = .lessThanOrEqualTo
        case .MA_CritOper_IsOnOrAfter:
            type = .greaterThanOrEqualTo
        case .MA_CritOper_Under:
            type = .lessThan
        case .MA_CritOper_NotUnder:
            type = .greaterThanOrEqualTo
        default:
            type = .equalTo
        }

        let comparisonPredicate = NSComparisonPredicate(leftExpression: left, rightExpression: right, modifier: .direct, type: type)
        if self.operator != .MA_CritOper_NotContains {
            return comparisonPredicate
        } else {
            return NSCompoundPredicate(type: .not, subpredicates: [comparisonPredicate])
        }
    }
}
