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
@property (nonatomic) NSMutableDictionary<NSString *, NSImage *> *folderImages;

@end

@implementation FolderImageCache

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

- (NSURL *)cacheDirectoryURL
{
    if (!_cacheDirectoryURL) {
        NSFileManager *fileManager = NSFileManager.defaultManager;
        NSURL *appSupportURL = fileManager.vna_applicationSupportDirectory;
        NSURL *imagesURL = [appSupportURL URLByAppendingPathComponent:@"Images"
                                                          isDirectory:YES];
        _cacheDirectoryURL = imagesURL;
    }
    return _cacheDirectoryURL;
}

// Load the existing list of folder images from the designated folder image
// cache. We do this only once and we do it as quickly as possible. When we're
// done, the folderImages dictionary will be filled with image representations
// for each valid image file we find in the cache.
- (NSMutableDictionary<NSString *, NSImage *> *)folderImages
{
    if (_folderImages) {
        return _folderImages;
    }

    NSFileManager *fileManager = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    NSString *cacheDirectoryPath = self.cacheDirectoryURL.path;
    if (![fileManager fileExistsAtPath:cacheDirectoryPath
                           isDirectory:&isDirectory]) {
        if (![fileManager createDirectoryAtPath:cacheDirectoryPath
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:NULL]) {
            NSLog(@"Cannot create image cache at %@. Will not cache folder images in this session.",
                  cacheDirectoryPath);
        }
        _folderImages = [[NSMutableDictionary alloc] init];
        return _folderImages;
    }
    if (!isDirectory) {
        NSLog(@"The file at %@ is not a directory. Will not cache folder images in this session.",
              cacheDirectoryPath);
        _folderImages = [[NSMutableDictionary alloc] init];
        return _folderImages;
    }

    // Remember - not every file we find may be a valid image file. We use the
    // filename as the key but check the extension too.
    NSArray<NSString *> *filenames = [fileManager contentsOfDirectoryAtPath:cacheDirectoryPath
                                                                      error:NULL];
    if (!filenames) {
        _folderImages = [[NSMutableDictionary alloc] init];
        return _folderImages;
    }

    _folderImages = [[NSMutableDictionary alloc] initWithCapacity:filenames.count];
    for (NSString *filenameWithExtension in filenames) {
        if (![filenameWithExtension.pathExtension isEqualToString:@"tiff"]) {
            continue;
        }

        NSString *filePath =
            [cacheDirectoryPath stringByAppendingPathComponent:filenameWithExtension];
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:filePath];
        if (image && image.isValid) {
            NSString *filename = filePath
                                     .lastPathComponent
                                     .stringByDeletingPathExtension
                                     .vna_convertStringToValidPath;
            _folderImages[filename] = image;
        }
    }
    return _folderImages;
}

- (BOOL)cacheImageData:(NSData *)imageData
              filename:(NSString *)filename
{
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

    self.folderImages[filename] = image;

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

- (nullable NSImage *)retrieveImage:(NSString *)filename
{
    return self.folderImages[filename];
}

@end
