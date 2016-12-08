//
//  UIImage+Thumbnail.m
//  ttpic
//
//  Created by darrenyao on 14-6-9.
//  Copyright (c) 2014年 Tencent. All rights reserved.
//
// For details, see http://mindsea.com/2012/12/18/downscaling-huge-alassets-without-fear-of-sigkill

#import "UIImage+Thumbnail.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/ImageIO.h>

#if !__has_feature(objc_arc)
#error This class requires automatic reference counting
#endif

// Helper methods for thumbnailForAsset:maxPixelSide:
static size_t getAssetBytesCallback(void *info, void *buffer, off_t position, size_t count) {
    ALAssetRepresentation *rep = (__bridge id)info;
    
    NSError *error = nil;
    size_t countRead = [rep getBytes:(uint8_t *)buffer fromOffset:position length:count error:&error];
    
    if (countRead == 0 && error) {
        // We have no way of passing this info back to the caller, so we log it, at least.
        NSLog(@"thumbnailForAsset:maxPixelSide: got an error reading an asset: %@", error);
    }
    
    return countRead;
}

static void releaseAssetCallback(void *info) {
    // The info here is an ALAssetRepresentation which we CFRetain in thumbnailForAsset:maxPixelSide:.
    // This release balances that retain.
    CFRelease(info);
}

@implementation UIImage (Thumbnail)

+ (UIImage *)thumbnailForAsset:(ALAsset *)asset maxPixelSide:(NSUInteger)side {
    NSParameterAssert(asset != nil);
    NSParameterAssert(side > 0);
    
    ALAssetRepresentation *rep = [asset defaultRepresentation];
    if (rep == nil) {
        return nil;
    }
    
    CGDataProviderDirectCallbacks callbacks = {
        .version = 0,
        .getBytePointer = NULL,
        .releaseBytePointer = NULL,
        .getBytesAtPosition = getAssetBytesCallback,
        .releaseInfo = releaseAssetCallback,
    };
    
    CGDataProviderRef provider = CGDataProviderCreateDirect((void *)CFBridgingRetain(rep), [rep size], &callbacks);
    CGImageSourceRef source = CGImageSourceCreateWithDataProvider(provider, NULL);
    
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef) @{
                                                                                                      (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
                                                                                                      (NSString *)kCGImageSourceThumbnailMaxPixelSize : [NSNumber numberWithUnsignedInteger:side],
                                                                                                      (NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
                                                                                                      });
    CFRelease(source);
    CFRelease(provider);
    
    if (!imageRef) {
        return nil;
    }
    
    UIImage *toReturn = [[UIImage alloc] initWithCGImage:imageRef];
    
    CFRelease(imageRef);
    
    return toReturn;
}

+(UIImage *)thumbnailForFile:(NSString *)filePath maxPixelSide:(NSUInteger)side
{
    NSParameterAssert(filePath != nil);
    NSParameterAssert(side > 0);
    
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)fileURL, NULL);
    if (!imageSource){
        return nil;
    }
    
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef) @{
                                                                                                           (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
                                                                                                           (NSString *)kCGImageSourceThumbnailMaxPixelSize : [NSNumber numberWithUnsignedInteger:side],
                                                                                                           (NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
                                                                                                           });
    CFRelease(imageSource);
    
    if (!imageRef) {
        return nil;
    }
    
    UIImage *toReturn = [[UIImage alloc] initWithCGImage:imageRef];
    CFRelease(imageRef);
    
    return toReturn;
}

+(UIImage *)thumbnailForData:(NSData *)imageData maxPixelSide:(NSUInteger)side
{
    NSParameterAssert(imageData != nil);
    NSParameterAssert(side > 0);
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (!imageSource){
        return nil;
    }
    
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef) @{
                                                                                                           (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
                                                                                                           (NSString *)kCGImageSourceThumbnailMaxPixelSize : [NSNumber numberWithUnsignedInteger:side],
                                                                                                           (NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
                                                                                                           });
    CFRelease(imageSource);
    
    if (!imageRef) {
        return nil;
    }
    
    UIImage *toReturn = [[UIImage alloc] initWithCGImage:imageRef];
    CFRelease(imageRef);
    
    return toReturn;
}

-(UIImage *)thumbnailWithMaxPixelSide:(NSUInteger)side
{
    @autoreleasepool {
        NSLog(@"UIImagePNGRepresentation");
        NSData *imageData = UIImagePNGRepresentation(self);
        NSLog(@"UIImagePNGRepresentation end");
        if (imageData) {
            return [UIImage thumbnailForData:imageData maxPixelSide:side];
        }
    }
    return self;
}

+ (UIImage *)thumbnailForImage:(UIImage *)image
                  maxPixelSide:(NSUInteger)side
                       quality:(CGInterpolationQuality)quality{
    if (image == nil) {
        return nil;
    }
    
    if (image.images) {
        // Do not decode animated images
        return image;
    }
    
    
    CGImageRef imageRef = image.CGImage;
    CGFloat imageScale = image.scale;
    CGSize imageSize = CGSizeMake(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef));
    if (imageSize.width > imageSize.height) {
        float scale = side / imageSize.width;
        imageSize.width = side * imageScale;
        imageSize.height = floorf(imageSize.height * scale) * imageScale;
    } else {
        float scale = side / imageSize.height;
        imageSize.height = side * imageScale;
        imageSize.width = floorf(imageSize.width * scale) * imageScale;
    }
    
    CGRect imageRect = (CGRect){.origin = CGPointZero, .size = imageSize};
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
    
    int infoMask = (bitmapInfo & kCGBitmapAlphaInfoMask);
    BOOL anyNonAlpha = (infoMask == kCGImageAlphaNone ||
                        infoMask == kCGImageAlphaNoneSkipFirst ||
                        infoMask == kCGImageAlphaNoneSkipLast);
    
    // CGBitmapContextCreate doesn't support kCGImageAlphaNone with RGB.
    // https://developer.apple.com/library/mac/#qa/qa1037/_index.html
    if (infoMask == kCGImageAlphaNone && CGColorSpaceGetNumberOfComponents(colorSpace) > 1) {
        // Unset the old alpha info.
        bitmapInfo &= ~kCGBitmapAlphaInfoMask;
        
        // Set noneSkipFirst.
        bitmapInfo |= kCGImageAlphaNoneSkipFirst;
    }
    // Some PNGs tell us they have alpha but only 3 components. Odd.
    else if (!anyNonAlpha && CGColorSpaceGetNumberOfComponents(colorSpace) == 3) {
        // Unset the old alpha info.
        bitmapInfo &= ~kCGBitmapAlphaInfoMask;
        bitmapInfo |= kCGImageAlphaPremultipliedFirst;
    }
    
    // It calculates the bytes-per-row based on the bitsPerComponent and width arguments.
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 imageSize.width,
                                                 imageSize.height,
                                                 CGImageGetBitsPerComponent(imageRef),
                                                 0,
                                                 colorSpace,
                                                 bitmapInfo);
    CGColorSpaceRelease(colorSpace);
    
    // If failed, return undecompressed image
    if (!context) return image;
    CGContextSetInterpolationQuality(context, quality);
    CGContextDrawImage(context, imageRect, imageRef);
    CGImageRef scaleImageRef = CGBitmapContextCreateImage(context);
    
    CGContextRelease(context);
    
    UIImage *scaleImage = [UIImage imageWithCGImage:scaleImageRef scale:imageScale orientation:image.imageOrientation];
    CGImageRelease(scaleImageRef);
    return scaleImage;
}
@end
