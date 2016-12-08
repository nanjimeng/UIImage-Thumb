//
//  UIImage+Thumbnail.h
//  ttpic
//
//  Created by darrenyao on 14-6-9.
//  Copyright (c) 2014年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ALAsset;
@interface UIImage (Thumbnail)

/*
 * Returns a UIImage for the given asset, with size length at most the passed size.
 * The resulting UIImage will be already rotated to UIImageOrientationUp, so its CGImageRef
 * can be used directly without additional rotation handling.
 * This is done synchronously, so you should call this method on a background queue/thread.
 *
 * PS: make sure side <= the original image's side
 */
+ (UIImage *)thumbnailForAsset:(ALAsset *)asset maxPixelSide:(NSUInteger)side;

/*
 * create thumbnail for filePath
 */
+ (UIImage *)thumbnailForFile:(NSString *)filePath maxPixelSide:(NSUInteger)side;

/*
 * create thumbnail for NSData
 */
+ (UIImage *)thumbnailForData:(NSData *)imageData maxPixelSide:(NSUInteger)side;

/*
 * create thumbnail with max side
 */
- (UIImage *)thumbnailWithMaxPixelSide:(NSUInteger)side;

/**
 * @param quality kCGInterpolationLow
 */
+ (UIImage *)thumbnailForImage:(UIImage *)image
                  maxPixelSide:(NSUInteger)side
                        quality:(CGInterpolationQuality)quality;
@end
