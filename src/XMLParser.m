//
//  XMLParser.m
//  Vienna
//
//  Created by Steve on 5/27/05.
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
// 

#import "XMLParser.h"
#import "StringExtensions.h"
#import "Debug.h"
#import "AppController.h"

@interface XMLParser (Private)
	-(void)setTreeRef:(CFXMLTreeRef)treeRef;
	+(XMLParser *)treeWithCFXMLTreeRef:(CFXMLTreeRef)ref;
	-(XMLParser *)addTree:(NSString *)name withAttributes:(NSDictionary *)attributesDict closed:(BOOL)flag;
@end

@implementation XMLParser

/* setData
 * Initialises the XMLParser with a data block which contains the XML data.
 */
-(BOOL)setData:(NSData *)data
{
	CFXMLTreeRef newTree;

	NS_DURING
		newTree = CFXMLTreeCreateFromDataWithError(kCFAllocatorDefault, (CFDataRef)data, NULL, kCFXMLParserNoOptions, kCFXMLNodeCurrentVersion, NULL);
	NS_HANDLER
		if (newTree != nil)
			CFRelease(newTree);
		newTree = nil;
	NS_ENDHANDLER
	if (newTree != nil)
	{
		[self setTreeRef:newTree];
		CFRelease(newTree);
		return YES;
	}
	return NO;
}

/* hasValidTree
 * Return TRUE if we have a valid tree.
 */
-(BOOL)hasValidTree
{
	return tree != nil;
}

/* treeWithCFXMLTreeRef
 * Allocates a new instance of an XMLParser with the specified tree.
 */
+(XMLParser *)treeWithCFXMLTreeRef:(CFXMLTreeRef)ref
{
	XMLParser * parser = [[XMLParser alloc] init];
	[parser setTreeRef:ref];
	return [parser autorelease];
}

/* setTreeRef
 * Initialises the XMLParser with a data block which contains the XML data.
 */
-(void)setTreeRef:(CFXMLTreeRef)treeRef
{
	if (tree != nil)
		CFRelease(tree);
	if (node != nil)
		CFRelease(node);
	tree = treeRef;
	node = CFXMLTreeGetNode(tree);
	CFRetain(tree);
	CFRetain(node);
}

/* initWithEmptyTree
 * Creates an empty XML tree to which we can add nodes.
 */
-(id)initWithEmptyTree
{
	if ((self = [self init]) != nil)
	{
		// Create the document node
		CFXMLDocumentInfo documentInfo;
		documentInfo.sourceURL = NULL;
		documentInfo.encoding = kCFStringEncodingUTF8;
		CFXMLNodeRef docNode = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeDocument, CFSTR(""), &documentInfo, kCFXMLNodeCurrentVersion);
		CFXMLTreeRef xmlDocument = CFXMLTreeCreateWithNode(kCFAllocatorDefault, docNode);
		CFRelease(docNode);
		
		// Add the XML header to the document
		CFXMLProcessingInstructionInfo instructionInfo;
		instructionInfo.dataString = CFSTR("version=\"1.0\" encoding=\"utf-8\"");
		CFXMLNodeRef instructionNode = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeProcessingInstruction, CFSTR("xml"), &instructionInfo, kCFXMLNodeCurrentVersion);
		CFXMLTreeRef instructionTree = CFXMLTreeCreateWithNode(kCFAllocatorDefault, instructionNode);
		CFTreeAppendChild(xmlDocument, instructionTree);
		CFRelease(xmlDocument);
		
		// Create the parser object from this
		[self setTreeRef:instructionTree];
		CFRelease(instructionTree);
		CFRelease(instructionNode);
	}
	return self;
}

/* init
 * Designated initialiser.
 */

-(id)init
{
	if ((self = [super init]) != nil)
	{
		tree = nil;
		node = nil;
	}
	return self;
}

/* addTree
 * Adds a sub-tree to the current tree and returns its XMLParser object.
 */
-(XMLParser *)addTree:(NSString *)name
{
	CFXMLElementInfo info;
	info.attributes = NULL;
	info.attributeOrder = NULL;
	info.isEmpty = NO;

	CFXMLNodeRef newTreeNode = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeElement, (CFStringRef)name, &info, kCFXMLNodeCurrentVersion);
	CFXMLTreeRef newTree = CFXMLTreeCreateWithNode(kCFAllocatorDefault, newTreeNode);
	CFTreeAppendChild(tree, newTree);

	// Create the parser object from this
	XMLParser * newParser = [XMLParser treeWithCFXMLTreeRef:newTree];
	CFRelease(newTreeNode);
	CFRelease(newTree);
	return newParser;
}

/* addTree:withElement
 * Add a new tree and give it the specified element.
 */
-(XMLParser *)addTree:(NSString *)name withElement:(NSString *)value
{
	XMLParser * newTree = [self addTree:name];
	[newTree addElement:value];
	return newTree;
}

/* addElement
 * Add an element to the tree.
 */
-(void)addElement:(NSString *)value
{
	CFStringRef escapedString = CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault, (CFStringRef)value, NULL);
	CFXMLNodeRef newNode = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeText, escapedString, NULL, kCFXMLNodeCurrentVersion);   
	CFXMLTreeRef newTree = CFXMLTreeCreateWithNode(kCFAllocatorDefault, newNode);
	CFTreeAppendChild(tree, newTree);
	CFRelease(newTree);
	CFRelease(newNode);
	CFRelease(escapedString);
}

/* addClosedTree:withAttributes
 * Add a new tree with attributes to the tree.
 */
-(XMLParser *)addClosedTree:(NSString *)name withAttributes:(NSDictionary *)attributesDict
{
	return [self addTree:name withAttributes:attributesDict closed:YES];
}

/* addTree:withAttributes
 * Add a new tree with attributes to the tree.
 */
-(XMLParser *)addTree:(NSString *)name withAttributes:(NSDictionary *)attributesDict
{
	return [self addTree:name withAttributes:attributesDict closed:NO];
}

/* addTree:withAttributes:closed
 * Add a new tree with attributes to the tree.
 */
-(XMLParser *)addTree:(NSString *)name withAttributes:(NSDictionary *)attributesDict closed:(BOOL)flag
{
	CFXMLElementInfo info;
	info.attributes = (CFDictionaryRef)attributesDict;
	info.attributeOrder = (CFArrayRef)[attributesDict allKeys];
	info.isEmpty = flag;

	CFXMLNodeRef newNode = CFXMLNodeCreate (kCFAllocatorDefault, kCFXMLNodeTypeElement, (CFStringRef)name, &info, kCFXMLNodeCurrentVersion);   
	CFXMLTreeRef newTree = CFXMLTreeCreateWithNode(kCFAllocatorDefault, newNode);
	CFTreeAppendChild(tree, newTree);

	// Create the parser object from this
	XMLParser * newParser = [XMLParser treeWithCFXMLTreeRef:newTree];
	CFRelease(newTree);
	CFRelease(newNode);
	return newParser;
}

/* treeByIndex
 * Returns an XMLParser object for the child tree at the specified index.
 */
-(XMLParser *)treeByIndex:(CFIndex)index
{
	return [XMLParser treeWithCFXMLTreeRef:CFTreeGetChildAtIndex(tree, index)];
}

/* treeByPath
 * Retrieves a tree located by a specified sub-nesting of XML nodes. For example, given the
 * following XML document:
 *
 *   <root>
 *		<body>
 *			<element></element>
 *		</body>
 *   </root>
 *
 * Then treeByPath:@"root/body/element" will return the tree for the <element> node. If any
 * element does not exist, it returns nil.
 */
-(XMLParser *)treeByPath:(NSString *)path
{
	NSArray * pathElements = [path componentsSeparatedByString:@"/"];
	XMLParser * treeFound = self;
	
	for (NSString * treeName in pathElements)
	{
		treeFound = [treeFound treeByName:treeName];
		if (treeFound == nil)
			return nil;
	}
	return treeFound;
}

/* treeByName
 * Given a node in the XML tree, this returns the sub-tree with the specified name or nil
 * if the tree cannot be found.
 */
-(XMLParser *)treeByName:(NSString *)name
{
	CFIndex count = CFTreeGetChildCount(tree);
	CFIndex index;
	
	for (index = count - 1; index >= 0; --index)
	{
		CFXMLTreeRef subTree = CFTreeGetChildAtIndex(tree, index);
		CFXMLNodeRef subNode = CFXMLTreeGetNode(subTree);
		if ([name isEqualToString:(NSString *)CFXMLNodeGetString(subNode)])
			return [XMLParser treeWithCFXMLTreeRef:subTree];
	}
	return nil;
}

/* countOfChildren
 * Count of children of this tree
 */
-(CFIndex)countOfChildren
{
	return CFTreeGetChildCount(tree);
}

/* xmlForTree
 * Returns the XML text for the specified tree.
 */
-(NSString *)xmlForTree
{
	NSData * data = (NSData *)CFXMLTreeCreateXMLData(kCFAllocatorDefault, tree);
	NSString * xmlString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	CFRelease(data);
	return xmlString;
}

/* description
 * Make this return the XML string which is pretty useful.
 */
-(NSString *)description
{
	return [self xmlForTree];
}

/* attributesForTree
 * Returns a dictionary of all attributes on the current tree.
 */
-(NSDictionary *)attributesForTree
{
	if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeElement )
	{
		CFXMLElementInfo eInfo = *(CFXMLElementInfo *)CFXMLNodeGetInfoPtr(node);
		NSDictionary * dict = (NSDictionary *)eInfo.attributes;
		NSMutableDictionary * newDict = [[NSMutableDictionary alloc] init];

		// Make a copy of the attributes dictionary but force the keys to
		// lowercase.
		for (NSString * keyName in dict)
		{
			[newDict setObject:[dict objectForKey:keyName] forKey:[keyName lowercaseString]];
		}
		return [newDict autorelease];
	}
	return nil;
}

/* valueOfAttribute
 * Returns the value of the named attribute of the specified node. If the node is a processing instruction
 * then what we obtain from CFXMLNodeGetInfoPtr is a pointer to a CFXMLProcessingInstructionInfo structure
 * which encodes the entire processing instructions as a single string. Thus to obtain the 'attribute' that
 * equates to the processing instruction element we're interested in we need to parse that string to extract
 * the value.
 */
-(NSString *)valueOfAttribute:(NSString *)attributeName
{
	if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeElement)
	{
		CFXMLElementInfo eInfo = *(CFXMLElementInfo *)CFXMLNodeGetInfoPtr(node);
		if (eInfo.attributes != nil)
		{
			return (NSString *)CFDictionaryGetValue(eInfo.attributes, attributeName);
		}
	}
	else if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeProcessingInstruction)
	{
		CFXMLProcessingInstructionInfo eInfo = *(CFXMLProcessingInstructionInfo *)CFXMLNodeGetInfoPtr(node);
		NSScanner * scanner = [NSScanner scannerWithString:(NSString *)eInfo.dataString];
		while (![scanner isAtEnd])
		{
			NSString * instructionName = nil;
			NSString * instructionValue = nil;

			[scanner scanUpToString:@"=" intoString:&instructionName];
			[scanner scanString:@"=" intoString:nil];
			[scanner scanUpToString:@" " intoString:&instructionValue];
			
			if (instructionName != nil && instructionValue != nil)
			{
				if ([instructionName isEqualToString:attributeName])
					return [instructionValue stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
			}
		}
	}
	return nil;
}

/* nodeName
 * Returns the name of the node of this tree.
 */
-(NSString *)nodeName
{
	return (NSString *)CFXMLNodeGetString(node);
}

/* valueOfElement
 * Returns the value of the element of the specified tree. Special case for handling application/xhtml+xml which
 * is a bunch of XML/HTML embedded in the tree without a CDATA. In order to get the raw text, we need to extract
 * the XML data itself and append it as we go along.
 */
-(NSString *)valueOfElement
{
	NSMutableString * valueString = [NSMutableString stringWithCapacity:16];

	CFIndex count = CFTreeGetChildCount(tree);
	CFIndex index;

	for (index = 0; index < count; ++index)
	{
        if (index > 20000)  // there is an episodic problem with some Flickr feeds, which contain multiple <br /> tags ;
            break;          // so, we speedup things a little...
		CFXMLTreeRef subTree = CFTreeGetChildAtIndex(tree, index);
		CFXMLNodeRef subNode = CFXMLTreeGetNode(subTree);
		CFXMLNodeTypeCode type = CFXMLNodeGetTypeCode(subNode);
		
		if (type== kCFXMLNodeTypeElement) // XML or HTML...
		{
			CFDataRef valueData = CFXMLTreeCreateXMLData(NULL, subTree);

			NSString * nString = [[NSString alloc] initWithBytes:CFDataGetBytePtr(valueData) length:CFDataGetLength(valueData) encoding:NSUTF8StringEncoding];
			[valueString appendString:nString];
			[nString release];

			CFRelease(valueData);
		}
		else //CDATA, string...
		{
			NSString * valueName = (NSString *)CFXMLNodeGetString(subNode);
			if (valueName != nil)
			{
				if (type == kCFXMLNodeTypeEntityReference)
					valueName = [NSString mapEntityToString:valueName];
				[valueString appendString:valueName];
			}
		}
	}
	return valueString;
}

/* quoteAttributes
 * Scan the specified string and convert HTML literal characters to their entity equivalents.
 */
+(NSString *)quoteAttributes:(NSString *)stringToProcess
{
	NSMutableString * newString = [NSMutableString stringWithString:stringToProcess];
	[newString replaceString:@"&" withString:@"&amp;"];
	[newString replaceString:@"<" withString:@"&lt;"];
	[newString replaceString:@">" withString:@"&gt;"];
	[newString replaceString:@"\"" withString:@"&quot;"];
	[newString replaceString:@"'" withString:@"&apos;"];
	return newString;
}



/* parseXMLDate
 * Parse a date in an XML header into an NSCalendarDate. This is horribly expensive and needs
 * to be replaced with a parser that can handle these formats:
 *
 *   2005-10-23T10:12:22-4:00
 *   2005-10-23T10:12:22
 *   2005-10-23T10:12:22Z
 *   Mon, 10 Oct 2005 10:12:22 -4:00
 *   10 Oct 2005 10:12:22 -4:00
 *
 * These are the formats that I've discovered so far.
 */
+(NSDate *)parseXMLDate:(NSString *)dateString
{	
	int yearValue = 0;
	int monthValue = 1;
	int dayValue = 0;
	int hourValue = 0;
	int minuteValue = 0;
	int secondValue = 0;
	int tzOffset = 0;
	
	//We handle garbage there! (At least 1/1/00, so four digit)
	if ([[dateString stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]] length] < 4) return nil;
	
	NSDate *curlDate = [AppController getDateFromString:dateString];
	
	if (curlDate != nil)
		return curlDate;

	// Otherwise do it ourselves.
	// Expect the string to be loosely like a ISO 8601 subset
	NSScanner * scanner = [NSScanner scannerWithString:dateString];
	
	[scanner setScanLocation:0u];
	if (![scanner scanInt:&yearValue])
		return nil;
	if (yearValue < 100)
		yearValue += 2000;
	if ([scanner scanString:@"-" intoString:nil])
	{
		if (![scanner scanInt:&monthValue])
			return nil;
		if (monthValue < 1 || monthValue > 12)
			return nil;
		if ([scanner scanString:@"-" intoString:nil])
		{
			if (![scanner scanInt:&dayValue])
				return nil;
			if (dayValue < 1 || dayValue > 31)
				return nil;
		}
	}

	// Parse the time portion.
	// (I discovered that GMail sometimes returns a timestamp with 24 as the hour
	// portion although this is clearly contrary to the RFC spec. So be
	// prepared for things like this.)
	if ([scanner scanString:@"T" intoString:nil])
	{
		if (![scanner scanInt:&hourValue])
			return nil;
		hourValue %= 24;
		if ([scanner scanString:@":" intoString:nil])
		{
			if (![scanner scanInt:&minuteValue])
				return nil;
			if (minuteValue < 0 || minuteValue > 59)
				return nil;
			if ([scanner scanString:@":" intoString:nil] || [scanner scanString:@"." intoString:nil])
			{
				if (![scanner scanInt:&secondValue])
					return nil;
				if (secondValue < 0 || secondValue > 59)
					return nil;
				// Drop any fractional seconds
				if ([scanner scanString:@"." intoString:nil])
				{
					if (![scanner scanInt:nil])
						return nil;
				}
			}
		}
	}
	else
	{
		// If no time is specified, set the time to 11:59pm,
		// so new articles within the last 24 hours are detected.
		hourValue = 23;
		minuteValue = 59;
	}

	// At this point we're at any potential timezone
	// tzOffset needs to be the number of seconds since GMT
	if ([scanner scanString:@"Z" intoString:nil])
		tzOffset = 0;
	else if (![scanner isAtEnd])
	{
		if (![scanner scanInt:&tzOffset])
			return nil;
		if (tzOffset > 12)
			return nil;
	}

	// Now combine the whole thing into a date we know about.
	NSTimeZone * tzValue = [NSTimeZone timeZoneForSecondsFromGMT:tzOffset * 60 * 60];
	return [NSCalendarDate dateWithYear:yearValue month:monthValue day:dayValue hour:hourValue minute:minuteValue second:secondValue timeZone:tzValue];
}

/* dealloc
 * Clean up when we're done.
 */
-(void)dealloc
{
	if (node != nil)
		CFRelease(node);
	if (tree != nil)
		CFRelease(tree);
	[super dealloc];
}
@end
