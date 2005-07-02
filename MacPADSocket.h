//
//  MacPADSocket.h
//  MacPAD Version Check
//
//  Created by Kevin Ballard on Sun Dec 07 2003.
//  Copyright (c) 2003-2004 TildeSoft. All rights reserved.
//

#import <Foundation/Foundation.h>

// Result codes
typedef enum MacPADResultCode {
    kMacPADResultNoNewVersion = 0,  // No new version available. Not an error
    kMacPADResultMissingValues,     // One or both arguments to performCheck: were nil
    kMacPADResultInvalidURL,        // URL was invalid or could not be contacted
    kMacPADResultInvalidFile,       // XML file was missing or not well-formed
    kMacPADResultBadSyntax,         // Version info was missing from XML file
    kMacPADResultNewVersion         // New version is available. Not an error
} MacPADResultCode;

@interface MacPADSocket : NSObject {
@private
    NSFileHandle    *_fileHandle;
    NSURL           *_fileURL;
    NSString        *_currentVersion;
    NSString        *_newVersion;
    NSString        *_releaseNotes;
    NSString        *_productPageURL;
    NSMutableString *_buffer;
    NSArray         *_productDownloadURLs;
    int             _contentLength;
    BOOL            _headersReceived;
    BOOL            _statusReceived;
    id              _delegate;
}
// Public methods
-(void)performCheck:(NSURL *)url withVersion:(NSString *)version;
-(void)performCheckWithVersion:(NSString *)version;
-(void)performCheckWithURL:(NSURL *)url;
-(void)performCheck;
-(void)setDelegate:(id)delegate;
-(NSString *)newVersion;
-(NSString *)releaseNotes;
-(NSString *)productPageURL;
-(NSString *)productDownloadURL;
-(NSArray *)productDownloadURLs;

// Private methods
-(void)initiateCheck:(id)sender;
-(void)returnError:(MacPADResultCode)code message:(NSString *)msg;
-(void)returnSuccess:(NSDictionary *)userInfo;
-(void)returnFailure:(NSDictionary *)userInfo;
-(void)processDictionary:(NSDictionary *)dict;
-(NSComparisonResult)compareVersion:(NSString *)versionA toVersion:(NSString *)versionB;
-(NSArray *)splitVersion:(NSString *)version;
-(int)getCharType:(NSString *)character;
@end

// Constant strings
extern NSString *MacPADErrorCode;
extern NSString *MacPADErrorMessage;
extern NSString *MacPADNewVersionAvailable;

// NSNotifications
extern NSString *MacPADErrorOccurredNotification; // @"MacPADErrorCode", @"MacPADErrorMessage"
extern NSString *MacPADCheckFinishedNotification; // @"MacPADNewVersionAvailable"

@interface NSObject(MacPADSocketNotifications)
-(void)macPADErrorOccurred:(NSNotification *)aNotification;
-(void)macPADCheckFinished:(NSNotification *)aNotification;
@end