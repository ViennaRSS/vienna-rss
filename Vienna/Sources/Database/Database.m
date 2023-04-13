//
//  Database.m
//  Vienna
//
//  Created by Steve on Tue Feb 03 2004.
//  Copyright (c) 2004-2017 Steve Palmer and Vienna contributors. All rights reserved.
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

@import os.log;

#import "Database+Migration.h"
#import "Preferences.h"
#import "StringExtensions.h"
#import "Constants.h"
#import "ArticleRef.h"
#import "NSNotificationAdditions.h"
#import "Article.h"
#import "Folder.h"
#import "Field.h"
#import "Vienna-Swift.h"

#define VNA_LOG os_log_create("--", "Database")

@interface Database ()

@property (nonatomic) BOOL initializedfoldersDict;
@property (nonatomic) BOOL initializedSmartfoldersDict;
@property (nonatomic) NSMutableArray *fieldsOrdered;
@property (nonatomic) NSMutableDictionary *fieldsByName;
@property (nonatomic) NSMutableDictionary *foldersDict;
@property (nonatomic) NSMutableDictionary *smartfoldersDict;
@property (readwrite, nonatomic) BOOL readOnly;
@property (readwrite, nonatomic) NSInteger countOfUnread;

- (void)initaliseFields;
- (NSString *)relocateLockedDatabase:(NSString *)path;
- (CriteriaTree *)criteriaForFolder:(NSInteger)folderId;
- (NSArray *)arrayOfSubFolders:(Folder *)folder;
- (void)createInitialSmartFolder:(NSString *)folderName withCriteria:(Criteria *)criteria;
- (NSInteger)createFolderOnDatabase:(NSString *)name underParent:(NSInteger)parentId withType:(NSInteger)type;
+ (NSString *)databasePath;

@end

// The current database version number
static NSInteger const VNAMinimumSupportedDatabaseVersion = 12;
static NSInteger const VNACurrentDatabaseVersion = 23;

@implementation Database

NSNotificationName const VNADatabaseWillDeleteFolderNotification = @"Database Will Delete Folder";
NSNotificationName const VNADatabaseDidDeleteFolderNotification = @"Database Did Delete Folder";

/*!
 *  initialise the Database object with a specific path
 *
 *  @param dbPath the path to the database we want to initialise
 *
 *  @return an initialised Database object
 */
- (instancetype)initWithDatabaseAtPath:(NSString *)dbPath
{
    self = [super init];
    if (self) {
        _initializedfoldersDict = NO;
        _initializedSmartfoldersDict = NO;
        _countOfUnread = 0;
        _trashFolder = nil;
        _searchFolder = nil;
        _searchString = @"";
        _smartfoldersDict = [[NSMutableDictionary alloc] init];
        _foldersDict = [[NSMutableDictionary alloc] init];
        [self initaliseFields];
        _databaseQueue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
        // If we did not succeed getting read/write+create status,
        // then we need to prompt the user for a different location.
        if (_databaseQueue == nil) {
        	dbPath = [self relocateLockedDatabase:dbPath];
        	if (dbPath != nil)
        		_databaseQueue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
        }
        if (![self initialiseDatabase])
		{
			self = nil;
		}
    }
    return self;
}


/* sharedManager
 * Returns the single instance of the database manager.
 */
+ (instancetype)sharedManager {
    static id sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[Database alloc] initWithDatabaseAtPath:[Database databasePath]];
    });
    
    return sharedMyManager;
}


/*!
 *  Initialise the Vienna database. Create the initial database if
 *  necessary, otherwise migrate to the correct version if it is out of date
 *
 *  @return YES if the database is at the correct version and good to go
 */
- (BOOL)initialiseDatabase {
    NSInteger databaseVersion = self.databaseVersion;
    os_log_debug(VNA_LOG, "Database version: %ld", databaseVersion);
    
    if (databaseVersion >= VNACurrentDatabaseVersion) {
        // Most common case, so it is first
        // Nothing to do here
        return YES;
    } else if (databaseVersion >= VNAMinimumSupportedDatabaseVersion) {
        NSAlert * alert = [[NSAlert alloc] init];
        [alert setMessageText:NSLocalizedString(@"Database Upgrade", nil)];
        [alert setInformativeText:NSLocalizedString(@"Vienna must upgrade its database to the latest version. This may take a minute or so. We apologize for the inconvenience.", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Upgrade Database", @"Title of a button on an alert")];
        [alert addButtonWithTitle:NSLocalizedString(@"Quit Vienna", @"Title of a button on an alert")];
        NSInteger modalReturn = [alert runModal];
        if (modalReturn == NSAlertSecondButtonReturn)
        {
            return NO;
        }

        // Back up the database before any upgrade.
        NSFileManager *fileManager = NSFileManager.defaultManager;
        NSString *databaseBackupPath = [[Database databasePath] stringByAppendingPathExtension:@"bak"];
        NSError *error = nil;
        if ([fileManager fileExistsAtPath:databaseBackupPath]) {
            [fileManager removeItemAtPath:databaseBackupPath
                                    error:&error];
        }
        [fileManager copyItemAtPath:[Database databasePath]
                             toPath:databaseBackupPath
                              error:&error];

        // Log the error if the backup creation failed, but continue regardless.
        if (error) {
            NSLog(@"Database backup could not created: %@", error.localizedDescription);
        }

        [self.databaseQueue inDatabase:^(FMDatabase *db) {
            // Migrate the database to the newest version
            // TODO: move this into transaction so we can rollback on failure
            [Database migrateDatabase:db fromVersion:databaseVersion];
        }];
        
        // Confirm the database is now at the correct version
        if (self.databaseVersion == VNACurrentDatabaseVersion) {
            return YES;
        } else {
            return NO;
        }
    } else if ((databaseVersion > 0) && (databaseVersion < VNAMinimumSupportedDatabaseVersion)) {
        // database version is too old or schema not supported
        // TODO: help text for the user to fix the issue
        NSAlert *alert = [NSAlert new];
        alert.alertStyle = NSAlertStyleCritical;
        alert.messageText = NSLocalizedString(@"The database file format has changed", nil);
        alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"The database (%@) file format is not supported by this version of Vienna. Delete or rename the file and restart Vienna.", nil), self.databaseQueue.path];
        [alert runModal];
        return NO;
    } else if (databaseVersion == 0) {
        // database is fresh
		return [self setupInitialDatabase];
    }
    
    return NO;
}

/*!
 *  sets up an inital Vienna database at the given path
 *   TODO: put this into some Swift file to free VNACriteriaOperator enum from Objective-C legacy
 *
 *  @return True on succes
 */
- (BOOL)setupInitialDatabase {
    __block BOOL success = NO;
	[self.databaseQueue inDatabase:^(FMDatabase *db) {
		success = [self createTablesOnDatabase:db];
	}];
	if(!success) {
		return NO;
	}
    
    // Create a criteria to find all marked articles
    Criteria * markedCriteria = [[Criteria alloc] initWithField:MA_Field_Flagged operatorType:VNACriteriaOperatorEqualTo value:@"Yes"];
    [self createInitialSmartFolder:NSLocalizedString(@"Marked Articles", nil) withCriteria:markedCriteria];
    
    // Create a criteria to show all unread articles
    Criteria * unreadCriteria = [[Criteria alloc] initWithField:MA_Field_Read operatorType:VNACriteriaOperatorEqualTo value:@"No"];
    [self createInitialSmartFolder:NSLocalizedString(@"Unread Articles", nil) withCriteria:unreadCriteria];
    
    // Create a criteria to show all articles received today
    Criteria * todayCriteria = [[Criteria alloc] initWithField:MA_Field_Date operatorType:VNACriteriaOperatorEqualTo value:@"today"];
    [self createInitialSmartFolder:NSLocalizedString(@"Today's Articles", nil) withCriteria:todayCriteria];
    
	[self.databaseQueue inDatabase:^(FMDatabase *db) {
		// Create the trash folder
		[db executeUpdate:@"INSERT INTO folders (parent_id, foldername, unread_count, last_update, type, flags, next_sibling, first_child) VALUES (-1, ?, 0, 0, ?, 0, 0, 0)",
		 NSLocalizedString(@"Trash", nil), @(VNAFolderTypeTrash)];
	
		// Set the initial version
        db.userVersion = (uint32_t)VNACurrentDatabaseVersion;
	
		// Set the default sort order and write it to both the db and the prefs
		[db executeUpdate:@"INSERT INTO info (first_folder, folder_sort) VALUES (0, ?)",  @(VNAFolderSortManual)];
		[[Preferences standardPreferences] setFoldersTreeSortMethod:VNAFolderSortManual];
	}];
    
    // Set the initial folder order
    [self initFolderArray];
    NSInteger folderId = 0;
    NSInteger previousSibling = 0;
    NSArray * allFolders = self.foldersDict.allKeys;
    NSUInteger count = allFolders.count;
    NSUInteger index;
    for (index = 0u; index < count; ++index)
    {
        previousSibling = folderId;
        folderId = [allFolders[index] integerValue];
        if (index == 0u)
            [self setFirstChild:folderId forFolder:VNAFolderTypeRoot];
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
                NSDictionary * itemDict = demoFeedsDict[feedName];
                NSString * feedURL = [itemDict valueForKey:@"URL"];
                if (feedURL != nil && feedName != nil)
                    previousSibling = [self addRSSFolder:feedName underParent:VNAFolderTypeRoot afterChild:previousSibling subscriptionURL:feedURL];
            }
        }
    }
    return YES;
}


-(BOOL)createTablesOnDatabase:(FMDatabase *)db {
    // Enable FULL auto-vacuum mode before creating tables.
    [db executeUpdate:@"PRAGMA auto_vacuum = 1"];

    // Create the tables. We use the first table as a test whether we can
    // setup at the specified location
    [db executeUpdate:@"CREATE TABLE info (version, last_opened, first_folder, folder_sort)"];
    if ([db hadError]) {
        return NO;
    }
    [db executeUpdate:@"CREATE TABLE folders (folder_id integer primary key, parent_id, foldername, unread_count, last_update, type, flags, next_sibling, first_child)"];
    [db executeUpdate:@"CREATE TABLE messages (message_id, folder_id, parent_id, read_flag, marked_flag, deleted_flag, title, sender, link, createddate, date, text, revised_flag, enclosuredownloaded_flag, hasenclosure_flag, enclosure)"];
    [db executeUpdate:@"CREATE TABLE smart_folders (folder_id, search_string)"];
    [db executeUpdate:@"CREATE TABLE rss_folders (folder_id, feed_url, username, last_update_string, description, home_page, bloglines_id)"];
    [db executeUpdate:@"CREATE TABLE rss_guids (message_id, folder_id)"];
    [db executeUpdate:@"CREATE INDEX messages_folder_idx ON messages (folder_id)"];
    [db executeUpdate:@"CREATE INDEX messages_message_idx ON messages (message_id)"];
    [db executeUpdate:@"CREATE INDEX rss_guids_idx ON rss_guids (folder_id)"];
    [db executeUpdate:@"CREATE INDEX messages_read_flag ON messages(read_flag)"];
    [db executeUpdate:@"CREATE INDEX messages_deleted_flag ON messages(deleted_flag)"];
    if ([db hadError]) {
        return NO;
    }
    return YES;
}

/*!
 *  Initialise the mappings between the names of
 *  the database fields and the model fields
 */
-(void)initaliseFields {
    self.fieldsByName = [[NSMutableDictionary alloc] init];
    self.fieldsOrdered = [[NSMutableArray alloc] init];
    
    [self addField:MA_Field_Read type:VNAFieldTypeFlag tag:ArticleFieldIDRead sqlField:@"read_flag" visible:YES width:17];
    [self addField:MA_Field_Flagged type:VNAFieldTypeFlag tag:ArticleFieldIDFlagged sqlField:@"marked_flag" visible:YES width:17];
    [self addField:MA_Field_HasEnclosure type:VNAFieldTypeFlag tag:ArticleFieldIDHasEnclosure sqlField:@"hasenclosure_flag" visible:YES width:17];
    [self addField:MA_Field_Deleted type:VNAFieldTypeFlag tag:ArticleFieldIDDeleted sqlField:@"deleted_flag" visible:NO width:15];
    [self addField:MA_Field_Comments type:VNAFieldTypeInteger tag:ArticleFieldIDComments sqlField:@"comment_flag" visible:NO width:15];
    [self addField:MA_Field_GUID type:VNAFieldTypeInteger tag:ArticleFieldIDGUID sqlField:@"message_id" visible:NO width:72];
    [self addField:MA_Field_Subject type:VNAFieldTypeString tag:ArticleFieldIDSubject sqlField:@"title" visible:YES width:472];
    [self addField:MA_Field_Folder type:VNAFieldTypeFolder tag:ArticleFieldIDFolder sqlField:@"folder_id" visible:NO width:130];
    [self addField:MA_Field_Date type:VNAFieldTypeDate tag:ArticleFieldIDDate sqlField:@"date" visible:YES width:152];
    [self addField:MA_Field_Parent type:VNAFieldTypeInteger tag:ArticleFieldIDParent sqlField:@"parent_id" visible:NO width:72];
    [self addField:MA_Field_Author type:VNAFieldTypeString tag:ArticleFieldIDAuthor sqlField:@"sender" visible:YES width:138];
    [self addField:MA_Field_Link type:VNAFieldTypeString tag:ArticleFieldIDLink sqlField:@"link" visible:NO width:138];
    [self addField:MA_Field_Text type:VNAFieldTypeString tag:ArticleFieldIDText sqlField:@"text" visible:NO width:152];
    [self addField:MA_Field_Summary type:VNAFieldTypeString tag:ArticleFieldIDSummary sqlField:@"summary" visible:NO width:152];
    [self addField:MA_Field_Headlines type:VNAFieldTypeString tag:ArticleFieldIDHeadlines sqlField:@"" visible:NO width:100];
    [self addField:MA_Field_Enclosure type:VNAFieldTypeString tag:ArticleFieldIDEnclosure sqlField:@"enclosure" visible:NO width:100];
    [self addField:MA_Field_EnclosureDownloaded type:VNAFieldTypeFlag tag:ArticleFieldIDEnclosureDownloaded sqlField:@"enclosuredownloaded_flag" visible:NO width:100];

	//set user friendly and localizable names for some fields
	[self fieldByName:MA_Field_Read].displayName = NSLocalizedString(@"Read", @"Data field name visible in menu/smart folder definition");
	[self fieldByName:MA_Field_Flagged].displayName = NSLocalizedString(@"Flagged", @"Data field name visible in menu/smart folder definition");
	[self fieldByName:MA_Field_HasEnclosure].displayName = NSLocalizedString(@"Enclosure", @"Data field name (Y/N) visible in menu/smart folder definition");
	[self fieldByName:MA_Field_Enclosure].displayName = NSLocalizedString(@"Enclosure URL", @"Data field name (URL) visible in menu/article list");
	[self fieldByName:MA_Field_Deleted].displayName = NSLocalizedString(@"Deleted", @"Data field name visible in smart folder definition");
	[self fieldByName:MA_Field_Subject].displayName = NSLocalizedString(@"Subject", @"Data field name visible in menu/article list/smart folder definition");
	[self fieldByName:MA_Field_Folder].displayName = NSLocalizedString(@"Folder", @"Data field name visible in menu/article list/smart folder definition");
	[self fieldByName:MA_Field_Date].displayName = NSLocalizedString(@"Date", @"Data field name visible in menu/article list/smart folder definition");
	[self fieldByName:MA_Field_Author].displayName = NSLocalizedString(@"Author", @"Data field name visible in menu/article list/smart folder definition");
	[self fieldByName:MA_Field_Text].displayName = NSLocalizedString(@"Text", @"Data field name visible in smart folder definition");
	[self fieldByName:MA_Field_Summary].displayName = NSLocalizedString(@"Summary", @"Pseudo field name visible in menu/article list");
	[self fieldByName:MA_Field_Headlines].displayName = NSLocalizedString(@"Headlines", @"Pseudo field name visible in article list");
	[self fieldByName:MA_Field_Link].displayName = NSLocalizedString(@"Link", @"Data field name visible in menu/article list");
}

/* relocateLockedDatabase
 * Tell the user that the database could not be created at the path specified by path
 * and prompt for an alternative location. Opens and returns the new location if we were successful.
 */
-(NSString *)relocateLockedDatabase:(NSString *)path
{
	FMDatabase *sqlDatabase = [FMDatabase databaseWithPath:[Database databasePath]];

    NSAlert *alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = NSLocalizedString(@"Cannot create the Vienna database", nil);
    alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"A new Vienna database cannot be created at \"%@\" because the folder is probably located on a remote network share and this version of Vienna cannot manage remote databases. Please choose an alternative folder that is located on your local machine.", nil), path];
    [alert addButtonWithTitle:NSLocalizedString(@"Locate…", @"Title of a button on an alert")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Title of a button on an alert")];
    NSModalResponse alertResponse = [alert runModal];

    // When the cancel button is pressed.
	if (alertResponse == NSAlertSecondButtonReturn)
		return nil;

	// When the locate button is pressed.
	if (alertResponse == NSAlertFirstButtonReturn)
	{
		// Delete any existing database.
		if (sqlDatabase != nil)
		{
			[sqlDatabase close];
			sqlDatabase = nil;
			[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		}
		
		// Bring up modal UI to select the new location
		NSOpenPanel * openPanel = [NSOpenPanel openPanel];
		[openPanel setCanChooseFiles:NO];
		[openPanel setCanChooseDirectories:YES];
        if ([openPanel runModal] == NSModalResponseCancel)
			return nil;
		
		// Make the new database name.
		NSString * databaseName = path.lastPathComponent;
		NSString * newPath = [openPanel.URLs[0].path stringByAppendingPathComponent:databaseName];
		
		// And try to open it.
		sqlDatabase = [[FMDatabase alloc] initWithPath:newPath];
		if (!sqlDatabase || ![sqlDatabase open])
		{
            NSAlert *alert = [NSAlert new];
            alert.alertStyle = NSAlertStyleCritical;
            alert.messageText = NSLocalizedString(@"Sorry but Vienna was unable to open the database", nil);
            alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"The database file (%@) could not be opened for some reason. It may be corrupted or inaccessible. Please delete or rename the database file and restart Vienna.", nil), newPath];
            [alert runModal];

            sqlDatabase = nil;
			return nil;
		}
		
		// Save this to the preferences
		[[Preferences standardPreferences] setDefaultDatabase:newPath];
		[sqlDatabase close];
		return newPath;
	}
    [sqlDatabase close];
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
	if ([self createFolderOnDatabase:folderName underParent:VNAFolderTypeRoot withType:VNAFolderTypeSmart] >= 0)
	{
		CriteriaTree * criteriaTree = [[CriteriaTree alloc] init];
        criteriaTree.criteriaTree = [criteriaTree.criteriaTree arrayByAddingObject:(id<CriteriaElement>)criteria];
		
		__weak NSString * preparedCriteriaString = criteriaTree.string;
        [self.databaseQueue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"INSERT INTO smart_folders (folder_id, search_string) VALUES (?, ?)", @(db.lastInsertRowId), preparedCriteriaString];
        }];
	}
}

/* syncLastUpdate
 * Call this function to update the field in the info table which contains the last_updated
 * date. This is basically auditing data and is only called when the database is first opened
 * in this session.
 */
-(void)syncLastUpdate
{
    __block BOOL success;
    
	[self.databaseQueue inDatabase:^(FMDatabase *db) {
		success = [db executeUpdate:@"UPDATE info SET last_opened=?", [NSDate date]];

	}];
    if (success) {
        self.readOnly = NO;
    } else {
        self.readOnly = YES;
    }
}

/* countOfUnread
 * Return the total number of unread articles in the database.
 */
-(NSInteger)countOfUnread
{
    [self initFolderArray];
    return _countOfUnread;
}

/* addField
 * Add the specified field to our fields array.
 */
-(void)addField:(NSString *)name type:(NSInteger)type tag:(NSInteger)tag sqlField:(NSString *)sqlField visible:(BOOL)visible width:(NSInteger)width
{
	Field * field = [Field new];
	if (field != nil)
	{
		field.name = name;
		field.type = type;
		field.tag = tag;
		field.visible = visible;
		field.width = width;
		field.sqlField = sqlField;
		[self.fieldsOrdered addObject:field];
		[self.fieldsByName setValue:field forKey:name];
	}
}

/* arrayOfFields
 * Return the array of fields.
 */
-(NSArray *)arrayOfFields
{
	return self.fieldsOrdered;
}

/* fieldByTitle
 * Given a name, this function returns the field represented by
 * that name.
 */
-(Field *)fieldByName:(NSString *)name
{
	return [self.fieldsByName valueForKey:name];
}

/*!
 *  Get the current database version from the database
 *  This method fetches the version information from both
 *  the SQLite PRAGMA user_version and the legacy Vienna info
 *  table, returning the highest version number.
 *
 *  @return the current database version
 */
-(NSInteger)databaseVersion
{
    __block NSInteger dbVersion = 0;
    
    // FMDatabaseQueue  *queue = [[Database sharedManager] self.databaseQueue];
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * results = [db executeQuery:@"SELECT version FROM info"];
        dbVersion = 0;
        if ([results next])
        {
            dbVersion = [results intForColumn:@"version"];
        }
        [results close];
        
        // compare the SQLite PRAGMA user_version to the legacy version number
        if (db.userVersion > dbVersion) {
            dbVersion = db.userVersion;
        }
    }];

    return dbVersion;
}

/* compactDatabase
 * Compact the database using the vacuum command.
 */
-(void)compactDatabase
{
    if (!self.readOnly) {
        [self.databaseQueue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"VACUUM"];
        }];
    }
}

/* reindexDatabase
 * Reindex the database.
 */
-(void)reindexDatabase
{
    if (!self.readOnly) {
        [self.databaseQueue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"REINDEX"];
        }];
    }
}

/**
 *  Clears a specified flag for the specified folder
 *
 *  @param flag     the flag to clear
 *  @param folderId the folder to clear the flag from
 */
-(void)clearFlag:(NSUInteger)flag forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
	if (self.readOnly)
		return;
	
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		[folder clearFlag:flag];
        FMDatabaseQueue *queue = self.databaseQueue;
        [queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE folders SET flags=? WHERE folder_id=?", @(folder.flags), @(folderId)];
        [[NSNotificationCenter defaultCenter] vna_postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:@(folderId)];
        }];
	}
}


/**
 *  Sets the specified flag for the folder.
 *
 *  @param flag     flag to set
 *  @param folderId folder to set the flag for
 */
-(void)setFlag:(NSUInteger)flag forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
    if (self.readOnly) {
		return;
    }
    
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		[folder setFlag:flag];
        FMDatabaseQueue *queue = self.databaseQueue;
        [queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE folders SET flags=? WHERE folder_id=?", @(folder.flags), @(folderId)];
            [[NSNotificationCenter defaultCenter] vna_postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:@(folderId)];
        }];
	}
}

/**
 *  Sets the date when the folder was last updated.
 *
 *  @param lastUpdate The date of the last update
 *  @param folderId   The ID of the folder being updated
 */
-(void)setLastUpdate:(NSDate *)lastUpdate forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
    if (self.readOnly) {
		return;
    }
	// If no change to last update, do nothing
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader))
	{
        if ([folder.lastUpdate isEqualToDate:lastUpdate]) {
			return;
        }
		folder.lastUpdate = lastUpdate;
		NSTimeInterval interval = lastUpdate.timeIntervalSince1970;
        FMDatabaseQueue *queue = self.databaseQueue;
        [queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE folders SET last_update=? WHERE folder_id=?", @(interval), @(folderId)];
        }];
	}
}


/**
 *  Sets the last update string for the folder.
 *
 *  @param lastUpdateString The new last update string
 *  @param folderId         The ID of the folder being updated
 */
-(void)setLastUpdateString:(NSString *)lastUpdateString forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
    if (self.readOnly) {
		return;
    }
	// If no change to last update string, do nothing
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader))
	{
		if ([folder.lastUpdateString isEqualToString:lastUpdateString])
			return;
		
		folder.lastUpdateString = lastUpdateString;
        FMDatabaseQueue *queue = self.databaseQueue;
        [queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE rss_folders SET last_update_string=? WHERE folder_id=?",
             folder.lastUpdateString, @(folderId)];
        }];
	}
}

/**
 *  Change the URL of the feed on the specified RSS folder subscription.
 *
 *  @param feed_url the URL to set the folder's feed to
 *  @param folderId the ID of the folder whose URL we are changing
 *
 *  @return YES on success
 */
-(BOOL)setFeedURL:(NSString *)feed_url forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
    if (self.readOnly) {
		return NO;
    }
	
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil && ![folder.feedURL isEqualToString:feed_url])
	{
		folder.feedURL = feed_url;
        FMDatabaseQueue *queue = self.databaseQueue;
        [queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE rss_folders SET feed_url=? WHERE folder_id=?", feed_url, @(folderId)];
            [[NSNotificationCenter defaultCenter] vna_postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:@(folderId)];
        }];
	}
	return YES;
}

/**
 *  Sets the identifier of the feed to a value which is returned by the OpenReader server.
 *  Identifiers format vary with servers :
 *  - most common form is URL-based :                         feed/https://www.lemonde.fr/rss/une.xml
 *  - TheOldReader identifiers are based on hex data :        feed/5bdadad8c70bc2e3ae000e3a
 *  - FreshRSS ones are based on decimal sequences per user : feed/16
 *
 *  @param remoteId the identifier to set the folder's feed to
 *  @param folderId the ID of the folder whose remote identifier we are setting
 *
 *  @return YES on success
 */
-(BOOL)setRemoteId:(NSString *)remoteId forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
    if (self.readOnly) {
		return NO;
    }

	Folder * folder = [self folderFromID:folderId];
	if (folder != nil && ![folder.remoteId isEqualToString:remoteId])
	{
		folder.remoteId = remoteId;
        FMDatabaseQueue *queue = self.databaseQueue;
        [queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE rss_folders SET bloglines_id=? WHERE folder_id=?", remoteId, @(folderId)];
        }];
	}
	return YES;
}

/*!
 *  Add a Google Reader RSS Feed folder and return the ID of the new folder.
 *
 *  @param feedName      The name of the RSS folder
 *  @param parentId      The parent folder ID
 *  @param predecessorId The predecessor folder ID
 *  @param feed_url      The URL of the RSS Feed folder
 *
 *  @return The ID of the new folder
 */
-(NSInteger)addOpenReaderFolder:(NSString *)feedName underParent:(NSInteger)parentId afterChild:(NSInteger)predecessorId
        subscriptionURL:(NSString *)feed_url remoteId:(NSString *)remoteId
{
    NSInteger folderId =
        [self addFolder:parentId afterChild:predecessorId folderName:feedName type:VNAFolderTypeOpenReader canAppendIndex:YES];
    if (folderId != -1) {
        FMDatabaseQueue *queue = self.databaseQueue;
        __block BOOL success;
        [queue inDatabase:^(FMDatabase *db) {
                   success =
                   [db executeUpdate:
                   @"INSERT INTO rss_folders (folder_id, description, username, home_page, last_update_string, feed_url, bloglines_id) VALUES (?, ?, '', '', '', ?, ?)",
                   @(folderId),
                   feedName, // description
                   // username
                   // home_page
                   // last_update_string
                   feed_url,
                   remoteId];
               }];
        if (!success) {
            return -1;
        }

        // Add this new folder to our internal cache
        Folder *folder = [self folderFromID:folderId];
        folder.feedDescription = feedName;
        folder.feedURL = feed_url;
        folder.remoteId = remoteId;
    }
    return folderId;
} /* addOpenReaderFolder */

/*!
 *  Add a RSS Feed folder and return the ID of the new folder.
 *
 *  @param feedName      The name of the RSS folder
 *  @param parentId      The parent folder ID
 *  @param predecessorId The predecessor folder ID
 *  @param feed_url      The URL of the RSS Feed folder
 *
 *  @return The ID of the new folder
 */
-(NSInteger)addRSSFolder:(NSString *)feedName underParent:(NSInteger)parentId afterChild:(NSInteger)predecessorId subscriptionURL:(NSString *)feed_url
{
	NSInteger folderId = [self addFolder:parentId afterChild:predecessorId folderName:feedName type:VNAFolderTypeRSS canAppendIndex:YES];
	if (folderId != -1)
	{
        FMDatabaseQueue *queue = self.databaseQueue;
        __block BOOL success;
        [queue inDatabase:^(FMDatabase *db) {
            success = [db executeUpdate:@"INSERT INTO rss_folders (folder_id, description, username, home_page, last_update_string, feed_url, bloglines_id) "
             "VALUES (?, '', '', '', '', ?, 0)",
             @(folderId),
             feed_url];
        }];

        if (!success) {
			return -1;
        }
        
		// Add this new folder to our internal cache
		Folder * folder = [self folderFromID:folderId];
		folder.feedURL = feed_url;
	}
	return folderId;
}

/* addFolder
 * Create a new folder under the specified parent and give it the requested name and type. If
 * canAppendIndex is YES then we adjust the name to ensure that the folder name remains unique. If
 * we hit an error, the function returns -1.
 */
-(NSInteger)addFolder:(NSInteger)parentId afterChild:(NSInteger)predId folderName:(NSString *)name type:(NSInteger)type canAppendIndex:(BOOL)canAppendIndex
{
	__block NSInteger predecessorId = predId;
	Folder * folder = nil;

	// Prime the cache
	[self initFolderArray];

	// Exit now if we're read-only
	if (self.readOnly)
		return -1;

	if (!canAppendIndex)
	{
		folder = [self folderFromName:name];
		if (folder)
			return folder.itemId;
	}
	else
	{
		// If a folder of that name already exists then adjust the name by appending
		// an index number to make it unique.
		NSString * oldName = name;
		NSUInteger index = 1;

		while (([self folderFromName:name]) != nil)
			name = [NSString stringWithFormat:@"%@ (%lu)", oldName, (unsigned long)index++];
	}

	NSInteger nextSibling = 0;
	BOOL manualSort = [Preferences standardPreferences].foldersTreeSortMethod == VNAFolderSortManual;
	if (manualSort)
	{
		if (predecessorId > 0)
		{
			Folder * predecessor = [self folderFromID:predecessorId];
			if (predecessor != nil)
				nextSibling = predecessor.nextSiblingId;
			else
				predecessorId = 0;
		}
		if (predecessorId < 0)
		{
            FMDatabaseQueue *queue = self.databaseQueue;
            
            [queue inDatabase:^(FMDatabase *db) {
                FMResultSet * siblings = [db executeQuery:@"SELECT folder_id FROM folders WHERE parent_id=? AND next_sibling=0", @(parentId)];
                if([siblings next]) {
                    predecessorId = [siblings intForColumn:@"folder_id"];
                } else {
                    predecessorId =  0;
                }
				[siblings close];
			}];
		}
		if (predecessorId == 0)
		{
			if (parentId == VNAFolderTypeRoot)
				nextSibling = self.firstFolderId;
			else
			{
				Folder * parent = [self folderFromID:parentId];
				if (parent != nil)
					nextSibling = parent.firstChildId;
			}
		}
	}

	// Here we create the folder anew.
	NSInteger newItemId = [self createFolderOnDatabase:name underParent:parentId withType:type];
	if (newItemId != -1)
	{
		// Add this new folder to our internal cache. If this is an RSS or Open Reader
		// folder, mark it so that somewhere down the line we'll request the
		// image for the folder.
		folder = [[Folder alloc] initWithId:newItemId parentId:parentId name:name type:type];
		if ((type == VNAFolderTypeRSS)||(type == VNAFolderTypeOpenReader))
			[folder setFlag:VNAFolderFlagCheckForImage];
		self.foldersDict[@(newItemId)] = folder;
		
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
		[[NSNotificationCenter defaultCenter] vna_postNotificationOnMainThreadWithName:@"MA_Notify_FolderAdded" object:folder];
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
    FMDatabaseQueue *queue = self.databaseQueue;

	__block NSInteger newItemId = -1;
	NSInteger flags = 0;
	NSInteger nextSibling = 0;
	NSInteger firstChild = 0;
	
	// For new folders, last update is set to before now
	NSDate * lastUpdate = [NSDate distantPast];
	NSTimeInterval interval = lastUpdate.timeIntervalSince1970;

	// Require an image check if we're a subscription folder
    if ((type == VNAFolderTypeRSS) || (type == VNAFolderTypeOpenReader)) {
		flags = VNAFolderFlagCheckForImage;
    }
	// Create the folder in the database. One thing to watch out for here that has
	// bit me before. When adding new fields to the folders table, remember to init
	// the field here even if its just to an empty value.
    [queue inDatabase:^(FMDatabase *db) {
        BOOL success = [db executeUpdate:
                             @"INSERT INTO folders (foldername, parent_id, unread_count, last_update, type, flags, next_sibling, first_child) VALUES(?, ?, 0, ?, ?, ?, ?, ?)",
                             name,
                             @(parentId),
                             // unread_count = 0
                             @(interval),
                             @(type),
                             @(flags),
                             @(nextSibling),
                             @(firstChild)];
	
        // Quick way of getting the last autoincrement primary key value (the folder_id).
        if (success) {
            newItemId = db.lastInsertRowId;
        }
    }];
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
 * Delete the specified folder. This function can be very SQL intensive.
 */
-(BOOL)wrappedDeleteFolder:(NSInteger)folderId
{
    NSArray * arrayOfChildFolders = [self arrayOfFolders:folderId];
    Folder * folder;
    FMDatabaseQueue *queue = self.databaseQueue;

	// Recurse and delete child folders
    for (folder in arrayOfChildFolders) {
		[self wrappedDeleteFolder:folder.itemId];
    }

	// Adjust unread counts on parents
	folder = [self folderFromID:folderId];
	NSInteger adjustment = -folder.unreadCount;
	folder = [self folderFromID:folder.parentId];
	while (folder != nil)
	{
		folder.childUnreadCount = folder.childUnreadCount + adjustment;
		folder = [self folderFromID:folder.parentId];
	}

	// Delete all articles in this folder then delete ourselves.
	folder = [self folderFromID:folderId];
	_countOfUnread -= folder.unreadCount;
    if (folder.type == VNAFolderTypeSmart) {
        [queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"DELETE FROM smart_folders WHERE folder_id=?", @(folderId)];
        }];
    }

	// If this is an RSS feed, delete from the feeds
	// and delete raw feed source
	if (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader)
	{
        [queue inTransaction:^(FMDatabase *db, BOOL * rollback) {
            [db executeUpdate:@"DELETE FROM rss_folders WHERE folder_id=?", @(folderId)];
            [db executeUpdate:@"DELETE FROM rss_guids WHERE folder_id=?", @(folderId)];
        }];
		
		NSString * feedSourceFilePath = folder.feedSourceFilePath;
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
	if (folder.type == VNAFolderTypeSearch)
	{
		[self setSearchFolder:nil];
	}

	// Update the sort order if necessary
	if ([Preferences standardPreferences].foldersTreeSortMethod == VNAFolderSortManual)
	{
		__block NSInteger previousSibling = -999;
        [queue inDatabase:^(FMDatabase *db) {
            FMResultSet * results = [db executeQuery:@"SELECT folder_id FROM folders WHERE parent_id=? AND next_sibling=?", @(folder.parentId), @(folderId)];
			if ([results next])
			{
				previousSibling = [results intForColumn:@"folder_id"];
			}
			[results close];
		}];
		if (previousSibling != -999)
			[self setNextSibling:folder.nextSiblingId forFolder:previousSibling];
		else
			[self setFirstChild:folder.nextSiblingId forFolder:folder.parentId];


	}
	
	// For a smart folder, the next line is a no-op but it helpfully takes care of the case where a
	// normal folder had it's type grobbed to VNAFolderTypeSmart.
    [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:@"DELETE FROM messages WHERE folder_id=?", @(folderId)];
        [db executeUpdate:@"DELETE FROM folders WHERE folder_id=?", @(folderId)];
    }];

	// Remove from the folders array. Do this after we send the notification
	// so that the notification handlers don't fail if they try to dereference the
	// folder.
	[self.foldersDict removeObjectForKey:@(folderId)];
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
	if (self.readOnly)
		return NO;

	// Make sure this is a valid folder
	folder = [self folderFromID:folderId];
	if (folder == nil)
		return NO;

	arrayOfChildFolders = [self arrayOfSubFolders:folder];
	arrayOfFolderIds = [NSMutableArray arrayWithCapacity:arrayOfChildFolders.count];

	// Send the pre-delete notification before we start the transaction so that the handlers can
	// safely do any database access.
	for (folder in arrayOfChildFolders)
	{
		numFolder = @(folder.itemId);
		[arrayOfFolderIds addObject:numFolder];
		[[NSNotificationCenter defaultCenter] vna_postNotificationOnMainThreadWithName:VNADatabaseWillDeleteFolderNotification object:numFolder];
	}

	// Now do the deletion.
	result = [self wrappedDeleteFolder:folderId];

	// Send the post-delete notification after we're finished. Note that the folder actually corresponding to
	// each numFolder won't exist any more and the handlers need to be aware of this.
    for (numFolder in arrayOfFolderIds) {
		[[NSNotificationCenter defaultCenter] vna_postNotificationOnMainThreadWithName:VNADatabaseDidDeleteFolderNotification object:numFolder];
    }
	
	return result;
}


/**
 *  Renames the specified folder.
 *
 *  @param newName  the name name for the folder
 *  @param folderId the ID of the folder to rename
 *
 *  @return YES on success
 */
-(BOOL)setName:(NSString *)newName forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
    if (self.readOnly) {
		return NO;
    }
    
	// Find our folder element.
	Folder * folder = [self folderFromID:folderId];
	if (!folder)
		return NO;

	// Do nothing if the name hasn't changed. Otherwise it is wasted
	// effort, basically.
    if ([folder.name isEqualToString:newName]) {
		return NO;
    }

	folder.name = newName;

	// Rename in the database
    FMDatabaseQueue *queue = self.databaseQueue;
    [queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"UPDATE folders SET foldername=? WHERE folder_id=?", newName, @(folderId)];
    }];

	// Send a notification that the folder has changed. It is the responsibility of the
	// notifiee that they work out that the name is the part that has changed.
	[[NSNotificationCenter defaultCenter] vna_postNotificationOnMainThreadWithName:@"MA_Notify_FolderNameChanged" object:@(folderId)];
	return YES;
}


/**
 *  Sets the folder description both in the internal structure and in the folder_description table.
 *
 *  @param newDescription The new description for the folder
 *  @param folderId       The ID of the folder
 *
 *  @return YES on success
 */
-(BOOL)setDescription:(NSString *)newDescription forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
    if (self.readOnly) {
		return NO;
    }
	// Find our folder element.
	Folder * folder = [self folderFromID:folderId];
    if (!folder) {
		return NO;
    }
	
	// Do nothing if the description hasn't changed. Otherwise it is wasted
	// effort, basically.
    if ([folder.feedDescription isEqualToString:newDescription]) {
		return NO;
    }
	
	folder.feedDescription = newDescription;
	
	// Add a new description or update the one we have
    FMDatabaseQueue *queue = self.databaseQueue;
    [queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"UPDATE rss_folders SET description=? WHERE folder_id=?",
         newDescription, @(folderId)];
    }];

	// Send a notification that the folder has changed. It is the responsibility of the
	// notifiee that they work out that the description is the part that has changed.
	[[NSNotificationCenter defaultCenter] vna_postNotificationOnMainThreadWithName:@"MA_Notify_FolderDescriptionChanged"
                                                                        object:@(folderId)];
	return YES;
}


/**
 *  Sets the folder's associated home page URL link in both in the internal 
 *  structure and in the folder_description table.
 *
 *  @param homePageURL The home page URL
 *  @param folderId The ID of the folder getting updated
 *
 *  @return YES on success
 */
-(BOOL)setHomePage:(NSString *)homePageURL forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
    if (self.readOnly) {
		return NO;
    }
	// Find our folder element.
	Folder * folder = [self folderFromID:folderId];
	if (!folder)
		return NO;

	// Do nothing if the link hasn't changed. Otherwise it is wasted
	// effort, basically.
    if ([folder.homePage isEqualToString:homePageURL] || homePageURL==nil) {
		return NO;
    }

	folder.homePage = homePageURL;

	// Add a new link or update the one we have
    FMDatabaseQueue *queue = self.databaseQueue;
    [queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"UPDATE rss_folders SET home_page=? WHERE folder_id=?",
         homePageURL, @(folderId)];
    }];


	// Send a notification that the folder has changed. It is the responsibility of the
	// notifiee that they work out that the link is the part that has changed.
	[[NSNotificationCenter defaultCenter] vna_postNotificationOnMainThreadWithName:@"MA_Notify_FolderHomePageChanged"
                                                                        object:@(folderId)];
	return YES;
}

/* setFolderUsername
 * Sets the folder's user name in both in the internal structure and in the folder_description table.
 */
-(BOOL)setFolderUsername:(NSInteger)folderId newUsername:(NSString *)name
{
	// Exit now if we're read-only
	if (self.readOnly) return NO;
	
	// Find our folder element.
	Folder * folder = [self folderFromID:folderId];
	if (!folder) return NO;
	
	// Do nothing if the link hasn't changed. Otherwise it is wasted
	// effort, basically.
	if ([folder.username isEqualToString:name]) return NO;
	
	folder.username = name;
	
	// Add a new link or update the one we have
    FMDatabaseQueue *queue = self.databaseQueue;
    [queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"UPDATE rss_folders SET username=? WHERE folder_id=?",
         name, @(folderId)];
    }];

	return YES;
}

/* setParent
 * Changes the parent for the specified folder then updates the database.
 */
-(BOOL)setParent:(NSInteger)newParentID forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
    if (self.readOnly) {
		return NO;
    }
	
	Folder * folder = [self folderFromID:folderId];
	if (folder.parentId == newParentID)
		return NO;

	// Sanity check. Make sure we're not reparenting to our
	// subordinate.
	Folder * parentFolder = [self folderFromID:newParentID];
	while (parentFolder != nil)
	{
		if (parentFolder.itemId == folderId)
			return NO;
		parentFolder = [self folderFromID:parentFolder.parentId];
	}

	// Adjust the child unread count for the old parent.
	NSInteger adjustment = 0;
	if (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader)
		adjustment = folder.unreadCount;
	else if (folder.groupFolder)
		adjustment = folder.childUnreadCount;
	if (adjustment > 0)
	{
		parentFolder = [self folderFromID:folder.parentId];
		while (parentFolder != nil)
		{
			parentFolder.childUnreadCount = parentFolder.childUnreadCount - adjustment;
			parentFolder = [self folderFromID:parentFolder.parentId];
		}
	}
	
	// Do the re-parent
    folder.parentId = newParentID;
	
	// In addition to reparenting the child, we also need to fix up the unread count for all
	// precedent parents.
	if (adjustment > 0)
	{
		parentFolder = [self folderFromID:newParentID];
		while (parentFolder != nil)
		{
			parentFolder.childUnreadCount = parentFolder.childUnreadCount + adjustment;
			parentFolder = [self folderFromID:parentFolder.parentId];
		}
	}

	// Update the database now
    FMDatabaseQueue *queue = self.databaseQueue;
    [queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"UPDATE folders SET parent_id=? WHERE folder_id=?",
         @(newParentID), @(folderId)];
    }];
	return YES;
}

/* setFirstChild
 * Changes the first child of the specified folder and then updates the database.
 */
-(BOOL)setFirstChild:(NSInteger)childId forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
    if (self.readOnly) {
		return NO;
    }
	
    FMDatabaseQueue *queue = self.databaseQueue;
    
	if (folderId == VNAFolderTypeRoot)
	{
		[queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE info SET first_folder=?", @(childId)];
        }];
	}
	else
	{
		Folder * folder = [self folderFromID:folderId];
		if (folder == nil)
			return NO;
		
		folder.firstChildId = childId;
        [queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE folders SET first_child=? WHERE folder_id=?",
             @(childId), @(folderId)];
        }];
	}
	
	return YES;
}

/* setNextSibling
 * Changes the next sibling for the specified folder and then updates the database.
 */
-(BOOL)setNextSibling:(NSUInteger)nextSiblingId forFolder:(NSInteger)folderId
{
	// Exit now if we're read-only
    if (self.readOnly) {
		return NO;
    }
    
	Folder * folder = [self folderFromID:folderId];
	if (folder == nil)
		return NO;
	
	folder.nextSiblingId = nextSiblingId;
	
    FMDatabaseQueue *queue = self.databaseQueue;
    [queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"UPDATE folders SET next_sibling=? WHERE folder_id=?",
         @(nextSiblingId), @(folderId)];
    }];

	return YES;
}

/* firstFolderId
 * Returns the ID of the first folder (first child of root).
 */
-(NSInteger)firstFolderId
{
	__block NSInteger folderId = 0;
    FMDatabaseQueue *queue = self.databaseQueue;
    [queue inDatabase:^(FMDatabase *db) {
        FMResultSet * results = [db executeQuery:@"SELECT first_folder FROM info"];
        if ([results next])
        {
            folderId = [results intForColumn:@"first_folder"];
        }
        [results close];
    }];
    
	return folderId;
}

/* trashFolderId;
 * Returns the ID of the trash folder.
 */
-(NSInteger)trashFolderId
{
	return self.trashFolder.itemId;
}

/* searchFolderId;
 * Returns the ID of the search folder. If it doesn't exist then we create
 * it now.
 */
-(NSInteger)searchFolderId
{
	if (self.searchFolder == nil)
	{
		NSInteger folderId = [self addFolder:VNAFolderTypeRoot afterChild:0 folderName: NSLocalizedString(@"Search Results", nil) type:VNAFolderTypeSearch canAppendIndex:YES];
		self.searchFolder = [self folderFromID:folderId];
	}
	return self.searchFolder.itemId;
}

/* folderFromID
 * Retrieve a Folder given its ID.
 */
-(Folder *)folderFromID:(NSInteger)wantedId
{
	return self.foldersDict[@(wantedId)];
}

/* folderFromName
 * Retrieve a Folder given its name.
 */
-(Folder *)folderFromName:(NSString *)wantedName
{	
	Folder * folder;
	for (folder in [self.foldersDict objectEnumerator])
	{
		if ([folder.name isEqualToString:wantedName])
			break;
	}
	return folder;
}


/*!
 *  folderFromFeedURL
 *
 *  @param wantedFeedURL The feed URL the folder is wanted for
 *
 *  @return An RSSFolder that is subscribed to the specified feed URL.
 */
-(Folder *)folderFromFeedURL:(NSString *)wantedFeedURL
{
	Folder * folder;
	
	for (folder in [self.foldersDict objectEnumerator])
	{
		if ([folder.feedURL isEqualToString:wantedFeedURL])
			break;
	}
	return folder;
}

/*!
 *  folderFromRemoteId
 *
 *  @param wantedRemoteId The remote identifier the folder is wanted for
 *
 *  @return An OpenReaderFolder that corresponds
 */

-(Folder *)folderFromRemoteId:(NSString *)wantedRemoteId
{
	Folder * folder;

	for (folder in [self.foldersDict objectEnumerator])
	{
		if ([folder.remoteId isEqualToString:wantedRemoteId])
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
    if (!self.readOnly) {
        [self.databaseQueue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE info SET folder_sort=?", @([Preferences standardPreferences].foldersTreeSortMethod)];
        }];
    }
}

/* addArticle
 * Adds an article in the specified folder. Returns YES if the
 * article was added or NO if we couldn't add the article for
 * some reason.
 */
-(BOOL)addArticle:(Article *)article toFolder:(NSInteger)folderID
{
    FMDatabaseQueue *queue = self.databaseQueue;

    // Exit now if we're read-only
	if (self.readOnly)
		return NO;

    // Extract the article data from the dictionary.
    NSString * articleBody = article.body;
    NSString * articleTitle = article.title;
    NSDate * articleDate = article.date;
    NSString * articleLink = article.link.vna_trimmed;
    NSString * userName = article.author.vna_trimmed;
    NSString * articleEnclosure = article.enclosure.vna_trimmed;
    NSString * articleGuid = article.guid;
    NSInteger parentId = article.parentId;
    BOOL marked_flag = article.flagged;
    BOOL read_flag = article.read;
    BOOL revised_flag = article.revised;
    BOOL deleted_flag = article.deleted;
    BOOL hasenclosure_flag = article.hasEnclosure;

    // We always set the created date ourselves
    article.createdDate = [NSDate date];

    // Set some defaults
    if (articleDate == nil)
        articleDate = [NSDate date];
    if (userName == nil)
        userName = @"";

    // Parse off the title
    if (articleTitle == nil || articleTitle.vna_isBlank)
        articleTitle = [NSString vna_stringByRemovingHTML:articleBody].vna_firstNonBlankLine;

    // Dates are stored as time intervals
    NSTimeInterval interval = articleDate.timeIntervalSince1970;
    NSTimeInterval createdInterval = article.createdDate.timeIntervalSince1970;
    
    __block BOOL success;
    [queue inTransaction:^(FMDatabase *db,  BOOL *rollback) {
        success = [db executeUpdate:@"INSERT INTO messages (message_id, parent_id, folder_id, sender, link, date, createddate, read_flag, marked_flag, deleted_flag, title, text, revised_flag, enclosure, hasenclosure_flag) "
         @"VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
         articleGuid,
         @(parentId),
         @(folderID),
         userName,
         articleLink,
         @(interval),
         @(createdInterval),
         @(read_flag),
         @(marked_flag),
         @(deleted_flag),
         articleTitle,
         articleBody,
         @(revised_flag),
         articleEnclosure,
         @(hasenclosure_flag)];
        if (!success) {
            NSLog(@"error = %@", [db lastErrorMessage]);
            *rollback = YES;
            return;
         }
        
        success = [db executeUpdate:@"INSERT INTO rss_guids (message_id, folder_id) VALUES (?, ?)", articleGuid, @(folderID)];
        if (!success) {
            NSLog(@"error = %@", [db lastErrorMessage]);
            *rollback = YES;
            return;
        }

    }];
	return (success);
}

/* updateArticle
 * Updates an article in the specified folder. Returns YES if the
 * article was updated or NO if we couldn't update the article for
 * some reason.
 */
-(BOOL)updateArticle:(Article *)existingArticle ofFolder:(NSInteger)folderID withArticle:(Article *)article
{
    // Exit now if we're read-only
	if (self.readOnly)
		return NO;

	FMDatabaseQueue *queue = self.databaseQueue;

    // Extract the data from the new state of article
    NSString * articleBody = article.body;
    NSString * articleTitle = article.title;
    NSDate * articleDate = article.date;
    NSString * articleLink = article.link.vna_trimmed;
    NSString * userName = article.author.vna_trimmed;
    NSString * articleGuid = article.guid;
    NSInteger parentId = article.parentId;
    BOOL revised_flag = article.revised;

    // Set some defaults
    if (articleDate == nil)
        articleDate = existingArticle.date;
    if (userName == nil)
        userName = @"";

    // Parse off the title
    if (articleTitle == nil || articleTitle.vna_isBlank)
        articleTitle = [NSString vna_stringByRemovingHTML:articleBody].vna_firstNonBlankLine;

    // Dates are stored as time intervals
    NSTimeInterval interval = articleDate.timeIntervalSince1970;

    // The article is revised if either the title or the body has changed.

    NSString * existingTitle = existingArticle.title;
    BOOL isArticleRevised = ![existingTitle isEqualToString:articleTitle];
    if (!isArticleRevised)
    {
        __block NSString * existingBody = existingArticle.body;
        // the article text may not have been loaded yet, for instance if the folder is not displayed
        if (existingBody == nil)
        {
            [queue inDatabase:^(FMDatabase *db) {
                FMResultSet * results = [db executeQuery:@"SELECT text FROM messages WHERE folder_id=? AND message_id=?",
                                         @(folderID), articleGuid];
                if ([results next]) {
                        existingBody = [results stringForColumn:@"text"];
                } else {
                        existingBody = @"";
                }
                [results close];
            }];
        }
        isArticleRevised = ![existingBody isEqualToString:articleBody];
    }

    if (isArticleRevised)
    {
        // Articles preexisting in database should be marked as revised.
        // New articles created during the current refresh should not be marked as revised,
        // even if there are multiple versions of the new article in the feed.
        if (existingArticle.revised || (existingArticle.status == ArticleStatusEmpty))
            revised_flag = YES;

        __block BOOL success;
        [queue inDatabase:^(FMDatabase *db) {
            success = [db executeUpdate:@"UPDATE messages SET parent_id=?, sender=?, link=?, date=?, "
             @"read_flag=0, title=?, text=?, revised_flag=? WHERE folder_id=? AND message_id=?",
             @(parentId),
             userName,
             articleLink,
             @(interval),
             articleTitle,
             articleBody,
             @(revised_flag),
             @(folderID),
             articleGuid];

        }];
        
        if (!success)
            return NO;
        else
        {
            // update the existing article in memory
            existingArticle.title = articleTitle;
            existingArticle.body = articleBody;
            [existingArticle markRevised:revised_flag];
            existingArticle.parentId = parentId;
            existingArticle.author = userName;
            existingArticle.link = articleLink;
            return YES;
        }
    }
    else
    {
        return NO;
    }
}

/* purgeArticlesOlderThanTag
 * Deletes all non-flagged articles from the messages list that are older than the 
 * specification. Cf. comments about autoExpireDuration in Preferences.m :
 *   A zero value disables auto-expire.
 *   Increments of 1000 specify months, so 1000 = 1 month, 1001 = 1 month and 1 day
 */
-(void)purgeArticlesOlderThanTag:(NSUInteger)tag
{
    if (tag > 0) {
        NSUInteger months = tag / 1000;
        NSUInteger days = tag%1000;
        NSDate *date = [[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitMonth
                                                                value:-months
                                                               toDate:[NSDate date]
                                                              options:0];
        date = [[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitDay
                                                        value:-days
                                                        toDate:date
                                                        options:0];
        NSTimeInterval timeDiff = date.timeIntervalSince1970;

        [self.databaseQueue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE messages SET deleted_flag=1 WHERE deleted_flag=0 AND marked_flag=0 AND read_flag=1 AND date < ?", @(timeDiff)];
        }];
    }
}

/* purgeDeletedArticles
 * Remove from the database all articles which have the deleted_flag field set to YES. This
 * also requires that we remove the same articles from all folder caches.
 */
-(void)purgeDeletedArticles
{
    __block BOOL success;
	[self.databaseQueue inDatabase:^(FMDatabase *db) {
		success = [db executeUpdate:@"DELETE FROM messages WHERE deleted_flag=1"];
	}];

	if (success)
	{
		for (Folder * folder in [self.foldersDict objectEnumerator])
			[folder clearCache];

		[[NSNotificationCenter defaultCenter] vna_postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:@(self.trashFolderId)];
	}
}

/* deleteArticle
 * Permanently deletes a article from the specified folder
 */
-(BOOL)deleteArticle:(Article *)article
{
	NSInteger folderId = article.folderId;
	NSString * guid = article.guid;
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
        FMDatabaseQueue *queue = self.databaseQueue;
        __block BOOL success;
        [queue inDatabase:^(FMDatabase *db) {
            success = [db executeUpdate:@"DELETE FROM messages WHERE folder_id=? AND message_id=?",
                       @(folderId), guid];
        }];

        if (success)
        {
            if (!article.read)
            {
                [self setFolderUnreadCount:folder adjustment:-1];
            }
            if (folder.countOfCachedArticles > 0)
			{
				// If we're in a smart folder, the cached article may be different.
				Article * cachedArticle = [folder articleFromGuid:guid];
				[cachedArticle markDeleted:YES];
				[folder removeArticleFromCache:guid];
			}
            return YES;
        }
	}
	return NO;
}

/* initSmartfoldersDict
 * Preloads all the smart folders into the smartfoldersDict dictionary.
 */
-(void)initSmartfoldersDict
{
	if (!self.initializedSmartfoldersDict)
	{
        FMDatabaseQueue *queue = self.databaseQueue;
        // Make sure we have a database queue.
		NSAssert(queue, @"Database queue not assigned for this item");
		
		[queue inDatabase:^(FMDatabase *db) {
			FMResultSet * results = [db executeQuery:@"SELECT folder_id, search_string FROM smart_folders"];
			while([results next])
			{
				NSInteger folderId = [results stringForColumnIndex:0].integerValue;
				NSString * search_string = [results stringForColumnIndex:1];
				
				CriteriaTree * criteriaTree = [[CriteriaTree alloc] initWithString:search_string];
				self.smartfoldersDict[@(folderId)] = criteriaTree;
			}
			[results close];
		}];
		self.initializedSmartfoldersDict = YES;
	}
}

/* searchStringForSmartFolder
 * Retrieve the smart folder criteria string for the specified folderId. Returns nil if
 * folderId is not a smart folder.
 */
-(CriteriaTree *)searchStringForSmartFolder:(NSInteger)folderId
{
	[self initSmartfoldersDict];
	return self.smartfoldersDict[@(folderId)];
}

/* addSmartFolder
 * Create a new smart folder. If the specified folder already exists, then this is synonymous to
 * calling updateSearchFolder.
 */
-(NSInteger)addSmartFolder:(NSString *)folderName underParent:(NSInteger)parentId withQuery:(CriteriaTree *)criteriaTree
{
	NSInteger folderId = [self addFolder:parentId afterChild:0 folderName:folderName type:VNAFolderTypeSmart canAppendIndex:NO];
	if (folderId != -1)
	{
        FMDatabaseQueue *queue = self.databaseQueue;
        [queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"INSERT INTO smart_folders (folder_id, search_string) VALUES (?, ?)",
             @(folderId),
             criteriaTree.string];
        }];

		self.smartfoldersDict[@(folderId)] = criteriaTree;
	}
	return folderId;
}

/* updateSearchFolder
 * Updates the search string for the specified folder.
 */
-(void)updateSearchFolder:(NSInteger)folderId withFolder:(NSString *)folderName withQuery:(CriteriaTree *)criteriaTree
{
	Folder * folder = [self folderFromID:folderId];
    if (![folder.name isEqualToString:folderName]) {
        [self setName:folderName forFolder:folderId];
    }

	// Update the smart folder string
    FMDatabaseQueue *queue = self.databaseQueue;
    [queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"UPDATE smart_folders SET search_string=? WHERE folder_id=?",
         criteriaTree.string,
         @(folderId)];
    }];

	self.smartfoldersDict[@(folderId)] = criteriaTree;
	
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc vna_postNotificationOnMainThreadWithName:@"MA_Notify_ArticleListContentChange"
                                          object:@(folderId)];
}

/* initFolderArray
 * Initializes the folder array if necessary.
 */
-(void)initFolderArray
{
	if (!self.initializedfoldersDict)
	{
		// Make sure we have a database.
		NSAssert(self.databaseQueue, @"Database not assigned for this item");
		
		// Keep running count of total unread articles
		_countOfUnread = 0;
        
        FMDatabaseQueue *queue = self.databaseQueue;
        
        [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            FMResultSet * results = [db executeQuery:@"SELECT folder_id, parent_id, foldername, unread_count, last_update,"
                @" type, flags, next_sibling, first_child FROM folders ORDER BY folder_id"];
            if (!results) {
                NSLog(@"%s: executeQuery error: %@", __FUNCTION__, [db lastErrorMessage]);
                return;
            }
            
            while ([results next])
            {
                NSInteger newItemId = [results stringForColumnIndex:0].integerValue;
                NSInteger newParentId = [results stringForColumnIndex:1].integerValue;
                NSString * name = [results stringForColumnIndex:2];
                if (name == nil) { // Paranoid check because of https://github.com/ViennaRSS/vienna-rss/issues/877
                    name = [Database untitledFeedFolderName];
                }
                NSInteger unreadCount = [results stringForColumnIndex:3].integerValue;
                NSDate * lastUpdate = [NSDate dateWithTimeIntervalSince1970:[results stringForColumnIndex:4].doubleValue];
                NSInteger type = [results stringForColumnIndex:5].integerValue;
                NSInteger flags = [results stringForColumnIndex:6].integerValue;
                NSInteger nextSibling = [results stringForColumnIndex:7].integerValue;
                NSInteger firstChild = [results stringForColumnIndex:8].integerValue;
                
                Folder * folder = [[Folder alloc] initWithId:newItemId parentId:newParentId name:name type:type];
                folder.nextSiblingId = nextSibling;
                folder.firstChildId = firstChild;
                if (folder.type != VNAFolderTypeRSS && folder.type != VNAFolderTypeOpenReader) {
                    unreadCount = 0;
                }
                folder.unreadCount = unreadCount;
                folder.lastUpdate = lastUpdate;
                [folder setFlag:flags];
                if (unreadCount > 0) {
                    self->_countOfUnread += unreadCount;
                }
                self.foldersDict[@(newItemId)] = folder;
                
                // Remember the trash folder
                if (folder.type == VNAFolderTypeTrash) {
                    self.trashFolder = folder;
                }
                
                // Remember the search folder
                if (folder.type == VNAFolderTypeSearch) {
                    self.searchFolder = folder;
                }
            }
            [results close];
		
        	// Load all RSS folders and add them to the list.
			results = [db executeQuery:@"SELECT folder_id, feed_url, username, last_update_string, description, home_page, bloglines_id FROM rss_folders"];
			while ([results next])
			{
				NSInteger folderId = [results stringForColumnIndex:0].integerValue;
				NSString * url = [results stringForColumnIndex:1];
				NSString * username = [results stringForColumnIndex:2];
				NSString * lastUpdateString = [results stringForColumnIndex:3];
				NSString * descriptiontext = [results stringForColumnIndex:4];
				NSString * linktext = [results stringForColumnIndex:5];
				NSString * remoteId = [results stringForColumnIndex:6];
				
				Folder * folder = [self folderFromID:folderId];
				folder.feedDescription = descriptiontext;
				folder.homePage = linktext;
				folder.feedURL = url;
				folder.lastUpdateString = lastUpdateString;
				folder.username = username;
				folder.remoteId = remoteId;
			}
			[results close];
		}];
		// Fix the childUnreadCount for every parent
		for (Folder * folder in [self.foldersDict objectEnumerator])
		{
			if (folder.unreadCount > 0 && folder.parentId != VNAFolderTypeRoot)
			{
				Folder * parentFolder = [self folderFromID:folder.parentId];
				while (parentFolder != nil)
				{
					parentFolder.childUnreadCount = parentFolder.childUnreadCount + folder.unreadCount;
					parentFolder = [self folderFromID:parentFolder.parentId];
				}
			}
		}
		// Done
		self.initializedfoldersDict = YES;
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
	if (self.initializedfoldersDict == NO)
		[self initFolderArray];

	NSMutableArray * newArray = [NSMutableArray array];
	if (newArray != nil)
	{		
		for (Folder * folder in [self.foldersDict objectEnumerator])
		{
			if (folder.parentId == parentId)
				[newArray addObject:folder];
		}
	}
	return [newArray copy];
}

/* arrayOfSubFolders
 * Returns an NSArray of all folders from the specified folder down.
 */
-(NSArray *)arrayOfSubFolders:(Folder *)folder {
	NSMutableArray * newArray = [NSMutableArray arrayWithObject:folder];
	if (newArray != nil)
	{
		NSInteger parentId = folder.itemId;
		
		for (Folder * item in [self.foldersDict objectEnumerator])
		{
			if (item.parentId == parentId)
			{
                if (item.type == VNAFolderTypeGroup) {
					[newArray addObjectsFromArray:[self arrayOfSubFolders:item]];
                }
                else {
					[newArray addObject:item];
                }
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
	if (self.initializedfoldersDict == NO)
		[self initFolderArray];
	
	return self.foldersDict.allValues;
}

/* minimalCacheForFolder
 * Returns a minimal cache of article information for the specified folder,
 * which is enough for tasks like feed refreshes, but is not complete enough
 * for displaying articles : it lacks articles' descriptions and dates.
 */
-(NSArray *)minimalCacheForFolder:(NSInteger)folderId
{
	// Prime the folder cache
	[self initFolderArray];

    __block NSInteger unread_count = 0;
	NSMutableArray * myCache = [NSMutableArray array];

    FMDatabaseQueue *queue = self.databaseQueue;
    [queue inDatabase:^(FMDatabase *db) {
        FMResultSet * results = [db executeQueryWithFormat:@"SELECT message_id, read_flag, marked_flag, deleted_flag, title, link, revised_flag, hasenclosure_flag, enclosure FROM messages WHERE folder_id=%ld", (long)folderId];
        while([results next])
        {
            NSString * guid = [results stringForColumnIndex:0];
            BOOL read_flag = [results stringForColumnIndex:1].integerValue;
            BOOL marked_flag = [results stringForColumnIndex:2].integerValue;
            BOOL deleted_flag = [results stringForColumnIndex:3].integerValue;
            NSString * title = [results stringForColumnIndex:4];
            NSString * link = [results stringForColumnIndex:5];
            BOOL revised_flag = [results stringForColumnIndex:6].integerValue;
            BOOL hasenclosure_flag = [results stringForColumnIndex:7].integerValue;
            NSString * enclosure = [results stringForColumnIndex:8];

            // Keep our own track of unread articles
            if (!read_flag)
                ++unread_count;
            
            Article * article = [[Article alloc] initWithGuid:guid];
            [article markRead:read_flag];
            [article markFlagged:marked_flag];
            [article markRevised:revised_flag];
            [article markDeleted:deleted_flag];
            article.folderId = folderId;
            article.title = title;
            article.link = link;
            article.enclosure = enclosure;
            article.hasEnclosure = hasenclosure_flag;
            [myCache addObject:article];
        }
        [results close];
    }];
    
    // This is a good time to do a quick check to ensure that our
    // own count of unread is in sync with the folders count and fix
    // them if not.
    Folder * folder = [self folderFromID:folderId];
    if (unread_count != folder.unreadCount)
    {
        NSLog(@"Fixing unread count for %@ (%ld on folder versus %ld in articles)", folder.name, (long)folder.unreadCount, (long)unread_count);
        NSInteger diff = (unread_count - folder.unreadCount);
        [self setFolderUnreadCount:folder adjustment:diff];
        [folder setNonPersistedFlag:VNAFolderFlagBuggySync];
    }

    return [myCache copy];
}

/* sqlScopeForFolder
 * Create a SQL 'where' clause that scopes to either the individual folder or the folder and
 * all sub-folders.
 */
-(NSString *)sqlScopeForFolder:(Folder *)folder flags:(VNAQueryScope)scopeFlags field:(NSString *)field
{
	NSString * operatorString = (scopeFlags & VNAQueryScopeInclusive) ? @"=" : @"<>";
	NSString * conditionString = (scopeFlags & VNAQueryScopeInclusive) ? @" or " : @" and ";
	BOOL subScope = (scopeFlags & VNAQueryScopeSubFolders) ? YES : NO; // Avoid problems casting into BOOL.
	NSInteger folderId;

	// If folder is nil, rather than report an error, default to some impossible value
	if (folder != nil)
		folderId = folder.itemId;
	else
	{
		subScope = NO;
		folderId = 0;
	}

	// Group folders must always have subscope
    if (folder && folder.type == VNAFolderTypeGroup) {
		subScope = YES;
    }

	// Straightforward folder is <something>
    if (!subScope) {
		return [NSString stringWithFormat:@"%@%@%ld", field, operatorString, (long)folderId];
    }
	// For under/not-under operators, we're creating a SQL statement of the format
	// (folder_id = <value1> || folder_id = <value2>...). It is possible to try and simplify
	// the string by looking for ranges but I suspect that given the spread of IDs this may
	// well be false optimisation.
	//
	NSArray * childFolders = [self arrayOfSubFolders:folder];
	NSMutableString * sqlString = [[NSMutableString alloc] init];
	NSInteger count = childFolders.count;
	NSInteger index;
	
    if (count > 1) {
		[sqlString appendString:@"("];
    }
	for (index = 0; index < count; ++index)
	{
		Folder * folder = childFolders[index];
		if (index > 0)
			[sqlString appendString:conditionString];
		[sqlString appendFormat:@"%@%@%ld", field, operatorString, (long)folder.itemId];
	}
	if (count > 1)
		[sqlString appendString:@")"];
	return sqlString;
}

/* criteriaForFolder
 * Returns the CriteriaTree that will return the folder contents.
 * TODO: put this in Criteria+SQL.swift or some other swift file to free VNACriteriaOperator enum from Objective-C legacy
 */
-(CriteriaTree *)criteriaForFolder:(NSInteger)folderId
{
	Folder * folder = [self folderFromID:folderId];
	if (folder == nil)
		return nil;

	if (folder.type == VNAFolderTypeSearch) {
        CriteriaTree *tree = [CriteriaTree new];
        Criteria *clause = [[Criteria alloc] initWithField:MA_Field_Text
                                              operatorType:VNACriteriaOperatorContains
                                                     value:self.searchString];
        tree.criteriaTree = [tree.criteriaTree arrayByAddingObject:(id<CriteriaElement>)clause];
        return tree;
    }
	
	if (folder.type == VNAFolderTypeTrash)
	{
		CriteriaTree * tree = [[CriteriaTree alloc] init];
		Criteria * clause = [[Criteria alloc] initWithField:MA_Field_Deleted operatorType:VNACriteriaOperatorEqualTo value:@"Yes"];
		tree.criteriaTree = [tree.criteriaTree arrayByAddingObject:(id<CriteriaElement>)clause];
		return tree;
	}

	if (folder.type == VNAFolderTypeSmart)
	{
		[self initSmartfoldersDict];
		return self.smartfoldersDict[@(folderId)];
	}

	CriteriaTree * tree = [[CriteriaTree alloc] init];
	Criteria * clause = [[Criteria alloc] initWithField:MA_Field_Folder operatorType:VNACriteriaOperatorUnder value:folder.name];
    tree.criteriaTree = [tree.criteriaTree arrayByAddingObject:(id<CriteriaElement>)clause];
	return tree;
}

/* arrayOfUnreadArticlesRefs
 * Retrieves an array of ArticleReference objects that represent all unread
 * articles in the specified folder.
 * Note : when possible, you should use the interface provided by the Folder class instead of this
 */
-(NSArray *)arrayOfUnreadArticlesRefs:(NSInteger)folderId
{
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
        NSMutableArray * newArray = [NSMutableArray arrayWithCapacity:folder.unreadCount];
        FMDatabaseQueue *queue = self.databaseQueue;
        [queue inDatabase:^(FMDatabase *db) {
            FMResultSet * results = [db executeQuery:@"SELECT message_id FROM messages WHERE folder_id=? AND read_flag=0", @(folderId)];
            while ([results next])
            {
                NSString * guid = [results stringForColumnIndex:0];
                [newArray addObject:[ArticleReference makeReferenceFromGUID:guid inFolder:folderId]];
            }
            [results close];
        }];
        return [newArray copy];
	}
	else
	    return nil;
}

/* arrayOfArticles
 * Retrieves an array containing all articles (including text) for the
 * specified folder. If folderId is zero, all folders are searched. The
 * filterString option constrains the array to all those articles that
 * contain the specified filter.
 */
-(NSArray *)arrayOfArticles:(NSInteger)folderId filterString:(NSString *)filterString
{
	NSMutableArray * newArray = [NSMutableArray array];
	NSString * filterClause = @"";
	__weak NSString * queryString;
	Folder * folder = nil;
	__block NSInteger unread_count = 0;

	queryString=@"SELECT message_id, folder_id, parent_id, read_flag, marked_flag, deleted_flag, title, sender,"
		@" link, createddate, date, text, revised_flag, hasenclosure_flag, enclosure FROM messages";

	// If folderId is zero then we're searching the entire database
	// otherwise we need to construct a criteria tree for this folder
	if (folderId != 0)
	{
		folder = [self folderFromID:folderId];
        if (folder == nil) {
			return nil;
        }
		CriteriaTree * tree = [self criteriaForFolder:folderId];
        queryString = [NSString stringWithFormat:@"%@ WHERE (%@)", queryString, [tree toSQLForDatabase:self]];
	}

	// prepare filter if needed
	if ([filterString isNotEqualTo:@""]) {
		if (folderId == 0) {
			filterClause = @"WHERE (title LIKE '%' || ? || '%' OR text LIKE '%' || ? || '%')";
		} else {
			filterClause = @"AND (title LIKE '%' || ? || '%' OR text LIKE '%' || ? || '%')";
		}
		queryString = [NSString stringWithFormat:@"%@ %@", queryString, filterClause];
	};

	// Time to run the query
    FMDatabaseQueue *queue = self.databaseQueue;
    [queue inDatabase:^(FMDatabase *db) {
		FMResultSet * results;
		if ([filterString isEqualTo:@""]) {
			results = [db executeQuery:queryString];
		} else {
			results = [db executeQuery:queryString, filterString, filterString];
		}
		while ([results next])
		{
			Article * article = [[Article alloc] initWithGuid:[results stringForColumnIndex:0]];
			article.folderId = [results intForColumnIndex:1];
			article.parentId = [results intForColumnIndex:2];
			[article markRead:[results intForColumnIndex:3]];
			[article markFlagged:[results intForColumnIndex:4]];
			[article markDeleted:[results intForColumnIndex:5]];
			article.title = [results stringForColumnIndex:6];
			article.author = [results stringForColumnIndex:7];
			article.link = [results stringForColumnIndex:8];
			article.createdDate = [NSDate dateWithTimeIntervalSince1970:[results stringForColumnIndex:9].doubleValue];
			article.date = [NSDate dateWithTimeIntervalSince1970:[results stringForColumnIndex:10].doubleValue];
			NSString * text = [results stringForColumnIndex:11];
			article.body = text;
			[article markRevised:[results intForColumnIndex:12]];
			article.hasEnclosure = [results intForColumnIndex:13];
			article.enclosure = [results stringForColumnIndex:14];
		
			if (folder == nil || !article.deleted || folder.type == VNAFolderTypeTrash)
				[newArray addObject:article];
			
			// Keep our own track of unread articles
			if (!article.read)
				++unread_count;
			
		}
		[results close];
	}];
    
    // This is a good time to do a quick check to ensure that our
    // own count of unread is in sync with the folders count and fix
    // them if not.
    if (folder && [filterString isEqualTo:@""] && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader))
    {
        if (unread_count != folder.unreadCount)
        {
            NSLog(@"Fixing unread count for %@ (%ld on folder versus %ld in articles)", folder.name, (long)folder.unreadCount, (long)unread_count);
            NSInteger diff = (unread_count - folder.unreadCount);
            [self setFolderUnreadCount:folder adjustment:diff];
            [folder setNonPersistedFlag:VNAFolderFlagBuggySync];
        }
    }

	return [newArray copy];
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
		if ([self markFolderRead:folder.itemId])
			result = YES;
	}

	folder = [self folderFromID:folderId];
	if (folder != nil && folder.unreadCount > 0)
	{
        FMDatabaseQueue *queue = self.databaseQueue;
        __block BOOL success;
        [queue inDatabase:^(FMDatabase *db) {
            success = [db executeUpdate:@"UPDATE messages SET read_flag=1 WHERE folder_id=? AND read_flag=0",
             @(folderId)];
        }];

		if (success)
		{
			if (folder.countOfCachedArticles > 0)
			{
			    // update the existing cache of articles and update the unread count
			    [folder markArticlesInCacheRead];
			}
            // set the unread count to 0
            [self setFolderUnreadCount:folder adjustment:-folder.unreadCount];
			result = YES;
		}
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
		Article * article = [folder articleFromGuid:guid];
		if (article != nil && isRead != article.read)
		{
			// Mark an individual article read
            FMDatabaseQueue *queue = self.databaseQueue;
            __block BOOL success;
            [queue inDatabase:^(FMDatabase *db) {
                success = [db executeUpdate:@"UPDATE messages SET read_flag=? WHERE folder_id=? AND message_id=?",
                           @(isRead), @(folderId), guid];
            }];
			if (success)
			{
				NSInteger adjustment = (isRead ? -1 : 1);

				[article markRead:isRead];
				[self setFolderUnreadCount:folder adjustment:adjustment];
			}
		}
	}
}

/* markUnreadArticlesFromFolder
 * Marks as unread a set of articles.
 */
-(void)markUnreadArticlesFromFolder:(Folder *)folder guidArray:(NSArray *)guidArray
{
    FMDatabaseQueue *queue = self.databaseQueue;
    NSInteger folderId = folder.itemId;
	if(guidArray.count>0)
	{
		NSString * guidList = [guidArray componentsJoinedByString:@"','"];
        [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
			NSString * statement1 = [NSString stringWithFormat:@"UPDATE messages SET read_flag=1 WHERE folder_id=%ld AND read_flag=0 AND message_id NOT IN ('%@')", (long)folderId, guidList];
			[db executeUpdate:statement1];
			NSString * statement2 = [NSString stringWithFormat:@"UPDATE messages SET read_flag=0 WHERE folder_id=%ld AND read_flag=1 AND message_id IN ('%@')", (long)folderId, guidList];
			[db executeUpdate:statement2];
        }];
	}
	else
	{
        [queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE messages SET read_flag=1 WHERE folder_id=? AND read_flag=0", @(folderId)];
        }];
	}
	NSInteger adjustment = guidArray.count-folder.unreadCount;
	[self setFolderUnreadCount:folder adjustment:adjustment];
}

/* markStarredArticlesFromFolder
 * Marks starred a set of articles.
 */
-(void)markStarredArticlesFromFolder:(Folder *)folder guidArray:(NSArray *)guidArray
{
    FMDatabaseQueue *queue = self.databaseQueue;
    NSInteger folderId = folder.itemId;
	if(guidArray.count>0)
	{
		NSString * guidList = [guidArray componentsJoinedByString:@"','"];
		[queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
			NSString * statement1 = [NSString stringWithFormat:@"UPDATE messages SET marked_flag=1 WHERE folder_id=%ld AND marked_flag=0 AND message_id IN ('%@')", (long)folderId, guidList];
			[db executeUpdate:statement1];
			NSString * statement2 = [NSString stringWithFormat:@"UPDATE messages SET marked_flag=0 WHERE folder_id=%ld AND marked_flag=1 AND message_id NOT IN ('%@')", (long)folderId, guidList];
			[db executeUpdate:statement2];
        }];
	}
	else
	{
        [queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE messages SET marked_flag=0 WHERE folder_id=? AND marked_flag=1", @(folderId)];
        }];
	}
}

/* setFolderUnreadCount
 * Adjusts the unread count on the specified folder by the given delta. The same delta is
 * also applied to the childUnreadCount of all ancestor folders.
 */
-(void)setFolderUnreadCount:(Folder *)folder adjustment:(NSUInteger)adjustment
{
	_countOfUnread += adjustment;
	NSInteger newCount = folder.unreadCount + adjustment;
	folder.unreadCount = newCount;
    FMDatabaseQueue *queue = self.databaseQueue;
    [queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"UPDATE folders SET unread_count=? WHERE folder_id=?", @(newCount), @(folder.itemId)];
        [[NSNotificationCenter defaultCenter] vna_postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:@(folder.itemId)];
    }];

	// Update childUnreadCount for parents.
	Folder * tmpFolder = [self folderFromID:folder.parentId];
	while (tmpFolder != nil)
	{
		tmpFolder.childUnreadCount = tmpFolder.childUnreadCount + adjustment;
		tmpFolder = [self folderFromID:tmpFolder.parentId];
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
		Article * article = [folder articleFromGuid:guid];
		if (article != nil && isFlagged != article.flagged)
		{
            FMDatabaseQueue *queue = self.databaseQueue;
            __block BOOL success;
            [queue inDatabase:^(FMDatabase *db) {
                success = [db executeUpdate:@"UPDATE messages SET marked_flag=? WHERE folder_id=? AND message_id=?",
                 @(isFlagged),
                 @(folderId),
                 guid];
            }];

			if (success)
			{
				// Mark an individual article flagged
                [article markFlagged:isFlagged];
			}
		}
	}
}

/* markArticleDeleted
 * Marks an article as deleted. Deleted articles should have been marked read first.
 */
-(void)markArticleDeleted:(Article *)article isDeleted:(BOOL)isDeleted
{
	NSInteger folderId = article.folderId;
	NSString * guid = article.guid;
	Folder * folder = [self folderFromID:folderId];
	if (folder !=nil) {
		if (isDeleted && !article.read) {
			[self markArticleRead:folderId guid:guid isRead:YES];
		}
        FMDatabaseQueue *queue = self.databaseQueue;
        [queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE messages SET deleted_flag=? WHERE folder_id=? AND message_id=?",
             @(isDeleted),
             @(folderId),
             guid];
        }];
        if (isDeleted && !article.deleted) {
            [article markDeleted:YES];
            if (folder.countOfCachedArticles > 0)
			{
				// If we're in a smart folder, the cached article may be different.
				Article * cachedArticle = [folder articleFromGuid:guid];
				[cachedArticle markDeleted:YES];
				[folder removeArticleFromCache:guid];
			}
        }
        else if (!isDeleted) {
            // if we undelete, allow the RSS or OpenReader folder
            // to get the restored article 
            [folder restoreArticleToCache:article];
            [article markDeleted:NO];
        }
	}
}

/* isTrashEmpty
 * Returns YES if there are no deleted articles, NO if there are deleted articles
 */
-(BOOL)isTrashEmpty
{
	__block BOOL result;
    FMDatabaseQueue *queue = self.databaseQueue;
	[queue inDatabase:^(FMDatabase *db) {
        FMResultSet * results = [db executeQuery:@"SELECT deleted_flag FROM messages WHERE deleted_flag=1"];
        if ([results next])
        {
            result= NO;
        }
        else
            result=YES;
        [results close];
    }];

	return result;
}

/* guidHistoryForFolderId
 * Returns an array of all article guids ever downloaded for the specified folder.
 */
-(NSArray *)guidHistoryForFolderId:(NSInteger)folderId
{
	NSMutableArray * articleGuids = [NSMutableArray array];
    FMDatabaseQueue *queue = self.databaseQueue;
    [queue inDatabase:^(FMDatabase *db) {
		FMResultSet * results = [db executeQuery:@"SELECT message_id FROM rss_guids WHERE folder_id=?", @(folderId)];
		while ([results next])
		{
			NSString * guid = [results stringForColumn:@"message_id"];
			if (guid != nil)
			{
				[articleGuids addObject:guid];
			}
		}
		[results close];
	}];
	
	return [articleGuids copy];
}

/*!
 *  Get the path to the database file
 *
 *  @return A string representation of the database file's path
 */
+ (NSString *)databasePath {
    // Fully expand the path and make sure it exists because if the
    // database file itself doesn't exist, we want to create it and
    // we can't create it on a non-existent path.
    NSFileManager * fileManager = [NSFileManager defaultManager];
    NSString * qualifiedDatabaseFileName = [[Preferences standardPreferences] defaultDatabase].stringByExpandingTildeInPath;
    NSString * databaseFolder = qualifiedDatabaseFileName.stringByDeletingLastPathComponent;
    BOOL isDir;
    
    
    if (![fileManager fileExistsAtPath:databaseFolder isDirectory:&isDir])
    {
        NSError *error;
        if (![fileManager createDirectoryAtPath:databaseFolder withIntermediateDirectories:YES attributes:NULL error:&error])
        {
            NSAlert *alert = [NSAlert alertWithError:error];
            alert.alertStyle = NSAlertStyleCritical;
            alert.messageText = NSLocalizedString(@"Sorry, but Vienna was unable to create the database folder", nil);
            alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"Vienna was trying to create the folder \"%@\" but an error occurred. Check the permissions on the folders on the path specified.", nil), databaseFolder];
            [alert runModal];

            return nil;
        }
    }
    
    return qualifiedDatabaseFileName;
}


/* close
 * Close the database. All internal resources are released and a new,
 * possibly different, database can be opened instead.
 */
-(void)close
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self.foldersDict removeAllObjects];
	[self.smartfoldersDict removeAllObjects];
	self.trashFolder = nil;
	self.searchFolder = nil;
	self.initializedfoldersDict = NO;
	self.initializedSmartfoldersDict = NO;
	_countOfUnread = 0;
    [self.databaseQueue close];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[self close];
}
@end

