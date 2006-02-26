//
//  SQLDatabase.m
//  SQLite Test
//
//  Created by Dustin Mierau on Tue Apr 02 2002.
//  Copyright (c) 2002 Blackhole Media, Inc. All rights reserved.
//

#import "SQLDatabase.h"
#import "SQLDatabasePrivate.h"

@implementation SQLDatabase

+ (id)databaseWithFile:(NSString*)inPath
{
	return [[[SQLDatabase alloc] initWithFile:inPath] autorelease];
}

#pragma mark -

-(id)initWithFile:(NSString*)inPath
{
	if( ![super init])
		return nil;
	
	mPath = [inPath copy];
	mDatabase = NULL;
	lastError = SQLITE_OK;
	
	return self;
}

-(id)init
{
	if( ![super init])
		return nil;
	
	mPath = NULL;
	mDatabase = NULL;
	
	return self;
}

-(void)dealloc
{
	[self close];
	[mPath release];
	[super dealloc];
}

#pragma mark -

-(BOOL)open
{
	if (sqlite3_open( [mPath fileSystemRepresentation], &mDatabase) == SQLITE_OK)
	{
		[[self performQuery:@"pragma cache_size=2000;"] release];
		[[self performQuery:@"pragma synchronous=1;"] release];
		return YES;
	}
	return NO;
}

-(void)close
{
	if( !mDatabase )
		return;
	
	sqlite3_close( mDatabase );
	mDatabase = NULL;
}

#pragma mark -

+ (NSString*)prepareStringForQuery:(NSString*)inString
{
	NSMutableString*	string;
	NSRange				range = NSMakeRange( 0, [inString length]);
	NSRange				subRange;
	
	subRange = [inString rangeOfString:@"'" options:NSLiteralSearch range:range];
	if( subRange.location == NSNotFound )
		return inString;
	
	string = [NSMutableString stringWithString:inString];
	for( ; subRange.location != NSNotFound && range.length > 0;  )
	{
		subRange = [string rangeOfString:@"'" options:NSLiteralSearch range:range];
		if( subRange.location != NSNotFound )
			[string replaceCharactersInRange:subRange withString:@"''"];
		
		range.location = subRange.location + 2;
		range.length = ( [string length] < range.location ) ? 0 : ( [string length] - range.location );
	}
	
	return string;
}

-(int)lastInsertRowId
{
	if( !mDatabase )
		return -1;

	return sqlite3_last_insert_rowid( mDatabase );
}

-(int)lastError
{
	return lastError;
}

-(SQLResult*)performQuery:(NSString*)inQuery
{
	SQLResult*	sqlResult = nil;
	char**		results;
	int			columns;
	int			rows;
	
	if( !mDatabase )
		return nil;
	
	lastError = sqlite3_get_table( mDatabase, [inQuery UTF8String], &results, &rows, &columns, NULL );
	if( lastError != SQLITE_OK )
	{
		sqlite3_free_table( results );
		return nil;
	}
	
	sqlResult = [[SQLResult alloc] initWithTable:results rows:rows columns:columns];
	if( !sqlResult )
		sqlite3_free_table( results );
	
	return sqlResult;
}

-(SQLResult*)performQueryWithFormat:(NSString*)inFormat, ...
{
	SQLResult*	sqlResult = nil;
	NSString*	query = nil;
	va_list		arguments;
	
	if( inFormat == nil )
		return nil;
	
	va_start( arguments, inFormat );
	
	query = [[NSString alloc] initWithFormat:inFormat arguments:arguments];
	sqlResult = [self performQuery:query];
	[query release];
	
	va_end( arguments );
	
	return sqlResult;
}

@end
