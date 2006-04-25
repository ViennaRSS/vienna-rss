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

+(id)databaseWithFile:(NSString*)inPath
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

// This is a VERY rudimentary regexp handler that only recognises \w prefix in the
// regexp string to match a word. Later we can add more functionality once the
// phrase parser is capable of supporting that functionality.
static void sqlite3_regexp(sqlite3_context *DB, int argc, sqlite3_value **argv)
{
	int retval = 0;
	
	if (argc == 2)
	{
		const char * regexp = (const char*)sqlite3_value_text(argv[0]);
		const char * str = (const char*)sqlite3_value_text(argv[1]);
		if (regexp && str && *regexp && *str)
		{
			BOOL wordmatch = NO;
			if (*regexp == '\\' && *(regexp+1) == 'w')
			{
				regexp += 2;
				wordmatch = YES;
			}
			char * match = strcasestr(str, regexp);
			if (match)
			{
				if (!wordmatch)
					retval = 1;
				else
				{
					const char * endmatch = match + strlen(regexp);
					const char * endstr = str + strlen(str);
					if (match == str || isspace(*(match-1)))
					{
						if (endmatch == endstr || isspace(*endmatch))
							retval = 1;
					}
				}
			}
		}
	}
	sqlite3_result_int(DB, retval);
}

-(BOOL)open
{
	if (sqlite3_open( [mPath fileSystemRepresentation], &mDatabase) == SQLITE_OK)
	{
		[[self performQuery:@"pragma cache_size=2000;"] release];
		[[self performQuery:@"pragma default_cache_size=30000;"] release];
		[[self performQuery:@"pragma temp_store=1;"] release];
		[[self performQuery:@"pragma auto_vacuum=0;"] release];

		if (sqlite3_create_function(mDatabase, "regexp", 2, SQLITE_UTF8, NULL, sqlite3_regexp, NULL, NULL) == SQLITE_OK)
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

#ifdef LOG_QUERY_TIMES
// These routines should perhaps be in a different file?

// GetStartTime() returns the current time in seconds as a double.
// It's named GetStartTime instead of GetCurrentTime() since it is
// used only for timing.
static double GetStartTime()
{
	UnsignedWide microsecondsValue;
	Microseconds( &microsecondsValue );
	double twoPower32 = 4294967296.0;
	double doubleValue;
	double upperHalf = (double)microsecondsValue.hi;
	double lowerHalf = (double)microsecondsValue.lo;
	doubleValue = (upperHalf * twoPower32) + lowerHalf;
	return doubleValue * 0.000001;
}

// LogElapsedTime() dumps the query and elapsed time in seconds
// to the console.
static void LogElapsedTime( NSString * query, double startTime )
{
	double elapsedTime = GetStartTime() - startTime;
	NSLog( @"Query (%f secs): %@", elapsedTime, query );
}
#endif

-(SQLResult*)performQuery:(NSString*)inQuery
{
	SQLResult*	sqlResult = nil;
	char**		results;
	int			columns;
	int			rows;
	
	if( !mDatabase )
		return nil;

#ifdef LOG_QUERY_TIMES
	double startTime = GetStartTime();
#endif

	lastError = sqlite3_get_table( mDatabase, [inQuery UTF8String], &results, &rows, &columns, NULL );
	if( lastError != SQLITE_OK )
		sqlite3_free_table( results );
	else
	{
		sqlResult = [[SQLResult alloc] initWithTable:results rows:rows columns:columns];
		if( !sqlResult )
			sqlite3_free_table( results );
	}
	
#ifdef LOG_QUERY_TIMES
	LogElapsedTime( inQuery, startTime );
#endif

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
