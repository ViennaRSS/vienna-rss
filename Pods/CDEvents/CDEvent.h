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

/**
 * @headerfile CDEvent.h CDEvents/CDEvent.h
 * A class that wraps the data from a FSEvents event callback.
 * 
 * A class that wraps the data from a FSEvents event callback. Inspired and
 * based upon the open source project SCEvents created by Stuart Connolly
 * http://stuconnolly.com/projects/code/
 */

#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>

#pragma mark -
#pragma mark CDEvent types
/**
 * The event identifier type.
 *
 * @since 1.0.0
 */
typedef FSEventStreamEventId CDEventIdentifier;

/**
 * The event stream event flags type.
 *
 * @since 1.0.1
 */
typedef FSEventStreamEventFlags CDEventFlags;


#pragma mark -
#pragma mark CDEvent interface
/**
 * An Objective-C wrapper for a <code>FSEvents</code> event data.
 *
 * @note Inspired by <code>SCEvent</code> class of the <code>SCEvents</code> project by Stuart Connolly.
 * @note The class is immutable.
 *
 * @see FSEvents.h in CoreServices
 *
 * @since 1.0.0
 */
@interface CDEvent : NSObject <NSCoding, NSCopying> {}

#pragma mark Properties
/** @name Getting Event Properties */
/**
 * The event identifier.
 *
 * The event identifier as returned by <code>FSEvents</code>.
 *
 * @return The event identifier.
 *
 * @since 1.0.0
 */
@property (readonly) CDEventIdentifier			identifier;

/**
 * An approximate date and time the event occured.
 *
 * @return The approximate date and time the event occured.
 *
 * @since 1.0.0
 */
@property (strong, readonly) NSDate	*date;

/**
 * The URL of the item which changed.
 *
 * @return The URL of the item which changed.
 *
 * @since 1.0.0
 */
@property (strong, readonly) NSURL	*URL;


/** @name Getting Event Flags */
/**
 * The flags of the event.
 *
 * The flags of the event as returned by <code>FSEvents</code>.
 *
 * @return The flags of the event.
 *
 * @see FSEventStreamEventFlags
 *
 * @since 1.0.0
 */
@property (readonly) CDEventFlags				flags;

#pragma mark Specific flag properties
/**
 * Wheter there was some change in the directory at the specific path supplied in this event.
 *
 * @return <code>YES</code> if there was some change in the directory, otherwise <code>NO</code>.
 *
 * @see kFSEventStreamEventFlagNone
 * @see flags
 * @see mustRescanSubDirectories
 * @see isUserDropped
 * @see isKernelDropped
 * @see isEventIdentifiersWrapped
 * @see isHistoryDone
 * @see isRootChanged
 * @see didVolumeMount
 * @see didVolumeUnmount
 *
 * @since 1.1.0
 */
@property (readonly) BOOL						isGenericChange;

/**
 * Wheter you must rescan the whole URL including its children.
 *
 * Wheter your application must rescan not just the URL given in the event, but
 * all its children, recursively. This can happen if there was a problem whereby
 * events were coalesced hierarchically. For example, an event in
 * <code>/Users/jsmith/Music</code> and an event in
 * <code>/Users/jsmith/Pictures</code> might be coalesced into an event with
 * this flag set and URL <code>= /Users/jsmith</code>. If this flag is set
 * you may be able to get an idea of whether the bottleneck happened in the
 * kernel (less likely) or in your client (more likely) by checking if
 * isUserDropped or isKernelDropped returns <code>YES</code>.
 *
 * @return <code>YES</code> if you must rescan the whole directory including its children, otherwise <code>NO</code>.
 *
 * @see kFSEventStreamEventFlagMustScanSubDirs
 * @see flags
 * @see isGenericChange
 * @see isUserDropped
 * @see isKernelDropped
 * @see isEventIdentifiersWrapped
 * @see isHistoryDone
 * @see isRootChanged
 * @see didVolumeMount
 * @see didVolumeUnmount
 *
 * @since 1.1.0
 */
@property (readonly) BOOL						mustRescanSubDirectories;

/**
 * Provides some information as to what might have caused the need to rescan the URL including its children.
 *
 * @return <code>YES</code> if mustRescanSubDirectories returns <code>YES</code> and the cause were in userland, otherwise <code>NO</code>.
 *
 * @see kFSEventStreamEventFlagUserDropped
 * @see flags
 * @see isGenericChange
 * @see mustRescanSubDirectories
 * @see isKernelDropped
 * @see isEventIdentifiersWrapped
 * @see isHistoryDone
 * @see isRootChanged
 * @see didVolumeMount
 * @see didVolumeUnmount
 *
 * @since 1.1.0
 */
@property (readonly) BOOL						isUserDropped;

/**
 * Provides some information as to what might have caused the need to rescan the URL including its children.
 *
 * @return <code>YES</code> if mustRescanSubDirectories returns <code>YES</code> and the cause were in kernelspace, otherwise <code>NO</code>.
 *
 * @see kFSEventStreamEventFlagKernelDropped
 * @see flags
 * @see isGenericChange
 * @see mustRescanSubDirectories
 * @see isUserDropped
 * @see isEventIdentifiersWrapped
 * @see isHistoryDone
 * @see isRootChanged
 * @see didVolumeMount
 * @see didVolumeUnmount
 *
 * @since 1.1.0
 */
@property (readonly) BOOL						isKernelDropped;

/**
 * Wheter the 64-bit event identifier counter has wrapped around.
 *
 * Wheter the 64-bit event identifier counter has wrapped around. As a result,
 * previously-issued event identifiers are no longer valid arguments for the
 * sinceEventIdentifier parameter of the CDEvents init methods.
 *
 * @return <code>YES</code> if the 64-bit event identifier counter has wrapped around, otherwise <code>NO</code>.
 *
 * @see kFSEventStreamEventFlagEventIdsWrapped
 * @see flags
 * @see isGenericChange
 * @see mustRescanSubDirectories
 * @see isUserDropped
 * @see isKernelDropped
 * @see isHistoryDone
 * @see isRootChanged
 * @see didVolumeMount
 * @see didVolumeUnmount
 *
 * @since 1.1.0
 */
@property (readonly) BOOL						isEventIdentifiersWrapped;

/**
 * Denotes a sentinel event sent to mark the end of the "historical" events sent.
 *
 * Denotes a sentinel event sent to mark the end of the "historical" events sent
 * as a result of specifying a <i>sinceEventIdentifier</i> argument other than
 * kCDEventsSinceEventNow with the CDEvents init methods.
 *
 * @return <code>YES</code> if if the event is sent to mark the end of the "historical" events sent, otherwise <code>NO</code>.
 *
 * @see kFSEventStreamEventFlagHistoryDone
 * @see flags
 * @see isGenericChange
 * @see mustRescanSubDirectories
 * @see isUserDropped
 * @see isKernelDropped
 * @see isEventIdentifiersWrapped
 * @see isRootChanged
 * @see didVolumeMount
 * @see didVolumeUnmount
 * @see kCDEventsSinceEventNow
 * @see CDEvents
 *
 * @since 1.1.0
 */
@property (readonly) BOOL						isHistoryDone;

/**
 * Denotes a special event sent when there is a change to one of the URLs you asked to watch.
 *
 * Denotes a special event sent when there is a change to one of the URLs you
 * asked to watch. When this method returns <code>YES</code>, the event
 * identifier is zero and the <code>URL</code> corresponds to one of the URLs
 * you asked to watch (specifically, the one that changed). The URL may no
 * longer exist because it or one of its parents was deleted or renamed. Events
 * with this flag set will only be sent if you passed the flag
 * <code>kFSEventStreamCreateFlagWatchRoot</code> to the CDEvents.
 *
 * @return <code>YES</code> if there is a change to one of the URLs you asked to watch, otherwise <code>NO</code>.
 *
 * @see kFSEventStreamEventFlagRootChanged
 * @see flags
 * @see isGenericChange
 * @see mustRescanSubDirectories
 * @see isUserDropped
 * @see isKernelDropped
 * @see isEventIdentifiersWrapped
 * @see isHistoryDone
 * @see didVolumeMount
 * @see didVolumeUnmount
 * @see CDEvents
 * @see kCDEventsDefaultEventStreamFlags
 *
 * @since 1.1.0
 */
@property (readonly) BOOL						isRootChanged;

/**
 * Denotes a special event sent when a volume is mounted underneath one of the URLs being watched.
 *
 * Denotes a special event sent when a volume is mounted underneath one of the
 * URLs being watched. The URL in the event is the URL to the newly-mounted
 * volume. You will receive one of these notifications for every volume mount
 * event inside the kernel (independent of DiskArbitration). Beware that a
 * newly-mounted volume could contain an arbitrarily large directory hierarchy.
 * Avoid pitfalls like triggering a recursive scan of a non-local filesystem,
 * which you can detect by checking for the absence of the
 * <code>MNT_LOCAL</code> flag in the <code>f_flags</code> returned by statfs().
 * Also be aware of the <code>MNT_DONTBROWSE</code> flag that is set for volumes
 * which should not be displayed by user interface elements.
 *
 * @return <code>YES</code> if a volumen is mounted underneath one of the URLs being watched, otherwise <code>NO</code>.
 *
 * @see kFSEventStreamEventFlagMount
 * @see flags
 * @see isGenericChange
 * @see mustRescanSubDirectories
 * @see isUserDropped
 * @see isKernelDropped
 * @see isEventIdentifiersWrapped
 * @see isHistoryDone
 * @see isRootChanged
 * @see didVolumeUnmount
 *
 * @since 1.1.0
 */
@property (readonly) BOOL						didVolumeMount;

/**
 * Denotes a special event sent when a volume is unmounted underneath one of the URLs being watched.
 *
 * Denotes a special event sent when a volume is unmounted underneath one of the
 * URLs being watched. The URL in the event is the URL to the directory from
 * which the volume was unmounted. You will receive one of these notifications
 * for every volume unmount event inside the kernel. This is not a substitute
 * for the notifications provided by the DiskArbitration framework; you only get
 * notified after the unmount has occurred. Beware that unmounting a volume
 * could uncover an arbitrarily large directory hierarchy, although Mac OS X
 * never does that.
 *
 * @return <code>YES</code> if a volume is unmounted underneath one of the URLs being watched, otherwise <code>NO</code>.
 *
 * @see kFSEventStreamEventFlagUnmount
 * @see flags
 * @see isGenericChange
 * @see mustRescanSubDirectories
 * @see isUserDropped
 * @see isKernelDropped
 * @see isEventIdentifiersWrapped
 * @see isHistoryDone
 * @see isRootChanged
 * @see didVolumeMount
 *
 * @since 1.1.0
 */
@property (readonly) BOOL						didVolumeUnmount;


/**
 * The entirety of the documentation on file level events in lion is 3 sentences
 * long. Rename behavior is odd, making the combination of events and flags
 * somewhat confusing for atomic writes. It also appears possible to get a
 * singular event where a file has been created, modified, and removed.
 */
@property (readonly) BOOL                       isCreated;
@property (readonly) BOOL                       isRemoved;
@property (readonly) BOOL                       isInodeMetadataModified;
@property (readonly) BOOL                       isRenamed;
@property (readonly) BOOL                       isModified;
@property (readonly) BOOL                       isFinderInfoModified;
@property (readonly) BOOL                       didChangeOwner;
@property (readonly) BOOL                       isXattrModified;
@property (readonly) BOOL                       isFile;
@property (readonly) BOOL                       isDir;
@property (readonly) BOOL                       isSymlink;

#pragma mark Class object creators
/** @name Creating CDEvent Objects */
/**
 * Returns an <code>CDEvent</code> created with the given identifier, date, URL and flags.
 *
 * @param identifier The identifier of the the event.
 * @param date The date when the event occured.
 * @param URL The URL of the item the event concerns.
 * @param flags The flags of the event.
 * @return An <code>CDEvent</code> created with the given identifier, date, URL and flags.
 *
 * @see FSEventStreamEventFlags
 * @see initWithIdentifier:date:URL:flags:
 *
 * @since 1.0.0
 */
+ (CDEvent *)eventWithIdentifier:(NSUInteger)identifier
							date:(NSDate *)date
							 URL:(NSURL *)URL
						   flags:(CDEventFlags)flags;

#pragma mark Init methods
/**
 * Returns an <code>CDEvent</code> object initialized with the given identifier, date, URL and flags.
 *
 * @param identifier The identifier of the the event.
 * @param date The date when the event occured.
 * @param URL The URL of the item the event concerns.
 * @param flags The flags of the event.
 * @return An <code>CDEvent</code> object initialized with the given identifier, date, URL and flags.
 * @see FSEventStreamEventFlags
 * @see eventWithIdentifier:date:URL:flags:
 *
 * @since 1.0.0
 */
- (id)initWithIdentifier:(NSUInteger)identifier
					date:(NSDate *)date
					 URL:(NSURL *)URL
				   flags:(CDEventFlags)flags;

@end
