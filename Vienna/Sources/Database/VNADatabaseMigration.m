//
//  VNADatabaseMigration.m
//  Vienna
//
//  Created by Joshua Pore on 3/03/2015.
//  Copyright (c) 2015 The Vienna Project. All rights reserved.
//

#import "VNADatabaseMigration.h"
#import "Preferences.h"
#import "Constants.h"

@implementation VNADatabaseMigration


/*!
 *  Migrate the Vienna database schema
 *
 *  @param fromVer the version we want to migrate from
 */
+ (void)migrateDatabase:(FMDatabase *)db fromVersion:(NSInteger)fromVersion {
    
    switch (fromVersion+1) {
        case 13: {
            // Upgrade to rev 13.
            // Add createddate field to the messages table and initialise it to a date in the past.
            // Create an index on the message_id column.

            [db executeUpdate:@"alter table messages add column createddate"];
            [db executeUpdate:@"update messages set createddate=?", @([NSDate distantPast].timeIntervalSince1970)];
            [db executeUpdate:@"create index messages_message_idx on messages (message_id)"];
            db.userVersion = (uint32_t)13;

            NSLog(@"Updated database schema to version 13.");
        }
        case 14: {
            // Upgrade to rev 14.
            // Add next_sibling and next_child columns to folders table and first_folder column to info table to allow for manual sorting.
            // Initialize all values to 0. The correct values will be set by -[FoldersTree setManualSortOrderForNode:].
            // Make sure that all parent_id values are integers rather than strings, because previous versions of setParent:forFolder:
            // set them as strings.
            
            [db executeUpdate:@"alter table info add column first_folder"];
            [db executeUpdate:@"update info set first_folder=0"];
            
            [db executeUpdate:@"alter table folders add column next_sibling"];
            [db executeUpdate:@"update folders set next_sibling=0"];
            
            [db executeUpdate:@"alter table folders add column first_child"];
            [db executeUpdate:@"update folders set first_child=0"];
            
            [[Preferences standardPreferences] setFoldersTreeSortMethod:VNAFolderSortByName];
            
            FMResultSet * results = [db executeQuery:@"select folder_id, parent_id from folders"];
            while([results next])
            {
                NSNumber *folderId = [results objectForColumn:@"folder_id"];
                NSNumber *parentId = [results objectForColumn:@"parent_id"];
                [db executeUpdate:@"update folders set parent_id=? where folder_id=?",
                 parentId, folderId];
            }
            [results close];
            db.userVersion = (uint32_t)14;
            
            NSLog(@"Updated database schema to version 14.");
        }
        case 15: {
            // Upgrade to rev 15.
            // Move the folders tree sort method preference to the database, so that it can survive deletion of the preferences file.
            // Do not disturb the manual sort order, if it exists.
            
            [db executeUpdate:@"alter table info add column folder_sort"];
            NSInteger oldFoldersTreeSortMethod = [Preferences standardPreferences].foldersTreeSortMethod;
            [db executeUpdate:@"update info set folder_sort=?", @(oldFoldersTreeSortMethod)];
            db.userVersion = (uint32_t)15;
            
            NSLog(@"Updated database schema to version 15.");
        }
        case 16: {
            // Upgrade to rev 16.
            // Add revised_flag to messages table, and initialize all values to 0.
            
            [db executeUpdate:@"alter table messages add column revised_flag"];
            [db executeUpdate:@"update messages set revised_flag=0"];
            db.userVersion = (uint32_t)16;

            NSLog(@"Updated database schema to version 16.");
        }
        case 17: {
            // Upgrade to rev 17.
            // Add hasenclosure_flag, enclosuredownloaded_flag and enclosure to messages table, and initialize stuff.
 
            [db executeUpdate:@"alter table messages add column hasenclosure_flag"];
            [db executeUpdate:@"update messages set hasenclosure_flag=0"];
            [db executeUpdate:@"alter table messages add column enclosure"];
            [db executeUpdate:@"update messages set enclosure=''"];
            [db executeUpdate:@"alter table messages add column enclosuredownloaded_flag"];
            [db executeUpdate:@"update messages set enclosuredownloaded_flag=0"];
            db.userVersion = (uint32_t)17;

            NSLog(@"Updated database schema to version 17.");
        }
        case 18: {
            // Upgrade to rev 18.
            // Add table all message guids.

            [db executeUpdate:@"create table rss_guids as select message_id, folder_id from messages"];
            [db executeUpdate:@"create index rss_guids_idx on rss_guids (folder_id)"];
            db.userVersion = (uint32_t)18;

            NSLog(@"Updated database schema to version 18.");
        }
        case 19: {
            // Upgrade to rev 19.
            // Update the Vienna Developer's blog RSS URL after we changed from .org to .com

            FMResultSet *results = [db executeQuery:@"SELECT folder_id FROM rss_folders WHERE feed_url LIKE ?", @"%%vienna-rss.org%%"];

            if([results next]) {
                int viennaFolderId = [results intForColumn:@"folder_id"];
                [db executeUpdate:@"UPDATE rss_folders SET feed_url=?, home_page=? WHERE folder_id=?",
                 @"http://www.vienna-rss.com/?feed=rss2",
                 @"http://www.vienna-rss.com",
                 @(viennaFolderId)];
            }
            [results close];
            db.userVersion = (uint32_t)19;
            NSLog(@"Updated database schema to version 19.");
        }
        case 20: {
            // Upgrade to rev 20.
            // Update the Vienna Developer's blog RSS URL after moved to github pages
            
            FMResultSet *results = [db executeQuery:@"SELECT folder_id FROM rss_folders WHERE feed_url LIKE ?", @"%%www.vienna-rss.com/?feed=rss2%%"];
            
            if([results next]) {
                int viennaFolderId = [results intForColumn:@"folder_id"];
                [db executeUpdate:@"UPDATE rss_folders SET feed_url=? WHERE folder_id=?",
                 @"https://www.vienna-rss.com/feed.xml",
                 @(viennaFolderId)];
            }
            [results close];
            db.userVersion = (uint32_t)20;
            NSLog(@"Updated database schema to version 20.");
        }
        case 21: {
            // Removes line-breaks and tabs from author strings.

            FMResultSet *results = [db executeQuery:@"SELECT message_id, sender FROM messages WHERE TRIM(sender) > ''"];

            // Create a character set that contains new-line characters and the
            // tab character (Unicode U+0009).
            NSString *tabCharacter = [NSString stringWithCharacters:(UniChar[]){0x0009}
                                                             length:1];
            NSMutableCharacterSet *characterSet = NSMutableCharacterSet.newlineCharacterSet;
            [characterSet addCharactersInString:tabCharacter];

            while ([results next]) {
                NSString *oldSender = [results stringForColumn:@"sender"];

                if (!oldSender || oldSender.length == 0 ) {
                    continue;
                }

                // Search the whole  sender string for line-breaks and the tab
                // character. Other whitespace characters are preserved.
                NSScanner *scanner = [NSScanner scannerWithString:oldSender];
                NSString *scanResult = [NSString string];
                NSMutableString *newSender = [NSMutableString string];
                while ([scanner scanUpToCharactersFromSet:characterSet
                                               intoString:&scanResult]) {
                    [newSender appendString:scanResult];
                }

                // If the strings match, do not update the database entry.
                if ([newSender isEqualToString:oldSender]) {
                    continue;
                }

                NSString *messageID = [results stringForColumn:@"message_id"];
                [db executeUpdate:@"UPDATE messages SET sender=? WHERE message_id=?",
                 newSender, messageID];
            }

            db.userVersion = (uint32_t)21;
            NSLog(@"Updated database schema to version 21.");
        }
    }
    
}

@end
