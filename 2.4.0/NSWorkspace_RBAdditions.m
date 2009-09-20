//
//  NSWorkspace_RBAdditions.m
//  PathProps
//
//  Created by Rainer Brockerhoff on 10/04/2007.
//  Copyright 2007 Rainer Brockerhoff. All rights reserved.
//

#import "NSWorkspace_RBAdditions.h"
#include <IOKit/IOKitLib.h>
#include <sys/mount.h>

NSString* NSWorkspace_RBfstypename = @"NSWorkspace_RBfstypename";
NSString* NSWorkspace_RBmntonname = @"NSWorkspace_RBmntonname";
NSString* NSWorkspace_RBmntfromname = @"NSWorkspace_RBmntfromname";
NSString* NSWorkspace_RBdeviceinfo = @"NSWorkspace_RBdeviceinfo";
NSString* NSWorkspace_RBimagefilepath = @"NSWorkspace_RBimagefilepath";
NSString* NSWorkspace_RBconnectiontype = @"NSWorkspace_RBconnectiontype";
NSString* NSWorkspace_RBpartitionscheme = @"NSWorkspace_RBpartitionscheme";
NSString* NSWorkspace_RBserverURL = @"NSWorkspace_RBserverURL";

// This static funtion concatenates two strings, but first checks several possibilities...
// like one or the other nil, or one containing the other already.

static NSString* AddPart(NSString* first,NSString* second) {
	if (!second) {
		return first;
	}
	second = [second stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (first) {
		if ([first rangeOfString:second options:NSCaseInsensitiveSearch].location==NSNotFound) {
			if ([second rangeOfString:first options:NSCaseInsensitiveSearch].location==NSNotFound) {
				return [NSString stringWithFormat:@"%@; %@",first,second];
			}
			return second;
		}
		return first;
	}
	return second;
}

// This static functions recurses "upwards" over the IO registry. Returns strings that are concatenated
// and ultimately end up under the NSWorkspace_RBdeviceinfo key.
// This isn't too robust in that it assumes that objects returned by the objectForKey methods are
// either strings or dictionaries. A "standard" implementations would use either only CoreFoundation and
// IOKit calls for this, or do more robust type checking on the returned objects.
//
// Also notice that this works as determined experimentally in 10.4.9, there's no official docs I could find.
// YMMV, and it may stop working in any new version of Mac OS X.

static NSString* CheckParents(io_object_t thing,NSString* part,NSMutableDictionary* dict) {
	NSString* result = part;
    io_iterator_t parentsIterator = 0;
    kern_return_t kernResult = IORegistryEntryGetParentIterator(thing,kIOServicePlane,&parentsIterator);
    if ((kernResult==KERN_SUCCESS)&&parentsIterator) {
		io_object_t nextParent = 0;
		while ((nextParent = IOIteratorNext(parentsIterator))) {
			NSDictionary* props = nil;
			NSString* image = nil;
			NSString* partition = nil;
			NSString* connection = nil;
			kernResult = IORegistryEntryCreateCFProperties(nextParent,(CFMutableDictionaryRef*)&props,kCFAllocatorDefault,0);
			if (IOObjectConformsTo(nextParent,"IOApplePartitionScheme")) {
				partition = [props objectForKey:@"Content Mask"];
			} else if (IOObjectConformsTo(nextParent,"IOMedia")) {
				partition = [props objectForKey:@"Content"];
			} else if (IOObjectConformsTo(nextParent,"IODiskImageBlockStorageDeviceOutKernel")) {
				NSData* data = nil;
				if ((data = [[props objectForKey:@"Protocol Characteristics"] objectForKey:@"Virtual Interface Location Path"])) {
					image = [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding] autorelease];
				}
			} else if (IOObjectConformsTo(nextParent,"IOHDIXHDDriveInKernel")) {
				image = [props objectForKey:@"KDIURLPath"];
			}
			NSDictionary* subdict;
			if ((subdict = [props objectForKey:@"Protocol Characteristics"])) {
				connection = [subdict objectForKey:@"Physical Interconnect"];
			} else {
				connection = [props objectForKey:@"Physical Interconnect"];
			}
			if (connection) {
				[dict setObject:AddPart([dict objectForKey:NSWorkspace_RBconnectiontype],connection) forKey:NSWorkspace_RBconnectiontype];
			}
			if (partition) {
				[dict setObject:partition forKey:NSWorkspace_RBpartitionscheme];
			}
			if (image) {
				[dict setObject:image forKey:NSWorkspace_RBimagefilepath];
			}
			NSString* value;
			if ((subdict = [props objectForKey:@"Device Characteristics"])) {
				if ((value = [subdict objectForKey:@"Product Name"])) {
					result = AddPart(result,value);
				}
				if ((value = [subdict objectForKey:@"Product Revision Level"])) {
					result = AddPart(result,value);
				}
				if ((value = [subdict objectForKey:@"Vendor Name"])) {
					result = AddPart(result,value);
				}
			}
			if ((value = [props objectForKey:@"USB Serial Number"])) {
				result = AddPart(result,value);
			}
			if ((value = [props objectForKey:@"USB Vendor Name"])) {
				result = AddPart(result,value);
			}
			NSString* cls = [(NSString*)IOObjectCopyClass(nextParent) autorelease];
			if (![cls isEqualToString:@"IOPCIDevice"]) {
			
// Uncomment the following line to have the device tree dumped to the console.
//				NSLog(@"=================================> %@:%@\n",cls,props);

				result = CheckParents(nextParent,result,dict);
			}
			IOObjectRelease(nextParent);
		}
    }
    if (parentsIterator) {
		IOObjectRelease(parentsIterator);
    }
	return result;
}

// This formats the (partially undocumented) AFPXMountInfo info into a string.

__attribute__((unused))
static NSString* FormatAFPURL(AFPXVolMountInfoPtr mountInfo,NSString** devdesc) {
	UInt8* work = ((UInt8*)mountInfo)+mountInfo->serverNameOffset;
	if (devdesc) {
		*devdesc = [[[NSString alloc] initWithBytes:&work[1] length:work[0] encoding:NSUTF8StringEncoding] autorelease];
	}
	work = ((UInt8*)mountInfo)+mountInfo->volNameOffset;
	NSString* volname = [[[NSString alloc] initWithBytes:&work[1] length:work[0] encoding:NSUTF8StringEncoding] autorelease];
	work = ((UInt8*)mountInfo)+mountInfo->alternateAddressOffset;
	AFPAlternateAddress* afpa = (AFPAlternateAddress*)work;
	AFPTagData* afpta = (AFPTagData*)(&afpa->fAddressList);
	NSString* ip = nil;
	NSString* dns = nil;
	int i = afpa->fAddressCount;
	while ((i-->0)) {
		switch (afpta->fType) {
			case kAFPTagTypeIP:
				if (!ip) {
					ip = [[[NSString alloc] initWithBytes:&afpta->fData[0] length:afpta->fLength-2 encoding:NSUTF8StringEncoding] autorelease];
				}
				break;
			case kAFPTagTypeIPPort:
				ip = [NSString stringWithFormat:@"%u.%u.%u.%u:%u",afpta->fData[0],afpta->fData[1],afpta->fData[2],afpta->fData[3],OSSwapBigToHostInt16(*(UInt16*)&afpta->fData[4])];
				break;
			case kAFPTagTypeDNS:
				dns = [[[NSString alloc] initWithBytes:&afpta->fData[0] length:afpta->fLength-2 encoding:NSUTF8StringEncoding] autorelease];
				break;
			case 0x07:
				ip = [NSString stringWithFormat:@"[%x:%x:%x:%x:%x:%x:%x:%x]",OSSwapBigToHostInt16(*(UInt16*)&afpta->fData[0]),
					OSSwapBigToHostInt16(*(UInt16*)&afpta->fData[2]),OSSwapBigToHostInt16(*(UInt16*)&afpta->fData[4]),
					OSSwapBigToHostInt16(*(UInt16*)&afpta->fData[6]),OSSwapBigToHostInt16(*(UInt16*)&afpta->fData[8]),
					OSSwapBigToHostInt16(*(UInt16*)&afpta->fData[10]),OSSwapBigToHostInt16(*(UInt16*)&afpta->fData[12]),
					OSSwapBigToHostInt16(*(UInt16*)&afpta->fData[14])];
				break;
		}
		afpta = (AFPTagData*)((char*)afpta+afpta->fLength);
	}
	return [NSString stringWithFormat:@"afp://%@/%@",dns?:(ip?:@""),volname];
}

@implementation NSWorkspace (NSWorkspace_RBAdditions)

// Returns a NSDictionary with properties for the path. See details in the .h file.
// This assumes that the length of path is less than PATH_MAX (currently 1024 characters).

- (NSDictionary*)propertiesForPath:(NSString*)path {
	const char* ccpath = (const char*)[path fileSystemRepresentation];
	NSMutableDictionary* result = nil;
	struct statfs fs;
	if (!statfs(ccpath,&fs)) {
		NSString* from = [NSString stringWithUTF8String:fs.f_mntfromname];
		result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			[NSString stringWithUTF8String:fs.f_fstypename],NSWorkspace_RBfstypename,
			[NSString stringWithUTF8String:fs.f_mntonname],NSWorkspace_RBmntonname,
			nil];
		if (strncmp(fs.f_mntfromname,"/dev/",5)==0) {
// For a local volume,get the IO registry tree and search it for further info.
			mach_port_t masterPort = 0;
			io_iterator_t mediaIterator = 0;
			kern_return_t kernResult = IOMasterPort(bootstrap_port,&masterPort);
			if (kernResult==KERN_SUCCESS) {
				CFMutableDictionaryRef classesToMatch = IOBSDNameMatching(masterPort,0,&fs.f_mntfromname[5]);
				if (classesToMatch) {
					kernResult = IOServiceGetMatchingServices(masterPort,classesToMatch,&mediaIterator);
					if ((kernResult==KERN_SUCCESS)&&mediaIterator) {
						io_object_t firstMedia = 0;
						while ((firstMedia = IOIteratorNext(mediaIterator))) {
							NSString* stuff = CheckParents(firstMedia,nil,result);
							if (stuff) {
								[result setObject:stuff forKey:NSWorkspace_RBdeviceinfo];
							}
							IOObjectRelease(firstMedia);
						}
					}
				}
			}
			if (mediaIterator) {
				IOObjectRelease(mediaIterator);
			}
			if (masterPort) {
				mach_port_deallocate(mach_task_self(),masterPort);
			}
		}
		//Don't need this for disk images, gets around warnings for some deprecated functions
		
		/* else {
// For a network volume, get the volume reference number and use to get the server URL.
			FSRef ref;
			if (FSPathMakeRef((const UInt8*)ccpath,&ref,NULL)==noErr) {
				FSCatalogInfo info;
				if (FSGetCatalogInfo(&ref,kFSCatInfoVolume,&info,NULL,NULL,NULL)==noErr) {
					ParamBlockRec pb;
					UInt16 vmisize = 0;
					VolumeMountInfoHeaderPtr mountInfo = NULL;
					pb.ioParam.ioCompletion = NULL;
					pb.ioParam.ioNamePtr = NULL;
					pb.ioParam.ioVRefNum = info.volume;
					pb.ioParam.ioBuffer = (Ptr)&vmisize;
					pb.ioParam.ioReqCount = sizeof(vmisize);
					if ((PBGetVolMountInfoSize(&pb)==noErr)&&vmisize) {
						mountInfo = (VolumeMountInfoHeaderPtr)malloc(vmisize);
						if (mountInfo) {
							pb.ioParam.ioBuffer = (Ptr)mountInfo;
							pb.ioParam.ioReqCount = vmisize;
							if (PBGetVolMountInfo(&pb)==noErr) {
								NSString* url = nil;
								switch (mountInfo->media) {
								case AppleShareMediaType:
									url = FormatAFPURL((AFPXVolMountInfoPtr)mountInfo,&from);
									break;
								case 'http':
									url = from;
									break;
								case 'crbm':
								case 'nfs_':
								case 'cifs':
									url = [NSString stringWithUTF8String:(char*)mountInfo+sizeof(VolumeMountInfoHeader)+sizeof(OSType)];
									break;
								}
								if (url) {
									[result setObject:url forKey:NSWorkspace_RBserverURL];
								}
							}
						}
						free(mountInfo);
					}
				}
			}
		}*/
		[result setObject:from forKey:NSWorkspace_RBmntfromname];
	}
	return result;
}

@end
