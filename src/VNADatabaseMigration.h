//
//  VNADatabaseMigration.h
//  Vienna
//
//  Created by Joshua Pore on 3/03/2015.
//  Copyright (c) 2015 The Vienna Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FMDB.h>

@interface VNADatabaseMigration : NSObject

+ (void)migrateDatabase:(FMDatabase *)db fromVersion:(NSInteger)fromVersion;

@end
