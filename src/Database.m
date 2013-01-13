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
#import "Preferences.h"
#import "StringExtensions.h"
#import "CalendarExtensions.h"
#import "Constants.h"
#import "ArticleRef.h"
#import "SearchString.h"
#import "NSNotificationAdditions.h"
#import "RefreshManager.h"

// Private scope flags
#define MA_Scope_Inclusive		1
#define MA_Scope_SubFolders		2

// Private functions
@interface Database (Private)
	-(NSString *)relocateLockedDatabase:(NSString *)path;
	-(void)setDatabaseVersion:(NSInteger)newVersion;
	-(BOOL)initArticleArray:(Folder *)folder;
	-(void)verifyThreadSafety;
	-(CriteriaTree *)criteriaForFolder:(NSInteger)folderId;
	-(NSArray *)arrayOfSubFolders:(Folder *)folder;
	-(NSString *)sqlScopeForFolder:(Folder *)folder flags:(NSInteger)scopeFlags;
	-(void)createInitialSmartFolder:(NSString *)folderName withCriteria:(Criteria *)criteria;
	-(NSInteger)createFolderOnDatabase:(NSString *)name underParent:(NSInteger)parentId withType:(NSInteger)type;
	-(NSInteger)executeSQL:(NSString *)sqlStatement;
	-(NSInteger)executeSQLWithFormat:(NSString *)sqlStatement, ...;
@end

// The current database version number
const NSInteger MA_Min_Supported_DB_Version = 12;
const NSInteger MA_Current_DB_Version = 18;

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
		initializedfoldersDict = NO;
		initializedSmartfoldersDict = NO;
		countOfUnread = 0;
		trashFolder = nil;
		searchFolder = nil;
		searchString = @"";
		smartfoldersDict = [[[NSMutableDictionary alloc] init] retain];
		foldersDict = [[[NSMutableDictionary alloc] init] retain];
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
		if (![_sharedDatabase initDatabase:[[Preferences standardPreferences] defaultDatabase]])
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
		NSError *error;
		if (![fileManager createDirectoryAtPath:databaseFolder withIntermediateDirectories:YES attributes:NULL error:&error])
		{
			NSRunAlertPanel(NSLocalizedString(@"Cannot create database folder", nil),
							[NSString stringWithFormat:NSLocalizedString(@"Cannot create database folder text: %@", nil), error],
							NSLocalizedString(@"Close", nil), @"", @"",
							databaseFolder);
			[error release];
			return NO;
		}
	}
	
	// Open the database at the well known location
	sqlDatabase = [[SQLDatabase alloc] initWithFile:qualifiedDatabaseFileName];
	if (!sqlDatabase || ![sqlDatabase open])
	{
		NSRunAlertPanel(NSLocalizedString(@"Cannot open database", nil),
						NSLocalizedString(@"Cannot open database text", nil),
						NSLocalizedString(@"Close", nil), @"", @"",
						qualifiedDatabaseFileName);
		return NO;
	}

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

	// Trap unsupported databases
	if (databaseVersion > 0 && databaseVersion < MA_Min_Supported_DB_Version)
	{
		NSRunAlertPanel(NSLocalizedString(@"Unrecognised database format", nil),
						NSLocalizedString(@"Unrecognised database format text", nil),
						NSLocalizedString(@"Close", nil), @"", @"",
						qualifiedDatabaseFileName);
		return NO;
	}
	
	// Create the tables when the database is empty.
	if (databaseVersion == 0)
	{
		// Create the tables. We use the first table as a test whether we can actually
		// write to the specified location. If not then we need to prompt the user for
		// a different location.
		NSInteger resultCode;
		while ((resultCode = [self executeSQL:@"create table info (version, last_opened, first_folder, folder_sort)"]) != SQLITE_OK)
		{
			if (resultCode != SQLITE_LOCKED)
				return NO;

			// Database was opened but table was locked.
			NSString * newPath = [self relocateLockedDatabase:qualifiedDatabaseFileName];
			if (newPath == nil)
				return NO;
			qualifiedDatabaseFileName = newPath;
		}
		
		[self beginTransaction];

		[self executeSQL:@"create table folders (folder_id integer primary key, parent_id, foldername, unread_count, last_update, type, flags, next_sibling, first_child)"];
		[self executeSQL:@"create table messages (message_id, folder_id, parent_id, read_flag, marked_flag, deleted_flag, title, sender, link, createddate, date, text, revised_flag, enclosuredownloaded_flag, hasenclosure_flag, enclosure)"];
		[self executeSQL:@"create table smart_folders (folder_id, search_string)"];
		[self executeSQL:@"create table rss_folders (folder_id, feed_url, username, last_update_string, description, home_page, bloglines_id)"];
		[self executeSQL:@"create table rss_guids (message_id, folder_id)"];
		[self executeSQL:@"create index messages_folder_idx on messages (folder_id)"];
		[self executeSQL:@"create index messages_message_idx on messages (message_id)"];
		[self executeSQL:@"create index rss_guids_idx on rss_guids (folder_id)"];

		// Create a criteria to find all marked articles
		Criteria * markedCriteria = [[Criteria alloc] initWithField:MA_Field_Flagged withOperator:MA_CritOper_Is withValue:@"Yes"];
		[self createInitialSmartFolder:NSLocalizedString(@"Marked Articles", nil) withCriteria:markedCriteria];
		[markedCriteria release];

		// Create a criteria to show all unread articles
		Criteria * unreadCriteria = [[Criteria alloc] initWithField:MA_Field_Read withOperator:MA_CritOper_Is withValue:@"No"];
		[self createInitialSmartFolder:NSLocalizedString(@"Unread Articles", nil) withCriteria:unreadCriteria];
		[unreadCriteria release];
		
		// Create a criteria to show all articles received today
		Criteria * todayCriteria = [[Criteria alloc] initWithField:MA_Field_Date withOperator:MA_CritOper_Is withValue:@"today"];
		[self createInitialSmartFolder:NSLocalizedString(@"Today's Articles", nil) withCriteria:todayCriteria];
		[todayCriteria release];

		// Create the trash folder
		[self executeSQLWithFormat:@"insert into folders (parent_id, foldername, unread_count, last_update, type, flags, next_sibling, first_child) values (-1, '%@', 0, 0, %d, 0, 0, 0)",
			NSLocalizedString(@"Trash", nil),
			MA_Trash_Folder];

		// Set the initial version
		databaseVersion = MA_Current_DB_Version;
		[self executeSQLWithFormat:@"insert into info (version, first_folder, folder_sort) values (%d, 0, %d)", databaseVersion, MA_FolderSort_Manual];
		[[Preferences standardPreferences] setFoldersTreeSortMethod:MA_FolderSort_Manual];
		
		// Set the initial folder order
		[self initFolderArray];
		NSInteger folderId = 0;
		NSInteger previousSibling = 0;
		NSArray * allFolders = [foldersDict allKeys];
		NSUInteger count = [allFolders count];
		NSUInteger index;
		for (index = 0u; index < count; ++index)
		{
			previousSibling = folderId;
			folderId = [[allFolders objectAtIndex:index] intValue];
			if (index == 0u)
				[self setFirstChild:folderId forFolder:MA_Root_Folder];
			else
				[self setNextSibling:folderId forFolder:previousSibling];
		}
		
		// If we have a DemoFeeds.plist in the resources then use it to create some initial demo
		// RSS feeds.
		NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
		NSString * pathToPList = [thisBundle pathForResource:@"DemoFeeds.plist" ofType:@""];
		if (pathToPList != nil)
		{
			NSDictionary * demoFeedsDict = [NSDictionary dictionaryWithContentsOfFile:pathToPList];
			if (demoFeedsDict)
			{
				for (NSString * feedName in demoFeedsDict)
				{
					NSDictionary * itemDict = [demoFeedsDict objectForKey:feedName];
					NSString * feedURL = [itemDict valueForKey:@"URL"];
					if (feedURL != nil && feedName != nil)
						previousSibling = [self addRSSFolder:feedName underParent:MA_Root_Folder afterChild:previousSibling subscriptionURL:feedURL];
				}
			}
		}
		
		[self commitTransaction];
	}
	else if (databaseVersion < MA_Current_DB_Version)
	{
		NSAlert * alert = [[NSAlert alloc] init];
		[alert setMessageText:NSLocalizedString(@"Database Upgrade", nil)];
		[alert setInformativeText:NSLocalizedString(@"Vienna must upgrade its database to the latest version. This may take a minute or so. We apologize for the inconveninece.", nil)];
		[alert addButtonWithTitle:NSLocalizedString(@"Upgrade Database", nil)];
		[alert addButtonWithTitle:NSLocalizedString(@"Quit Vienna", nil)];
		NSInteger modalReturn = [alert runModal];
		[alert release];
		if (modalReturn == NSAlertSecondButtonReturn)
		{
			return NO;
		}
		
		// Backup the database before any upgrade
		NSString * backupDatabaseFileName = [qualifiedDatabaseFileName stringByAppendingPathExtension:@"bak"];
		[[NSFileManager defaultManager] copyItemAtPath:qualifiedDatabaseFileName toPath:backupDatabaseFileName error:nil];
	}
		
	// Upgrade to rev 13.
	// Add createddate field to the messages table and initialise it to a date in the past.
	// Create an index on the message_id column.
	if (databaseVersion < 13)
	{
		[self beginTransaction];
		
		[self executeSQL:@"alter table messages add column createddate"];
		[self executeSQLWithFormat:@"update messages set createddate=%f", [[NSDate distantPast] timeIntervalSince1970]];
		[self executeSQL:@"create index messages_message_idx on messages (message_id)"];

		[self commitTransaction];
		NSLog(@"Updated database schema to version %d.", databaseVersion);
	}
	
	// Upgrade to rev 14.
	// Add next_sibling and next_child columns to folders table and first_folder column to info table to allow for manual sorting.
	// Initialize all values to 0. The correct values will be set by -[FoldersTree setManualSortOrderForNode:].
	// Make sure that all parent_id values are integers rather than strings, because previous versions of setParent:forFolder:
	// set them as strings.
	if (databaseVersion < 14)
	{
		[self beginTransaction];
		
		[self executeSQL:@"alter table info add column first_folder"];
		[self executeSQL:@"update info set first_folder=0"];
		
		[self executeSQL:@"alter table folders add column next_sibling"];
		[self executeSQL:@"update folders set next_sibling=0"];
		
		[self executeSQL:@"alter table folders add column first_child"];
		[self executeSQL:@"update folders set first_child=0"];
		
		[[Preferences standardPreferences] setFoldersTreeSortMethod:MA_FolderSort_ByName];
		
		SQLResult * results = [sqlDatabase performQuery:@"select folder_id, parent_id from folders"];
		if (results && [results rowCount])
		{
			for (SQLRow * row in [results rowEnumerator])
			{
				NSInteger folderId = [[row stringForColumn:@"folder_id"] intValue];
				NSInteger parentId = [[row stringForColumn:@"parent_id"] intValue];
				[self executeSQLWithFormat:@"update folders set parent_id=%ld where folder_id=%ld", parentId, folderId];
			}
		}
		[results release];
		
		[self commitTransaction];
		NSLog(@"Updated database schema to version %d.", databaseVersion);

	}
	
	// Upgrade to rev 15.
	// Move the folders tree sort method preference to the database, so that it can survive deletion of the preferences file.
	// Do not disturb the manual sort order, if it exists.
	if (databaseVersion < 15)
	{
		[self beginTransaction];
		
		[self executeSQL:@"alter table info add column folder_sort"];
		
		NSInteger oldFoldersTreeSortMethod = [[Preferences standardPreferences] foldersTreeSortMethod];
		[self executeSQLWithFormat:@"update info set folder_sort=%d", oldFoldersTreeSortMethod];
		[self commitTransaction];
		NSLog(@"Updated database schema to version %d.", databaseVersion);
	}
	
	// Upgrade to rev 16.
	// Add revised_flag to messages table, and initialize all values to 0.
	if (databaseVersion < 16)
	{
		[self beginTransaction];
		
		[self executeSQL:@"alter table messages add column revised_flag"];
		[self executeSQL:@"update messages set revised_flag=0"];
		
		// Set the new version
		[self setDatabaseVersion:16];		
		[self commitTransaction];
	}
	
	
	// Upgrade to rev 17.
	// Add hasenclosure_flag, enclosuredownloaded_flag and enclosure to messages table, and initialize stuff.
	if (databaseVersion < 17)
	{
		[self beginTransaction];
		
		[self executeSQL:@"alter table messages add column hasenclosure_flag"];
		[self executeSQL:@"update messages set hasenclosure_flag=0"];
		[self executeSQL:@"alter table messages add column enclosure"];
		[self executeSQL:@"update messages set enclosure=''"];
		[self executeSQL:@"alter table messages add column enclosuredownloaded_flag"];
		[self executeSQL:@"update messages set enclosuredownloaded_flag=0"];
		
		// Set the new version
		[self setDatabaseVersion:17];		
		[self commitTransaction];
	}		
	
	// Upgrade to rev 18.
	// Add table all message guids.
	if (databaseVersion < 18)
	{
		[self beginTransaction];
		
		[self executeSQL:@"create table rss_guids as select message_id, folder_id from messages"];
		[self executeSQL:@"create index rss_guids_idx on rss_guids (folder_id)"];
		
		// Set the new version
		[self setDatabaseVersion:18];		
		[self commitTransaction];
	}
	
	// Read the folders tree sort method from the database.
	// Make sure that the folders tree is not yet registered to receive notifications at this point.
	NSInteger newFoldersTreeSortMethod = MA_FolderSort_ByName;
	SQLResult * sortResults = [sqlDatabase performQuery:@"select folder_sort from info"];
	if (sortResults && [sortResults rowCount])
	{
		newFoldersTreeSortMethod = [[[sortResults rowAtIndex:0] stringForColumn:@"folder_sort"] intValue];
	}
	[sortResults release];
	[[Preferences standardPreferences] setFoldersTreeSortMethod:newFoldersTreeSortMethod];
	
	// Register for notifications of change in folders tree sort method.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAutoSortFoldersTreeChange:) name:@"MA_Notify_AutoSortFoldersTreeChange" object:nil];
	
	// Initial check if the database is read-only
	[self syncLastUpdate];

	// Create fields
	fieldsByName = [[[NSMutableDictionary alloc] init] retain];
	fieldsOrdered = [[NSMutableArray alloc] init];

	[self addField:MA_Field_Read type:MA_FieldType_Flag tag:MA_FieldID_Read sqlField:@"read_flag" visible:YES width:17];
	[self addField:MA_Field_Flagged type:MA_FieldType_Flag tag:MA_FieldID_Flagged sqlField:@"marked_flag" visible:YES width:17];
	[self addField:MA_Field_HasEnclosure type:MA_FieldType_Flag tag:MA_FieldID_HasEnclosure sqlField:@"hasenclosure_flag" visible:YES width:17];
	[self addField:MA_Field_Deleted type:MA_FieldType_Flag tag:MA_FieldID_Deleted sqlField:@"deleted_flag" visible:NO width:15];
	[self addField:MA_Field_Comments type:MA_FieldType_Integer tag:MA_FieldID_Comments sqlField:@"comment_flag" visible:NO width:15];
	[self addField:MA_Field_GUID type:MA_FieldType_Integer tag:MA_FieldID_GUID sqlField:@"message_id" visible:NO width:72];
	[self addField:MA_Field_Subject type:MA_FieldType_String tag:MA_FieldID_Subject sqlField:@"title" visible:YES width:472];
	[self addField:MA_Field_Folder type:MA_FieldType_Folder tag:MA_FieldID_Folder sqlField:@"folder_id" visible:NO width:130];
	[self addField:MA_Field_Date type:MA_FieldType_Date tag:MA_FieldID_Date sqlField:@"date" visible:YES width:152];
	[self addField:MA_Field_Parent type:MA_FieldType_Integer tag:MA_FieldID_Parent sqlField:@"parent_id" visible:NO width:72];
	[self addField:MA_Field_Author type:MA_FieldType_String tag:MA_FieldID_Author sqlField:@"sender" visible:YES width:138];
	[self addField:MA_Field_Link type:MA_FieldType_String tag:MA_FieldID_Link sqlField:@"link" visible:NO width:138];
	[self addField:MA_Field_Text type:MA_FieldType_String tag:MA_FieldID_Text sqlField:@"text" visible:NO width:152];
	[self addField:MA_Field_Summary type:MA_FieldType_String tag:MA_FieldID_Summary sqlField:@"summary" visible:NO width:152];
	[self addField:MA_Field_Headlines type:MA_FieldType_String tag:MA_FieldID_Headlines sqlField:@"" visible:NO width:100];
	[self addField:MA_Field_Enclosure type:MA_FieldType_String tag:MA_FieldID_Enclosure sqlField:@"enclosure" visible:NO width:100];
	[self addField:MA_Field_EnclosureDownloaded type:MA_FieldType_Flag tag:MA_FieldID_EnclosureDownloaded sqlField:@"enclosuredownloaded_flag" visible:NO width:100];
	
	return YES;
}

/* relocateLockedDatabase
 * Tell the user that the database could not be created at the path specified by path
 * and prompt for an alternative location. Opens and returns the new location if we were successful.
 */
-(NSString *)relocateLockedDatabase:(NSString *)path
{
	NSString * errorTitle = NSLocalizedString(@"Locate Title", nil);
	NSString * errorText = NSLocalizedString(@"Locate Text", nil);
	NSInteger option = NSRunAlertPanel(errorTitle, errorText, NSLocalizedString(@"Locate", nil), NSLocalizedString(@"Exit", nil), nil, path);
	if (option == 0)
		return nil;

	// Locate button.
	if (option == 1)
	{
		// Delete any existing database.
		if (sqlDatabase != nil)
		{
			[sqlDatabase close];
			[sqlDatabase release];
			sqlDatabase = nil;
			[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		}
		
		// Bring up modal UI to select the new location
		NSOpenPanel * openPanel = [NSOpenPanel openPanel];
		[openPanel setCanChooseFiles:NO];
		[openPanel setCanChooseDirectories:YES];
		if ([openPanel runModalForDirectory:nil file:nil] == NSCancelButton)
			return nil;
		
		// Make the new database name.
		NSString * databaseName = [path lastPathComponent];
		NSString * newPath = [[[openPanel filenames] objectAtIndex:0] stringByAppendingPathComponent:databaseName];
		
		// And try to open it.
		sqlDatabase = [[SQLDatabase alloc] initWithFile:newPath];
		if (!sqlDatabase || ![sqlDatabase open])
		{
			NSRunAlertPanel(NSLocalizedString(@"Cannot open database", nil),
							NSLocalizedString(@"Cannot open database text", nil),
							NSLocalizedString(@"Close", nil), @"", @"",
							newPath);
			return nil;
		}
		
		// Save this to the preferences
		[[Preferences standardPreferences] setDefaultDatabase:newPath];
		return newPath;
	}
	return nil;
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
-(NSInteger)executeSQL:(NSString *)sqlStatement
{
	[self verifyThreadSafety];
	[[sqlDatabase performQuery:sqlStatement] release];
	return [sqlDatabase lastError];
}

/* executeSQLWithFormat
 * Formats and executes the specified SQL statement and discards the result. Should be used for
 * SQL statements that do not return results.
 */
-(NSInteger)executeSQLWithFormat:(NSString *)sqlStatement, ...
{
	va_list arguments;
	va_start(arguments, sqlStatement);
	NSString * query = [[NSString alloc] initWithFormat:sqlStatement arguments:arguments];
	[self executeSQL:query];
	[query release];
	va_end(arguments);
	return [sqlDatabase lastError];
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
 * Return the total number of unread articles in the database.
 */
-(NSInteger)countOfUnread
{
	[self initFolderArray];
	return countOfUnread;
}

/* addField
 * Add the specified field to our fields array.
 */
-(void)addField:(NSString *)name type:(NSInteger)type tag:(NSInteger)tag sqlField:(NSString *)sqlField visible:(BOOL)visible width:(NSInteger)width
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
-(NSInteger)databaseVersion
{
	return databaseVersion;
}

/* setDatabaseVersion
 * Sets the version stamp in the database.
 */
-(void)setDatabaseVersion:(NSInteger)newVersion
{
	[self executeSQLWithFormat:@"update info set version=%ld", newVersion];
	databaseVersion = newVersion;
	NSLog(@"Updated database schema to version %d.", databaseVersion);
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

/* clearFolderFlag
 * Clears the specified flag for the folder.
 */
-(void)clearFolderFlag:(NSInteger)folderId flagToClear:(NSUInteger)flag
{
	// Exit now if we're read-only
	if (readOnly)
		return;
	
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		[folder clearFlag:flag];
		[self executeSQLWithFormat:@"update folders set flags=%d where folder_id=%d", [folder flags], folderId];
	}
}

/* setFolderFlag
 * Sets the specified flag for the folder.
 */
-(void)setFolderFlag:(NSInteger)folderId flagToSet:(NSUInteger)flag
{
	// Exit now if we're read-only
	if (readOnly)
		return;
	
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		[folder setFlag:flag];
		[self executeSQLWithFormat:@"update folders set flags=%lu where folder_id=%ld", [folder flags], folderId];
	}
}

/* setFolderLastUpdate
 * Sets the date when the folder was last updated.
 */
-(void)setFolderLastUpdate:(NSInteger)folderId lastUpdate:(NSDate *)lastUpdate
{
	// Exit now if we're read-only
	if (readOnly)
		return;

	// If no change to last update, do nothing
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil && (IsRSSFolder(folder) || IsGoogleReaderFolder(folder)))
	{
		if ([[folder lastUpdate] isEqualToDate:lastUpdate])
			return;

		[folder setLastUpdate:lastUpdate];
		NSTimeInterval interval = [lastUpdate timeIntervalSince1970];
		[self executeSQLWithFormat:@"update folders set last_update=%f where folder_id=%ld", interval, folderId];
	}
}

/* setFolderLastUpdateString
 * Sets the last update string for the folder.
 */
-(void)setFolderLastUpdateString:(NSInteger)folderId lastUpdateString:(NSString *)lastUpdateString
{
	// Exit now if we're read-only
	if (readOnly)
		return;
	
	// If no change to last update string, do nothing
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil && (IsRSSFolder(folder) || IsGoogleReaderFolder(folder)))
	{
		if ([[folder lastUpdateString] isEqualToString:lastUpdateString])
			return;
		
		[folder setLastUpdateString:lastUpdateString];
		[self executeSQLWithFormat:@"update rss_folders set last_update_string='%@' where folder_id=%ld", [folder lastUpdateString], folderId];
	}
}

/* setFolderFeedURL
 * Change the URL of the feed on the specified RSS folder subscription.
 */
-(BOOL)setFolderFeedURL:(NSInteger)folderId newFeedURL:(NSString *)url
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;
	
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil && ![[folder feedURL] isEqualToString:url])
	{
		NSString * preparedURL = [SQLDatabase prepareStringForQuery:url];

		[folder setFeedURL:url];
		[self executeSQLWithFormat:@"update rss_folders set feed_url='%@' where folder_id=%ld", preparedURL, folderId];
	}
	return YES;
}


-(NSInteger)addGoogleReaderFolder:(NSString *)feedName underParent:(NSInteger)parentId afterChild:(NSInteger)predecessorId subscriptionURL:(NSString *)url {
	NSInteger folderId = [self addFolder:parentId afterChild:predecessorId folderName:feedName type:MA_GoogleReader_Folder canAppendIndex:YES];
	//TODO: optimization using unique add function for addRSSFolder
	if (folderId != -1)
	{
		NSString * preparedURL = [SQLDatabase prepareStringForQuery:url];
		NSString *preparedName = [SQLDatabase prepareStringForQuery:feedName];
		
		[self verifyThreadSafety];
		SQLResult * results = [sqlDatabase performQueryWithFormat:
							   @"insert into rss_folders (folder_id, description, username, home_page, last_update_string, feed_url, bloglines_id) "
							   "values (%ld, '%@', '', '', '', '%@', %d)",
							   folderId,
							   preparedName,
							   preparedURL,
							   0];
		if (!results)
			return -1;
		
		// Add this new folder to our internal cache
		Folder * folder = [self folderFromID:folderId];
		[folder setFeedURL:url];
		[results release];
	}
	return folderId;
}


/* addRSSFolder
 * Add an RSS Feed folder and return the ID of the new folder.
 */
-(NSInteger)addRSSFolder:(NSString *)feedName underParent:(NSInteger)parentId afterChild:(NSInteger)predecessorId subscriptionURL:(NSString *)url
{
	NSInteger folderId = [self addFolder:parentId afterChild:predecessorId folderName:feedName type:MA_RSS_Folder canAppendIndex:YES];
	if (folderId != -1)
	{
		NSString * preparedURL = [SQLDatabase prepareStringForQuery:url];

		[self verifyThreadSafety];
		SQLResult * results = [sqlDatabase performQueryWithFormat:
					@"insert into rss_folders (folder_id, description, username, home_page, last_update_string, feed_url, bloglines_id) "
					 "values (%ld, '', '', '', '', '%@', %d)",
					folderId,
					preparedURL,
					0];
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
 * canAppendIndex is YES then we adjust the name to ensure that the folder name remains unique. If
 * we hit an error, the function returns -1.
 */
-(NSInteger)addFolder:(NSInteger)parentId afterChild:(NSInteger)predecessorId folderName:(NSString *)name type:(NSInteger)type canAppendIndex:(BOOL)canAppendIndex
{
	Folder * folder = nil;

	// Prime the cache
	[self initFolderArray];

	// Exit now if we're read-only
	if (readOnly)
		return -1;

	if (!canAppendIndex)
	{
		folder = [self folderFromName:name];
		if (folder)
			return [folder itemId];
	}
	else
	{
		// If a folder of that name already exists then adjust the name by appending
		// an index number to make it unique.
		NSString * oldName = name;
		NSUInteger index = 1;

		while (([self folderFromName:name]) != nil)
			name = [NSString stringWithFormat:@"%@ (%li)", oldName, index++];
	}

	NSInteger nextSibling = 0;
	BOOL manualSort = [[Preferences standardPreferences] foldersTreeSortMethod] == MA_FolderSort_Manual;
	if (manualSort)
	{
		if (predecessorId > 0)
		{
			Folder * predecessor = [self folderFromID:predecessorId];
			if (predecessor != nil)
				nextSibling = [predecessor nextSiblingId];
			else
				predecessorId = 0;
		}
		if (predecessorId < 0)
		{
			[self verifyThreadSafety];
			SQLResult * siblings = [sqlDatabase performQueryWithFormat:@"select folder_id from folders where parent_id=%ld and next_sibling=0", parentId];
			predecessorId = (siblings && [siblings rowCount]) ? [[[siblings rowAtIndex:0] stringForColumn:@"folder_id"] intValue] : 0;
			[siblings release];			
		}
		if (predecessorId == 0)
		{
			if (parentId == MA_Root_Folder)
				nextSibling = [self firstFolderId];
			else
			{
				Folder * parent = [self folderFromID:parentId];
				if (parent != nil)
					nextSibling = [parent firstChildId];
			}
		}
	}

	// Here we create the folder anew.
	NSInteger newItemId = [self createFolderOnDatabase:name underParent:parentId withType:type];
	if (newItemId != -1)
	{
		// Add this new folder to our internal cache. If this is an RSS or Google Reader
		// folder, mark it so that somewhere down the line we'll request the
		// image for the folder.
		folder = [[[Folder alloc] initWithId:newItemId parentId:parentId name:name type:type] autorelease];
		if ((type == MA_RSS_Folder)||(type == MA_GoogleReader_Folder))
			[folder setFlag:MA_FFlag_CheckForImage];
		[foldersDict setObject:folder forKey:[NSNumber numberWithInt:newItemId]];
		
		if (manualSort)
		{
			if (nextSibling > 0)
				[self setNextSibling:nextSibling forFolder:newItemId];
			if (predecessorId > 0)
				[self setNextSibling:newItemId forFolder:predecessorId];
			else
				[self setFirstChild:newItemId forFolder:parentId];
		}

		// Send a notification when new folders are added
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FolderAdded" object:folder];
	}
	return newItemId;
}

/* createFolderOnDatabase:underParent:withType
 * Generic (and internal!) function that creates a new folder in the database. It just creates
 * the folder without any real sanity checks which are assumed to have been done by the caller.
 * Returns the ID of the newly created folder or -1 if we failed.
 */
-(NSInteger)createFolderOnDatabase:(NSString *)name underParent:(NSInteger)parentId withType:(NSInteger)type
{
	NSString * preparedName = [SQLDatabase prepareStringForQuery:name];
	NSInteger newItemId = -1;
	NSInteger flags = 0;
	NSInteger nextSibling = 0;
	NSInteger firstChild = 0;
	
	// For new folders, last update is set to before now
	NSDate * lastUpdate = [NSDate distantPast];
	NSTimeInterval interval = [lastUpdate timeIntervalSince1970];

	// Require an image check if we're a subscription folder
	if ((type == MA_RSS_Folder) || (type == MA_GoogleReader_Folder))
		flags = MA_FFlag_CheckForImage;

	// Create the folder in the database. One thing to watch out for here that has
	// bit me before. When adding new fields to the folders table, remember to init
	// the field here even if its just to an empty value.
	[self verifyThreadSafety];
	SQLResult * results = [sqlDatabase performQueryWithFormat:
		@"insert into folders (foldername, parent_id, unread_count, last_update, type, flags, next_sibling, first_child) values('%@', %ld, 0, %f, %ld, %ld, %ld, %ld)",
		preparedName,
		parentId,
		interval,
		type,
		flags,
		nextSibling,
		firstChild];
	
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
+(NSString *)untitledFeedFolderName
{
	return NSLocalizedString(@"(Untitled Feed)", nil);
}

/* wrappedDeleteFolder
 * Delete the specified folder. This function should be called from within a
 * transaction wrapper since it can be very SQL intensive.
 */
-(BOOL)wrappedDeleteFolder:(NSInteger)folderId
{
	NSArray * arrayOfChildFolders = [self arrayOfFolders:folderId];
	Folder * folder;

	// Recurse and delete child folders
	for (folder in arrayOfChildFolders)
		[self wrappedDeleteFolder:[folder itemId]];

	// Adjust unread counts on parents
	folder = [self folderFromID:folderId];
	NSInteger adjustment = -[folder unreadCount];
	while ([folder parentId] != MA_Root_Folder)
	{
		folder = [self folderFromID:[folder parentId]];
		[folder setChildUnreadCount:[folder childUnreadCount] + adjustment];
	}

	// Delete all articles in this folder then delete ourselves.
	folder = [self folderFromID:folderId];
	countOfUnread -= [folder unreadCount];
	if (IsSmartFolder(folder))
		[self executeSQLWithFormat:@"delete from smart_folders where folder_id=%ld", folderId];

	// If this is an RSS feed, delete from the feeds
	// and delete raw feed source
	if (IsRSSFolder(folder) || IsGoogleReaderFolder(folder))
	{
		[self executeSQLWithFormat:@"delete from rss_folders where folder_id=%ld", folderId];
		[self executeSQLWithFormat:@"delete from rss_guids where folder_id=%ld", folderId];
		
		NSString * feedSourceFilePath = [folder feedSourceFilePath];
		if (feedSourceFilePath != nil)
		{
			BOOL isDirectory = YES;
			if ([[NSFileManager defaultManager] fileExistsAtPath:feedSourceFilePath isDirectory:&isDirectory] && !isDirectory)
			{
				[[NSFileManager defaultManager] removeItemAtPath:feedSourceFilePath error:NULL];
			}
			
			NSString * backupPath = [feedSourceFilePath stringByAppendingPathExtension:@"bak"];
			if ([[NSFileManager defaultManager] fileExistsAtPath:backupPath isDirectory:&isDirectory] && !isDirectory)
			{
				[[NSFileManager defaultManager] removeItemAtPath:backupPath error:NULL];
			}
		}
	}

	// If we deleted the search folder, null out our cached handle
	if (IsSearchFolder(folder))
	{
		[searchFolder release];
		searchFolder = nil;
	}

	// Update the sort order if necessary
	if ([[Preferences standardPreferences] foldersTreeSortMethod] == MA_FolderSort_Manual)
	{
		[self verifyThreadSafety];
		SQLResult * results = [sqlDatabase performQueryWithFormat:@"select folder_id from folders where parent_id=%ld and next_sibling=%ld", [folder parentId], folderId];
		if (results && [results rowCount])
		{
			NSInteger previousSibling = [[[results rowAtIndex:0] stringForColumn:@"folder_id"] intValue];
			[self setNextSibling:[folder nextSiblingId] forFolder:previousSibling];
		}
		else
			[self setFirstChild:[folder nextSiblingId] forFolder:[folder parentId]];
		[results release];
	}
	
	// For a smart folder, the next line is a no-op but it helpfully takes care of the case where a
	// normal folder had it's type grobbed to MA_Smart_Folder.
	[self executeSQLWithFormat:@"delete from messages where folder_id=%ld", folderId];
	[self executeSQLWithFormat:@"delete from folders where folder_id=%ld", folderId];

	// Remove from the folders array. Do this after we send the notification
	// so that the notification handlers don't fail if they try to dereference the
	// folder.
	[foldersDict removeObjectForKey:[NSNumber numberWithInt:folderId]];
	return YES;
}

/* deleteFolder
 * Delete the specified folder. If the folder has any children, delete them too. Also delete
 * all articles associated with the folder. Then send a notification that the folder went bye-bye.
 */
-(BOOL)deleteFolder:(NSInteger)folderId
{
	NSMutableArray * arrayOfFolderIds;
	NSArray * arrayOfChildFolders;
	NSNumber * numFolder;
	Folder * folder;
	BOOL result;

	// Exit now if we're read-only
	if (readOnly)
		return NO;

	// Make sure this is a valid folder
	folder = [self folderFromID:folderId];
	if (folder == nil)
		return NO;

	arrayOfChildFolders = [self arrayOfSubFolders:folder];
	arrayOfFolderIds = [NSMutableArray arrayWithCapacity:[arrayOfChildFolders count]];

	// Send the pre-delete notification before we start the transaction so that the handlers can
	// safely do any database access.
	for (folder in arrayOfChildFolders)
	{
		numFolder = [NSNumber numberWithInt:[folder itemId]];
		[arrayOfFolderIds addObject:numFolder];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_WillDeleteFolder" object:numFolder];
	}

	// Now do the deletion.
	[self beginTransaction];
	result = [self wrappedDeleteFolder:folderId];
	[self commitTransaction];

	// Send the post-delete notification after we're finished. Note that the folder actually corresponding to
	// each numFolder won't exist any more and the handlers need to be aware of this.
	for (numFolder in arrayOfFolderIds)
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FolderDeleted" object:numFolder];
	
	return result;
}

/* setFolderName
 * Renames the specified folder.
 */
-(BOOL)setFolderName:(NSInteger)folderId newName:(NSString *)newName
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
	[self executeSQLWithFormat:@"update folders set foldername='%@' where folder_id=%ld", preparedNewName, folderId];

	// Send a notification that the folder has changed. It is the responsibility of the
	// notifiee that they work out that the name is the part that has changed.
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FolderNameChanged" object:[NSNumber numberWithInt:folderId]];
	return YES;
}

/* setFolderDescription
 * Sets the folder description both in the internal structure and in the folder_description table.
 */
-(BOOL)setFolderDescription:(NSInteger)folderId newDescription:(NSString *)newDescription
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
	if ([[folder feedDescription] isEqualToString:newDescription])
		return NO;
	
	[folder setFeedDescription:newDescription];
	
	// Add a new description or update the one we have
	NSString * preparedNewDescription = [SQLDatabase prepareStringForQuery:newDescription];
	[self executeSQLWithFormat:@"update rss_folders set description='%@' where folder_id=%ld", preparedNewDescription, folderId];

	// Send a notification that the folder has changed. It is the responsibility of the
	// notifiee that they work out that the description is the part that has changed.
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FolderDescriptionChanged" object:[NSNumber numberWithInt:folderId]];
	return YES;
}

/* setFolderHomePage
 * Sets the folder's associated URL link in both in the internal structure and in the folder_description table.
 */
-(BOOL)setFolderHomePage:(NSInteger)folderId newHomePage:(NSString *)newHomePage
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
	if ([[folder homePage] isEqualToString:newHomePage]||newHomePage==nil)
		return NO;

	[folder setHomePage:newHomePage];

	// Add a new link or update the one we have
	NSString * preparedNewLink = [SQLDatabase prepareStringForQuery:newHomePage];
	[self executeSQLWithFormat:@"update rss_folders set home_page='%@' where folder_id=%ld", preparedNewLink, folderId];

	// Send a notification that the folder has changed. It is the responsibility of the
	// notifiee that they work out that the link is the part that has changed.
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FolderHomePageChanged" object:[NSNumber numberWithInt:folderId]];
	return YES;
}

/* setFolderUsername
 * Sets the folder's user name in both in the internal structure and in the folder_description table.
 */
-(BOOL)setFolderUsername:(NSInteger)folderId newUsername:(NSString *)name
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
	[self executeSQLWithFormat:@"update rss_folders set username='%@' where folder_id=%ld", preparedName, folderId];
	return YES;
}

/* setParent
 * Changes the parent for the specified folder then updates the database.
 */
-(BOOL)setParent:(NSInteger)newParentID forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;
	
	Folder * folder = [self folderFromID:folderId];
	if ([folder parentId] == newParentID)
		return NO;

	// Sanity check. Make sure we're not reparenting to our
	// subordinate.
	Folder * parentFolder = [self folderFromID:newParentID];
	while (parentFolder != nil)
	{
		if ([parentFolder itemId] == folderId)
			return NO;
		parentFolder = [self folderFromID:[parentFolder parentId]];
	}

	// Adjust the child unread count for the old parent.
	NSInteger adjustment = 0;
	if ([folder isRSSFolder])
		adjustment = [folder unreadCount];
	else if ([folder isGroupFolder])
		adjustment = [folder childUnreadCount];
	if (adjustment > 0)
	{
		parentFolder = [self folderFromID:[folder parentId]];
		while (parentFolder != nil)
		{
			[parentFolder setChildUnreadCount:[parentFolder childUnreadCount] - adjustment];
			parentFolder = [self folderFromID:[parentFolder parentId]];
		}
	}
	
	// Do the re-parent
	[folder setParent:newParentID];
	
	// In addition to reparenting the child, we also need to fix up the unread count for all
	// precedent parents.
	if (adjustment > 0)
	{
		parentFolder = [self folderFromID:newParentID];
		while (parentFolder != nil)
		{
			[parentFolder setChildUnreadCount:[parentFolder childUnreadCount] + adjustment];
			parentFolder = [self folderFromID:[parentFolder parentId]];
		}
	}

	// Update the database now
	[self executeSQLWithFormat:@"update folders set parent_id=%ld where folder_id=%ld", newParentID, folderId];
	return YES;
}

/* setFirstChild
 * Changes the first child of the specified folder and then updates the database.
 */
-(BOOL)setFirstChild:(NSInteger)childId forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;
	
	if (folderId == MA_Root_Folder)
	{
		[self executeSQLWithFormat:@"update info set first_folder=%ld", childId];
	}
	else
	{
		Folder * folder = [self folderFromID:folderId];
		if (folder == nil)
			return NO;
		
		[folder setFirstChildId:childId];
		
		[self executeSQLWithFormat:@"update folders set first_child=%ld where folder_id=%ld", childId, folderId];
	}
	
	return YES;
}

/* setNextSibling
 * Changes the next sibling for the specified folder and then updates the database.
 */
-(BOOL)setNextSibling:(NSUInteger)nextSiblingId forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;
	
	Folder * folder = [self folderFromID:folderId];
	if (folder == nil)
		return NO;
	
	[folder setNextSiblingId:nextSiblingId];
	
	[self executeSQLWithFormat:@"update folders set next_sibling=%lu where folder_id=%ld", nextSiblingId, folderId];
	return YES;
}

/* firstFolderId
 * Returns the ID of the first folder (first child of root).
 */
-(NSInteger)firstFolderId
{
	NSInteger folderId = 0;
	[self verifyThreadSafety];
	SQLResult * results = [sqlDatabase performQuery:@"select first_folder from info"];
	if (results && [results rowCount])
	{
		folderId = [[[results rowAtIndex:0] stringForColumn:@"first_folder"] intValue];
	}
	[results release];
	return folderId;
}

/* trashFolderId;
 * Returns the ID of the trash folder.
 */
-(NSInteger)trashFolderId
{
	return [trashFolder itemId];
}

/* searchFolderId;
 * Returns the ID of the search folder. If it doesn't exist then we create
 * it now.
 */
-(NSInteger)searchFolderId
{
	if (searchFolder == nil)
	{
		NSInteger folderId = [self addFolder:MA_Root_Folder afterChild:0 folderName: NSLocalizedString(@"Search Results", nil) type:MA_Search_Folder canAppendIndex:YES];
		searchFolder = [[self folderFromID:folderId] retain];
	}
	return [searchFolder itemId];
}

/* folderFromID
 * Retrieve a Folder given it's ID.
 */
-(Folder *)folderFromID:(NSInteger)wantedId
{
	return [foldersDict objectForKey:[NSNumber numberWithInt:wantedId]];
}

/* folderFromName
 * Retrieve a Folder given it's name.
 */
-(Folder *)folderFromName:(NSString *)wantedName
{	
	Folder * folder;
	for (folder in [foldersDict objectEnumerator])
	{
		if ([[folder name] isEqualToString:wantedName])
			break;
	}
	return folder;
}

/* folderFromFeedURL
 * Returns the RSSFolder that is subscribed to the specified feed URL.
 */
-(Folder *)folderFromFeedURL:(NSString *)wantedFeedURL;
{
	Folder * folder;
	
	for (folder in [foldersDict objectEnumerator])
	{
		if ([[folder feedURL] isEqualToString:wantedFeedURL])
			break;
	}
	return folder;
}

/* handleAutoSortFoldersTreeChange
 * Called when preference changes for sorting folders tree.
 * Store the new method in the database.
 */
-(void)handleAutoSortFoldersTreeChange:(NSNotification *)notification
{
	if (!readOnly)
		[self executeSQLWithFormat:@"update info set folder_sort=%d", [[Preferences standardPreferences] foldersTreeSortMethod]];
}

/* createArticle
 * Adds or updates an article in the specified folder. Returns YES if the
 * article was added or updated or NO if we couldn't add the article for
 * some reason.
 */
-(BOOL)createArticle:(NSInteger)folderID article:(Article *)article guidHistory:(NSArray *)guidHistory
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;
	
	// Make sure the folder ID is valid. We need it to decipher
	// some info before we add the article.
	Folder * folder = [self folderFromID:folderID];
	if (folder != nil)
	{
		// Prime the article cache
		[self initArticleArray:folder];
		
		// Extract the article data from the dictionary.
		NSString * articleBody = [article body];
		NSString * articleTitle = [article title]; 
		NSDate * articleDate = [article date];
		NSString * articleLink = [article link];
		NSString * userName = [article author];
		NSString * articleEnclosure = [article enclosure];
		NSString * articleGuid = [article guid];
		NSInteger parentId = [article parentId];
		BOOL marked_flag = [article isFlagged];
		BOOL read_flag = [article isRead];
		BOOL revised_flag = [article isRevised];
		BOOL deleted_flag = [article isDeleted];
		BOOL hasenclosure_flag = [article hasEnclosure];
		
		// We always set the created date ourselves
		[article setCreatedDate:[NSDate date]];
		
		// Set some defaults
		if (articleDate == nil)
			articleDate = [NSDate date];
		if (userName == nil)
			userName = @"";
		
		// Parse off the title
		if (articleTitle == nil || [articleTitle isBlank])
			articleTitle = [articleBody firstNonBlankLine];
		
		// Save date as time intervals
		NSTimeInterval interval = [articleDate timeIntervalSince1970];
		NSTimeInterval createdInterval = [[article createdDate] timeIntervalSince1970];
		
		// Does this article already exist?
		Article * existingArticle = [folder articleFromGuid:articleGuid];
		// We're going to ignore the problem of feeds re-using guids, which is very naughty! Bad feed!
		
		// Fix title and article body so they're acceptable to SQL
		NSString * preparedArticleTitle = [SQLDatabase prepareStringForQuery:articleTitle];
		NSString * preparedArticleText = [SQLDatabase prepareStringForQuery:articleBody];
		NSString * preparedArticleLink = [SQLDatabase prepareStringForQuery:articleLink];
		NSString * preparedUserName = [SQLDatabase prepareStringForQuery:userName];
		NSString * preparedArticleGuid = [SQLDatabase prepareStringForQuery:articleGuid];
		NSString * preparedEnclosure = [SQLDatabase prepareStringForQuery:articleEnclosure];
		
		// Unread count adjustment factor
		NSInteger adjustment = 0;
		
		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		if (existingArticle == nil && [guidHistory containsObject:articleGuid])
		{
			return NO; // Article has been deleted and removed from database, so ignore
		}
		else if (existingArticle == nil)
		{
			SQLResult * results;
			
			results = [sqlDatabase performQueryWithFormat:
				@"insert into messages (message_id, parent_id, folder_id, sender, link, date, createddate, read_flag, marked_flag, deleted_flag, title, text, revised_flag, enclosure, hasenclosure_flag) "
				@"values('%@', %ld, %ld, '%@', '%@', %f, %f, %d, %d, %d, '%@', '%@', %d, '%@',%d)",
				preparedArticleGuid,
				parentId,
				folderID,
				preparedUserName,
				preparedArticleLink,
				interval,
				createdInterval,
				read_flag,
				marked_flag,
				deleted_flag,
				preparedArticleTitle,
				preparedArticleText,
				revised_flag,
				preparedEnclosure,
				hasenclosure_flag];
			if (!results)
				return NO;
			[results release];
			[self executeSQLWithFormat:@"insert into rss_guids (message_id, folder_id) values ('%@', %ld)", preparedArticleGuid, folderID];
			
			// Add the article to the folder
			[article setStatus:MA_MsgStatus_New];
			[folder addArticleToCache:article];
			
			// Update folder unread count
			if (!read_flag)
				adjustment = 1;
		}
		else if ([existingArticle isDeleted])
		{
			return NO;
		}
		else if (![[Preferences standardPreferences] boolForKey:MAPref_CheckForUpdatedArticles])
		{
			return NO;
		}
		else
		{
			// The article is revised if either the title or the body has changed.
			
			NSString * existingTitle = [existingArticle title];
			BOOL isArticleRevised = ![existingTitle isEqualToString:articleTitle];
			
			if (!isArticleRevised)
			{
				NSString * existingBody = [existingArticle body];
				// If the folder is not displayed, then the article text has not been loaded yet.
				if (existingBody == nil)
				{
					SQLResult * results = [sqlDatabase performQueryWithFormat:@"select text from messages where folder_id=%ld and message_id='%@'", folderID, preparedArticleGuid];
					if (results && [results rowCount])
					{
						existingBody = [[results rowAtIndex:0] stringForColumn:@"text"];
					}
					else
						existingBody = @"";
					[results release];
				}
				
				isArticleRevised = ![existingBody isEqualToString:articleBody];
			}
			
			if (isArticleRevised)
			{
				// Only pre-existing articles should be marked as revised.
				// New articles created during the current refresh should not be marked as revised,
				// even if there are multiple versions of the new article in the feed.
				revised_flag = [existingArticle isRevised];
				if (!revised_flag && ([existingArticle status] == MA_MsgStatus_Empty))
					revised_flag = YES;
				
				SQLResult * results;
				results = [sqlDatabase performQueryWithFormat:@"update messages set parent_id=%ld, sender='%@', link='%@', date=%f, "
					@"read_flag=0, title='%@', text='%@', revised_flag=%d where folder_id=%ld and message_id='%@'",
					parentId,
					preparedUserName,
					preparedArticleLink,
					interval,
					preparedArticleTitle,
					preparedArticleText,
					revised_flag,
					folderID,
					preparedArticleGuid];
				if (!results)
					return NO;
				[results release];
				
				[existingArticle setTitle:articleTitle];
				[existingArticle setBody:articleBody];
				[existingArticle markRevised:revised_flag];
				
				// Update folder unread count if necessary
				if ([existingArticle isRead])
				{
					adjustment = 1;
					[article setStatus:MA_MsgStatus_New];
					[existingArticle markRead:NO];
				}
				else
					[article setStatus:MA_MsgStatus_Updated];
			}
			else
			{
				return NO;
			}
		}
		
		// Fix unread count on parent folders
		if (adjustment != 0)
		{
			countOfUnread += adjustment;
			[self setFolderUnreadCount:folder adjustment:adjustment];
		}
		return YES;
	}
	return NO;
}

/* purgeArticlesOlderThanDays
 * Deletes all non-flagged articles from the messages list that are older than the specified
 * number of days.
 */
-(void)purgeArticlesOlderThanDays:(NSUInteger)daysToKeep
{
	if (daysToKeep > 0)
	{
		NSInteger dayDelta = (daysToKeep % 1000);
		NSInteger monthDelta = (daysToKeep / 1000);
		NSTimeInterval timeDiff = [[[NSCalendarDate calendarDate] dateByAddingYears:0 months:-monthDelta days:-dayDelta hours:0 minutes:0 seconds:0] timeIntervalSince1970];

		[self verifyThreadSafety];
		SQLResult * results = [sqlDatabase performQueryWithFormat:@"update messages set deleted_flag=1 where deleted_flag=0 and marked_flag=0 and read_flag=1 and date < %f", timeDiff];
		[results release];
	}
}

/* purgeDeletedArticles
 * Remove from the database all articles which have the deleted_flag field set to YES. This
 * also requires that we remove the same articles from all folder caches.
 */
-(void)purgeDeletedArticles
{
	// Verify we're on the right thread
	[self verifyThreadSafety];

	SQLResult * results = [sqlDatabase performQuery:@"delete from messages where deleted_flag=1"];
	if (results)
	{
		[self compactDatabase];
		[trashFolder clearCache];

		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[self trashFolderId]]];
	}
	[results release];
}

/* deleteArticle
 * Permanently deletes a article from the specified folder
 */
-(BOOL)deleteArticle:(NSInteger)folderId guid:(NSString *)guid
{
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		// Prime the article cache
		[self initArticleArray:folder];

		Article * article = [folder articleFromGuid:guid];
		if (article != nil)
		{
			NSString * preparedGuid = [SQLDatabase prepareStringForQuery:guid];

			// Verify we're on the right thread
			[self verifyThreadSafety];
			
			SQLResult * results = [sqlDatabase performQueryWithFormat:@"delete from messages where folder_id=%ld and message_id='%@'", folderId, preparedGuid];
			if (results)
			{
				if (![article isRead])
				{
					[self setFolderUnreadCount:folder adjustment:-1];
					--countOfUnread;
				}
				[folder removeArticleFromCache:guid];
				[results release];
				return YES;
			}
		}
	}
	return NO;
}

/* initSmartfoldersDict
 * Preloads all the smart folders into the smartfoldersDict dictionary.
 */
-(void)initSmartfoldersDict
{
	if (!initializedSmartfoldersDict)
	{
		// Make sure we have a database.
		NSAssert(sqlDatabase, @"Database not assigned for this item");
		
		SQLResult * results;

		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		results = [sqlDatabase performQuery:@"select folder_id, search_string from smart_folders"];
		if (results && [results rowCount])
		{
			for (SQLRow * row in [results rowEnumerator])
			{
				NSInteger folderId = [[row stringForColumnAtIndex:0] intValue];
				NSString * search_string = [row stringForColumnAtIndex:1];
				
				CriteriaTree * criteriaTree = [[CriteriaTree alloc] initWithString:search_string];
				[smartfoldersDict setObject:criteriaTree forKey:[NSNumber numberWithInt:folderId]];
				[criteriaTree release];
			}
		}
		[results release];
		initializedSmartfoldersDict = YES;
	}
}

/* searchStringForSmartFolder
 * Retrieve the smart folder criteria string for the specified folderId. Returns nil if
 * folderId is not a smart folder.
 */
-(CriteriaTree *)searchStringForSmartFolder:(NSInteger)folderId
{
	[self initSmartfoldersDict];
	return [smartfoldersDict objectForKey:[NSNumber numberWithInt:folderId]];
}

/* addSmartFolder
 * Create a new smart folder. If the specified folder already exists, then this is synonymous to
 * calling updateSearchFolder.
 */
-(NSInteger)addSmartFolder:(NSString *)folderName underParent:(NSInteger)parentId withQuery:(CriteriaTree *)criteriaTree
{
	Folder * folder = [self folderFromName:folderName];

	if (folder)
	{
		[self updateSearchFolder:[folder itemId] withFolder:folderName withQuery:criteriaTree];
		return [folder itemId];
	}

	NSInteger folderId = [self addFolder:parentId afterChild:0 folderName:folderName type:MA_Smart_Folder canAppendIndex:NO];
	if (folderId != -1)
	{
		NSString * preparedQueryString = [SQLDatabase prepareStringForQuery:[criteriaTree string]];
		[self executeSQLWithFormat:@"insert into smart_folders (folder_id, search_string) values (%ld, '%@')", folderId, preparedQueryString];
		[smartfoldersDict setObject:criteriaTree forKey:[NSNumber numberWithInt:folderId]];
	}
	return folderId;
}

/* updateSearchFolder
 * Updates the search string for the specified folder.
 */
-(BOOL)updateSearchFolder:(NSInteger)folderId withFolder:(NSString *)folderName withQuery:(CriteriaTree *)criteriaTree
{
	Folder * folder = [self folderFromID:folderId];
	if (![[folder name] isEqualToString:folderName])
		[self setFolderName:folderId newName:folderName];
	
	// Update the smart folder string
	NSString * preparedQueryString = [SQLDatabase prepareStringForQuery:[criteriaTree string]];
	[self executeSQLWithFormat:@"update smart_folders set search_string='%@' where folder_id=%ld", preparedQueryString, folderId];
	[smartfoldersDict setObject:criteriaTree forKey:[NSNumber numberWithInt:folderId]];
	
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
	return YES;
}

/* initFolderArray
 * Initializes the folder array if necessary.
 */
-(void)initFolderArray
{
	if (!initializedfoldersDict)
	{
		// Make sure we have a database.
		NSAssert(sqlDatabase, @"Database not assigned for this item");
		
		// Keep running count of total unread articles
		countOfUnread = 0;
		
		SQLResult * results;

		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		results = [sqlDatabase performQuery:@"select folder_id, parent_id, foldername, unread_count, last_update,"
			@" type, flags, next_sibling, first_child from folders order by folder_id"];
		if (results && [results rowCount])
		{			
			for (SQLRow * row in [results rowEnumerator])
			{
				NSInteger newItemId = [[row stringForColumnAtIndex:0] intValue];
				NSInteger newParentId = [[row stringForColumnAtIndex:1] intValue];
				NSString * name = [row stringForColumnAtIndex:2];
				NSInteger unreadCount = [[row stringForColumnAtIndex:3] intValue];
				NSDate * lastUpdate = [NSDate dateWithTimeIntervalSince1970:[[row stringForColumnAtIndex:4] doubleValue]];
				NSInteger type = [[row stringForColumnAtIndex:5] intValue];
				NSInteger flags = [[row stringForColumnAtIndex:6] intValue];
				NSInteger nextSibling = [[row stringForColumnAtIndex:7] intValue];
				NSInteger firstChild = [[row stringForColumnAtIndex:8] intValue];
				
				Folder * folder = [[[Folder alloc] initWithId:newItemId parentId:newParentId name:name type:type] autorelease];
				[folder setNextSiblingId:nextSibling];
				[folder setFirstChildId:firstChild];
				if (!IsRSSFolder(folder) && !IsGoogleReaderFolder(folder))
					unreadCount = 0;
				[folder setUnreadCount:unreadCount];
				[folder setLastUpdate:lastUpdate];
				[folder setFlag:flags];
				if (unreadCount > 0)
					countOfUnread += unreadCount;
				[foldersDict setObject:folder forKey:[NSNumber numberWithInt:newItemId]];

				// Remember the trash folder
				if (IsTrashFolder(folder))
					trashFolder = [folder retain];

				// Remember the search folder
				if (IsSearchFolder(folder))
					searchFolder = [folder retain];
			}
		}
		[results release];

		// Load all RSS folders and add them to the list.
		results = [sqlDatabase performQuery:@"select folder_id, feed_url, username, last_update_string, description, home_page from rss_folders"];
		if (results && [results rowCount])
		{
			for (SQLRow * row in[results rowEnumerator])
			{
				NSInteger folderId = [[row stringForColumnAtIndex:0] intValue];
				NSString * url = [row stringForColumnAtIndex:1];
				NSString * username = [row stringForColumnAtIndex:2];
				NSString * lastUpdateString = [row stringForColumnAtIndex:3];
				NSString * descriptiontext = [row stringForColumnAtIndex:4];
				NSString * linktext = [row stringForColumnAtIndex:5];
				
				Folder * folder = [self folderFromID:folderId];
				[folder setFeedDescription:descriptiontext];
				[folder setHomePage:linktext];
				[folder setFeedURL:url];
				[folder setLastUpdateString:lastUpdateString];
				[folder setUsername:username];
			}
		}
		[results release];
		
		// Fix the childUnreadCount for every parent		
		for (Folder * folder in [foldersDict objectEnumerator])
		{
			if ([folder unreadCount] > 0 && [folder parentId] != MA_Root_Folder)
			{
				Folder * parentFolder = [self folderFromID:[folder parentId]];
				while (parentFolder != nil)
				{
					[parentFolder setChildUnreadCount:[parentFolder childUnreadCount] + [folder unreadCount]];
					parentFolder = [self folderFromID:[parentFolder parentId]];
				}
			}
		}
		// Done
		initializedfoldersDict = YES;
	}
}

/* arrayOfFolders
 * Returns an NSArray of all folders with the specified parent. It does not include the
 * parent folder nor does it include any folders within groups under that parent. Specifically
 * it is a single level search and is actually slightly faster than arrayofSubFolders for
 * callers that require this distinction.
 */
-(NSArray *)arrayOfFolders:(NSInteger)parentId
{
	// Prime the cache
	if (initializedfoldersDict == NO)
		[self initFolderArray];

	NSMutableArray * newArray = [NSMutableArray array];
	if (newArray != nil)
	{		
		for (Folder * folder in [foldersDict objectEnumerator])
		{
			if ([folder parentId] == parentId)
				[newArray addObject:folder];
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
		NSInteger parentId = [folder itemId];
		
		for (Folder * item in [foldersDict objectEnumerator])
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

/* arrayOfAllFolders
 * Returns an unsorted array of all regular folders (RSS folders and group folders).
 */
-(NSArray *)arrayOfAllFolders
{
	// Prime the cache
	if (initializedfoldersDict == NO)
		[self initFolderArray];
	
	return [foldersDict allValues];
}

/* initArticleArray
 * Ensures that the specified folder has a minimal cache of article information.
 */
-(BOOL)initArticleArray:(Folder *)folder
{
	// Prime the folder cache
	[self initFolderArray];

	// Exit now if we're already initialized
	if ([folder countOfCachedArticles] == -1)
	{
		NSInteger folderId = [folder itemId];
		SQLResult * results;

		// Initialize to indicate that the folder array is valid.
		[folder markFolderEmpty];
		
		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		results = [sqlDatabase performQueryWithFormat:@"select message_id, read_flag, marked_flag, deleted_flag, title, link, revised_flag, hasenclosure_flag, enclosure from messages where folder_id=%ld", folderId];
		if (results && [results rowCount])
		{
			NSInteger unread_count = 0;
			SQLRow * row;

			for (row in [results rowEnumerator])
			{
				NSString * guid = [row stringForColumnAtIndex:0];
				BOOL read_flag = [[row stringForColumnAtIndex:1] intValue];
				BOOL marked_flag = [[row stringForColumnAtIndex:2] intValue];
				BOOL deleted_flag = [[row stringForColumnAtIndex:3] intValue];
				NSString * title = [row stringForColumnAtIndex:4];
				NSString * link = [row stringForColumnAtIndex:5];
				BOOL revised_flag = [[row stringForColumnAtIndex:6] intValue];
				BOOL hasenclosure_flag = [[row stringForColumnAtIndex:7] intValue];
				NSString * enclosure = [row stringForColumnAtIndex:8];

				// Keep our own track of unread articles
				if (!read_flag)
					++unread_count;
				
				Article * article = [[Article alloc] initWithGuid:guid];
				[article markRead:read_flag];
				[article markFlagged:marked_flag];
				[article markRevised:revised_flag];
				[article markDeleted:deleted_flag];
				[article setFolderId:folderId];
				[article setTitle:title];
				[article setLink:link];
				[article setEnclosure:enclosure];
				[article setHasEnclosure:hasenclosure_flag];
				[folder addArticleToCache:article];
				[article release];
			}

			// This is a good time to do a quick check to ensure that our
			// own count of unread is in sync with the folders count and fix
			// them if not.
			if (unread_count != [folder unreadCount])
			{
				NSLog(@"Fixing unread count for %@ (%ld on folder versus %ld in articles)", [folder name], (long)[folder unreadCount], (long)unread_count);
				NSInteger diff = (unread_count - [folder unreadCount]);
				[self setFolderUnreadCount:folder adjustment:diff];
				countOfUnread += diff;
			}
		}
		[results release];
	}
	return YES;
}

/* setSearchString
 * Sets the current search string for the search folder.
 */
-(void)setSearchString:(NSString *)newSearchString
{
	[newSearchString retain];
	[searchString release];
	searchString = newSearchString;
}

/* sqlScopeForFolder
 * Create a SQL 'where' clause that scopes to either the individual folder or the folder and
 * all sub-folders.
 */
-(NSString *)sqlScopeForFolder:(Folder *)folder flags:(NSInteger)scopeFlags
{
	Field * field = [self fieldByName:MA_Field_Folder];
	NSString * operatorString = (scopeFlags & MA_Scope_Inclusive) ? @"=" : @"<>";
	NSString * conditionString = (scopeFlags & MA_Scope_Inclusive) ? @" or " : @" and ";
	BOOL subScope = (scopeFlags & MA_Scope_SubFolders) ? YES : NO; // Avoid problems casting into BOOL.
	NSInteger folderId;

	// If folder is nil, rather than report an error, default to some impossible value
	if (folder != nil)
		folderId = [folder itemId];
	else
	{
		subScope = NO;
		folderId = 0;
	}

	// Group folders must always have subscope
	if (folder && IsGroupFolder(folder))
		subScope = YES;

	// Straightforward folder is <something>
	if (!subScope)
		return [NSString stringWithFormat:@"%@%@%ld", [field sqlField], operatorString, folderId];

	// For under/not-under operators, we're creating a SQL statement of the format
	// (folder_id = <value1> || folder_id = <value2>...). It is possible to try and simplify
	// the string by looking for ranges but I suspect that given the spread of IDs this may
	// well be false optimisation.
	//
	NSArray * childFolders = [self arrayOfSubFolders:folder];
	NSMutableString * sqlString = [[NSMutableString alloc] init];
	NSInteger count = [childFolders count];
	NSInteger index;
	
	if (count > 1)
		[sqlString appendString:@"("];
	for (index = 0; index < count; ++index)
	{
		Folder * folder = [childFolders objectAtIndex:index];
		if (index > 0)
			[sqlString appendString:conditionString];
		[sqlString appendFormat:@"%@%@%ld", [field sqlField], operatorString, [folder itemId]];
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
	NSInteger count = 0;

	for (Criteria * criteria in [criteriaTree criteriaEnumerator])
	{
		Field * field = [self fieldByName:[criteria field]];
		NSAssert1(field != nil, @"Criteria field %@ does not have an associated database field", [criteria field]);

		NSString * operatorString = nil;
		NSString * valueString = nil;
		
		switch ([criteria operator])
		{
			case MA_CritOper_Is:					operatorString = @"=%@"; break;
			case MA_CritOper_IsNot:					operatorString = @"<>%@"; break;
			case MA_CritOper_IsLessThan:			operatorString = @"<%@"; break;
			case MA_CritOper_IsGreaterThan:			operatorString = @">%@"; break;
			case MA_CritOper_IsLessThanOrEqual:		operatorString = @"<=%@"; break;
			case MA_CritOper_IsGreaterThanOrEqual:  operatorString = @">=%@"; break;
			case MA_CritOper_Contains:				operatorString = @" regexp '%@'"; break;
			case MA_CritOper_NotContains:			operatorString = @" not regexp '%@'"; break;
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

		// Unknown operator - skip this clause
		if (operatorString == nil)
			continue;
		
		if (count++ > 0)
			[sqlString appendString:[criteriaTree condition] == MA_CritCondition_All ? @" and " : @" or "];
		
		switch ([field type])
		{
			case MA_FieldType_Flag:
				valueString = [[criteria value] isEqualToString:@"Yes"] ? @"1" : @"0";
				break;
				
			case MA_FieldType_Folder: {
				Folder * folder = [self folderFromName:[criteria value]];
				NSInteger scopeFlags = 0;

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
				NSCalendarDate * startDate = [NSCalendarDate date];
				NSString * criteriaValue = [[criteria value] lowercaseString];
				NSInteger spanOfDays = 1;
				
				// "yesterday" is a short hand way of specifying the previous day.
				if ([criteriaValue isEqualToString:@"yesterday"])
				{
					startDate = [startDate dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0];
				}
				// "last week" is a short hand way of specifying a range from 7 days ago to today.
				else if ([criteriaValue isEqualToString:@"last week"])
				{
					startDate = [startDate dateByAddingYears:0 months:0 days:-6 hours:0 minutes:0 seconds:0];
					spanOfDays = 7;
				}
				
				criteriaValue = [NSString stringWithFormat:@"%ld/%ld/%ld %d:%d:%d", [startDate dayOfMonth], [startDate monthOfYear], [startDate yearOfCommonEra], 0, 0, 0];
				startDate = [NSCalendarDate dateWithString:criteriaValue calendarFormat:@"%d/%m/%Y %H:%M:%S"];
				
				if ([criteria operator] == MA_CritOper_Is)
				{
					NSCalendarDate * endDate;

					// Special case for Date is <date> because the resolution of the date field is in
					// milliseconds. So we need to translate this to a range for this to make sense.
					endDate = [startDate dateByAddingYears:0 months:0 days:spanOfDays hours:0 minutes:0 seconds:0];
					operatorString = [NSString stringWithFormat:@">=%f and %@<%f", [startDate timeIntervalSince1970], [field sqlField], [endDate timeIntervalSince1970]];
					valueString = @"";
				}
				else
				{
					if (([criteria operator] == MA_CritOper_IsAfter) || ([criteria operator] == MA_CritOper_IsOnOrBefore))
						startDate = [startDate dateByAddingYears:0 months:0 days:0 hours:23 minutes:59 seconds:59];
					valueString = [NSString stringWithFormat:@"%f", [startDate timeIntervalSince1970]];
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
-(CriteriaTree *)criteriaForFolder:(NSInteger)folderId
{
	Folder * folder = [self folderFromID:folderId];
	if (folder == nil)
		return nil;

	if (IsSearchFolder(folder))
		return [self searchStringToTree];
	
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
		[self initSmartfoldersDict];
		return [smartfoldersDict objectForKey:[NSNumber numberWithInt:folderId]];
	}

	CriteriaTree * tree = [[CriteriaTree alloc] init];
	Criteria * clause = [[Criteria alloc] initWithField:MA_Field_Folder withOperator:MA_CritOper_Under withValue:[folder name]];
	[tree addCriteria:clause];
	[clause release];
	return [tree autorelease];
}

/* arrayOfUnreadArticles
 * Retrieves an array of ArticleReference objects that represent all unread
 * articles in the specified folder.
 */
-(NSArray *)arrayOfUnreadArticles:(NSInteger)folderId
{
	Folder * folder = [self folderFromID:folderId];
	NSMutableArray * newArray = [NSMutableArray arrayWithCapacity:[folder unreadCount]];
	if (folder != nil)
	{
		if ([folder countOfCachedArticles] > 0)
		{
			// Messages already cached in this folder so use those. Note the use of
			// reverseObjectEnumerator since the odds are that the unread articles are
			// likely to be clustered with the most recent articles at the end of the
			// array so it makes the code slightly faster.
			NSInteger unreadCount = [folder unreadCount];
			NSEnumerator * enumerator = [[folder articles] reverseObjectEnumerator];
			Article * theRecord;

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
			SQLResult * results = [sqlDatabase performQueryWithFormat:@"select message_id from messages where folder_id=%ld and read_flag=0", folderId];
			if (results && [results rowCount])
			{				
				for (SQLRow * row in [results rowEnumerator])
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

/* arrayOfArticles
 * Retrieves an array containing all articles (except for text) for the
 * specified folder. If folderId is zero, all folders are searched. The
 * filterString option constrains the array to all those articles that
 * contain the specified filter.
 */
-(NSArray *)arrayOfArticles:(NSInteger)folderId filterString:(NSString *)filterString
{
	NSMutableArray * newArray = [NSMutableArray array];
	NSString * filterClause = @"";
	NSString * queryString;
	Folder * folder = nil;
	NSInteger unread_count = 0;

	queryString=@"select message_id, folder_id, parent_id, read_flag, marked_flag, deleted_flag, title, sender,"
		@" link, createddate, date, text, revised_flag, hasenclosure_flag, enclosure from messages";

	// If folderId is zero then we're searching the entire
	// database with or without a filter string.
	if (folderId == 0)
	{
		if ([filterString isNotEqualTo:@""])
			filterClause = [NSString stringWithFormat:@" where text like '%%%@%%'", filterString];
		queryString = [NSString stringWithFormat:@"%@%@", queryString, filterClause];
	}
	else
	{
		folder = [self folderFromID:folderId];
		if (folder == nil)
			return nil;
		[folder clearCache];

		// Construct a criteria tree for this query
		CriteriaTree * tree = [self criteriaForFolder:folderId];

		if ([filterString isNotEqualTo:@""])
			filterClause = [NSString stringWithFormat:@" and (title like '%%%@%%' or text like '%%%@%%')", filterString, filterString];
		queryString = [NSString stringWithFormat:@"%@ where (%@)%@", queryString, [self criteriaToSQL:tree], filterClause];
	}

	// Verify we're on the right thread
	[self verifyThreadSafety];

	// Time to run the query
	SQLResult * results = [sqlDatabase performQuery:queryString];
	if (results && [results rowCount])
	{
        Article * article;
        NSString * text;

		for (SQLRow * row in [results rowEnumerator])
		{
			article = [[Article alloc] initWithGuid:[row stringForColumnAtIndex:0]];
			[article setFolderId:[[row stringForColumnAtIndex:1] intValue]];
			[article setParentId:[[row stringForColumnAtIndex:2] intValue]];
			[article markRead:[[row stringForColumnAtIndex:3] intValue]];
			[article markFlagged:[[row stringForColumnAtIndex:4] intValue]];
			[article markDeleted:[[row stringForColumnAtIndex:5] intValue]];
			[article setTitle:[row stringForColumnAtIndex:6]];
			[article setAuthor:[row stringForColumnAtIndex:7]];
			[article setLink:[row stringForColumnAtIndex:8]];
			[article setCreatedDate:[NSDate dateWithTimeIntervalSince1970:[[row stringForColumnAtIndex:9] doubleValue]]];
			[article setDate:[NSDate dateWithTimeIntervalSince1970:[[row stringForColumnAtIndex:10] doubleValue]]];
        	text = [row stringForColumnAtIndex:11];
			[article setBody:text];
			[article markRevised:[[row stringForColumnAtIndex:12] intValue]];
			[article setHasEnclosure:[[row stringForColumnAtIndex:13] intValue]];
			[article setEnclosure:[row stringForColumnAtIndex:14]];
			if (folder == nil || ![article isDeleted] || IsTrashFolder(folder))
				[newArray addObject:article];
			[folder addArticleToCache:article];
            
			// Keep our own track of unread articles
			if (![article isRead])
				++unread_count;
            
			[article release];
		}

		// This is a good time to do a quick check to ensure that our
		// own count of unread is in sync with the folders count and fix
		// them if not.
		if (folder && [filterString isEqualTo:@""] && IsRSSFolder(folder))
		{
			if (unread_count != [folder unreadCount])
			{
				NSLog(@"Fixing unread count for %@ (%ld on folder versus %ld in articles)", [folder name], (long)[folder unreadCount], (long)unread_count);
				NSInteger diff = (unread_count - [folder unreadCount]);
				[self setFolderUnreadCount:folder adjustment:diff];
				countOfUnread += diff;
			}
		}
	}

	// Deallocate
	[results release];
	return newArray;
}

/* markFolderRead
 * Mark all articles in the folder and sub-folders read. This should be called
 * within a transaction since it is SQL intensive.
 */
-(BOOL)markFolderRead:(NSInteger)folderId
{
	Folder * folder;
	BOOL result = NO;

	// Recurse and mark child folders read too
	for (folder in [self arrayOfFolders:folderId])
	{
		if ([self markFolderRead:[folder itemId]])
			result = YES;
	}

	folder = [self folderFromID:folderId];
	if (folder != nil && [folder unreadCount] > 0)
	{
		[self verifyThreadSafety];
		SQLResult * results = [sqlDatabase performQueryWithFormat:@"update messages set read_flag=1 where folder_id=%ld and read_flag=0", folderId];
		if (results)
		{
			NSInteger count = [folder unreadCount];
			if ([folder countOfCachedArticles] > 0)
			{
				NSEnumerator * enumerator = [[folder articles] objectEnumerator];
				NSInteger remainingUnread = count;
				Article * article;

				while (remainingUnread > 0 && (article = [enumerator nextObject]) != nil)
					if (![article isRead])
					{
						[article markRead:YES];
						--remainingUnread;
					}
			}
			countOfUnread -= count;
			[self setFolderUnreadCount:folder adjustment:-count];
		}
		[results release];
		result = YES;
	}
	return result;
}

/* markArticleRead
 * Marks a article as read or unread.
 */
-(void)markArticleRead:(NSInteger)folderId guid:(NSString *)guid isRead:(BOOL)isRead
{
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		// Prime the article cache
		[self initArticleArray:folder];

		Article * article = [folder articleFromGuid:guid];
		if (article != nil && isRead != [article isRead])
		{
			NSString * preparedGuid = [SQLDatabase prepareStringForQuery:guid];

			// Verify we're on the right thread
			[self verifyThreadSafety];

			// Mark an individual article read
			SQLResult * results = [sqlDatabase performQueryWithFormat:@"update messages set read_flag=%d where folder_id=%ld and message_id='%@'", isRead, folderId, preparedGuid];
			if (results)
			{
				NSInteger adjustment = (isRead ? -1 : 1);

				[article markRead:isRead];
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
-(void)setFolderUnreadCount:(Folder *)folder adjustment:(NSUInteger)adjustment
{
	NSInteger unreadCount = [folder unreadCount];
	[folder setUnreadCount:unreadCount + adjustment];
	[self executeSQLWithFormat:@"update folders set unread_count=%ld where folder_id=%ld", [folder unreadCount], [folder itemId]];
	
	// Update childUnreadCount for our parent. Since we're just working
	// on one article, we do this the faster way.
	Folder * tmpFolder = folder;
	while ([tmpFolder parentId] != MA_Root_Folder)
	{
		tmpFolder = [self folderFromID:[tmpFolder parentId]];
		[tmpFolder setChildUnreadCount:[tmpFolder childUnreadCount] + adjustment];
	}
}

/* markArticleFlagged
 * Marks a article as flagged or unflagged.
 */
-(void)markArticleFlagged:(NSInteger)folderId guid:(NSString *)guid isFlagged:(BOOL)isFlagged
{
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		// Prime the article cache
		[self initArticleArray:folder];

		Article * article = [folder articleFromGuid:guid];
		if (article != nil && isFlagged != [article isFlagged])
		{
			NSString * preparedGuid = [SQLDatabase prepareStringForQuery:guid];

			// Verify we're on the right thread
			[self verifyThreadSafety];

			// Mark an individual article flagged
			SQLResult * results = [sqlDatabase performQueryWithFormat:@"update messages set marked_flag=%d where folder_id=%ld and message_id='%@'", isFlagged, folderId, preparedGuid];
			if (results)
			{

				[article markFlagged:isFlagged];
			}
			[results release];
		}
	}
}

/* markArticleDeleted
 * Marks a article as deleted. Deleted articles always get marked read first.
 */
-(void)markArticleDeleted:(NSInteger)folderId guid:(NSString *)guid isDeleted:(BOOL)isDeleted
{
	if (isDeleted)
		[self markArticleRead:folderId guid:guid isRead:YES];
	NSString * preparedGuid = [SQLDatabase prepareStringForQuery:guid];
	[self executeSQLWithFormat:@"update messages set deleted_flag=%d where folder_id=%d and message_id='%@'", isDeleted, folderId, preparedGuid];
}

/* isTrashEmpty
 * Returns YES if there are no deleted articles, NO if there are deleted articles
 */
-(BOOL)isTrashEmpty
{
	[self verifyThreadSafety];
	SQLResult * results = [sqlDatabase performQuery:@"select deleted_flag from messages where deleted_flag=1"];
	if (results)
	{
		if ([results rowCount] > 0)
		{
			[results release];
			return NO;
		}
		else
		{
			[results release];
			return YES;
		}
	}
	else
		return YES;
}

/* guidHistoryForFolderId
 * Returns an array of all article guids ever downloaded for the specified folder.
 */
-(NSArray *)guidHistoryForFolderId:(NSInteger)folderId
{
	NSMutableArray * articleGuids = [NSMutableArray array];
	
	[self verifyThreadSafety];
	SQLResult * results = [sqlDatabase performQueryWithFormat:@"select message_id from rss_guids where folder_id=%ld", folderId];
	if (results)
	{
		if ([results rowCount] > 0)
		{
			for (SQLRow * row in [results rowEnumerator])
			{
				NSString * guid = [row stringForColumn:@"message_id"];
				if (guid != nil)
				{
					[articleGuids addObject:guid];
				}
			}
		}
		
		[results release];
	}
	
	return articleGuids;
}

/* close
 * Close the database. All internal resources are released and a new,
 * possibly different, database can be opened instead.
 */
-(void)close
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[foldersDict removeAllObjects];
	[smartfoldersDict removeAllObjects];
	[fieldsOrdered release];
	[fieldsByName release];
	[trashFolder release];
	[sqlDatabase close];
	initializedfoldersDict = NO;
	initializedSmartfoldersDict = NO;
	countOfUnread = 0;
	sqlDatabase = nil;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[searchString release];
	[foldersDict release];
	[smartfoldersDict release];
	if (sqlDatabase)
		[self close];
	[sqlDatabase release];
	[super dealloc];
}
@end
