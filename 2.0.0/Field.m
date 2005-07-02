//
//  VField.m
//  Vienna
//
//  Created by Steve on Mon Mar 22 2004.
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

#import "Field.h"

@implementation Field

/* init
 * Init an empty Field object.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		name = nil;
		displayName = nil;
		sqlField = nil;
		visible = NO;
		width = 20;
		type = MA_FieldType_Integer;
		tag = -1;
	}
	return self;
}

/* setName
 * Sets the name of the field. The field name is the unique internal string
 * representation of the field.
 */
-(void)setName:(NSString *)newName
{
	[newName retain];
	[name release];
	name = newName;
}

/* setDisplayName
 * Sets the display name of the field. This is the name that is intended to be
 * displayed in the UI.
 */
-(void)setDisplayName:(NSString *)newDisplayName
{
	[newDisplayName retain];
	[displayName release];
	displayName = newDisplayName;
}

/* setSqlField
 * Sets the SQL column name of the field. This must correspond to the name used
 * in the 'create table' statement when the table of which this field is part was
 * originally created.
 */
-(void)setSqlField:(NSString *)newSqlField
{
	[newSqlField retain];
	[sqlField release];
	sqlField = newSqlField;
}

/* setType
 * Sets the field type. This must be one of the valid values in the FieldType enum.
 * The field type is used to govern how the field value is interpreted.
 */
-(void)setType:(FieldType)newType
{
	type = newType;
}

/* setTag
 * Sets the field tag. The tag is simply an unique integer that identifies the field
 * in the same way that the field name is used. I suspect that at some point one of
 * these two will be deprecated for simplicity.
 */
-(void)setTag:(int)newTag
{
	tag = newTag;
}

/* setVisible
 * Sets whether or not this field is intended to be visible in the message list view by default.
 */
-(void)setVisible:(BOOL)flag
{
	visible = flag;
}

/* setWidth
 * Sets the default width of the field in the message list view.
 */
-(void)setWidth:(int)newWidth
{
	width = newWidth;
}

/* name
 * Returns the field name
 */
-(NSString *)name
{
	return name;
}

/* displayName
 * Returns the field display name.
 */
-(NSString *)displayName
{
	return displayName;
}

/* sqlField
 * Returns the SQL column name for this field.
 */
-(NSString *)sqlField
{
	return sqlField;
}

/* tag
 * Returns the field's tag number.
 */
-(int)tag
{
	return tag;
}

/* type
 * Returns the fields type.
 */
-(FieldType)type
{
	return type;
}

/* width
 * Returns the default width of the field in the message list view.
 */
-(int)width
{
	return width;
}

/* visible
 * Returns whether or not this field is visible by default in the message list view.
 */
-(BOOL)visible
{
	return visible;
}

/* description
 * Returns a detailed description of the field for debugging purposes.
 */
-(NSString *)description
{
	return [NSString stringWithFormat:@"('%@', displayName='%@', sqlField='%@', tag=%d, width=%d, visible=%d)", name, displayName, sqlField, tag, width, visible];
}

-(void)dealloc
{
	[name release];
	[super dealloc];
}
@end
