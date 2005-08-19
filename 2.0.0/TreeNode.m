//
//  TreeNode.m
//  Vienna
//
//  Created by Steve on Sat Jan 31 2004.
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

#import "TreeNode.h"

@implementation TreeNode

/* init
 * Initialises a treenode.
 */
-(id)init:(TreeNode *)parent folder:(Folder *)theFolder canHaveChildren:(BOOL)childflag
{
	if ((self = [super init]) != nil)
 	{
		int folderId = (theFolder ? [theFolder itemId] : MA_Root_Folder);
		[self setFolder:theFolder];
		[self setParentNode:parent];
		[self setCanHaveChildren:childflag];
		[self setNodeId:folderId];
		if (parent != nil)
		{
			[parent addChild:self];
			[self release];
		}
		children = [[NSMutableArray array] retain];
	}
	return self;
}

/* addChild
 * Add the specified node to the our list of children. The position at which the new child
 * is added depends on the type of the folder associated with the node and thus this code
 * is tightly coupled with the folder view and database. Specifically:
 *
 * 1. The folder type value dictates the order of each type relative to each other.
 * 2. Within a specified type, all folders are organised by name in ascending order.
 *
 * This function does not fail. It is assumed that the child can always be inserted into
 * place one way or the other.
 */
-(void)addChild:(TreeNode *)child
{
	NSAssert(canHaveChildren, @"Trying to add children to a node that cannot have children (canHaveChildren==NO)");
	TreeNode * previousChild = nil;
	TreeNode * forwardChild = nil;
	unsigned int insertIndex = 0;

	if ([children count] > 0)
		forwardChild = [children objectAtIndex:0];
	while (insertIndex < [children count])
	{
		TreeNode * theChild = [children objectAtIndex:insertIndex];
		Folder * theChildFolder = [theChild folder];
		Folder * ourChildFolder = [child folder];

		if (FolderType(ourChildFolder) < FolderType(theChildFolder))
			break;
		else if (IsSameFolderType(theChildFolder, ourChildFolder))
		{
			NSString * theChildName = [theChildFolder name];
			NSString * ourChildName = [ourChildFolder name];
			if ([theChildName caseInsensitiveCompare:ourChildName] == NSOrderedDescending)
				break;
		}
		previousChild = theChild;
		++insertIndex;
	}
	[children insertObject:child atIndex:insertIndex];
	if (previousChild)
	{
		forwardChild = [previousChild nextChild];
		[previousChild setNextChild:child];
	}
	[child setNextChild:forwardChild];
}

/* removeChild
 * Remove the specified child from the node list and any children
 * that it may have.
 */
-(void)removeChild:(TreeNode *)child andChildren:(BOOL)removeChildrenFlag
{
	NSEnumerator * enumerator = [children objectEnumerator];
	TreeNode * previousChild = nil;
	TreeNode * node;

	while ((node = [enumerator nextObject]) != nil)
	{
		if (node == child)
		{
			if (previousChild)
				[previousChild setNextChild:[node nextChild]];
			if (removeChildrenFlag)
				[node removeChildren];
			[children removeObject:node];
			break;
		}
		previousChild = node;
	}
}

/* removeChildren
 * Removes all of our child nodes.
 */
-(void)removeChildren
{
	[children removeAllObjects];
}

/* nodeFromID
 * Searches down from the current node to find the node that
 * has the given ID.
 */
-(TreeNode *)nodeFromID:(int)n
{
	NSEnumerator * enumerator = [children objectEnumerator];
	TreeNode * node;

	if ([self nodeId] == n)
		return self;
	while ((node = [enumerator nextObject]))
	{
		TreeNode * theNode;
		if ((theNode = [node nodeFromID:n]) != nil)
			return theNode;
	}
	return nil;
}

/* childByName
 * Returns the TreeNode for the specified named child
 */
-(TreeNode *)childByName:(NSString *)childName
{
	NSEnumerator * enumerator = [children objectEnumerator];
	TreeNode * node;
	
	while ((node = [enumerator nextObject]))
	{
		if ([childName isEqual:[node nodeName]])
			return node;
	}
	return nil;
}

/* childByIndex
 * Returns the TreeNode for the child at the specified index offset. (Note that we don't
 * assert index here. The objectAtIndex function will take care of that for us.)
 */
-(TreeNode *)childByIndex:(int)index
{
	return [children objectAtIndex:index];
}

/* setParentNode
 * Sets a treenode's parent
 */
-(void)setParentNode:(TreeNode *)parent
{
	parentNode = parent;
}

/* setNextChild
 * Sets the specified child as the next child.
 */
-(void)setNextChild:(TreeNode *)child
{
	nextChild = child;
}

/* parentNode
 * Returns our parent node.
 */
-(TreeNode *)parentNode
{
	return parentNode;
}

/* nextChild
 * Returns the next child.
 */
-(TreeNode *)nextChild
{
	return nextChild;
}

/* firstChild
 * Returns the first child node or nil if we have no children
 */
-(TreeNode *)firstChild
{
	if ([children count] == 0)
		return nil;
	return [children objectAtIndex:0];
}

/* setNodeId
 * Sets a node's unique Id.
 */
-(void)setNodeId:(int)n
{
	nodeId = n;
}

/* nodeId
 * Returns the node's ID
 */
-(int)nodeId
{
	return nodeId;
}

/* setFolder
 * Sets the folder associated with this node.
 */
-(void)setFolder:(Folder *)newFolder
{
	[newFolder retain];
	[folder release];
	folder = newFolder;
}

/* folder
 * Returns the folder associated with the node
 */
-(Folder *)folder
{
	return folder;
}

/* nodeName
 * Returns the node's name which is basically the name of the folder
 * associated with the node. If no folder is associated with this node
 * then the name is an empty string.
 */
-(NSString *)nodeName
{
	return folder ? [folder name] : @"";
}

/* countOfChildren
 * Returns the number of direct child nodes of this node
 */
-(int)countOfChildren
{
	return [children count];
}

/* setCanHaveChildren
 * Sets the flag which specifies whether or not this node can have
 * children. This is not the same as actually adding children. The
 * outline view sets the expand symbol based on whether or not a
 * node item is ever expandable.
 */
-(void)setCanHaveChildren:(BOOL)childFlag
{
	canHaveChildren = childFlag;
}

/* canHaveChildren
 * Returns whether or not this node can have children.
 */
-(BOOL)canHaveChildren
{
	return canHaveChildren;
}

/* description
 * Returns a TreeNode description
 */
-(NSString *)description
{
	return [NSString stringWithFormat:@"%@ (Parent=%d, Sibling=%d, # of children=%d)", [folder name], parentNode, nextChild, [children count]];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[children release];
	[folder release];
	[super dealloc];
}
@end
