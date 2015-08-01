/**
 * CDEvents
 *
 * Copyright (c) 2010-2013 Aron Cedercrantz
 * http://github.com/rastersize/CDEvents/
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "CDEvent.h"
#import "compat.h"

@implementation CDEvent

#pragma mark Properties
@synthesize identifier	= _identifier;
@synthesize date		= _date;
@synthesize URL			= _URL;
@synthesize flags		= _flags;


#pragma mark Class object creators
+ (CDEvent *)eventWithIdentifier:(NSUInteger)identifier
							date:(NSDate *)date
							 URL:(NSURL *)URL
						   flags:(CDEventFlags)flags
{
	return [[CDEvent alloc] initWithIdentifier:identifier
										   date:date
											URL:URL
										  flags:flags];
}


#pragma mark Init/dealloc methods

- (id)initWithIdentifier:(NSUInteger)identifier
					date:(NSDate *)date
					 URL:(NSURL *)URL
				   flags:(CDEventFlags)flags
{
	if ((self = [super init])) {
		_identifier	= identifier;
		_flags		= flags;
		_date		= date;
		_URL		= URL;
	}
	
	return self;
}


#pragma mark NSCoding methods
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:[NSNumber numberWithUnsignedInteger:[self identifier]] forKey:@"identifier"];
	[aCoder encodeObject:[NSNumber numberWithUnsignedInteger:[self flags]] forKey:@"flags"];
	[aCoder encodeObject:[self date] forKey:@"date"];
	[aCoder encodeObject:[self URL] forKey:@"URL"];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [self initWithIdentifier:[[aDecoder decodeObjectForKey:@"identifier"] unsignedIntegerValue]
							   date:[aDecoder decodeObjectForKey:@"date"]
								URL:[aDecoder decodeObjectForKey:@"URL"]
							  flags:[[aDecoder decodeObjectForKey:@"flags"] unsignedIntValue]];
	
	return self;
}


#pragma mark NSCopying methods
- (id)copyWithZone:(NSZone *)zone
{
	// We can do this since we are immutable.
	return self;
}

#pragma mark Specific flag properties
- (BOOL)isGenericChange
{
	return (kFSEventStreamEventFlagNone == _flags);
}

#define FLAG_CHECK(flags, flag) ((flags) & (flag))

#define FLAG_PROPERTY(name, flag)                   \
- (BOOL)name                                        \
{ return (FLAG_CHECK(_flags, flag) ? YES : NO); }

FLAG_PROPERTY(mustRescanSubDirectories,     kFSEventStreamEventFlagMustScanSubDirs)
FLAG_PROPERTY(isUserDropped,                kFSEventStreamEventFlagUserDropped)
FLAG_PROPERTY(isKernelDropped,              kFSEventStreamEventFlagKernelDropped)
FLAG_PROPERTY(isEventIdentifiersWrapped,    kFSEventStreamEventFlagEventIdsWrapped)
FLAG_PROPERTY(isHistoryDone,                kFSEventStreamEventFlagHistoryDone)
FLAG_PROPERTY(isRootChanged,                kFSEventStreamEventFlagRootChanged)
FLAG_PROPERTY(didVolumeMount,               kFSEventStreamEventFlagMount)
FLAG_PROPERTY(didVolumeUnmount,             kFSEventStreamEventFlagUnmount)

// file-level events introduced in 10.7
FLAG_PROPERTY(isCreated,                    kFSEventStreamEventFlagItemCreated)
FLAG_PROPERTY(isRemoved,                    kFSEventStreamEventFlagItemRemoved)
FLAG_PROPERTY(isInodeMetadataModified,      kFSEventStreamEventFlagItemInodeMetaMod)
FLAG_PROPERTY(isRenamed,                    kFSEventStreamEventFlagItemRenamed)
FLAG_PROPERTY(isModified,                   kFSEventStreamEventFlagItemModified)
FLAG_PROPERTY(isFinderInfoModified,         kFSEventStreamEventFlagItemFinderInfoMod)
FLAG_PROPERTY(didChangeOwner,               kFSEventStreamEventFlagItemChangeOwner)
FLAG_PROPERTY(isXattrModified,              kFSEventStreamEventFlagItemXattrMod)
FLAG_PROPERTY(isFile,                       kFSEventStreamEventFlagItemIsFile)
FLAG_PROPERTY(isDir,                        kFSEventStreamEventFlagItemIsDir)
FLAG_PROPERTY(isSymlink,                    kFSEventStreamEventFlagItemIsSymlink)

#pragma mark Misc
- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %p { identifier = %ld, URL = %@, flags = %ld, date = %@ }>",
			[self className],
			self,
			(unsigned long)[self identifier],
			[self URL],
			(unsigned long)[self flags],
			[self date]];
}

@end
