//
//  Database+Migration.h
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

#import "Database.h"

@import FMDB;

@interface Database (Migration)

/// Migrates the Vienna database schema.
/// @param database The database to migrate.
/// @param previousVersion The version to migrate from.
+ (void)migrateDatabase:(FMDatabase *)database
            fromVersion:(NSInteger)previousVersion;
+ (void)rollbackDatabase:(FMDatabase *)database
               toVersion:(NSInteger)oldVersion;
+ (NSArray *)availableVersionsForRollback;
@end
