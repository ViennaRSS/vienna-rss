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
 * @headerfile compat.h
 * FSEventStream flag compatibility shim
 *
 * In order to compile a binary against an older SDK yet still support the
 * features present in later OS releases, we need to define any missing enum
 * constants not present in the older SDK. This allows us to safely defer
 * feature detection to runtime (and avoid recompilation).
 */

#import <CoreServices/CoreServices.h>

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1060
// ignoring events originating from the current process introduced in 10.6
FSEventStreamCreateFlags kFSEventStreamCreateFlagIgnoreSelf = 0x00000008;
#endif

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1070
// file-level events introduced in 10.7
FSEventStreamCreateFlags kFSEventStreamCreateFlagFileEvents = 0x00000010;
FSEventStreamEventFlags kFSEventStreamEventFlagItemCreated = 0x00000100,
                        kFSEventStreamEventFlagItemRemoved = 0x00000200,
                        kFSEventStreamEventFlagItemInodeMetaMod = 0x00000400,
                        kFSEventStreamEventFlagItemRenamed = 0x00000800,
                        kFSEventStreamEventFlagItemModified = 0x00001000,
                        kFSEventStreamEventFlagItemFinderInfoMod = 0x00002000,
                        kFSEventStreamEventFlagItemChangeOwner = 0x00004000,
                        kFSEventStreamEventFlagItemXattrMod = 0x00008000,
                        kFSEventStreamEventFlagItemIsFile = 0x00010000,
                        kFSEventStreamEventFlagItemIsDir = 0x00020000,
                        kFSEventStreamEventFlagItemIsSymlink = 0x00040000;
#endif
