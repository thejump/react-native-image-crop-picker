//
//  Compression.m
//  imageCropPicker
//
//  Created by Ivan Pusic on 12/24/16.
//  Copyright © 2016 Ivan Pusic. All rights reserved.
//

#import "Compression.h"

#import "SDAVAssetExportSession.h"
@implementation Compression

- (instancetype)init {
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                 @"640x480": AVAssetExportPreset640x480,
                                                                                 @"960x540": AVAssetExportPreset960x540,
                                                                                 @"1280x720": AVAssetExportPreset1280x720,
                                                                                 @"1920x1080": AVAssetExportPreset1920x1080,
                                                                                 @"LowQuality": AVAssetExportPresetLowQuality,
                                                                                 @"MediumQuality": AVAssetExportPresetMediumQuality,
                                                                                 @"HighestQuality": AVAssetExportPresetHighestQuality,
                                                                                 @"Passthrough": AVAssetExportPresetPassthrough,
                                                                                 }];
    
    if (@available(iOS 9.0, *)) {
        [dic addEntriesFromDictionary:@{@"3840x2160": AVAssetExportPreset3840x2160}];
    } else {
        // Fallback on earlier versions
    }
    
    self.exportPresets = dic;
    
    return self;
}

- (ImageResult*) compressImageDimensions:(UIImage*)image
                   compressImageMaxWidth:(CGFloat)maxWidth
                  compressImageMaxHeight:(CGFloat)maxHeight
                              intoResult:(ImageResult*)result {
    
    //[origin] if ([maxWidth integerValue] == 0 || [maxHeight integerValue] == 0) {
    //when pick a width< height image and only set "compressImageMaxWidth",will cause a {0,0}size image
    //Now fix it
    if (maxWidth  == 0 || maxHeight  == 0) {
        result.width = [NSNumber numberWithFloat:image.size.width];
        result.height = [NSNumber numberWithFloat:image.size.height];
        result.image = image;
        return result;
    }
    
    CGFloat oldWidth = image.size.width;
    CGFloat oldHeight = image.size.height;
    
    CGFloat scaleFactor = (oldWidth > oldHeight) ? maxWidth / oldWidth : maxHeight / oldHeight;
    if(scaleFactor>1){
        scaleFactor=1;
    }
    int newWidth = oldWidth * scaleFactor;
    int newHeight = oldHeight * scaleFactor;
    CGSize newSize = CGSizeMake(newWidth, newHeight);
    
    UIGraphicsBeginImageContext(newSize);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    result.width = [NSNumber numberWithFloat:newWidth];
    result.height = [NSNumber numberWithFloat:newHeight];
    result.image = resizedImage;
    return result;
}

- (ImageResult*) compressImage:(UIImage*)image
                   withOptions:(NSDictionary*)options {
    
    ImageResult *result = [[ImageResult alloc] init];
    result.width = @(image.size.width);
    result.height = @(image.size.height);
    result.image = image;
    result.mime = @"image/jpeg";
    
    NSNumber *compressImageMaxWidth = [options valueForKey:@"compressImageMaxWidth"];
    NSNumber *compressImageMaxHeight = [options valueForKey:@"compressImageMaxHeight"];
    
    // determine if it is necessary to resize image
    BOOL shouldResizeWidth = (compressImageMaxWidth != nil && [compressImageMaxWidth floatValue] < image.size.width);
    BOOL shouldResizeHeight = (compressImageMaxHeight != nil && [compressImageMaxHeight floatValue] < image.size.height);
    
    if (shouldResizeWidth || shouldResizeHeight) {
        CGFloat maxWidth = compressImageMaxWidth != nil ? [compressImageMaxWidth floatValue] : image.size.width;
        CGFloat maxHeight = compressImageMaxHeight != nil ? [compressImageMaxHeight floatValue] : image.size.height;
        
        [self compressImageDimensions:image
                compressImageMaxWidth:maxWidth
               compressImageMaxHeight:maxHeight
                           intoResult:result];
    }
    
    // parse desired image quality
    NSNumber *compressQuality = [options valueForKey:@"compressImageQuality"];
    if (compressQuality == nil) {
        compressQuality = [NSNumber numberWithFloat:0.8];
    }
    
    // convert image to jpeg representation
    result.data = UIImageJPEGRepresentation(result.image, [compressQuality floatValue]);
     result.mime = @"image/jpeg";
   
    return result;
}

- (void)compressVideo:(NSURL*)inputURL
            outputURL:(NSURL*)outputURL
          withOptions:(NSDictionary*)options
              handler:(void (^)(SDAVAssetExportSession*,NSNumber *))handler {

    
    AVAsset* videoAsset = [AVAsset assetWithURL:inputURL];
    AVAssetTrack* clipVideoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    
    SDAVAssetExportSession *encoder = [SDAVAssetExportSession.alloc initWithAsset:videoAsset];
  
  
    AVMutableComposition* composition = [[AVMutableComposition alloc] init];
    [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    AVMutableVideoComposition* videoComposition = [[AVMutableVideoComposition alloc] init];
    NSLog(@"video 1 w : %f  ", clipVideoTrack.naturalSize.width);
    NSLog(@"video 1 h : %f  ", clipVideoTrack.naturalSize.height);
    double height=clipVideoTrack.naturalSize.height;
    double width=clipVideoTrack.naturalSize.width;
    
    CGFloat scaleFactor = (width > height) ? 1280 / width : 1280 / height;
    if(scaleFactor>1){
        scaleFactor=1;
    }
    width = width * scaleFactor;
    height = height * scaleFactor;
   
    UIInterfaceOrientation orientation = [self orientationForTrack:videoAsset];
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            break;
        case UIInterfaceOrientationPortrait:
        case UIInterfaceOrientationPortraitUpsideDown:
            if(width>height){
                int temp=width;
                width=height;
                height=temp;
            }
            break;
        default:
            break;
    }
    NSLog(@"video 1 w : %f  ", width);
    NSLog(@"video 1 h : %f  ", height);
    
    videoComposition.renderSize = CGSizeMake(width,height);
    videoComposition.frameDuration = CMTimeMake(1, 30);
    //   NSLog(@"FPS is  : %f ", CMTimeGetSeconds(videoAsset.duration));
    
    AVMutableVideoCompositionLayerInstruction* transformer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:clipVideoTrack];
    
    AVMutableVideoCompositionInstruction* instruction = [[AVMutableVideoCompositionInstruction alloc] init];
    //  NSLog(@"video 1 duration : %f  ", CMTimeGetSeconds(videoAsset.duration));
    
    NSNumber *_duration = [options valueForKey:@"videoDuration"];
    double duration = [_duration doubleValue];
    if(CMTimeGetSeconds(videoAsset.duration)>duration){
        instruction.timeRange =CMTimeRangeMake( kCMTimeZero, CMTimeMakeWithSeconds(duration, 600));
    }
    else{
        instruction.timeRange =CMTimeRangeMake( kCMTimeZero, videoAsset.duration);
    }
    
    // NSLog(@"video 1 duration : %f  ", CMTimeGetSeconds(instruction.timeRange.duration));
    
    CGAffineTransform transform = [self transformBasedOnAsset:videoAsset track:clipVideoTrack scaleFactor:scaleFactor];
    
    //   CGAffineTransform transform = clipVideoTrack.preferredTransform;
    
    [transformer setTransform:transform atTime:kCMTimeZero];
    
    [instruction setLayerInstructions:@[transformer]];
    [videoComposition setInstructions:@[instruction]];
    
    // Export
    [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];
    
   
    encoder.outputURL=outputURL;
    encoder.outputFileType = AVFileTypeMPEG4;
    encoder.shouldOptimizeForNetworkUse = YES;
    
    encoder.videoSettings = @
    {
    AVVideoCodecKey: AVVideoCodecH264,
    AVVideoWidthKey: @(width),
    AVVideoHeightKey: @(height),
    AVVideoCompressionPropertiesKey: @
        {
        AVVideoAverageBitRateKey: @3000000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264High40,
        },
    };
    encoder.audioSettings = @
    {
    AVFormatIDKey: @(kAudioFormatMPEG4AAC),
    AVNumberOfChannelsKey: @2,
    AVSampleRateKey: @44100,
    AVEncoderBitRateKey: @128000,
    };
    
    

    encoder.videoComposition=videoComposition;
    encoder.timeRange=CMTimeRangeMake( kCMTimeZero, instruction.timeRange.duration);
    
    
    [encoder exportAsynchronouslyWithCompletionHandler:^
     {
         int status = encoder.status;
         
         if (status == AVAssetExportSessionStatusCompleted)
         {
               handler(encoder,@(CMTimeGetSeconds(videoAsset.duration)));
             // encoder.outputURL <- this is what you want!!
         }
         else if (status == AVAssetExportSessionStatusCancelled)
         {
             NSLog(@"Export failed %@", encoder.error);
             handler(encoder,0);
         }
         else
         {
               NSLog(@"Export failed %@", encoder.error );
             handler(encoder,0);
         }
     }];
}


- (UIInterfaceOrientation)orientationForTrack:(AVAsset *)asset {
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    
    if([tracks count] > 0) {
        AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
        CGAffineTransform t = videoTrack.preferredTransform;
        
        // Portrait
        if(t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0) {
            orientation = UIInterfaceOrientationPortrait;
        }
        // PortraitUpsideDown
        if(t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0) {
            orientation = UIInterfaceOrientationPortraitUpsideDown;
        }
        // LandscapeRight
        if(t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0) {
            orientation = UIInterfaceOrientationLandscapeRight;
        }
        // LandscapeLeft
        if(t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0) {
            orientation = UIInterfaceOrientationLandscapeLeft;
        }
    }
    return orientation;
}


- (CGAffineTransform)transformBasedOnAsset:(AVAsset *)asset track:(AVAssetTrack*) track
                               scaleFactor:(double) scaleFactor
 {
   
     
     
    UIInterfaceOrientation orientation = [self orientationForTrack:asset];
     
     CGPoint offset;
     double angle;
     BOOL portrait;
     switch (orientation) {
         case UIInterfaceOrientationLandscapeLeft:
         case UIInterfaceOrientationLandscapeRight:
             portrait=false;
         case UIInterfaceOrientationPortrait:
         case UIInterfaceOrientationPortraitUpsideDown:
             portrait=true;
         default:
             break;
     }
     
     double height=track.naturalSize.height*scaleFactor;
     double width=track.naturalSize.width*scaleFactor;
     if(portrait){
        // height=track.naturalSize.width;
        // width=track.naturalSize.height;
     }
     
     
    CGAffineTransform finalTranform;
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
            finalTranform = CGAffineTransformMake(-1, 0, 0, -1, width, height);
            break;
        case UIInterfaceOrientationLandscapeRight:
            finalTranform = CGAffineTransformMake(1, 0, 0, 1, 0, 0);
       break;
        case UIInterfaceOrientationPortrait:
                finalTranform = CGAffineTransformMake(0, 1, -1, 0, height, 0);
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            finalTranform = CGAffineTransformMake(0, -1, 1, 0, 0, width);
            break;
        default:
            finalTranform = CGAffineTransformMake(1, 0, 0, 1, 0, 0);
            break;
    }
     
     CGAffineTransform scale= CGAffineTransformScale(finalTranform,scaleFactor, scaleFactor);
     
     return scale;
     
 //   return finalTranform;
}


@end
