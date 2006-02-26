//
//  MacPADSocket.m
//  MacPAD Version Check
//
//  Created by Kevin Ballard on Sun Dec 07 2003.
//  Copyright (c) 2003-2004 TildeSoft. All rights reserved.
//

#import "MacPADSocket.h"

// Constant strings
NSString *MacPADErrorCode = @"MacPADErrorCode";
NSString *MacPADErrorMessage = @"MacPADErrorMessage";
NSString *MacPADNewVersionAvailable = @"MacPADNewVersionAvailable";

// NSNotifications
NSString *MacPADErrorOccurredNotification = @"MacPADErrorOccurredNotification";
NSString *MacPADCheckFinishedNotification = @"MacPADCheckFinishedNotification";

enum {
    kNumberType,
    kStringType,
    kPeriodType
};

@implementation MacPADSocket

// Code
-(id)init
{
    if ((self = [super init]) != nil) {
        _fileHandle = nil;
        _fileURL = nil;
        _currentVersion = nil;
        _newVersion = nil;
        _releaseNotes = nil;
        _productPageURL = nil;
        _productDownloadURLs = nil;
        _buffer = nil;
    }
    return self;
}

-(void)initiateCheck:(id)sender;
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfURL:_fileURL];
    [self processDictionary:dict];
    [pool release];
}

-(void)performCheck:(NSURL *)url withVersion:(NSString *)version
{
    // Make sure we were actually *given* stuff
    if (url == nil || version == nil) {
        // Bah
        [self returnError:kMacPADResultMissingValues message:@"URL or version was nil"];
        return;
    }
    
    // Save the current version and URL
    [_currentVersion release];
    _currentVersion = [version copy];
    [_fileURL release];
    _fileURL = [url copy];
    
    [NSThread detachNewThreadSelector:@selector(initiateCheck:) toTarget:self withObject:nil];
    
    /*NSNumber *port = [url port];
    if (port == nil) {
        // No port information? Default to 80 - it's http!
        port = [NSNumber numberWithInt:80];
    }
    NSString *host = [url host];
    if (host == nil) {
        // Not a valid URL? Error out
        [self returnError:kMacPADResultInvalidURL message:@"Invalid URL"];
        return;
    }
    NSString *path = [url path];
    if (path == nil || [path isEqualToString:@""]) {
        path = @"/";
    }
    
    NSSocketPort *socketPort = [[NSSocketPort alloc] initRemoteWithTCPPort:[port intValue] host:host];
    if ([socketPort address] == nil) {
        // The URL isn't valid
        [self returnError:kMacPADResultInvalidURL message:@"Couldn't resolve remote host address"];
        return;
    }
    struct sockaddr *address = (struct sockaddr *)[[socketPort address] bytes];
    [socketPort release];
    int remoteSocket = socket(address->sa_family, SOCK_STREAM, 0);
    
    if (connect(remoteSocket, address, address->sa_len) != 0) {
        // Couldn't connect
        close(remoteSocket);
        [self returnError:kMacPADResultInvalidURL message:@"Couldn't connect to remote host"];
        return;
    }
    
    // In case we tried to check during a check, we should release the old filehandle and unregister
    // ourselves with the notification center
    [_fileHandle release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:remoteSocket closeOnDealloc:YES];
    
    // Now that we have our socket, lets make our request.
    // It's just a simple GET statement.
    NSString *data = [NSString stringWithFormat:@"GET %@ HTTP/1.1\r\nHost: %@\r\n\r\n", path, host];
    [_fileHandle writeData:[data dataUsingEncoding:NSASCIIStringEncoding]];
    
    // Init a couple of variables
    // Releasing the strings shouldn't be necessary, but what if someone
    // re-uses a socket? We don't want to leave extra strings hanging about
    _contentLength = 0;
    _headersReceived = NO;
    _statusReceived = NO;
    [_newVersion release];
    _newVersion = nil;
    [_releaseNotes release];
    _releaseNotes = nil;
    [_productPageURL release];
    _productPageURL = nil;
    [_productDownloadURLs release];
    _productDownloadURLs = nil;
    [_buffer release];
    _buffer = [[NSMutableString alloc] init];
    
    // Now lets start listening for the response
    // First we have to register ourselves with the notification center
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processData:)
                                                 name:NSFileHandleReadCompletionNotification object:_fileHandle];
    [_fileHandle readInBackgroundAndNotify];*/
}

-(void)performCheckWithVersion:(NSString *)version
{
    // This method makes use of the MacPAD.url file inside the application bundle
    // If this file isn't there, or it's not in the correct format, this will return
    // error kMacPADResultMissingValues with an appropriate message
    // If it is there, it calls performCheck:withVersion: with the URL
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MacPAD" ofType:@"url"];
    if (path == nil) {
        // File is missing
        [self returnError:kMacPADResultMissingValues message:@"MacPAD.url file was not found"];
        return;
    }
    NSString *contents = [NSString stringWithContentsOfFile:path];
    if (contents == nil) {
        // The file can't be opened
        [self returnError:kMacPADResultMissingValues message:@"The MacPAD.url file can't be opened"];
        return;
    }
    
    NSString *urlString;
    NSRange range = [contents rangeOfString:@"URL="];
    if (range.location != NSNotFound) {
        // We have a URL= prefix
        range.location += range.length;
        range.length = [contents length] - range.location;
        urlString = [contents substringWithRange:range];
    } else {
        // The file is the URL
        urlString = contents;
    }
    // Strip whitespace
    urlString = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // Perform the check
    [self performCheck:[NSURL URLWithString:urlString] withVersion:version];
}

-(void)performCheckWithURL:(NSURL *)url
{
    // Gets the version from the Info.plist file and calls performCheck:withVersion:
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    [self performCheck:url withVersion:version];
}

-(void)performCheck
{
    // Gets the version from the Info.plist file and calls performCheckWithVersion:
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    [self performCheckWithVersion:version];
}

-(void)setDelegate:(id)delegate
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    if (_delegate != nil) {
        // Unregister with the notification center
        [nc removeObserver:_delegate name:MacPADErrorOccurredNotification object:self];
        [nc removeObserver:_delegate name:MacPADCheckFinishedNotification object:self];
        [_delegate autorelease];
    }
    _delegate = [delegate retain];
    // Register the new MacPADSocketNotification methods for the delegate
    // Only register if the delegate implements it, though
    if ([_delegate respondsToSelector:@selector(macPADErrorOccurred:)]) {
        [nc addObserver:_delegate selector:@selector(macPADErrorOccurred:)
                          name:MacPADErrorOccurredNotification object:self];
    }
    if ([_delegate respondsToSelector:@selector(macPADCheckFinished:)]) {
        [nc addObserver:_delegate selector:@selector(macPADCheckFinished:)
                          name:MacPADCheckFinishedNotification object:self];
    }
}

-(NSString *)releaseNotes
{
    if (_releaseNotes == nil) {
        return @"";
    } else {
        return [[_releaseNotes copy] autorelease];
    }
}

-(NSString *)newVersion
{
    if (_newVersion == nil) {
        return @"";
    } else {
        return [[_newVersion copy] autorelease];
    }
}

-(NSString *)productPageURL
{
    if (_productPageURL == nil) {
        return @"";
    } else {
        return [[_productPageURL copy] autorelease];
    }
}

-(NSString *)productDownloadURL
{
    if (_productDownloadURLs != nil && [_productDownloadURLs count] >= 1) {
        return [_productDownloadURLs objectAtIndex:0];
    } else {
        return @"";
    }
}

-(NSArray *)productDownloadURLs
{
    if (_productDownloadURLs == nil) {
        return [NSArray array];
    } else {
        return [[_productDownloadURLs copy] autorelease];
    }
}

-(void)returnError:(MacPADResultCode)code message:(NSString *)msg
{
    NSNumber *yesno = [NSNumber numberWithBool:(code == kMacPADResultNewVersion)];
    NSNumber *errorCode = [NSNumber numberWithInt:code];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:yesno, MacPADNewVersionAvailable,
                                                msg, MacPADErrorMessage, errorCode, MacPADErrorCode, nil];
    if (code == 0 || code == 5) {
        // Not an error
        [self performSelectorOnMainThread:@selector(returnSuccess:) withObject:userInfo waitUntilDone:NO];
    } else {
        // It's an error
        [self performSelectorOnMainThread:@selector(returnFailure:) withObject:userInfo waitUntilDone:NO];
    }
}

-(void)returnSuccess:(NSDictionary *)userInfo
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MacPADCheckFinishedNotification
                                                        object:self userInfo:userInfo];
}

-(void)returnFailure:(NSDictionary *)userInfo
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MacPADErrorOccurredNotification
                                                        object:self userInfo:userInfo];
}

-(void)processDictionary:(NSDictionary *)dict
{
    if (dict == nil) {
        [self returnError:kMacPADResultInvalidURL message:@"Remote file or URL was invalid"];
        return;
    }
    
    _newVersion = [[dict objectForKey:@"productVersion"] copy];
    if (_newVersion == nil) {
        // File is missing version information
        [self returnError:kMacPADResultBadSyntax message:@"Product version information missing"];
        return;
    }
    
    // Get release notes
    _releaseNotes = [[dict objectForKey:@"productReleaseNotes"] copy];
    
    // Get product page URL
    _productPageURL = [[dict objectForKey:@"productPageURL"] copy];
    
    // Get the first product download URL
    _productDownloadURLs = [[dict objectForKey:@"productDownloadURL"] copy];
    
    // Compare versions
    if ([self compareVersion:_newVersion toVersion:_currentVersion] == NSOrderedAscending) {
        // It's a new version
        [self returnError:kMacPADResultNewVersion message:@"New version available"];
    } else {
        [self returnError:kMacPADResultNoNewVersion message:@"No new version available"];
    }
    
    // We're done
}

-(void)dealloc
{
    // Unregister the delegate with the notification center
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:_delegate name:MacPADErrorOccurredNotification object:self];
    [nc removeObserver:_delegate name:MacPADCheckFinishedNotification object:self];
    [nc removeObserver:self];
    
    // Release objects
    [_delegate release];
    [_fileHandle release];
    [_currentVersion release];
    [_buffer release];
    [_newVersion release];
    [_releaseNotes release];
    [_productPageURL release];
    [_productDownloadURLs release];
    
    [super dealloc];
}

-(NSComparisonResult)compareVersion:(NSString *)versionA toVersion:(NSString *)versionB
{
    NSArray *partsA = [self splitVersion:versionA];
    NSArray *partsB = [self splitVersion:versionB];
    
    NSString *partA, *partB;
    int i, n, typeA, typeB, intA, intB;
    
    n = MIN([partsA count], [partsB count]);
    for (i = 0; i < n; ++i) {
        partA = [partsA objectAtIndex:i];
        partB = [partsB objectAtIndex:i];
        
        typeA = [self getCharType:partA];
        typeB = [self getCharType:partB];
        
        // Compare types
        if (typeA == typeB) {
            // Same type; we can compare
            if (typeA == kNumberType) {
                intA = [partA intValue];
                intB = [partB intValue];
                if (intA > intB) {
                    return NSOrderedAscending;
                } else if (intA < intB) {
                    return NSOrderedDescending;
                }
            } else if (typeA == kStringType) {
                NSComparisonResult result = [partA compare:partB];
                if (result != NSOrderedSame) {
                    return result;
                }
            }
        } else {
            // Not the same type? Now we have to do some validity checking
            if (typeA != kStringType && typeB == kStringType) {
                // typeA wins
                return NSOrderedAscending;
            } else if (typeA == kStringType && typeB != kStringType) {
                // typeB wins
                return NSOrderedDescending;
            } else {
                // One is a number and the other is a period. The period is invalid
                if (typeA == kNumberType) {
                    return NSOrderedAscending;
                } else {
                    return NSOrderedDescending;
                }
            }
        }
    }
    // The versions are equal up to the point where they both still have parts
    // Lets check to see if one is larger than the other
    if ([partsA count] != [partsB count]) {
        // Yep. Lets get the next part of the larger
        // n holds the value we want
        NSString *missingPart;
        int missingType, shorterResult, largerResult;
        
        if ([partsA count] > [partsB count]) {
            missingPart = [partsA objectAtIndex:n];
            shorterResult = NSOrderedDescending;
            largerResult = NSOrderedAscending;
        } else {
            missingPart = [partsB objectAtIndex:n];
            shorterResult = NSOrderedAscending;
            largerResult = NSOrderedDescending;
        }
        
        missingType = [self getCharType:missingPart];
        // Check the type
        if (missingType == kStringType) {
            // It's a string. Shorter version wins
            return shorterResult;
        } else {
            // It's a number/period. Larger version wins
            return largerResult;
        }
    }
    
    // The 2 strings are identical
    return NSOrderedSame;
}

-(NSArray *)splitVersion:(NSString *)version
{
    NSString *character;
    NSMutableString *s;
    int i, n, oldType, newType;
    NSMutableArray *parts = [NSMutableArray array];
    if ([version length] == 0) {
        // Nothing to do here
        return parts;
    }
    s = [[[version substringToIndex:1] mutableCopy] autorelease];
    oldType = [self getCharType:s];
    n = [version length] - 1;
    for (i = 1; i <= n; ++i) {
        character = [version substringWithRange:NSMakeRange(i, 1)];
        newType = [self getCharType:character];
        if (oldType != newType || oldType == kPeriodType) {
            // We've reached a new segment
            [parts addObject:[s copy]];
            [s setString:character];
        } else {
            // Add character to string and continue
            [s appendString:character];
        }
        oldType = newType;
    }
    
    // Add the last part onto the array
    [parts addObject:[s copy]];
    return parts;
}

-(int)getCharType:(NSString *)character
{
    if ([character isEqualToString:@"."]) {
        return kPeriodType;
    } else if ([character isEqualToString:@"0"] || [character intValue] != 0) {
        return kNumberType;
    } else {
        return kStringType;
    }
}
@end
