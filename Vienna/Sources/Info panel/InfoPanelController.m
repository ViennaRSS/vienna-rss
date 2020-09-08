//
//  InfoPanelController.m
//  Vienna
//
//  Created by Steve on 4/21/06.
//  Copyright (c) 2004-2006 Steve Palmer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "InfoPanelController.h"

#import "Database.h"
#import "DateFormatterExtension.h"
#import "Folder.h"
#import "StringExtensions.h"

@interface InfoPanelController () <NSWindowDelegate>

@property (weak, nonatomic) IBOutlet NSTextField *folderName;
@property (weak, nonatomic) IBOutlet NSTextField *lastRefreshDate;
@property (weak, nonatomic) IBOutlet NSImageView * folderImage;
@property (weak, nonatomic) IBOutlet NSTextField * urlField;
@property (weak, nonatomic) IBOutlet NSTextField * username;
@property (weak, nonatomic) IBOutlet NSSecureTextField * password;
@property (weak, nonatomic) IBOutlet NSTextField * folderSize;
@property (weak, nonatomic) IBOutlet NSTextField * folderUnread;
@property (weak, nonatomic) IBOutlet NSButton * isSubscribed;
@property (weak, nonatomic) IBOutlet NSButton * loadFullHTML;
@property (weak, nonatomic) IBOutlet NSTextField * folderDescription;
@property (weak, nonatomic) IBOutlet NSButton * validateButton;
@property (nonatomic) NSInteger infoFolderId;

@property (weak, nonatomic) IBOutlet NSButton *openCachedFileButton;
@property (nonatomic) NSString *cachedFile;

@end

@implementation InfoPanelController

// MARK: Initialization

- (instancetype)initWithFolder:(NSInteger)folderId {
    if (self = [super initWithWindowNibName:@"InfoWindow"]) {
		_infoFolderId = folderId;

        Database *database = [Database sharedManager];
        _cachedFile = [database folderFromID:_infoFolderId].feedSourceFilePath;
    }

	return self;
}

- (void)dealloc {
	[NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)awakeFromNib {
	[self updateFolder];
	[self enableValidateButton];
	self.window.initialFirstResponder = self.urlField;
	self.window.delegate = self;

	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleUrlTextDidChange:) name:NSControlTextDidChangeNotification object:self.urlField];
	[nc addObserver:self selector:@selector(handleFolderNameTextDidChange:) name:NSControlTextDidChangeNotification object:self.folderName];
	[self.folderName setEditable:YES];

    // Check if the source file exists. If not, disable the button.
    NSFileManager *fileManager = NSFileManager.defaultManager;
    self.openCachedFileButton.enabled = [fileManager fileExistsAtPath:self.cachedFile];
}

/* updateFolder
 * Update the folder info in response to changes on the folder itself.
 */
-(void)updateFolder
{
	Folder * folder = [[Database sharedManager] folderFromID:self.infoFolderId];
	
	// Set the window caption
	NSString * caption = [NSString stringWithFormat:NSLocalizedString(@"%@ Info", nil), folder.name];
	self.window.title = caption;

	// Set the header details
	self.folderName.stringValue = folder.name;
	self.folderImage.image = folder.image; 
	if ([folder.lastUpdate isEqualToDate:[NSDate distantPast]])
		[self.lastRefreshDate setStringValue:NSLocalizedString(@"Never", nil)];
	else
        self.lastRefreshDate.stringValue = [NSDateFormatter relativeDateStringFromDate:folder.lastUpdate];

	// Fill out the panels
	self.urlField.stringValue = folder.feedURL;
	self.username.stringValue = folder.username;
	self.password.stringValue = folder.password;
	// for Google feeds, URL may not be changed and no authentication is supported
	if (folder.type == VNAFolderTypeOpenReader) {
		//[urlField setSelectable:NO];
		[self.urlField setEditable:NO];
		self.urlField.textColor = [NSColor disabledControlTextColor];
		[self.username setEditable:NO];
		self.username.textColor = [NSColor disabledControlTextColor];
		[self.password setEditable:NO];
		self.password.textColor = [NSColor disabledControlTextColor];
	}
	self.folderDescription.stringValue = folder.feedDescription;
	self.folderSize.stringValue = [NSString stringWithFormat:NSLocalizedString(@"%u articles", nil), (unsigned int)MAX(0, [folder countOfCachedArticles])];
	self.folderUnread.stringValue = [NSString stringWithFormat:NSLocalizedString(@"%u unread", nil), (unsigned int)folder.unreadCount];
	self.isSubscribed.state = (folder.flags & VNAFolderFlagUnsubscribed) ? NSControlStateValueOff : NSControlStateValueOn;
	self.loadFullHTML.state = (folder.flags & VNAFolderFlagLoadFullHTML) ? NSControlStateValueOn : NSControlStateValueOff;
}

/* urlFieldChanged
 * Called when the URL field is changed.
 */
-(IBAction)urlFieldChanged:(id)sender
{
	NSString * newUrl = self.urlField.stringValue.trim;
    [[Database sharedManager] setFeedURL:newUrl forFolder:self.infoFolderId];
}

/* subscribedChanged
 * Called when the subscribe button is changed.
 */
-(IBAction)subscribedChanged:(id)sender
{
    if (self.isSubscribed.state == NSControlStateValueOn) {
        [[Database sharedManager] clearFlag:VNAFolderFlagUnsubscribed forFolder:self.infoFolderId];
    }
    else {
		[[Database sharedManager] setFlag:VNAFolderFlagUnsubscribed forFolder:self.infoFolderId];
    }
}

/* loadFullHTMLChanged
 * Called when the loadFullHTML button is changed.
 */
-(IBAction)loadFullHTMLChanged:(id)sender
{
    if (self.loadFullHTML.state == NSControlStateValueOn) {
        [[Database sharedManager] setFlag:VNAFolderFlagLoadFullHTML forFolder:self.infoFolderId];
    }
    else {
		[[Database sharedManager] clearFlag:VNAFolderFlagLoadFullHTML forFolder:self.infoFolderId];
    }
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_LoadFullHTMLChange"
                                                        object:@(self.infoFolderId)];
}

/* handleUrlTextDidChange [delegate]
 * This function is called when the contents of the url field is changed.
 * We disable the Subscribe button if the input fields are empty or enable it otherwise.
 */
-(void)handleUrlTextDidChange:(NSNotification *)aNotification
{
	[self enableValidateButton];
}

/* handleFolderNameTextDidChange [delegate]
 * This function is called when the contents of the folder name field is changed.
 * We update the folder's name.
 */
-(void)handleFolderNameTextDidChange:(NSNotification *)aNotification
{
    [[Database sharedManager] setName:self.folderName.stringValue forFolder:self.infoFolderId];
}

/* enableValidateButton
 * Disable the Validate button if the URL field is empty.
 */
-(void)enableValidateButton
{
	self.validateButton.enabled = !self.urlField.stringValue.blank;
}

/* validateURL
 * Validate the URL in the text field.
 */
- (IBAction)validateURL:(id)sender {
    NSString *validatorURL = @"https://validator.w3.org/feed/check.cgi";
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:validatorURL];

    NSString *validatedURL = self.urlField.stringValue.trim;
    NSCharacterSet *urlQuerySet = NSCharacterSet.URLQueryAllowedCharacterSet;
    NSString *encodedURL = [validatedURL stringByAddingPercentEncodingWithAllowedCharacters:urlQuerySet];

    // Override the text field's URL with the encoded one.
    self.urlField.stringValue = encodedURL;

    // Create the query using the encoded URL.
    urlComponents.query = [NSString stringWithFormat:@"url=%@", encodedURL];

    if (self.delegate) {
        [self.delegate infoPanelControllerWillOpenURL:urlComponents.URL];
    } else {
        // For sake of completion, open the URL with the default browser if
        // no delegate is set.
        [NSWorkspace.sharedWorkspace openURL:urlComponents.URL];
    }
}

/* authenticationChanged
 * Update the authentication information for this feed when the Update button is
 * clicked.
 */
-(IBAction)authenticationChanged:(id)sender
{
	NSString * usernameString = self.username.stringValue.trim;
	NSString * passwordString = self.password.stringValue;
	
	Database * db = [Database sharedManager];
	Folder * folder = [db folderFromID:self.infoFolderId];
	[db setFolderUsername:folder.itemId newUsername:usernameString];
	folder.password = passwordString;
}

/* windowShouldClose
 * Commit the window's current first responder before closing.
 */
- (BOOL)windowShouldClose:(id)sender
{
	// Set the first responder so any open edit fields get committed.
	[self.window makeFirstResponder:self.window];

	// Go ahead and close the window.
	return YES;
}

/*
 Opens the cached file of the feed using the default application associated
 with its type.
 */
- (IBAction)openCachedFile:(id)sender {
    [[NSWorkspace sharedWorkspace] openFile:self.cachedFile];
}

@end
