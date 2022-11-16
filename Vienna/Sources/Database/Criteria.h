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

@import Foundation;

/* Enum of valid criteria operators
 */
typedef NS_ENUM(NSUInteger, VNACriteriaOperator) {
    VNACriteriaOperatorEqualTo = 1,
    VNACriteriaOperatorNotEqualTo,
    VNACriteriaOperatorLessThan,
    VNACriteriaOperatorGreaterThan,
    VNACriteriaOperatorLessThanOrEqualTo,
    VNACriteriaOperatorGreaterThanOrEqualTo,
    VNACriteriaOperatorContains,
    VNACriteriaOperatorContainsNot,
    VNACriteriaOperatorBefore,
    VNACriteriaOperatorAfter,
    VNACriteriaOperatorOnOrBefore,
    VNACriteriaOperatorOnOrAfter,
    VNACriteriaOperatorUnder,
    VNACriteriaOperatorNotUnder
} NS_SWIFT_NAME(Criteria.Operator);

typedef NS_ENUM(NSUInteger, VNACriteriaCondition) {
    VNACriteriaConditionAll = 0,
    VNACriteriaConditionAny,
    VNACriteriaConditionInvalid,
    VNACriteriaConditionNone,
} NS_SWIFT_NAME(CriteriaTree.Condition);

@protocol PredicateConvertible
    @property(nonnull, readonly) NSPredicate *predicate;
    -(instancetype _Nullable)initWithPredicate:(NSPredicate *_Nonnull)predicate;
@end

@protocol CriteriaElement <PredicateConvertible>

@end

@interface Criteria: NSObject <CriteriaElement> {
	NSString * field;
	NSString * value;
	VNACriteriaOperator operator;
}

// Public functions
+(NSString *_Nonnull)localizedStringFromOperator:(CriteriaOperator)operator;
-(instancetype _Nullable)initWithField:(NSString *_Nonnull)newField withOperator:(VNACriteriaOperator)newOperator withValue:(NSString *_Nonnull)newValue NS_DESIGNATED_INITIALIZER;
+(NSArray *_Nonnull)arrayOfOperators;
@property (nonatomic, copy) NSString *_Nonnull field;
@property (nonatomic, copy) NSString *_Nonnull value;
@property (nonatomic) VNACriteriaOperator operator;
@end

@interface CriteriaTree: NSObject <CriteriaElement> {
	VNACriteriaCondition condition;
	NSMutableArray<NSObject<CriteriaElement> *> * criteriaTree;
}

// Public functions
-(instancetype _Nullable)initWithString:(NSString *_Nonnull)string;
-(instancetype _Nullable)initWithXml:(NSXMLElement *_Nullable)xml NS_DESIGNATED_INITIALIZER;
@property (nonnull, nonatomic, readonly) NSEnumerator<NSObject<CriteriaElement> *> *criteriaEnumerator;
-(void)addCriteria:(NSObject<CriteriaElement> *_Nonnull)newCriteria;
@property (nonnull, readonly, nonatomic) NSString *string;
@property (nonatomic) VNACriteriaCondition condition;
@property (nonnull, nonatomic) NSArray<NSObject<CriteriaElement> *> *criteriaTree;

@end
