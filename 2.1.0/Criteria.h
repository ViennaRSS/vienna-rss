//
//  CriteriaTree.h
//  Vienna
//
//  Created by Steve on Thu Apr 29 2004.
//  Copyright (c) 2004-2005 Steve Palmer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>

/* Enum of valid criteria operators
 */
typedef enum {
	MA_CritOper_Is = 1,
	MA_CritOper_IsNot,
	MA_CritOper_IsLessThan,
	MA_CritOper_IsGreaterThan,
	MA_CritOper_IsLessThanOrEqual,
	MA_CritOper_IsGreaterThanOrEqual,
	MA_CritOper_Contains,
	MA_CritOper_NotContains,
	MA_CritOper_IsBefore,
	MA_CritOper_IsAfter,
	MA_CritOper_IsOnOrBefore,
	MA_CritOper_IsOnOrAfter,
	MA_CritOper_Under,
	MA_CritOper_NotUnder,
	MA_CritOper_HasPhrase,
	MA_CritOper_NotHasPhrase
} CriteriaOperator;

typedef enum {
	MA_CritCondition_All = 0,
	MA_CritCondition_Any,
	MA_CritCondition_Invalid
} CriteriaCondition;

@interface Criteria : NSObject {
	NSString * field;
	NSString * value;
	CriteriaOperator operator;
}

// Public functions
-(id)initWithField:(NSString *)newField withOperator:(CriteriaOperator)newOperator withValue:(NSString *)newValue;
+(NSString *)stringFromOperator:(CriteriaOperator)operator;
+(CriteriaOperator)operatorFromString:(NSString *)string;
+(NSArray *)arrayOfOperators;
-(void)setField:(NSString *)newField;
-(void)setOperator:(CriteriaOperator)newOperator;
-(void)setValue:(NSString *)newValue;
-(NSString *)field;
-(NSString *)value;
-(CriteriaOperator)operator;
@end

@interface CriteriaTree : NSObject {
	CriteriaCondition condition;
	NSMutableArray * criteriaTree;
}

// Public functions
-(id)initWithString:(NSString *)string;
-(NSEnumerator *)criteriaEnumerator;
-(void)addCriteria:(Criteria *)newCriteria;
-(NSString *)string;
-(CriteriaCondition)condition;
-(void)setCondition:(CriteriaCondition)newCondition;
+(CriteriaCondition)conditionFromString:(NSString *)string;
+(NSString *)conditionToString:(CriteriaCondition)condition;
@end
