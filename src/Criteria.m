//
//  CriteriaTree.m
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

#import "Criteria.h"

@implementation Criteria

/* init
 * Initialise an empty Criteria.
 */
-(id)init
{
	return [self initWithField:@"" withOperator:0 withValue:@""];
}

/* initWithField
 * Initalises a new Criteria with the specified values.
 */
-(id)initWithField:(NSString *)newField withOperator:(CriteriaOperator)newOperator withValue:(NSString *)newValue
{
	if ((self = [super init]) != nil)
	{
		[self setField:newField];
		[self setOperator:newOperator];
		[self setValue:newValue];
	}
	return self;
}

/* operatorString
 * Returns the string representation of the operator.
 * Note: do NOT localise these strings. For UI display, the caller should use
 * NSLocalizedString() on the return value.
 */
+(NSString *)stringFromOperator:(CriteriaOperator)op
{
	NSString * operatorString = nil;
	switch (op)
	{
		case MA_CritOper_Is:					operatorString = @"is"; break;
		case MA_CritOper_IsNot:					operatorString = @"is not"; break;
		case MA_CritOper_IsAfter:				operatorString = @"is after"; break;
		case MA_CritOper_IsBefore:				operatorString = @"is before"; break;
		case MA_CritOper_IsOnOrAfter:			operatorString = @"is on or after"; break;
		case MA_CritOper_IsOnOrBefore:			operatorString = @"is on or before"; break;
		case MA_CritOper_Contains:				operatorString = @"contains"; break;
		case MA_CritOper_NotContains:			operatorString = @"does not contain"; break;
		case MA_CritOper_Under:					operatorString = @"under"; break;
		case MA_CritOper_NotUnder:				operatorString = @"not under"; break;
		case MA_CritOper_IsLessThan:			operatorString = @"is less than"; break;
		case MA_CritOper_IsGreaterThan:			operatorString = @"is greater than"; break;
		case MA_CritOper_IsLessThanOrEqual:		operatorString = @"is less than or equal to"; break;
		case MA_CritOper_IsGreaterThanOrEqual:	operatorString = @"is greater than or equal to"; break;
	}
	return operatorString;
}

/* operatorFromString
 * Given a string representing an operator, returns the CriteriaOperator value
 * that represents that string.
 */
+(CriteriaOperator)operatorFromString:(NSString *)string
{
	NSArray * operatorArray = [Criteria arrayOfOperators];
	NSUInteger  index;
	
	for (index = 0; index < [operatorArray count]; ++index)
	{
		CriteriaOperator op = [[operatorArray objectAtIndex:index] intValue];
		if ([string isEqualToString:[Criteria stringFromOperator:op]])
			return op;
	}
	return 0;
}

/* arrayOfOperators
 * Returns an array of NSNumbers that represent all supported operators.
 */
+(NSArray *)arrayOfOperators
{
	return [NSArray arrayWithObjects:
		[NSNumber numberWithInt:MA_CritOper_Is],
		[NSNumber numberWithInt:MA_CritOper_IsNot],
		[NSNumber numberWithInt:MA_CritOper_IsAfter],
		[NSNumber numberWithInt:MA_CritOper_IsBefore],
		[NSNumber numberWithInt:MA_CritOper_IsOnOrAfter],
		[NSNumber numberWithInt:MA_CritOper_IsOnOrBefore],
		[NSNumber numberWithInt:MA_CritOper_Contains],
		[NSNumber numberWithInt:MA_CritOper_NotContains],
		[NSNumber numberWithInt:MA_CritOper_IsLessThan],
		[NSNumber numberWithInt:MA_CritOper_IsLessThanOrEqual],
		[NSNumber numberWithInt:MA_CritOper_IsGreaterThan],
		[NSNumber numberWithInt:MA_CritOper_IsGreaterThanOrEqual],
		[NSNumber numberWithInt:MA_CritOper_Under],
		[NSNumber numberWithInt:MA_CritOper_NotUnder],
		nil];
}

/* setField
 * Sets the field element of a criteria.
 */
-(void)setField:(NSString *)newField
{
	[newField retain];
	[field release];
	field = newField;
}

/* setOperator
 * Sets the operator element of a criteria.
 */
-(void)setOperator:(CriteriaOperator)newOperator
{
	// Convert deprecated under/not-under operators
	// to is/is-not.
	if (newOperator == MA_CritOper_Under)
		newOperator = MA_CritOper_Is;
	if (newOperator == MA_CritOper_NotUnder)
		newOperator = MA_CritOper_IsNot;
	operator = newOperator;
}

/* setValue
 * Sets the value element of a criteria.
 */
-(void)setValue:(NSString *)newValue
{
	[newValue retain];
	[value release];
	value = newValue;
}

/* field
 * Returns the field element of a criteria.
 */
-(NSString *)field
{
	return field;
}

/* operator
 * Returns the operator element of a criteria
 */
-(CriteriaOperator)operator
{
	return operator;
}

/* value
 * Returns the value element of a criteria.
 */
-(NSString *)value
{
	return value;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[value release];
	value=nil;
	[field release];
	field=nil;
	[super dealloc];
}
@end

@implementation CriteriaTree

/* init
 * Initialise an empty CriteriaTree
 */
-(id)init
{
	return [self initWithString:@""];
}

/* initWithString
 * Initialises an criteria tree object with the specified string. The caller is responsible for
 * releasing the tree.
 */
-(id)initWithString:(NSString *)string
{
	if ((self = [super init]) != nil)
	{
		criteriaTree = [[NSMutableArray alloc] init];
		condition = MA_CritCondition_All;
        NSError *error = nil;
        NSXMLDocument *criteriaTreeDoc = [[NSXMLDocument alloc]
                                          initWithXMLString:string
                                          options:NSXMLNodeOptionsNone
                                          error:&error];
        
		if (!error)
		{
            NSArray *criteriaArray = [criteriaTreeDoc.rootElement elementsForName:@"criteria"];
            condition = [CriteriaTree conditionFromString:[[criteriaTreeDoc.rootElement attributeForName:@"condition"] stringValue]];
            if (condition == MA_CritCondition_Invalid) {
                // For backward compatibility, the absence of the condition attribute
                // assumes that we're matching ALL conditions.
                condition = MA_CritCondition_All;
            }
            
            for (NSXMLElement *criteriaElement in criteriaArray) {
                NSString *fieldname = [[criteriaElement attributeForName:@"field"] stringValue];
                NSString *operator = [[[criteriaElement elementsForName:@"operator"]
                                       firstObject] stringValue];
                NSString *value = [[[criteriaElement elementsForName:@"value"]
                                    firstObject] stringValue];
                
                Criteria *newCriteria = [[Criteria alloc]
                                         initWithField:fieldname
                                         withOperator:operator.integerValue
                                         withValue:value];
                [self addCriteria:newCriteria];
                [newCriteria release];
                
            }
        }
		[criteriaTreeDoc release];
	}
	return self;
}

/* conditionFromString
 * Converts a condition string to its condition value. Returns -1 if the
 * string is invalid.
 * Note: Do NOT localise these strings. They're written to the XML file.
 */
+(CriteriaCondition)conditionFromString:(NSString *)string
{
	if (string != nil)
	{
		if ([[string lowercaseString] isEqualToString:@"any"])
			return MA_CritCondition_Any;
		if ([[string lowercaseString] isEqualToString:@"all"])
			return MA_CritCondition_All;
	}
	return MA_CritCondition_Invalid;
}

/* conditionToString
 * Returns the string representation of the specified condition.
 * Note: Do NOT localise these strings. They're written to the XML file.
 */
+(NSString *)conditionToString:(CriteriaCondition)condition
{
	if (condition == MA_CritCondition_Any)
		return @"any";
	if (condition == MA_CritCondition_All)
		return @"all";
	return @"";
}

/* condition
 * Return the criteria condition.
 */
-(CriteriaCondition)condition
{
	return condition;
}

/* setCondition
 * Sets the criteria condition.
 */
-(void)setCondition:(CriteriaCondition)newCondition
{
	condition = newCondition;
}

/* criteriaEnumerator
 * Returns an enumerator that will iterate over the criteria
 * object. We do it this way because we can't necessarily guarantee
 * that the criteria will be stored in an NSArray or any other collection
 * object for which NSEnumerator is supported.
 */
-(NSEnumerator *)criteriaEnumerator
{
	return [criteriaTree objectEnumerator];
}

/* addCriteria
 * Adds the specified criteria to the criteria array.
 */
-(void)addCriteria:(Criteria *)newCriteria
{
	[criteriaTree addObject:newCriteria];
}

/* string
 * Returns the complete criteria tree as a string.
 */
-(NSString *)string
{
    NSXMLDocument *criteriaDoc = [NSXMLDocument document];
    [criteriaDoc setStandalone:YES];
    [criteriaDoc setCharacterEncoding:@"UTF-8"];
    [criteriaDoc setVersion:@"1.0"];
    
    NSDictionary * conditionDict = [NSDictionary dictionaryWithObject:[CriteriaTree conditionToString:condition] forKey:@"condition"];
    NSXMLElement *criteriaGroup = [[NSXMLElement alloc] initWithName:@"criteriagroup"];
    [criteriaGroup setAttributesWithDictionary:conditionDict];
    
    for (Criteria *criteria in criteriaTree) {
        NSDictionary * criteriaDict = [NSDictionary dictionaryWithObject:[criteria field] forKey:@"field"];
        NSXMLElement *criteriaElement = [[NSXMLElement alloc] initWithName:@"criteria"];
        [criteriaElement setAttributesWithDictionary:criteriaDict];
        NSXMLElement *operatorElement = [[NSXMLElement alloc]
                                        initWithName:@"operator"
                                        stringValue:[NSString stringWithFormat:
                                                     @"%d", criteria.operator]];
        NSXMLElement *valueElement = [[NSXMLElement alloc]
                                        initWithName:@"value"
                                        stringValue:criteria.value];
        
        [criteriaGroup addChild:criteriaElement];
        [criteriaElement addChild:operatorElement];
        [criteriaElement addChild:valueElement];
        
    }
    [criteriaDoc addChild:criteriaGroup];
    
	return criteriaDoc.XMLString;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[criteriaTree release];
	criteriaTree=nil;
	[super dealloc];
}
@end
