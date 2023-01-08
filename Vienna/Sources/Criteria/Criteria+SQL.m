//
//  Criteria+SQL.m
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

#import "Criteria+SQL.h"
#import "Database.h"
#import "Field.h"
#import "Article.h"

@implementation CriteriaTree (SQL)

-(NSString *)stringForCriteria:(Criteria *)criteria database:(Database *)database {

    NSMutableString *sqlString = [NSMutableString string];

    Field * field = [database fieldByName:criteria.field];
    NSAssert1(field != nil, @"Criteria field %@ does not have an associated database field", [criteria field]);

    NSString * operatorString = nil;
    NSString * valueString = nil;

    switch (criteria.operatorType) {
        case VNACriteriaOperatorEqualTo:
            if (field.type == VNAFieldTypeString) {
                operatorString = @"='%@'"; break;
            } else {
                operatorString = @"=%@"; break;
            }
        case VNACriteriaOperatorNotEqualTo:
            if (field.type == VNAFieldTypeString) {
                operatorString = @"<>'%@'"; break;
            } else {
                operatorString = @"<>%@"; break;
            }
        case VNACriteriaOperatorLessThan:
            operatorString = @"<%@"; break;
        case VNACriteriaOperatorGreaterThan:
            operatorString = @">%@"; break;
        case VNACriteriaOperatorLessThanOrEqualTo:
            operatorString = @"<=%@"; break;
        case VNACriteriaOperatorGreaterThanOrEqualTo:
            operatorString = @">=%@"; break;
        case VNACriteriaOperatorContains:
            operatorString = @" LIKE '%%%@%%'"; break;
        case VNACriteriaOperatorContainsNot:
            operatorString = @" NOT LIKE '%%%@%%'"; break;
        case VNACriteriaOperatorBefore:
            operatorString = @"<%@"; break;
        case VNACriteriaOperatorAfter:
            operatorString = @">%@"; break;
        case VNACriteriaOperatorOnOrBefore:
            operatorString = @"<=%@"; break;
        case VNACriteriaOperatorOnOrAfter:
            operatorString = @">=%@"; break;

        case VNACriteriaOperatorUnder:
        case VNACriteriaOperatorNotUnder:
            // Handle the operatorString later. For now just make sure we're working with the
            // right field types.
            NSAssert([field type] == VNAFieldTypeFolder, @"Under operators only valid for folder field types");
            break;
    }

    // Unknown operator - skip this clause
    if (operatorString == nil) {
        return nil;
    }

    switch (field.type)
    {
        case VNAFieldTypeFlag:
            valueString = [criteria.value isEqualToString:@"Yes"] ? @"1" : @"0";
            break;
        case VNAFieldTypeFolder: {
            Folder * folder = [database folderFromName:criteria.value];
            NSString *scopeString = [database sqlScopeForFolder:folder criteriaOperator:criteria.operatorType];
            [sqlString appendString:scopeString];
            break;
        }
        case VNAFieldTypeDate: {
            NSCalendar *calendar = NSCalendar.currentCalendar;
            NSDate *startDate = [calendar startOfDayForDate:[NSDate date]];
            NSString * criteriaValue = criteria.value.lowercaseString;
            NSCalendarUnit calendarUnit = NSCalendarUnitDay;

            // "yesterday" is a short hand way of specifying the previous day.
            if ([criteriaValue isEqualToString:@"yesterday"]) {
                startDate = [calendar dateByAddingUnit:NSCalendarUnitDay
                                                 value:-1
                                                toDate:startDate
                                               options:0];
            }
            // "last week" is a short hand way of specifying a range from 7 days ago to today.
            else if ([criteriaValue isEqualToString:@"last week"]) {
                startDate = [calendar dateByAddingUnit:NSCalendarUnitWeekOfYear
                                                 value:-1
                                                toDate:startDate
                                               options:0];
                calendarUnit = NSCalendarUnitWeekOfYear;
            }

            if (criteria.operatorType == VNACriteriaOperatorEqualTo) {
                NSDate *endDate = [calendar dateByAddingUnit:calendarUnit
                                                       value:1
                                                      toDate:startDate
                                                     options:0];
                NSString *dateIs = [NSString stringWithFormat:@"( %@>=%f AND %@<%f )", field.sqlField, startDate.timeIntervalSince1970, field.sqlField, endDate.timeIntervalSince1970];
                [sqlString appendString:dateIs];
            }
            else {
                if ((criteria.operatorType == VNACriteriaOperatorAfter) || (criteria.operatorType == VNACriteriaOperatorOnOrBefore)) {
                    startDate = [calendar dateByAddingUnit:NSCalendarUnitDay
                                                     value:1
                                                    toDate:startDate
                                                   options:0];
                }
                valueString = [NSString stringWithFormat:@"%f", startDate.timeIntervalSince1970];
            }
            break;
        }
        case VNAFieldTypeString:
            if (field.tag == ArticleFieldIDText) {
                // Special case for searching the text field. We always include the title field in the
                // search so the resulting SQL statement becomes:
                //
                //   (text op value or title op value)
                //
                // where op is the appropriate operator.
                //
                Field * titleField = [database fieldByName:MA_Field_Subject];
                NSString * value = [NSString stringWithFormat:operatorString, criteria.value];
                NSString *op = criteria.operatorType == VNACriteriaOperatorNotEqualTo || criteria.operatorType == VNACriteriaOperatorContainsNot ? @"AND" : @"OR";
                [sqlString appendFormat:@"(%1$@%2$@ %3$@ %4$@%2$@)", field.sqlField, value, op, titleField.sqlField];
                break;
            }
        case VNAFieldTypeInteger:
            valueString = [NSString stringWithFormat:@"%@", criteria.value];
            break;
    }

    if (valueString != nil) {
        [sqlString appendString:field.sqlField];
        [sqlString appendFormat:operatorString, valueString];
    }

    return sqlString;
}

/* criteriaToSQLForDatabase
 * Converts a criteria tree to it's SQL representative.
 */
-(NSString *)toSQLForDatabase:(Database *)database
{
    NSMutableString * sqlString = [NSMutableString string];
    NSInteger count = 0;

    for (NSObject<CriteriaElement> *criteria in self.criteriaTree)
    {
        NSString *conditionString = @"";
        if (count++ > 0) {
            switch (self.condition) {
            case VNACriteriaConditionAny:
                conditionString = @" OR ";
                break;
            case VNACriteriaConditionNone:
                conditionString = @" AND NOT ";
                break;
            case VNACriteriaConditionAll:
            default:
                conditionString = @" AND ";
                break; //Unknown condition
            }
        } else if (self.condition == VNACriteriaConditionNone) {
            conditionString = @"NOT ";
        }

        [sqlString appendString:conditionString];

        if ([criteria isKindOfClass:[CriteriaTree class]]) {
            [sqlString appendString:[NSString stringWithFormat:@"( %@ )", [(CriteriaTree *)criteria toSQLForDatabase:database]]];
        } else {
            [sqlString appendString:[self stringForCriteria:(Criteria *)criteria database:database]];
        }
    }
    return sqlString;
}

@end
