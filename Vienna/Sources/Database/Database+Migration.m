//
//  Database+Migration.m
//  Vienna
//
//  Copyright 2015 Joshua Pore
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "Database+Migration.h"

#import "Preferences.h"
#import "Vienna-Swift.h"

@implementation Database (Migration)

+ (void)migrateDatabase:(FMDatabase *)database
            fromVersion:(NSInteger)previousVersion
{
    switch (previousVersion + 1) {
        case 13: {
            // Add createddate field to the messages table and initialise it to
            // a date in the past. Create an index on the message_id column.

            [database executeUpdate:@"ALTER TABLE messages "
                                     "ADD COLUMN createddate"];
            NSTimeInterval interval = NSDate.distantPast.timeIntervalSince1970;
            [database executeUpdate:@"UPDATE messages SET createddate = ?",
                                    @(interval)];
            [database executeUpdate:@"CREATE INDEX messages_message_idx "
                                     "ON messages (message_id)"];
            database.userVersion = (uint32_t)13;

            NSLog(@"Updated database schema to version 13.");
        }
        case 14: {
            // Add next_sibling and next_child columns to folders table and
            // first_folder column to info table to allow for manual sorting.
            // Initialize all values to 0. The correct values will be set by
            // -[FoldersTree setManualSortOrderForNode:]. Make sure that all
            // parent_id values are integers rather than strings, because
            // previous versions of setParent:forFolder: set them as strings.

            [database executeUpdate:@"ALTER TABLE info "
                                     "ADD COLUMN first_folder"];
            [database executeUpdate:@"UPDATE info SET first_folder = 0"];

            [database executeUpdate:@"ALTER TABLE folders "
                                     "ADD COLUMN next_sibling"];
            [database executeUpdate:@"UPDATE folders SET next_sibling = 0"];

            [database executeUpdate:@"ALTER TABLE folders "
                                     "ADD COLUMN first_child"];
            [database executeUpdate:@"UPDATE folders SET first_child = 0"];

            Preferences *preferences = [Preferences standardPreferences];
            [preferences setFoldersTreeSortMethod:VNAFolderSortByName];

            FMResultSet *results = [database executeQuery:@"SELECT folder_id, "
                                                           "parent_id "
                                                           "FROM folders"];
            while ([results next]) {
                NSNumber *folderId = [results objectForColumn:@"folder_id"];
                NSNumber *parentId = [results objectForColumn:@"parent_id"];
                [database executeUpdate:@"UPDATE folders "
                                         "SET parent_id = ? "
                                         "WHERE folder_id = ?",
                                        parentId,
                                        folderId];
            }
            [results close];
            database.userVersion = (uint32_t)14;

            NSLog(@"Updated database schema to version 14.");
        }
        case 15: {
            // Move the folders tree sort method preference to the database, so
            // that it can survive deletion of the preferences file. Do not
            // disturb the manual sort order, if it exists.

            [database executeUpdate:@"ALTER TABLE info ADD COLUMN folder_sort"];
            Preferences *preferences = [Preferences standardPreferences];
            NSInteger oldSortMethod = preferences.foldersTreeSortMethod;
            [database executeUpdate:@"UPDATE info SET folder_sort = ?",
                                    @(oldSortMethod)];
            database.userVersion = (uint32_t)15;

            NSLog(@"Updated database schema to version 15.");
        }
        case 16: {
            // Add revised_flag to messages table, and initialize all values to
            // 0.

            [database executeUpdate:@"ALTER TABLE messages "
                                     "ADD COLUMN revised_flag"];
            [database executeUpdate:@"UPDATE messages SET revised_flag = 0"];
            database.userVersion = (uint32_t)16;

            NSLog(@"Updated database schema to version 16.");
        }
        case 17: {
            // Add hasenclosure_flag, enclosuredownloaded_flag and enclosure to
            // messages table, and initialize stuff.

            [database executeUpdate:@"ALTER TABLE messages "
                                     "ADD COLUMN hasenclosure_flag"];
            [database executeUpdate:@"UPDATE messages "
                                     "SET hasenclosure_flag = 0"];
            [database executeUpdate:@"ALTER TABLE messages "
                                     "ADD COLUMN enclosure"];
            [database executeUpdate:@"UPDATE messages SET enclosure = ''"];
            [database executeUpdate:@"ALTER TABLE messages "
                                     "ADD COLUMN enclosuredownloaded_flag"];
            [database executeUpdate:@"UPDATE messages "
                                     "SET enclosuredownloaded_flag = 0"];
            database.userVersion = (uint32_t)17;

            NSLog(@"Updated database schema to version 17.");
        }
        case 18: {
            // Add table all message guids.

            [database executeUpdate:@"CREATE TABLE rss_guids "
                                     "AS SELECT message_id, folder_id "
                                     "FROM messages"];
            [database executeUpdate:@"CREATE INDEX rss_guids_idx "
                                     "ON rss_guids (folder_id)"];
            database.userVersion = (uint32_t)18;

            NSLog(@"Updated database schema to version 18.");
        }
        case 19: {
            // Update the Vienna Developer's blog RSS URL after we changed from
            // .org to .com

            FMResultSet *results =
                [database executeQuery:@"SELECT folder_id "
                                        "FROM rss_folders "
                                        "WHERE feed_url LIKE ?",
                                       @"%%vienna-rss.org%%"];

            if ([results next]) {
                int viennaFolderId = [results intForColumn:@"folder_id"];
                [database executeUpdate:@"UPDATE rss_folders "
                                         "SET feed_url = ?, home_page = ? "
                                         "WHERE folder_id = ?",
                                        @"http://www.vienna-rss.com/?feed=rss2",
                                        @"http://www.vienna-rss.com",
                                        @(viennaFolderId)];
            }
            [results close];
            database.userVersion = (uint32_t)19;
            NSLog(@"Updated database schema to version 19.");
        }
        case 20: {
            // Update the Vienna Developer's blog RSS URL after moved to github
            // pages

            FMResultSet *results =
                [database executeQuery:@"SELECT folder_id "
                                        "FROM rss_folders "
                                        "WHERE feed_url LIKE ?",
                                       @"%%www.vienna-rss.com/?feed=rss2%%"];

            if ([results next]) {
                int viennaFolderId = [results intForColumn:@"folder_id"];
                [database executeUpdate:@"UPDATE rss_folders "
                                         "SET feed_url = ? "
                                         "WHERE folder_id = ?",
                                        @"https://www.vienna-rss.com/feed.xml",
                                        @(viennaFolderId)];
            }
            [results close];
            database.userVersion = (uint32_t)20;
            NSLog(@"Updated database schema to version 20.");
        }
        case 21: {
            // Removes line-breaks and tabs from author strings.

            FMResultSet *results =
                [database executeQuery:@"SELECT message_id, sender "
                                        "FROM messages "
                                        "WHERE TRIM(sender) > ''"];

            // Create a character set that contains new-line characters and the
            // tab character (Unicode U+0009).
            NSMutableCharacterSet *characterSet = nil;
            characterSet = NSMutableCharacterSet.newlineCharacterSet;
            unichar character[] = {0x0009};
            NSString *tabCharacter = [NSString stringWithCharacters:character
                                                             length:1];
            [characterSet addCharactersInString:tabCharacter];

            while ([results next]) {
                NSString *oldSender = [results stringForColumn:@"sender"];

                if (!oldSender || oldSender.length == 0) {
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
                [database executeUpdate:@"UPDATE messages "
                                         "SET sender= ? "
                                         "WHERE message_id = ?",
                                        newSender,
                                        messageID];
            }

            database.userVersion = (uint32_t)21;
            NSLog(@"Updated database schema to version 21.");
        }
        case 22: {
            // Enables auto-vacuum mode on the database. Enabling this requires
            // a VACUUM operation, which usually takes some time to complete.
            [database executeStatements:@"PRAGMA auto_vacuum = 1; VACUUM"];

            database.userVersion = (uint32_t)22;
            NSLog(@"Updated database schema to version 22.");
        }
        case 23: {
            // Create indexes for unread and non deleted messages
            [database executeStatements:@"CREATE INDEX messages_read_flag ON messages(read_flag)"];
            [database executeStatements:@"CREATE INDEX messages_deleted_flag ON messages(deleted_flag)"];

            database.userVersion = (uint32_t)23;
            NSLog(@"Updated database schema to version 23.");
        }
        case 24:
        case 25:
        case 26: {
            //correct articles that were saved with updatedDate is 1.1.1970 00:00
            [database executeStatements:@"UPDATE messages SET date = createddate WHERE date = 0"];

            database.userVersion = (uint32_t)26;
            NSLog(@"Updated database schema to version 26.");
        }
    }
}

@end
