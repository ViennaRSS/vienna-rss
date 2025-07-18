//
//  FolderImageCache.m
//  Vienna
//
//  Created by Joshua Pore on 8/03/2015.
//  Copyright (c) 2015 The Vienna Project. All rights reserved.
//

#import "FolderImageCache.h"

@import UniformTypeIdentifiers;

#import "NSFileManager+Paths.h"
#import "StringExtensions.h"

@interface FolderImageCache ()

@property (nonatomic) NSURL *cacheDirectoryURL;

-(void)initFolderImagesArray;

@end

@implementation FolderImageCache {
    NSString *imagesCacheFolder;
    NSMutableDictionary *folderImagesArray;
    BOOL initializedFolderImagesArray;
}

/* defaultCache
 * Returns a pointer to the default cache. There is just one default cache
 * and we instantiate it if it doesn't exist.
 */
+ (FolderImageCache *)defaultCache
{
    static FolderImageCache *folderImageCache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        folderImageCache = [FolderImageCache new];
    });
    return folderImageCache;
}

/* init
 * Init an instance of the folder image cache.
 */
-(instancetype)init
{
    if ((self = [super init]) != nil) {
        imagesCacheFolder = nil;
        initializedFolderImagesArray = NO;
        folderImagesArray = [[NSMutableDictionary alloc] init];
    }
    return self;
}

/* cacheImageData:filename:
 * Add the specified image to the cache and save it to disk.
 */
- (BOOL)cacheImageData:(NSData *)imageData
              filename:(NSString *)filename
{
    [self initFolderImagesArray];

    // This method presumes that the imageData object represents an ICO file.
    // NSImage uses one or more NSImageRep instances to create the image. The
    // ICO format is a container for PNG and BMP, both of which are supported
    // by NSBitmapImageRep. An ICO file can comprise multiple images, similar
    // to TIFF, the target format for storage.
    NSImage *image = [[NSImage alloc] initWithData:imageData];
    if (!image) {
        return NO;
    }

    // macOS 15 does not handle images with indexed pixel samples correctly.
    // Those images have to be converted by applying the standard RGB color
    // space (sRGB) that is commonly used on the web.
    for (NSImageRep *rep in image.representations) {
        if (![rep isKindOfClass:[NSBitmapImageRep class]]) {
            continue;
        }
        NSBitmapImageRep *bitmapRep = (NSBitmapImageRep *)rep;
        // -bitmapImageRepByConvertingToColorSpace:renderingIntent: returns the
        // same bitmap image rep if the color space is the same.
        NSBitmapImageRep *convertedBitmapRep =
            [bitmapRep bitmapImageRepByConvertingToColorSpace:NSColorSpace.sRGBColorSpace
                                              renderingIntent:NSColorRenderingIntentDefault];
        if (convertedBitmapRep && ![convertedBitmapRep isEqual:bitmapRep]) {
            [image removeRepresentation:bitmapRep];
            [image addRepresentation:convertedBitmapRep];
        }
    }

    folderImagesArray[filename] = image;

    NSURL *url = nil;
    if (@available(macOS 11, *)) {
        url = [self.cacheDirectoryURL URLByAppendingPathComponent:filename
                                                 conformingToType:UTTypeTIFF];
    } else {
        url = [self.cacheDirectoryURL URLByAppendingPathComponent:filename
                                                      isDirectory:NO];
        url = [url URLByAppendingPathExtension:@"tiff"];
    }
    return [image.TIFFRepresentation writeToURL:url atomically:YES];
}

/* retrieveImage
 * Retrieve the image for the specified URL from the cache.
 */
- (nullable NSImage *)retrieveImage:(NSString *)filename
{
    [self initFolderImagesArray];
    return folderImagesArray[filename];
}

/* initFolderImagesArray
 * Load the existing list of folder images from the designated folder image cache. We
 * do this only once and we do it as quickly as possible. When we're done, the folderImagesArray
 * will be filled with image representations for each valid image file we find in the cache.
 */
-(void)initFolderImagesArray
{
    if (!initializedFolderImagesArray) {
        NSFileManager * fileManager = [NSFileManager defaultManager];
        NSArray * listOfFiles;
        BOOL isDir;
        
        // Get and cache the path to the folder. This is the best time to make sure it
        // exists. The penalty for it not existing AND us being unable to create it is that
        // we don't cache folder icons in this session.
        NSURL *appSupportURL = fileManager.vna_applicationSupportDirectory;
        NSURL *imagesURL = [appSupportURL URLByAppendingPathComponent:@"Images"
                                                          isDirectory:YES];
        self.cacheDirectoryURL = imagesURL;
        imagesCacheFolder = imagesURL.path;
        if (![fileManager fileExistsAtPath:imagesCacheFolder isDirectory:&isDir]) {
            if (![fileManager createDirectoryAtPath:imagesCacheFolder withIntermediateDirectories:YES attributes:nil error:nil]) {
                NSLog(@"Cannot create image cache at %@. Will not cache folder images in this session.", imagesCacheFolder);
                imagesCacheFolder = nil;
            }
            initializedFolderImagesArray = YES;
            return;
        }
        
        if (!isDir) {
            NSLog(@"The file at %@ is not a directory. Will not cache folder images in this session.", imagesCacheFolder);
            imagesCacheFolder = nil;
            initializedFolderImagesArray = YES;
            return;
        }
        
        // Remember - not every file we find may be a valid image file. We use the filename as
        // the key but check the extension too.
        listOfFiles = [fileManager contentsOfDirectoryAtPath:imagesCacheFolder error:nil];
        if (listOfFiles != nil) {
            NSString * fileName;
            
            for (fileName in listOfFiles) {
                if ([fileName.pathExtension isEqualToString:@"tiff"]) {
                    NSString * fullPath = [imagesCacheFolder stringByAppendingPathComponent:fileName];
                    NSData * imageData = [fileManager contentsAtPath:fullPath];
                    NSImage * iconImage = [[NSImage alloc] initWithData:imageData];
                    if (iconImage.isValid) {
                        NSString * homePageSiteRoot = (fullPath.lastPathComponent.stringByDeletingPathExtension).vna_convertStringToValidPath;
                        folderImagesArray[homePageSiteRoot] = iconImage;
                    }
                }
            }
        }
        initializedFolderImagesArray = YES;
    }
}

@end
