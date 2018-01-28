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

#import <Cocoa/Cocoa.h>

/* Enum of valid criteria operators
 */
typedef NS_ENUM(NSUInteger, CriteriaOperator) {
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
	MA_CritOper_NotUnder
} ;

typedef NS_ENUM(NSUInteger, CriteriaCondition) {
	MA_CritCondition_All = 0,
	MA_CritCondition_Any,
	MA_CritCondition_Invalid
};

@interface Criteria : NSObject {
	NSString * field;
	NSString * value;
	CriteriaOperator operator;
}

// Public functions
-(instancetype)initWithField:(NSString *)newField withOperator:(CriteriaOperator)newOperator withValue:(NSString *)newValue NS_DESIGNATED_INITIALIZER;
+(NSString *)stringFromOperator:(CriteriaOperator)operator;
+(CriteriaOperator)operatorFromString:(NSString *)string;
+(NSArray *)arrayOfOperators;
@property (nonatomic, copy) NSString *field;
@property (nonatomic, copy) NSString *value;
@property (nonatomic) CriteriaOperator operator;
@end

@interface CriteriaTree : NSObject {
	CriteriaCondition condition;
	NSMutableArray * criteriaTree;
}

// Public functions
-(instancetype)initWithString:(NSString *)string NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly, strong) NSEnumerator *criteriaEnumerator;
-(void)addCriteria:(Criteria *)newCriteria;
@property (nonatomic, readonly, copy) NSString *string;
@property (nonatomic) CriteriaCondition condition;
+(CriteriaCondition)conditionFromString:(NSString *)string;
+(NSString *)conditionToString:(CriteriaCondition)condition;
@end
