//
//  Database.m
//  Vienna
//
//  Created by Steve on Tue Feb 03 2004.
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

#import "Database.h"
#import "StringExtensions.h"
#import "Constants.h"
#import "ArticleRef.h"

// Private scope flags
#define MA_Scope_Inclusive		1
#define MA_Scope_SubFolders		2

// Private functions
@interface Database (Private)
	-(void)setDatabaseVersion:(int)newVersion;
	-(void)verifyThreadSafety;
	-(CriteriaTree *)criteriaForFolder:(int)folderId;
	-(NSArray *)arrayOfSubFolders:(Folder *)folder;
	-(NSString *)sqlScopeForFolder:(Folder *)folder flags:(int)scopeFlags;
	-(void)createInitialSmartFolder:(NSString *)folderName withCriteria:(Criteria *)criteria;
	-(int)createFolderOnDatabase:(NSString *)name underParent:(int)parentId withType:(int)type;
	-(void)executeSQL:(NSString *)sqlStatement;
	-(void)executeSQLWithFormat:(NSString *)sqlStatement, ...;
@end

// The current database version number
const int MA_Min_Supported_DB_Version = 11;
const int MA_Current_DB_Version = 12;

// There's just one database and we manage access to it through a
// singleton object.
static Database * _sharedDatabase = nil;

@implementation Database

/* init
 * General object initialization.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		inTransaction = NO;
		sqlDatabase = NULL;
		initializedFoldersArray = NO;
		initializedSmartFoldersArray = NO;
		countOfUnread = 0;
		trashFolder = nil;
		smartFoldersArray = [[NSMutableDictionary dictionary] retain];
		foldersArray = [[NSMutableDictionary dictionary] retain];
	}
	return self;
}

/* sharedDatabase
 * Returns the single instance of the refresh manager.
 */
+(Database *)sharedDatabase
{
	if (!_sharedDatabase)
	{
		_sharedDatabase = [[Database alloc] init];
		if (![_sharedDatabase initDatabase:[[NSUserDefaults standardUserDefaults] stringForKey:MAPref_DefaultDatabase]])
		{
			[_sharedDatabase release];
			_sharedDatabase = nil;
		}
	}
	return _sharedDatabase;
}

/* initDatabase
 * Initalizes the database. The database is first checked to ensure it exists
 * and, if not, it is created with all the tables.
 */
-(BOOL)initDatabase:(NSString *)databaseFileName
{
	// Don't allow nested opens
	if (sqlDatabase)
		return NO;

	// Fully expand the path and make sure it exists because if the
	// database file itself doesn't exist, we want to create it and
	// we can't create it on a non-existent path.
	NSFileManager * fileManager = [NSFileManager defaultManager];
	NSString * qualifiedDatabaseFileName = [databaseFileName stringByExpandingTildeInPath];
	NSString * databaseFolder = [qualifiedDatabaseFileName stringByDeletingLastPathComponent];
	BOOL isDir;

	if (![fileManager fileExistsAtPath:databaseFolder isDirectory:&isDir])
	{
		if (![fileManager createDirectoryAtPath:databaseFolder attributes:NULL])
		{
			NSRunAlertPanel(NSLocalizedString(@"Cannot create database folder", nil),
							NSLocalizedString(@"Cannot create database folder text", nil),
							NSLocalizedString(@"Close", nil), @"", @"",
							databaseFolder);
			return NO;
		}
	}
	
	// Open the database at the well known location
	sqlDatabase = [[SQLDatabase alloc] initWithFile:qualifiedDatabaseFileName];
	if (!sqlDatabase || ![sqlDatabase open])
		return NO;

	// Get the info table. If it doesn't exist then the database is new
	SQLResult * results = [sqlDatabase performQuery:@"select version from info"];
	databaseVersion = 0;
	if (results && [results rowCount])
	{
		NSString * versionString = [[results rowAtIndex:0] stringForColumn:@"version"];
		databaseVersion = [versionString intValue];
	}
	[results release];

	// Save this thread handle to ensure we trap cases of calling the db on
	// the wrong thread.
	mainThread = [NSThread currentThread];

	// Handle upgrade here because we may want to create a new database
	if (databaseVersion == MA_Min_Supported_DB_Version)
	{
		NSString * backupDatabaseFileName = [qualifiedDatabaseFileName stringByAppendingPathExtension:@"bak"];
		int option = NSRunAlertPanel(NSLocalizedString(@"Upgrade Title", nil),
									 NSLocalizedString(@"Upgrade Text", nil),
									 NSLocalizedString(@"Upgrade", nil),
									 NSLocalizedString(@"New Database", nil),
									 NSLocalizedString(@"Exit", nil),
									 backupDatabaseFileName);
		if (option == -1)
			return NO;
		
		if (option == 0)
		{
			[[NSFileManager defaultManager] movePath:qualifiedDatabaseFileName toPath:backupDatabaseFileName handler:nil];
			sqlDatabase = [[SQLDatabase alloc] initWithFile:qualifiedDatabaseFileName];
			if (!sqlDatabase || ![sqlDatabase open])
				return NO;
			databaseVersion = 0;
		}

		if (option == 1)
			[[NSFileManager defaultManager] copyPath:qualifiedDatabaseFileName toPath:backupDatabaseFileName handler:nil];
	}
	
	
	// Create the tables when the database is empty.
	if (databaseVersion == 0)
	{
		// Create the tables
		[self executeSQL:@"create table info (version, last_opened)"];
		[self executeSQL:@"create table folders (folder_id integer primary key, parent_id, foldername, unread_count, last_update, type, flags)"];
		[self executeSQL:@"create table messages (message_id, folder_id, parent_id, read_flag, marked_flag, deleted_flag, title, sender, link, date, text)"];
		[self executeSQL:@"create table smart_folders (folder_id, search_string)"];
		[self executeSQL:@"create table rss_folders (folder_id, feed_url, username, last_update_string, description, home_page, bloglines_id)"];
		[self executeSQL:@"create index messages_folder_idx on messages (folder_id)"];

		// Create a criteria to find all marked messages
		Criteria * markedCriteria = [[Criteria alloc] initWithField:MA_Field_Flagged withOperator:MA_CritOper_Is withValue:@"Yes"];
		[self createInitialSmartFolder:NSLocalizedString(@"Marked Articles", nil) withCriteria:markedCriteria];
		[markedCriteria release];

		// Create a criteria to show all unread messages
		Criteria * unreadCriteria = [[Criteria alloc] initWithField:MA_Field_Read withOperator:MA_CritOper_Is withValue:@"No"];
		[self createInitialSmartFolder:NSLocalizedString(@"Unread Articles", nil) withCriteria:unreadCriteria];
		[unreadCriteria release];
		
		// Create a criteria to show all messages received today
		Criteria * todayCriteria = [[Criteria alloc] initWithField:MA_Field_Date withOperator:MA_CritOper_Is withValue:@"today"];
		[self createInitialSmartFolder:NSLocalizedString(@"Today's Articles", nil) withCriteria:todayCriteria];
		[todayCriteria release];

		// Create the trash folder
		[self executeSQLWithFormat:@"insert into folders (parent_id, foldername, unread_count, last_update, type, flags) values (-1, '%@', 0, 0, %d, 0)",
			NSLocalizedString(@"Trash", nil),
			MA_Trash_Folder];
		
		// Set the initial version
		databaseVersion = MA_Current_DB_Version;
		[self executeSQLWithFormat:@"insert into info (version) values (%d)", databaseVersion];
	}

	// Handle 'retyping' the message_id field when going from v11 to v12. This
	// code should be ripped out after we're sure everybody is now on a v12 db.
	if (databaseVersion == 11)
	{
		[self beginTransaction];

		// Add the deleted_flag column to the messages table
		[self executeSQL:@"alter table messages add column deleted_flag"];

		// Retype the message_id field to change it to a string since it was originally an integer
		// field in v11 and earlier.
		SQLResult * results = [sqlDatabase performQuery:@"select message_id, folder_id from messages"];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;

			while ((row = [enumerator nextObject]))
			{
				int messageNumber = [[row stringForColumn:@"message_id"] intValue];
				int folderId = [[row stringForColumn:@"folder_id"] intValue];

				NSString * guid = [NSString stringWithFormat:@"%d", messageNumber];
				NSString * preparedGuid = [SQLDatabase prepareStringForQuery:guid];
				[self executeSQLWithFormat:@"update messages set deleted_flag=0, message_id='%@' where message_id=%d and folder_id=%d",
					preparedGuid,
					messageNumber,
					folderId];
			}
		}
		[results release];

		// Create the trash folder
		[self executeSQLWithFormat:@"insert into folders (parent_id, foldername, unread_count, last_update, type, flags) values (-1, '%@', 0, 0, %d, 0)",
			NSLocalizedString(@"Trash", nil), MA_Trash_Folder];
		
		// Set the new version
		[self setDatabaseVersion:MA_Current_DB_Version];
		[self commitTransaction];
	}

	// Trap unsupported databases
	if (databaseVersion < MA_Min_Supported_DB_Version)
	{
		NSRunAlertPanel(NSLocalizedString(@"Unrecognised database format", nil),
						NSLocalizedString(@"Unrecognised database format text", nil),
						NSLocalizedString(@"Close", nil), @"", @"",
						qualifiedDatabaseFileName);
		return NO;
	}

	// Initial check if the database is read-only
	[self syncLastUpdate];

	// Create fields
	fieldsByName = [[NSMutableDictionary dictionary] retain];
	fieldsOrdered = [[NSMutableArray alloc] init];

	[self addField:MA_Field_Read type:MA_FieldType_Flag tag:MA_FieldID_Read sqlField:@"read_flag" visible:YES width:17];
	[self addField:MA_Field_Flagged type:MA_FieldType_Flag tag:MA_FieldID_Flagged sqlField:@"marked_flag" visible:YES width:15];
	[self addField:MA_Field_Deleted type:MA_FieldType_Flag tag:MA_FieldID_Deleted sqlField:@"deleted_flag" visible:NO width:15];
	[self addField:MA_Field_Comments type:MA_FieldType_Integer tag:MA_FieldID_Comments sqlField:@"comment_flag" visible:YES width:15];
	[self addField:MA_Field_GUID type:MA_FieldType_Integer tag:MA_FieldID_GUID sqlField:@"message_id" visible:NO width:72];
	[self addField:MA_Field_Subject type:MA_FieldType_String tag:MA_FieldID_Subject sqlField:@"title" visible:YES width:472];
	[self addField:MA_Field_Folder type:MA_FieldType_Folder tag:MA_FieldID_Folder sqlField:@"folder_id" visible:NO width:130];
	[self addField:MA_Field_Date type:MA_FieldType_Date tag:MA_FieldID_Date sqlField:@"date" visible:YES width:152];
	[self addField:MA_Field_Parent type:MA_FieldType_Integer tag:MA_FieldID_Parent sqlField:@"parent_id" visible:NO width:72];
	[self addField:MA_Field_Author type:MA_FieldType_String tag:MA_FieldID_Author sqlField:@"sender" visible:YES width:138];
	[self addField:MA_Field_Link type:MA_FieldType_String tag:MA_FieldID_Link sqlField:@"link" visible:NO width:138];
	[self addField:MA_Field_Text type:MA_FieldType_String tag:MA_FieldID_Text sqlField:@"text" visible:NO width:152];
	[self addField:MA_Field_Headlines type:MA_FieldType_String tag:MA_FieldID_Headlines sqlField:@"" visible:NO width:100];
	return YES;
}

/* createInitialSmartFolder
 * Create a smart folder in the database as part of creating a new database. This is intended to be
 * called from the database initialisation code and makes a number of assumptions about the state
 * of the class at that point. It is NOT a substitute for addSmartFolder. Specifically it does
 * not add the new folder to the internal cache nor broadcast any notifications.
 */
-(void)createInitialSmartFolder:(NSString *)folderName withCriteria:(Criteria *)criteria
{
	if ([self createFolderOnDatabase:folderName underParent:MA_Root_Folder withType:MA_Smart_Folder] >= 0)
	{
		CriteriaTree * criteriaTree = [[CriteriaTree alloc] init];
		[criteriaTree addCriteria:criteria];
		
		NSString * preparedCriteriaString = [SQLDatabase prepareStringForQuery:[criteriaTree string]];
		
		[self executeSQLWithFormat:@"insert into smart_folders (folder_id, search_string) values (%d, '%@')", [sqlDatabase lastInsertRowId], preparedCriteriaString];
		[criteriaTree release];
	}
}

/* executeSQL
 * Executes the specified SQL statement and discards the result. Should be used for
 * SQL statements that do not return results.
 */
-(void)executeSQL:(NSString *)sqlStatement
{
	[self verifyThreadSafety];
	[[sqlDatabase performQuery:sqlStatement] release];
}

/* executeSQLWithFormat
 * Formats and executes the specified SQL statement and discards the result. Should be used for
 * SQL statements that do not return results.
 */
-(void)executeSQLWithFormat:(NSString *)sqlStatement, ...
{
	va_list arguments;
	va_start(arguments, sqlStatement);
	NSString * query = [[NSString alloc] initWithFormat:sqlStatement arguments:arguments];
	[self executeSQL:query];
	[query release];
}

/* verifyThreadSafety
 * In debug mode we assert if the caller thread isn't the thread on which the database
 * was created. In release mode, we do nothing.
 */
-(void)verifyThreadSafety
{
	NSAssert([NSThread currentThread] == mainThread, @"Calling database on wrong thread!");
}

/* syncLastUpdate
 * Call this function to update the field in the info table which contains the last_updated
 * date. This is basically auditing data and is only called when the database is first opened
 * in this session.
 */
-(void)syncLastUpdate
{
	[self verifyThreadSafety];
	SQLResult * result = [sqlDatabase performQueryWithFormat:@"update info set last_opened='%@'", [NSDate date]];
	readOnly = (result == nil);
	[result release];
}

/* countOfUnread
 * Return the total number of unread messages in the database.
 */
-(int)countOfUnread
{
	return countOfUnread;
}

/* addField
 * Add the specified field to our fields array.
 */
-(void)addField:(NSString *)name type:(int)type tag:(int)tag sqlField:(NSString *)sqlField visible:(BOOL)visible width:(int)width
{
	Field * field = [[Field alloc] init];
	if (field != nil)
	{
		[field setName:name];
		[field setDisplayName:NSLocalizedString(name, nil)];
		[field setType:type];
		[field setTag:tag];
		[field setVisible:visible];
		[field setWidth:width];
		[field setSqlField:sqlField];
		[fieldsOrdered addObject:field];
		[fieldsByName setValue:field forKey:name];
		[field release];
	}
}

/* arrayOfFields
 * Return the array of fields.
 */
-(NSArray *)arrayOfFields
{
	return fieldsOrdered;
}

/* fieldByTitle
 * Given a name, this function returns the field represented by
 * that name.
 */
-(Field *)fieldByName:(NSString *)name
{
	return [fieldsByName valueForKey:name];
}

/* databaseVersion
 * Return the database version.
 */
-(int)databaseVersion
{
	return databaseVersion;
}

/* setDatabaseVersion
 * Sets the version stamp in the database.
 */
-(void)setDatabaseVersion:(int)newVersion
{
	[self executeSQLWithFormat:@"update info set version=%d", newVersion];
	databaseVersion = newVersion;
}

/* readOnly
 * Returns whether or not this database is read-only.
 */
-(BOOL)readOnly
{
	return readOnly;
}

/* beginTransaction
 * Starts a SQL transaction.
 */
-(void)beginTransaction
{
	NSAssert(!inTransaction, @"Whoops! Already in a transaction. You forgot to call commitTransaction somewhere");
	[self executeSQL:@"begin transaction"];
	inTransaction = YES;
}

/* commitTransaction
 * Commits a SQL transaction.
 */
-(void)commitTransaction
{
	NSAssert(inTransaction, @"Whoops! Not in a transaction. You forgot to call beginTransaction first");
	[self executeSQL:@"commit transaction"];
	inTransaction = NO;
}

/* compactDatabase
 * Compact the database using the vacuum command.
 */
-(void)compactDatabase
{
	if (!readOnly)
		[self executeSQL:@"vacuum"];
}

/* setFolderLastUpdate
 * Sets the date when the folder was last updated. The flushFolder function must be
 * called for the parent folder to flush this to the database.
 */
-(void)setFolderLastUpdate:(int)folderId lastUpdate:(NSDate *)lastUpdate
{
	// Exit now if we're read-only
	if (readOnly)
		return;

	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
		[folder setLastUpdate:lastUpdate];
}

/* setFolderFeedURL
 * Change the URL of the feed on the specified RSS folder subscription.
 */
-(BOOL)setFolderFeedURL:(int)folderId newFeedURL:(NSString *)url
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;
	
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil && ![[folder feedURL] isEqualToString:url])
	{
		NSString * preparedURL = [SQLDatabase prepareStringForQuery:url];

		[folder setFeedURL:url];
		[self executeSQLWithFormat:@"update rss_folders set feed_url='%@' where folder_id=%d", preparedURL, folderId];
	}
	return YES;
}

/* addRSSFolder
 * Add an RSS Feed folder and return the ID of the new folder. One distinction is that
 * RSS folder names need not be unique within the parent
 */
-(int)addRSSFolder:(NSString *)feedName underParent:(int)parentId subscriptionURL:(NSString *)url
{
	// Add the feed URL to the RSS feed table
	int folderId = [self addFolder:parentId folderName:feedName type:MA_RSS_Folder mustBeUnique:NO];
	if (folderId != -1)
	{
		NSString * preparedURL = [SQLDatabase prepareStringForQuery:url];

		[self verifyThreadSafety];
		SQLResult * results = [sqlDatabase performQueryWithFormat:
					@"insert into rss_folders (folder_id, description, username, home_page, last_update_string, feed_url, bloglines_id) "
					 "values (%d, '', '', '', '', '%@', %d)",
					folderId,
					preparedURL,
					MA_NonBloglines_Folder];
		if (!results)
			return -1;

		// Add this new folder to our internal cache
		Folder * folder = [self folderFromID:folderId];
		[folder setFeedURL:url];
		[results release];
	}
	return folderId;
}

/* addFolder
 * Create a new folder under the specified parent and give it the requested name and type. If
 * mustBeUnique is YES then we check to ensure that the folder name hasn't already been used. If
 * it has then we simply return the ID of the existing folder without changing its type. If we
 * hit an error, the function returns -1.
 */
-(int)addFolder:(int)parentId folderName:(NSString *)name type:(int)type mustBeUnique:(BOOL)mustBeUnique
{
	Folder * folder = nil;

	// Prime the cache
	[self initFolderArray];

	// Exit now if we're read-only
	if (readOnly)
		return -1;

	// If the folder must be unique then check for its
	// existence by name and if found, return its existing ID.
	if (mustBeUnique)
	{
		folder = [self folderFromName:name];
		if (folder)
			return [folder itemId];
	}

	// Here we create the folder anew.
	int newItemId = [self createFolderOnDatabase:name underParent:parentId withType:type];
	if (newItemId != -1)
	{
		// Add this new folder to our internal cache. If this is an RSS
		// folder, mark it so that somewhere down the line we'll request the
		// image for the folder.
		folder = [[[Folder alloc] initWithId:newItemId parentId:parentId name:name type:type] autorelease];
		if (type == MA_RSS_Folder)
			[folder setFlag:MA_FFlag_CheckForImage];
		[foldersArray setObject:folder forKey:[NSNumber numberWithInt:newItemId]];

		// Send a notification when new folders are added
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderAdded" object:folder];
	}
	return newItemId;
}

/* createFolderOnDatabase:underParent:withType
 * Generic (and internal!) function that creates a new folder in the database. It just creates
 * the folder without any real sanity checks which are assumed to have been done by the caller.
 * Returns the ID of the newly created folder or -1 if we failed.
 */
-(int)createFolderOnDatabase:(NSString *)name underParent:(int)parentId withType:(int)type
{
	NSString * preparedName = [SQLDatabase prepareStringForQuery:name];
	int newItemId = -1;
	int flags = 0;
	
	// For new folders, last update is set to before now
	NSDate * lastUpdate = [NSDate distantPast];
	NSTimeInterval interval = [lastUpdate timeIntervalSince1970];

	// Require an image check if we're an RSS folder
	if (type == MA_RSS_Folder)
		flags = MA_FFlag_CheckForImage;

	// Create the folder in the database. One thing to watch out for here that has
	// bit me before. When adding new fields to the folders table, remember to init
	// the field here even if its just to an empty value.
	[self verifyThreadSafety];
	SQLResult * results = [sqlDatabase performQueryWithFormat:
		@"insert into folders (foldername, parent_id, unread_count, last_update, type, flags) values('%@', %d, 0, %f, %d, %d)",
		preparedName,
		parentId,
		interval,
		type,
		flags];
	
	// Quick way of getting the last autoincrement primary key value (the folder_id).
	if (results)
	{
		newItemId = [sqlDatabase lastInsertRowId];
		[results release];
	}
	return newItemId;
}

/* untitledFeedFolderName
 * Returns the name given to untitled feed folders.
 */
-(NSString *)untitledFeedFolderName
{
	return NSLocalizedString(@"(Untitled Feed)", nil);
}

/* wrappedDeleteFolder
 * Delete the specified folder. This function should be called from within a
 * transaction wrapper since it can be very SQL intensive.
 */
-(BOOL)wrappedDeleteFolder:(int)folderId
{
	NSArray * arrayOfChildFolders = [self arrayOfFolders:folderId];
	NSEnumerator * enumerator = [arrayOfChildFolders objectEnumerator];
	Folder * folder;

	// Recurse and delete child folders
	while ((folder = [enumerator nextObject]) != nil)
		[self wrappedDeleteFolder:[folder itemId]];

	// Adjust unread counts on parents
	folder = [self folderFromID:folderId];
	int adjustment = -[folder unreadCount];
	while ([folder parentId] != MA_Root_Folder)
	{
		folder = [self folderFromID:[folder parentId]];
		[folder setChildUnreadCount:[folder childUnreadCount] + adjustment];
	}

	// Delete all messages in this folder then delete ourselves.
	folder = [self folderFromID:folderId];
	countOfUnread -= [folder unreadCount];
	if (IsSmartFolder(folder))
		[self executeSQLWithFormat:@"delete from smart_folders where folder_id=%d", folderId];

	// If this is an RSS feed, delete from the feeds
	if (IsRSSFolder(folder))
		[self executeSQLWithFormat:@"delete from rss_folders where folder_id=%d", folderId];

	// For a smart folder, the next line is a no-op but it helpfully takes care of the case where a
	// normal folder had it's type grobbed to MA_Smart_Folder.
	[self executeSQLWithFormat:@"delete from messages where folder_id=%d", folderId];
	[self executeSQLWithFormat:@"delete from folders where folder_id=%d", folderId];

	// Send a notification when the folder is deleted
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderDeleted" object:[NSNumber numberWithInt:folderId]];

	// Remove from the folders array. Do this after we send the notification
	// so that the notification handlers don't fail if they try to dereference the
	// folder.
	[foldersArray removeObjectForKey:[NSNumber numberWithInt:folderId]];
	return YES;
}

/* deleteFolder
 * Delete the specified folder. If the folder has any children, delete them too. Also delete
 * all messages associated with the folder. Then send a notification that the folder went bye-bye.
 */
-(BOOL)deleteFolder:(int)folderId
{
	BOOL result;

	// Exit now if we're read-only
	if (readOnly)
		return NO;

	[self beginTransaction];
	result = [self wrappedDeleteFolder:folderId];
	[self commitTransaction];
	return result;
}

/* setFolderName
 * Renames the specified folder.
 */
-(BOOL)setFolderName:(int)folderId newName:(NSString *)newName
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;

	// Find our folder element.
	Folder * folder = [self folderFromID:folderId];
	if (!folder)
		return NO;

	// Do nothing if the name hasn't changed. Otherwise it is wasted
	// effort, basically.
	if ([[folder name] isEqualToString:newName])
		return NO;

	[folder setName:newName];

	// Rename in the database
	NSString * preparedNewName = [SQLDatabase prepareStringForQuery:newName];
	[self executeSQLWithFormat:@"update folders set foldername='%@' where folder_id=%d", preparedNewName, folderId];

	// Send a notification that the folder has changed. It is the responsibility of the
	// notifiee that they work out that the name is the part that has changed.
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
	return YES;
}

/* setFolderDescription
 * Sets the folder description both in the internal structure and in the folder_description table.
 */
-(BOOL)setFolderDescription:(int)folderId newDescription:(NSString *)newDescription
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;
	
	// Find our folder element.
	Folder * folder = [self folderFromID:folderId];
	if (!folder)
		return NO;
	
	// Do nothing if the description hasn't changed. Otherwise it is wasted
	// effort, basically.
	if ([[folder description] isEqualToString:newDescription])
		return NO;
	
	[folder setDescription:newDescription];
	
	// Add a new description or update the one we have
	NSString * preparedNewDescription = [SQLDatabase prepareStringForQuery:newDescription];
	[self executeSQLWithFormat:@"update rss_folders set description='%@' where folder_id=%d", preparedNewDescription, folderId];

	// Send a notification that the folder has changed. It is the responsibility of the
	// notifiee that they work out that the description is the part that has changed.
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
	return YES;
}

/* setFolderHomePage
 * Sets the folder's associated URL link in both in the internal structure and in the folder_description table.
 */
-(BOOL)setFolderHomePage:(int)folderId newHomePage:(NSString *)newHomePage
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;
	
	// Find our folder element.
	Folder * folder = [self folderFromID:folderId];
	if (!folder)
		return NO;

	// Do nothing if the link hasn't changed. Otherwise it is wasted
	// effort, basically.
	if ([[folder homePage] isEqualToString:newHomePage])
		return NO;

	[folder setHomePage:newHomePage];

	// Add a new link or update the one we have
	NSString * preparedNewLink = [SQLDatabase prepareStringForQuery:newHomePage];
	[self executeSQLWithFormat:@"update rss_folders set home_page='%@' where folder_id=%d", preparedNewLink, folderId];

	// Send a notification that the folder has changed. It is the responsibility of the
	// notifiee that they work out that the link is the part that has changed.
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
	return YES;
}

/* setBloglinesId
 * Changes the Bloglines ID associated with this folder.
 */
-(BOOL)setBloglinesId:(int)folderId newBloglinesId:(long)bloglinesId
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;
	
	// Find our folder element.
	Folder * folder = [self folderFromID:folderId];
	if (!folder)
		return NO;
	
	// Do nothing if the ID hasn't changed
	if ([folder bloglinesId] == bloglinesId)
		return NO;
	
	[folder setBloglinesId:bloglinesId];
	
	// Update the ID in the database
	[self executeSQLWithFormat:@"update rss_folders set bloglines_id=%d where folder_id=%d", bloglinesId, folderId];
	
	// Send a notification that the folder has changed. It is the responsibility of the
	// notifiee that they work out that the ID is the part that has changed.
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
	return YES;
}

/* setFolderUsername
 * Sets the folder's user name in both in the internal structure and in the folder_description table.
 */
-(BOOL)setFolderUsername:(int)folderId newUsername:(NSString *)name
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;
	
	// Find our folder element.
	Folder * folder = [self folderFromID:folderId];
	if (!folder)
		return NO;
	
	// Do nothing if the link hasn't changed. Otherwise it is wasted
	// effort, basically.
	if ([[folder username] isEqualToString:name])
		return NO;
	
	[folder setUsername:name];
	
	// Add a new link or update the one we have
	NSString * preparedName = [SQLDatabase prepareStringForQuery:name];
	[self executeSQLWithFormat:@"update rss_folders set username='%@' where folder_id=%d", preparedName, folderId];
	return YES;
}

/* setParent
 * Changes the parent for the specified folder then updates the database.
 */
-(BOOL)setParent:(int)newParentID forFolder:(int)folderId
{
	Folder * folder = [self folderFromID:folderId];
	if ([folder parentId] == newParentID)
		return NO;

	// Sanity check. Make sure we're not reparenting to our
	// subordinate.
	Folder * parentFolder = [self folderFromID:newParentID];
	while (parentFolder != nil)
	{
		if ([parentFolder parentId] == folderId)
			return NO;
		parentFolder = [self folderFromID:[parentFolder parentId]];
	}

	// Adjust the child unread count for the old parent.
	parentFolder = [self folderFromID:[folder parentId]];
	while (parentFolder != nil)
	{
		[parentFolder setChildUnreadCount:[parentFolder childUnreadCount] - [folder unreadCount]];
		parentFolder = [self folderFromID:[parentFolder parentId]];
	}
	
	// Do the re-parent
	[folder setParent:newParentID];
	
	// In addition to reparenting the child, we also need to fix up the unread count for all
	// precedent parents.
	parentFolder = [self folderFromID:newParentID];
	while (parentFolder != nil)
	{
		[parentFolder setChildUnreadCount:[parentFolder childUnreadCount] + [folder unreadCount]];
		parentFolder = [self folderFromID:[parentFolder parentId]];
	}

	// Update the database now
	[self executeSQLWithFormat:@"update folders set parent_id='%d' where folder_id=%d", newParentID, folderId];
	return YES;
}

/* trashFolderId;
 * Returns the ID of the trash folder.
 */
-(int)trashFolderId
{
	return [trashFolder itemId];
}

/* folderFromID
 * Retrieve a Folder given it's ID.
 */
-(Folder *)folderFromID:(int)wantedId
{
	return [foldersArray objectForKey:[NSNumber numberWithInt:wantedId]];
}

/* folderFromName
 * Retrieve a Folder given it's name.
 */
-(Folder *)folderFromName:(NSString *)wantedName
{
	NSEnumerator * enumerator = [foldersArray objectEnumerator];
	Folder * item;
	
	while ((item = [enumerator nextObject]) != nil)
	{
		if ([[item name] isEqualToString:wantedName])
			break;
	}
	return item;
}

/* folderFromFeedURL
 * Returns the RSSFolder that is subscribed to the specified feed URL.
 */
-(Folder *)folderFromFeedURL:(NSString *)wantedFeedURL;
{
	NSEnumerator * enumerator = [foldersArray objectEnumerator];
	Folder * item;
	
	while ((item = [enumerator nextObject]) != nil)
	{
		if ([[item feedURL] isEqualToString:wantedFeedURL])
			break;
	}
	return item;
}

/* addMessage
 * Adds or updates a message in the specified folder. Returns the GUID of the
 * message that was added or updated or -1 if we couldn't add the message for
 * some reason.
 */
-(BOOL)addMessage:(int)folderID message:(Message *)message
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;

	// Make sure the folder ID is valid. We need it to decipher
	// some info before we add the message.
	Folder * folder = [self folderFromID:folderID];
	if (folder != nil)
	{
		// Prime the message cache
		[self initMessageArray:folder];

		// Extract the message data from the dictionary.
		NSString * messageText = [[message messageData] objectForKey:MA_Field_Text];
		NSString * messageTitle = [[message messageData] objectForKey:MA_Field_Subject]; 
		NSDate * messageDate = [[message messageData] objectForKey:MA_Field_Date];
		NSString * messageLink = [[message messageData] objectForKey:MA_Field_Link];
		NSString * userName = [[message messageData] objectForKey:MA_Field_Author];
		NSString * messageGuid = [message guid];
		int parentId = [message parentId];
		BOOL marked_flag = [message isFlagged];
		BOOL read_flag = [message isRead];
		BOOL deleted_flag = [message isDeleted];

		// Set some defaults
		if (messageDate == nil)
			messageDate = [NSDate date];
		if (userName == nil)
			userName = @"";

		// Parse off the title
		if (messageTitle == nil || [messageTitle isBlank])
			messageTitle = [messageText firstNonBlankLine];

		// Save date as time intervals
		NSTimeInterval interval = [messageDate timeIntervalSince1970];

		// Unread count adjustment factor
		int adjustment = 0;
		
		// Fix title and message body so they're acceptable to SQL
		NSString * preparedMessageTitle = [SQLDatabase prepareStringForQuery:messageTitle];
		NSString * preparedMessageText = [SQLDatabase prepareStringForQuery:messageText];
		NSString * preparedMessageLink = [SQLDatabase prepareStringForQuery:messageLink];
		NSString * preparedUserName = [SQLDatabase prepareStringForQuery:userName];
		NSString * preparedMessageGuid = [SQLDatabase prepareStringForQuery:messageGuid];

		// Verify we're on the right thread
		[self verifyThreadSafety];

		// Does this message already exist?
		Message * theMessage = [folder messageFromGuid:messageGuid];
		if (theMessage == nil)
		{
			SQLResult * results;

			results = [sqlDatabase performQueryWithFormat:
					@"insert into messages (message_id, parent_id, folder_id, sender, link, date, read_flag, marked_flag, deleted_flag, title, text) "
					"values('%@', %d, %d, '%@', '%@', %f, %d, %d, %d, '%@', '%@')",
					preparedMessageGuid,
					parentId,
					folderID,
					preparedUserName,
					preparedMessageLink,
					interval,
					read_flag,
					marked_flag,
					deleted_flag,
					preparedMessageTitle,
					preparedMessageText];
			if (!results)
				return NO;
			[results release];

			// Add the message to the folder
			[message setStatus:MA_MsgStatus_New];
			[folder addMessage:message];
			
			// Update folder unread count
			if (!read_flag)
				adjustment = 1;
		}
		else if (![[self messageText:folderID guid:messageGuid] isEqualToString:messageText])
		{
			BOOL read_flag = [theMessage isRead];
			SQLResult * results;

			results = [sqlDatabase performQueryWithFormat:@"update messages set parent_id=%d, sender='%@', link='%@', date=%f, read_flag=%d, "
													 "marked_flag=%d, deleted_flag=%d, title='%@', text='%@' where folder_id=%d and message_id='%@'",
													 parentId,
													 preparedUserName,
													 preparedMessageLink,
													 interval,
													 read_flag,
													 marked_flag,
													 deleted_flag,
													 preparedMessageTitle,
													 preparedMessageText,
													 folderID,
													 preparedMessageGuid];
			if (!results)
				return NO;

			// This was an updated message
			[message setStatus:MA_MsgStatus_Updated];
			[results release];
		}

		// Fix unread count on parent folders
		if (adjustment != 0)
		{
			countOfUnread += adjustment;
			[folder setUnreadCount:[folder unreadCount] + adjustment];
			while ([folder parentId] != MA_Root_Folder)
			{
				folder = [self folderFromID:[folder parentId]];
				[folder setChildUnreadCount:[folder childUnreadCount] + adjustment];
			}
		}
		return YES;
	}
	return NO;
}

/* deleteDeletedMessages
 * Remove from the database all messages which have the deleted_flag field set to YES. This
 * also requires that we remove the same messages from all folder caches.
 */
-(void)deleteDeletedMessages
{
	// Verify we're on the right thread
	[self verifyThreadSafety];

	SQLResult * results = [sqlDatabase performQuery:@"delete from messages where deleted_flag=1"];
	if (results)
	{
		[trashFolder clearMessages];

		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[self trashFolderId]]];
	}
	[results release];
}

/* deleteMessage
 * Permanently deletes a message from the specified folder
 */
-(BOOL)deleteMessage:(int)folderId guid:(NSString *)guid
{
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		// Prime the message cache
		[self initMessageArray:folder];

		Message * message = [folder messageFromGuid:guid];
		if (message != nil)
		{
			NSString * preparedGuid = [SQLDatabase prepareStringForQuery:guid];

			// Verify we're on the right thread
			[self verifyThreadSafety];
			
			SQLResult * results = [sqlDatabase performQueryWithFormat:@"delete from messages where folder_id=%d and message_id='%@'", folderId, preparedGuid];
			if (results)
			{
				if (![message isRead])
				{
					[folder setUnreadCount:[folder unreadCount] - 1];
					--countOfUnread;
					
					// Update childUnreadCount for our parent. Since we're just working
					// on one message, we do this the faster way.
					Folder * parentFolder = folder;
					while ([parentFolder parentId] != MA_Root_Folder)
					{
						parentFolder = [self folderFromID:[parentFolder parentId]];
						[parentFolder setChildUnreadCount:[parentFolder childUnreadCount] - 1];
					}
				}
				[folder deleteMessage:guid];
				[results release];
				return YES;
			}
		}
	}
	return NO;
}

/* flushFolder
 * Updates the unread count for a folder in the database
 */
-(void)flushFolder:(int)folderId
{
	Folder * folder = [self folderFromID:folderId];
	if ([folder needFlush] && !IsSmartFolder(folder))
	{
		NSTimeInterval interval = [[folder lastUpdate] timeIntervalSince1970];
		[self executeSQLWithFormat:@"update folders set flags=%d, unread_count=%d, last_update=%f where folder_id=%d",
									[folder flags],
									[folder unreadCount],
									interval,
									folderId];

		// For RSS folders, update the metadata associated with it.
		if (IsRSSFolder(folder))
			[self executeSQLWithFormat:@"update rss_folders set last_update_string='%@' where folder_id=%d",
										[folder lastUpdateString],
										folderId];

		// Mark this folder as not needing any further updates
		[folder resetFlush];
	}
}

/* initSmartFoldersArray
 * Preloads all the smart folders into the smartFoldersArray dictionary.
 */
-(void)initSmartFoldersArray
{
	if (!initializedSmartFoldersArray)
	{
		// Make sure we have a database.
		NSAssert(sqlDatabase, @"Database not assigned for this item");
		
		SQLResult * results;

		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		results = [sqlDatabase performQuery:@"select * from smart_folders"];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;

			while ((row = [enumerator nextObject]))
			{
				NSString * search_string = [row stringForColumn:@"search_string"];
				int folderId = [[row stringForColumn:@"folder_id"] intValue];
				
				CriteriaTree * criteriaTree = [[CriteriaTree alloc] initWithString:search_string];
				[smartFoldersArray setObject:criteriaTree forKey:[NSNumber numberWithInt:folderId]];
				[criteriaTree release];
			}
		}
		[results release];
		initializedSmartFoldersArray = YES;
	}
}

/* searchStringForSearchFolder
 * Retrieve the smart folder criteria string for the specified folderId. Returns nil if
 * folderId is not a smart folder.
 */
-(CriteriaTree *)searchStringForSearchFolder:(int)folderId
{
	[self initSmartFoldersArray];
	return [smartFoldersArray objectForKey:[NSNumber numberWithInt:folderId]];
}

/* addSmartFolder
 * Create a new smart folder. If the specified folder already exists, then this is synonymous to
 * calling updateSearchFolder.
 */
-(int)addSmartFolder:(NSString *)folderName underParent:(int)parentId withQuery:(CriteriaTree *)criteriaTree
{
	Folder * folder = [self folderFromName:folderName];
	BOOL success = YES;

	if (folder)
	{
		[self updateSearchFolder:[folder itemId] withFolder:folderName withQuery:criteriaTree];
		return [folder itemId];
	}

	int folderId = [self addFolder:parentId folderName:folderName type:MA_Smart_Folder mustBeUnique:YES];
	if (folderId == -1)
		success = NO;
	else
	{
		NSString * preparedQueryString = [SQLDatabase prepareStringForQuery:[criteriaTree string]];
		[self executeSQLWithFormat:@"insert into smart_folders (folder_id, search_string) values (%d, '%@')", folderId, preparedQueryString];
		[smartFoldersArray setObject:criteriaTree forKey:[NSNumber numberWithInt:folderId]];

		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
	}
	return folderId;
}

/* updateSearchFolder
 * Updates the search string for the specified folder.
 */
-(BOOL)updateSearchFolder:(int)folderId withFolder:(NSString *)folderName withQuery:(CriteriaTree *)criteriaTree
{
	Folder * folder = [self folderFromID:folderId];
	if (![[folder name] isEqualToString:folderName])
		[folder setName:folderName];
	
	// Update the smart folder string
	NSString * preparedQueryString = [SQLDatabase prepareStringForQuery:[criteriaTree string]];
	[self executeSQLWithFormat:@"update smart_folders set search_string='%@' where folder_id=%d", preparedQueryString, folderId];
	[smartFoldersArray setObject:criteriaTree forKey:[NSNumber numberWithInt:folderId]];
	
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
	return YES;
}

/* initFolderArray
 * Initializes the folder array if necessary.
 */
-(void)initFolderArray
{
	if (!initializedFoldersArray)
	{
		// Make sure we have a database.
		NSAssert(sqlDatabase, @"Database not assigned for this item");
		
		// Keep running count of total unread messages
		countOfUnread = 0;
		
		SQLResult * results;

		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		results = [sqlDatabase performQuery:@"select * from folders order by folder_id"];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;
			
			while ((row = [enumerator nextObject]))
			{
				NSString * name = [row stringForColumn:@"foldername"];
				NSDate * lastUpdate = [NSDate dateWithTimeIntervalSince1970:[[row stringForColumn:@"last_update"] doubleValue]];
				int newItemId = [[row stringForColumn:@"folder_id"] intValue];
				int newParentId = [[row stringForColumn:@"parent_id"] intValue];
				int unreadCount = [[row stringForColumn:@"unread_count"] intValue];
				int type = [[row stringForColumn:@"type"] intValue];
				int flags = [[row stringForColumn:@"flags"] intValue];

				Folder * folder = [[[Folder alloc] initWithId:newItemId parentId:newParentId name:name type:type] autorelease];
				if (!IsRSSFolder(folder))
					unreadCount = 0;
				[folder setUnreadCount:unreadCount];
				[folder setLastUpdate:lastUpdate];
				[folder setFlag:flags];
				if (unreadCount > 0)
					countOfUnread += unreadCount;
				[foldersArray setObject:folder forKey:[NSNumber numberWithInt:newItemId]];
				
				// Remember the trash folder
				if (IsTrashFolder(folder))
					trashFolder = [folder retain];
			}
		}
		[results release];

		// Fix the childUnreadCount for every parent
		NSEnumerator * folderEnumerator = [foldersArray objectEnumerator];
		Folder * folder;
		
		while ((folder = [folderEnumerator nextObject]) != nil)
			if ([folder unreadCount] > 0 && [folder parentId] != MA_Root_Folder)
			{
				Folder * parentFolder = [self folderFromID:[folder parentId]];
				while (parentFolder != nil)
				{
					[parentFolder setChildUnreadCount:[parentFolder childUnreadCount] + [folder unreadCount]];
					parentFolder = [self folderFromID:[parentFolder parentId]];
				}
			}

		// Load all RSS folders and add them to the list.
		results = [sqlDatabase performQuery:@"select * from rss_folders"];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;
			
			while ((row = [enumerator nextObject]))
			{
				int folderId = [[row stringForColumn:@"folder_id"] intValue];
				long bloglinesId = [[row stringForColumn:@"bloglines_id"] intValue];
				NSString * descriptiontext = [row stringForColumn:@"description"];
				NSString * url = [row stringForColumn:@"feed_url"];
				NSString * linktext = [row stringForColumn:@"home_page"];
				NSString * username = [row stringForColumn:@"username"];
				NSString * lastUpdateString = [row stringForColumn:@"last_update_string"];
				
				Folder * folder = [self folderFromID:folderId];
				[folder setDescription:descriptiontext];
				[folder setHomePage:linktext];
				[folder setFeedURL:url];
				[folder setLastUpdateString:lastUpdateString];
				[folder setUsername:username];
				[folder setBloglinesId:bloglinesId];
			}
		}
		[results release];

		// Done
		initializedFoldersArray = YES;
	}
}

/* arrayOfFolders
 * Returns an NSArray of all folders with the specified parent. It does not include the
 * parent folder nor does it include any folders within groups under that parent. Specifically
 * it is a single level search and is actually slightly faster than arrayofSubFolders for
 * callers that require this distinction.
 */
-(NSArray *)arrayOfFolders:(int)parentId
{
	// Prime the cache
	if (initializedFoldersArray == NO)
		[self initFolderArray];

	NSMutableArray * newArray = [NSMutableArray array];
	if (newArray != nil)
	{
		NSEnumerator * enumerator = [foldersArray objectEnumerator];
		Folder * item;
		
		while ((item = [enumerator nextObject]) != nil)
		{
			if ([item parentId] == parentId)
				[newArray addObject:item];
		}
	}
	return [newArray sortedArrayUsingSelector:@selector(folderNameCompare:)];
}

/* arrayOfSubFolders
 * Returns an NSArray of all folders from the specified folder down.
 */
-(NSArray *)arrayOfSubFolders:(Folder *)folder
{
	NSMutableArray * newArray = [NSMutableArray arrayWithObject:folder];
	if (newArray != nil)
	{
		NSEnumerator * enumerator = [foldersArray objectEnumerator];
		int parentId = [folder itemId];
		Folder * item;
		
		while ((item = [enumerator nextObject]) != nil)
		{
			if ([item parentId] == parentId)
			{
				if (IsGroupFolder(item))
					[newArray addObjectsFromArray:[self arrayOfSubFolders:item]];
				else
					[newArray addObject:item];
			}
		}
	}
	return [newArray sortedArrayUsingSelector:@selector(folderIDCompare:)];
}

/* arrayOfRSSFolders
 * Return an array of RSS folders.
 */
-(NSArray *)arrayOfRSSFolders
{
	// Prime the cache
	if (initializedFoldersArray == NO)
		[self initFolderArray];
	
	NSMutableArray * newArray = [NSMutableArray array];
	if (newArray != nil)
	{
		NSEnumerator * enumerator = [foldersArray objectEnumerator];
		Folder * item;
		
		while ((item = [enumerator nextObject]) != nil)
		{
			if (IsRSSFolder(item))
				[newArray addObject:item];
		}
	}
	return [newArray sortedArrayUsingSelector:@selector(folderNameCompare:)];
}

/* initMessageArray
 * Ensures that the specified folder has a minimal cache of message information. This is just
 * the message id and the read flag.
 */
-(BOOL)initMessageArray:(Folder *)folder
{
	// Prime the folder cache
	[self initFolderArray];

	// Exit now if we're already initialized
	if ([folder messageCount] == -1)
	{
		int folderId = [folder itemId];
		SQLResult * results;

		// Initialize to indicate that the folder array is valid.
		[folder markFolderEmpty];
		
		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		results = [sqlDatabase performQueryWithFormat:@"select message_id, title, sender, read_flag from messages where folder_id=%d", folderId];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			int unread_count = 0;
			SQLRow * row;

			while ((row = [enumerator nextObject]) != nil)
			{
				NSString * guid = [row stringForColumn:@"message_id"];
				NSString * title = [row stringForColumn:@"title"];
				NSString * author = [row stringForColumn:@"sender"];
				BOOL read_flag = [[row stringForColumn:@"read_flag"] intValue];

				// Keep our own track of unread messages
				if (!read_flag)
					++unread_count;
				
				Message * message = [[Message alloc] initWithGuid:guid];
				[message markRead:read_flag];
				[message setFolderId:folderId];
				[message setTitle:title];
				[message setAuthor:author];
				[folder addMessage:message];
				[message release];
			}

			// This is a good time to do a quick check to ensure that our
			// own count of unread is in sync with the folders count and fix
			// them if not.
			if (unread_count != [folder unreadCount])
			{
				NSLog(@"Fixing unread count for %@ (%d on folder versus %d in messages)", [folder name], [folder unreadCount], unread_count);
				int diff = (unread_count - [folder unreadCount]);
				[self setFolderUnreadCount:folder adjustment:diff];
				countOfUnread += diff;
			}
		}
		[results release];
	}
	return YES;
}

/* releaseMessages
 * Free up the memory used to cache copies of the messages in the specified folder.
 */
-(void)releaseMessages:(int)folderId
{
	[[self folderFromID:folderId] clearMessages];
}

/* sqlScopeForFolder
 * Create a SQL 'where' clause that scopes to either the individual folder or the folder and
 * all sub-folders.
 */
-(NSString *)sqlScopeForFolder:(Folder *)folder flags:(int)scopeFlags
{
	Field * field = [self fieldByName:MA_Field_Folder];
	NSString * operatorString = (scopeFlags & MA_Scope_Inclusive) ? @"=" : @"<>";
	BOOL subScope = (scopeFlags & MA_Scope_SubFolders);
	int folderId;

	// If folder is nil, rather than report an error, default to some impossible value
	if (folder != nil)
		folderId = [folder itemId];
	else
	{
		subScope = NO;
		folderId = 0;
	}

	// Straightforward folder is <something>
	if (!subScope)
		return [NSString stringWithFormat:@"%@%@%d", [field sqlField], operatorString, folderId];

	// For under/not-under operators, we're creating a SQL statement of the format
	// (folder_id = <value1> || folder_id = <value2>...). It is possible to try and simplify
	// the string by looking for ranges but I suspect that given the spread of IDs this may
	// well be false optimisation.
	//
	NSArray * childFolders = [self arrayOfSubFolders:folder];
	NSMutableString * sqlString = [[NSMutableString alloc] init];
	int count = [childFolders count];
	int index;
	
	if (count > 1)
		[sqlString appendString:@"("];
	for (index = 0; index < count; ++index)
	{
		Folder * folder = [childFolders objectAtIndex:index];
		if (index > 0)
			[sqlString appendString:@" or "];
		[sqlString appendFormat:@"%@%@%d", [field sqlField], operatorString, [folder itemId]];
	}
	if (count > 1)
		[sqlString appendString:@")"];
	return [sqlString autorelease];
}

/* criteriaToSQL
 * Converts a criteria tree to it's SQL representative.
 */
-(NSString *)criteriaToSQL:(CriteriaTree *)criteriaTree
{
	NSMutableString * sqlString = [[NSMutableString alloc] init];
	NSEnumerator * enumerator = [criteriaTree criteriaEnumerator];
	Criteria * criteria;
	int count = 0;

	while ((criteria = [enumerator nextObject]) != nil)
	{
		Field * field = [self fieldByName:[criteria field]];
		NSAssert1(field != nil, @"Criteria field %@ does not have an associated database field", [criteria field]);

		NSString * operatorString = nil;
		NSString * valueString = nil;
		
		if (count++ > 0)
			[sqlString appendString:[criteriaTree condition] == MA_CritCondition_All ? @" and " : @" or "];

		switch ([criteria operator])
		{
			case MA_CritOper_Is:					operatorString = @"=%@"; break;
			case MA_CritOper_IsNot:					operatorString = @"<>%@"; break;
			case MA_CritOper_IsLessThan:			operatorString = @"<%@"; break;
			case MA_CritOper_IsGreaterThan:			operatorString = @">%@"; break;
			case MA_CritOper_IsLessThanOrEqual:		operatorString = @"<=%@"; break;
			case MA_CritOper_IsGreaterThanOrEqual:  operatorString = @">=%@"; break;
			case MA_CritOper_Contains:				operatorString = @" like '%%%@%%'"; break;
			case MA_CritOper_NotContains:			operatorString = @" not like '%%%@%%'"; break;
			case MA_CritOper_IsBefore:				operatorString = @"<%@"; break;
			case MA_CritOper_IsAfter:				operatorString = @">%@"; break;
			case MA_CritOper_IsOnOrBefore:			operatorString = @"<=%@"; break;
			case MA_CritOper_IsOnOrAfter:			operatorString = @">=%@"; break;
				
			case MA_CritOper_Under:
			case MA_CritOper_NotUnder:
				// Handle the operatorString later. For now just make sure we're working with the
				// right field types.
				NSAssert([field type] == MA_FieldType_Folder, @"Under operators only valid for folder field types");
				break;
		}

		switch ([field type])
		{
			case MA_FieldType_Flag:
				valueString = [[criteria value] isEqualToString:@"Yes"] ? @"1" : @"0";
				break;
				
			case MA_FieldType_Folder: {
				Folder * folder = [self folderFromName:[criteria value]];
				int scopeFlags = 0;

				switch ([criteria operator])
				{
					case MA_CritOper_Under:		scopeFlags = MA_Scope_SubFolders|MA_Scope_Inclusive; break;
					case MA_CritOper_NotUnder:	scopeFlags = MA_Scope_SubFolders; break;
					case MA_CritOper_Is:		scopeFlags = MA_Scope_Inclusive; break;
					case MA_CritOper_IsNot:		scopeFlags = 0; break;
					default:					NSAssert(false, @"Invalid operator for folder field type");
				}
				[sqlString appendString:[self sqlScopeForFolder:folder flags:scopeFlags]];
				break;
				}
				
			case MA_FieldType_Date: {
				NSCalendarDate * startDate;

				// "today" is a short hand way of specifying the current date.
				if ([[[criteria value] lowercaseString] isEqualToString:@"today"])
				{
					NSCalendarDate * now = [NSCalendarDate date];
					NSString * todayString = [NSString stringWithFormat:@"%d/%d/%d", [now dayOfMonth], [now monthOfYear], [now yearOfCommonEra]];
					startDate = [NSCalendarDate dateWithString:todayString calendarFormat:@"%d/%m/%Y"];
				}
				else
					startDate = [NSCalendarDate dateWithString:[criteria value] calendarFormat:@"%d/%m/%y"];
				if ([criteria operator] != MA_CritOper_Is)
					valueString = [NSString stringWithFormat:@"%f", [startDate timeIntervalSince1970]];
				else
				{
					NSCalendarDate * endDate;

					// Special case for Date is <date> because the resolution of the date field is in
					// milliseconds. So we need to translate this to a range for this to make sense.
					endDate = [startDate dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0];
					operatorString = [NSString stringWithFormat:@">=%f and %@<%f", [startDate timeIntervalSince1970], [field sqlField], [endDate timeIntervalSince1970]];
					valueString = @"";
				}
				break;
				}

			case MA_FieldType_String:
				if ([field tag] == MA_FieldID_Text)
				{
					// Special case for searching the text field. We always include the title field in the
					// search so the resulting SQL statement becomes:
					//
					//   (text op value or title op value)
					//
					// where op is the appropriate operator.
					//
					Field * titleField = [self fieldByName:MA_Field_Subject];
					NSString * value = [NSString stringWithFormat:operatorString, [criteria value]];
					[sqlString appendFormat:@"(%@%@ or %@%@)", [field sqlField], value, [titleField sqlField], value];
					break;
				}
					
			case MA_FieldType_Integer:
				valueString = [NSString stringWithFormat:@"%@", [criteria value]];
				break;
		}
		
		if (valueString != nil)
		{
			[sqlString appendString:[field sqlField]];
			[sqlString appendFormat:operatorString, valueString];
		}
	}
	return [sqlString autorelease];
}

/* criteriaForFolder
 * Returns the CriteriaTree that will return the folder contents.
 */
-(CriteriaTree *)criteriaForFolder:(int)folderId
{
	Folder * folder = [self folderFromID:folderId];
	if (folder == nil)
		return nil;

	if (IsTrashFolder(folder))
	{
		CriteriaTree * tree = [[CriteriaTree alloc] init];
		Criteria * clause = [[Criteria alloc] initWithField:MA_Field_Deleted withOperator:MA_CritOper_Is withValue:@"Yes"];
		[tree addCriteria:clause];
		[clause release];
		return [tree autorelease];
	}

	if (IsSmartFolder(folder))
	{
		[self initSmartFoldersArray];
		return [smartFoldersArray objectForKey:[NSNumber numberWithInt:folderId]];
	}
	
	CriteriaTree * tree = [[CriteriaTree alloc] init];
	Criteria * clause = [[Criteria alloc] initWithField:MA_Field_Folder withOperator:MA_CritOper_Under withValue:[folder name]];
	[tree addCriteria:clause];
	[clause release];
	return [tree autorelease];
}

/* arrayOfUnreadMessages
 * Retrieves an array of ArticleReference objects that represent all unread
 * articles in the specified folder.
 */
-(NSArray *)arrayOfUnreadMessages:(int)folderId
{
	Folder * folder = [self folderFromID:folderId];
	NSMutableArray * newArray = [NSMutableArray arrayWithCapacity:[folder unreadCount]];
	if (folder != nil)
	{
		if ([folder messageCount] > 0)
		{
			// Messages already cached in this folder so use those. Note the use of
			// reverseObjectEnumerator since the odds are that the unread articles are
			// likely to be clustered with the most recent articles at the end of the
			// array so it makes the code slightly faster.
			int unreadCount = [folder unreadCount];
			NSEnumerator * enumerator = [[folder articles] reverseObjectEnumerator];
			Message * theRecord;

			while (unreadCount > 0 && (theRecord = [enumerator nextObject]) != nil)
				if (![theRecord isRead])
				{
					[newArray addObject:[ArticleReference makeReference:theRecord]];
					--unreadCount;
				}
		}
		else
		{
			[self verifyThreadSafety];
			SQLResult * results = [sqlDatabase performQueryWithFormat:@"select message_id from messages where folder_id=%d and read_flag=0", folderId];
			if (results && [results rowCount])
			{
				NSEnumerator * enumerator = [results rowEnumerator];
				SQLRow * row;
				
				while ((row = [enumerator nextObject]) != nil)
				{
					NSString * guid = [row stringForColumn:@"message_id"];
					[newArray addObject:[ArticleReference makeReferenceFromGUID:guid inFolder:folderId]];
				}
			}
			[results release];
		}
	}
	return newArray;
}

/* arrayOfMessages
 * Retrieves an array containing all messages (except for text) for the
 * current folder. This info is always cached.
 */
-(NSArray *)arrayOfMessages:(int)folderId filterString:(NSString *)filterString
{
	Folder * folder = [self folderFromID:folderId];
	NSMutableArray * newArray = [NSMutableArray array];
	int unread_count = 0;

	if (folder != nil)
	{
		[folder clearMessages];

		// Construct a criteria tree for this query
		CriteriaTree * tree = [self criteriaForFolder:folderId];
		if ([filterString isNotEqualTo:@""])
		{
			Criteria * clause = [[Criteria alloc] initWithField:MA_Field_Text withOperator:MA_CritOper_Contains withValue:filterString];
			[tree addCriteria:clause];
			[clause release];
		}

		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		// Time to run the query
		SQLResult * results = [sqlDatabase performQueryWithFormat:@"select * from messages where %@", [self criteriaToSQL:tree]];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;

			while ((row = [enumerator nextObject]) != nil)
			{
				NSString * guid = [row stringForColumn:@"message_id"];
				int parentId = [[row stringForColumn:@"parent_id"] intValue];
				int messageFolderId = [[row stringForColumn:@"folder_id"] intValue];
				NSString * messageTitle = [row stringForColumn:@"title"];
				NSString * author = [row stringForColumn:@"sender"];
				NSString * link = [row stringForColumn:@"link"];
				BOOL read_flag = [[row stringForColumn:@"read_flag"] intValue];
				BOOL marked_flag = [[row stringForColumn:@"marked_flag"] intValue];
				BOOL deleted_flag = [[row stringForColumn:@"deleted_flag"] intValue];
				NSDate * messageDate = [NSDate dateWithTimeIntervalSince1970:[[row stringForColumn:@"date"] doubleValue]];

				// Keep our own track of unread messages
				if (!read_flag)
					++unread_count;

				Message * message = [[Message alloc] initWithGuid:guid];
				[message setTitle:messageTitle];
				[message setAuthor:author];
				[message setLink:link];
				[message setDate:messageDate];
				[message markRead:read_flag];
				[message markFlagged:marked_flag];
				[message markDeleted:deleted_flag];
				[message setFolderId:messageFolderId];
				[message setParentId:parentId];
				if (!deleted_flag || IsTrashFolder(folder))
					[newArray addObject:message];
				[folder addMessage:message];
				[message release];
			}

			// This is a good time to do a quick check to ensure that our
			// own count of unread is in sync with the folders count and fix
			// them if not.
			if ([filterString isEqualTo:@""] && IsRSSFolder(folder))
			{
				if (unread_count != [folder unreadCount])
				{
					NSLog(@"Fixing unread count for %@ (%d on folder versus %d in messages)", [folder name], [folder unreadCount], unread_count);
					int diff = (unread_count - [folder unreadCount]);
					[self setFolderUnreadCount:folder adjustment:diff];
					countOfUnread += diff;
				}
			}
		}

		// Deallocate
		[results release];
	}
	return newArray;
}

/* wrappedMarkFolderRead
 * Mark all messages in the folder and sub-folders read. This should be called
 * within a transaction since it is SQL intensive.
 */
-(BOOL)wrappedMarkFolderRead:(int)folderId
{
	NSArray * arrayOfChildFolders = [self arrayOfFolders:folderId];
	NSEnumerator * enumerator = [arrayOfChildFolders objectEnumerator];
	BOOL result = NO;
	Folder * folder;

	// Recurse and mark child folders read too
	while ((folder = [enumerator nextObject]) != nil)
	{
		if ([self wrappedMarkFolderRead:[folder itemId]])
			result = YES;
	}

	folder = [self folderFromID:folderId];
	if (folder != nil && [folder unreadCount] > 0)
	{
		[self verifyThreadSafety];
		SQLResult * results = [sqlDatabase performQueryWithFormat:@"update messages set read_flag=1 where folder_id=%d", folderId];
		if (results)
		{
			int count = [folder unreadCount];
			NSEnumerator * enumerator = [[folder articles] objectEnumerator];
			int remainingUnread = count;
			Message * message;

			while (remainingUnread > 0 && (message = [enumerator nextObject]) != nil)
				if (![message isRead])
				{
					[message markRead:YES];
					--remainingUnread;
				}
			countOfUnread -= count;
			[self setFolderUnreadCount:folder adjustment:-count];
		}
		[results release];
		result = YES;
	}
	return result;
}

/* markFolderRead
 * Mark all messages in the specified folder read
 */
-(BOOL)markFolderRead:(int)folderId
{
	BOOL result;

	[self beginTransaction];
	result = [self wrappedMarkFolderRead:folderId];
	[self commitTransaction];
	return result;
}

/* markMessageRead
 * Marks a message as read or unread.
 */
-(void)markMessageRead:(int)folderId guid:(NSString *)guid isRead:(BOOL)isRead
{
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		// Prime the message cache
		[self initMessageArray:folder];

		Message * message = [folder messageFromGuid:guid];
		if (message != nil && isRead != [message isRead])
		{
			NSString * preparedGuid = [SQLDatabase prepareStringForQuery:guid];

			// Verify we're on the right thread
			[self verifyThreadSafety];

			// Mark an individual message read
			SQLResult * results = [sqlDatabase performQueryWithFormat:@"update messages set read_flag=%d where folder_id=%d and message_id='%@'", isRead, folderId, preparedGuid];
			if (results)
			{
				int adjustment = (isRead ? -1 : 1);

				[message markRead:isRead];
				countOfUnread += adjustment;
				[self setFolderUnreadCount:folder adjustment:adjustment];
			}
			[results release];
		}
	}
}

/* setFolderUnreadCount
 * Adjusts the unread count on the specified folder by the given delta. The same delta is
 * also applied to the childUnreadCount of all ancestor folders.
 */
-(void)setFolderUnreadCount:(Folder *)folder adjustment:(int)adjustment
{
	int unreadCount = [folder unreadCount];
	[folder setUnreadCount:unreadCount + adjustment];
	
	// Update childUnreadCount for our parent. Since we're just working
	// on one message, we do this the faster way.
	Folder * tmpFolder = folder;
	while ([tmpFolder parentId] != MA_Root_Folder)
	{
		tmpFolder = [self folderFromID:[tmpFolder parentId]];
		[tmpFolder setChildUnreadCount:[tmpFolder childUnreadCount] + adjustment];
	}

	// Update the count in the database.
	[self executeSQLWithFormat:@"update folders set unread_count=%d where folder_id=%d", [folder unreadCount], [folder itemId]];
}

/* markMessageFlagged
 * Marks a message as flagged or unflagged.
 */
-(void)markMessageFlagged:(int)folderId guid:(NSString *)guid isFlagged:(BOOL)isFlagged
{
	NSString * preparedGuid = [SQLDatabase prepareStringForQuery:guid];
	[self executeSQLWithFormat:@"update messages set marked_flag=%d where folder_id=%d and message_id='%@'", isFlagged, folderId, preparedGuid];
}

/* markMessageDeleted
 * Marks a message as deleted. Deleted messages always get marked read first.
 */
-(void)markMessageDeleted:(int)folderId guid:(NSString *)guid isDeleted:(BOOL)isDeleted
{
	if (isDeleted)
		[self markMessageRead:folderId guid:guid isRead:YES];
	NSString * preparedGuid = [SQLDatabase prepareStringForQuery:guid];
	[self executeSQLWithFormat:@"update messages set deleted_flag=%d where folder_id=%d and message_id='%@'", isDeleted, folderId, preparedGuid];
}

/* messageText
 * Retrieve the text of the specified message.
 */
-(NSString *)messageText:(int)folderId guid:(NSString *)guid
{
	NSString * preparedGuid = [SQLDatabase prepareStringForQuery:guid];
	SQLResult * results;
	NSString * text;

	// Verify we're on the right thread
	[self verifyThreadSafety];
	
	results = [sqlDatabase performQueryWithFormat:@"select text from messages where folder_id=%d and message_id='%@'", folderId, preparedGuid];
	if (results && [results rowCount] > 0)
	{
		int lastRow = [results rowCount] - 1;
		text = [[results rowAtIndex:lastRow] stringForColumn:@"text"];
	}
	else
		text = @"** Cannot retrieve text for message **";
	[results release];
	return text;
}

/* close
 * Close the database. All internal resources are released and a new,
 * possibly different, database can be opened instead.
 */
-(void)close
{
	[foldersArray removeAllObjects];
	[smartFoldersArray removeAllObjects];
	[fieldsOrdered release];
	[fieldsByName release];
	[trashFolder release];
	[sqlDatabase close];
	initializedFoldersArray = NO;
	initializedSmartFoldersArray = NO;
	countOfUnread = 0;
	sqlDatabase = nil;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[foldersArray release];
	[smartFoldersArray release];
	if (sqlDatabase)
		[self close];
	[sqlDatabase release];
	[super dealloc];
}
@end
