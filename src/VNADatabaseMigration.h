//
//  VNADatabaseMigration.h
//  Vienna
//
//  Created by Joshua Pore on 3/03/2015.
//  Copyright (c) 2015 The Vienna Project. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VNADatabaseMigration : NSObject

- (void)migrateSchemaFromVersion:(NSInteger)fromVersion toVersion:(NSInteger)toVersion;

@end
