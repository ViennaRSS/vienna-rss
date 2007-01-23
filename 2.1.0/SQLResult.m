//
//  SQLResult.m
//  SQLite Test
//
//  Created by Dustin Mierau on Tue Apr 02 2002.
//  Copyright (c) 2002 Blackhole Media, Inc. All rights reserved.
//

#import "SQLDatabase.h"
#import "SQLDatabasePrivate.h"

@implementation SQLResult

static SEL sRowAtIndexSelector;
static SEL sRowCountSelector;

+ (void)initialize
{
	if( self != [SQLResult class])
		return;
	
	sRowAtIndexSelector = @selector( rowAtIndex: );
	sRowCountSelector = @selector( rowCount );
}

#pragma mark -

-(id)initWithTable:(char**)inTable rows:(int)inRows columns:(int)inColumns
{
	if( ![super init])
		return nil;
	
	mTable = inTable;
	mRows = inRows;
	mColumns = inColumns;
	
	return self;
}

-(id)init
{
	if( ![super init])
		return nil;
	
	mTable = NULL;
	mRows = 0;
	mColumns = 0;
	
	return self;
}

-(void)dealloc
{
	if( mTable )
	{
		sqlite3_free_table( mTable );
		mTable = NULL;
	}
	
	[super dealloc];
}

#pragma mark -

-(int)rowCount
{
	return mRows;
}

-(int)columnCount
{
	return mColumns;
}

#pragma mark -

-(SQLRow*)rowAtIndex:(int)inIndex
{
	if( inIndex >= mRows )
		return nil;
	
	return [[[SQLRow alloc] initWithColumns:mTable rowData:( mTable + ( ( inIndex + 1 ) * mColumns ) ) columns:mColumns] autorelease];
}

-(NSEnumerator*)rowEnumerator
{
	return [[[SQLRowEnumerator allocWithZone:[self zone]] initWithResult:self] autorelease];
}

@end

#pragma mark -

@implementation SQLRowEnumerator

-(id)initWithResult:(SQLResult*)inResult
{
	if( ![super init])
		return nil;
	
	mResult = [inResult retain];
	mPosition = 0;
	mRowAtIndexMethod = [mResult methodForSelector:sRowAtIndexSelector];
	mRowCountMethod = (int (*)(SQLResult*, SEL))[mResult methodForSelector:sRowCountSelector];
	
	return self;
}

-(void)dealloc
{
	[mResult release];
	[super dealloc];
}

-(id)nextObject
{
	if( mPosition >= (*mRowCountMethod)(mResult, sRowCountSelector) )
		return nil;
	
	return (*mRowAtIndexMethod)(mResult, sRowAtIndexSelector, mPosition++);
}

@end