//
//  Folder.h
//  Vienna
//
//  Created by Steve on Thu Feb 19 2004.
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
#import "Message.h"

// Folder types
//   MA_Root_Folder = the abstract root folder
//   MA_Group_Folder = a folder used to group other folders
//   MA_Smart_Folder = the messages are dynamically collected by a custom query
//   MA_RSS_Folder = folder contains RSS articles
//
#define MA_Root_Folder			-1
#define MA_Smart_Folder			2
#define MA_Group_Folder			3
#define MA_RSS_Folder			4

// Macro to simplify getting folder types
#define FolderType(f)			([(f) type])
#define IsSmartFolder(f)		(([(f) type]) == MA_Smart_Folder)
#define IsRSSFolder(f)			(([(f) type]) == MA_RSS_Folder)
#define IsGroupFolder(f)		(([(f) type]) == MA_Group_Folder)
#define IsSameFolderType(f,g)	(([(f) type]) == ([(g) type]))

// Folder flags
// (These must be bitmask values!)
//   MA_FFlag_CheckForImage = asks the refresh code to update the folder image
//
#define MA_FFlag_CheckForImage		1
#define MA_FFlag_NeedCredentials	2

@interface Folder : NSObject {
	int itemId;
	int parentId;
	int unreadCount;
	int type;
	int childUnreadCount;
	unsigned int flags;
	BOOL isMessages;
	BOOL needFlush;
	NSDate * lastUpdate;
	NSMutableDictionary * attributes;
	NSMutableDictionary * messages;
}

// Accessor functions
-(id)initWithId:(int)itemId parentId:(int)parentId name:(NSString *)name type:(int)type;
-(NSString *)name;
-(NSString *)folderName;
-(NSString *)description;
-(NSString *)homePage;
-(NSString *)feedURL;
-(NSDate *)lastUpdate;
-(NSString *)lastUpdateString;
-(NSString *)username;
-(NSString *)password;
-(NSDictionary *)attributes;
-(int)parentId;
-(int)itemId;
-(int)messageCount;
-(int)unreadCount;
-(int)type;
-(unsigned int)flags;
-(NSImage *)image;
-(int)childUnreadCount;
-(void)clearMessages;
-(BOOL)needFlush;
-(void)resetFlush;
-(void)setName:(NSString *)name;
-(void)setUnreadCount:(int)count;
-(void)setType:(int)newType;
-(void)setParent:(int)newParent;
-(void)setImage:(NSImage *)newImage;
-(void)setFlag:(unsigned int)flagToSet;
-(void)clearFlag:(unsigned int)flagToClear;
-(void)setChildUnreadCount:(int)count;
-(void)setDescription:(NSString *)newDescription;
-(void)setHomePage:(NSString *)newHomePage;
-(void)setFeedURL:(NSString *)feedURL;
-(void)setUsername:(NSString *)newUsername;
-(void)setPassword:(NSString *)newPassword;
-(void)setLastUpdate:(NSDate *)newLastUpdate;
-(void)setLastUpdateString:(NSString *)newLastUpdateString;
-(NSArray *)messages;
-(Message *)messageFromID:(int)messageId;
-(void)addMessage:(Message *)newMessage;
-(void)deleteMessage:(int)messageId;
-(void)markFolderEmpty;
-(NSComparisonResult)folderNameCompare:(Folder *)otherObject;
-(NSComparisonResult)folderIDCompare:(Folder *)otherObject;
@end
