//
//  FolderImageCache.m
//  Vienna
//
//  Created by Joshua Pore on 8/03/2015.
//  Copyright (c) 2015 The Vienna Project. All rights reserved.
//

#import "FolderImageCache.h"
#import "Preferences.h"
#import "StringExtensions.h"

@interface FolderImageCache ()
-(void)initFolderImagesArray;

@end


static FolderImageCache * _folderImageCache = nil;

@implementation FolderImageCache


/* defaultCache
 * Returns a pointer to the default cache. There is just one default cache
 * and we instantiate it if it doesn't exist.
 */
+(FolderImageCache *)defaultCache
{
    if (_folderImageCache == nil)
        _folderImageCache = [[FolderImageCache alloc] init];
    return _folderImageCache;
}

/* init
 * Init an instance of the folder image cache.
 */
-(instancetype)init
{
    if ((self = [super init]) != nil)
    {
        imagesCacheFolder = nil;
        initializedFolderImagesArray = NO;
        folderImagesArray = [[NSMutableDictionary alloc] init];
    }
    return self;
}

/* addImage
 * Add the specified image to the cache and save it to disk.
 */
-(void)addImage:(NSImage *)image forURL:(NSString *)baseURL
{
    // Add in memory
    [self initFolderImagesArray];
    folderImagesArray[baseURL] = image;
    
    // Save icon to disk here.
    if (imagesCacheFolder != nil)
    {
        NSString * fullFilePath = [[imagesCacheFolder stringByAppendingPathComponent:baseURL] stringByAppendingPathExtension:@"tiff"];
        NSData *imageData = nil;
        @try {
            imageData = image.TIFFRepresentation;
        }
        @catch (NSException *error) {
            imageData = nil;
            NSLog(@"tiff exception with %@", fullFilePath);
        }
        if (imageData != nil)
            [[NSFileManager defaultManager] createFileAtPath:fullFilePath contents:imageData attributes:nil];
    }
}

/* retrieveImage
 * Retrieve the image for the specified URL from the cache.
 */
-(NSImage *)retrieveImage:(NSString *)baseURL
{
    [self initFolderImagesArray];
    return folderImagesArray[baseURL];
}

/* initFolderImagesArray
 * Load the existing list of folder images from the designated folder image cache. We
 * do this only once and we do it as quickly as possible. When we're done, the folderImagesArray
 * will be filled with image representations for each valid image file we find in the cache.
 */
-(void)initFolderImagesArray
{
    if (!initializedFolderImagesArray)
    {
        NSFileManager * fileManager = [NSFileManager defaultManager];
        NSArray * listOfFiles;
        BOOL isDir;
        
        // Get and cache the path to the folder. This is the best time to make sure it
        // exists. The penalty for it not existing AND us being unable to create it is that
        // we don't cache folder icons in this session.
        imagesCacheFolder = [Preferences standardPreferences].imagesFolder;
        if (![fileManager fileExistsAtPath:imagesCacheFolder isDirectory:&isDir])
        {
            if (![fileManager createDirectoryAtPath:imagesCacheFolder withIntermediateDirectories:YES attributes:nil error:nil])
            {
                NSLog(@"Cannot create image cache at %@. Will not cache folder images in this session.", imagesCacheFolder);
                imagesCacheFolder = nil;
            }
            initializedFolderImagesArray = YES;
            return;
        }
        
        if (!isDir)
        {
            NSLog(@"The file at %@ is not a directory. Will not cache folder images in this session.", imagesCacheFolder);
            imagesCacheFolder = nil;
            initializedFolderImagesArray = YES;
            return;
        }
        
        // Remember - not every file we find may be a valid image file. We use the filename as
        // the key but check the extension too.
        listOfFiles = [fileManager contentsOfDirectoryAtPath:imagesCacheFolder error:nil];
        if (listOfFiles != nil)
        {
            NSString * fileName;
            
            for (fileName in listOfFiles)
            {
                if ([fileName.pathExtension isEqualToString:@"tiff"])
                {
                    NSString * fullPath = [imagesCacheFolder stringByAppendingPathComponent:fileName];
                    NSData * imageData = [fileManager contentsAtPath:fullPath];
                    NSImage * iconImage = [[NSImage alloc] initWithData:imageData];
                    if (iconImage.valid)
                    {
                        iconImage.size = NSMakeSize(16, 16);
                        NSString * homePageSiteRoot = (fullPath.lastPathComponent.stringByDeletingPathExtension).convertStringToValidPath;
                        folderImagesArray[homePageSiteRoot] = iconImage;
                    }
                }
            }
        }
        initializedFolderImagesArray = YES;
    }
}

@end
