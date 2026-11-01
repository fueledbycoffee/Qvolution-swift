// Declarations the AVFoundation Swift overlay wraps, written for Darling. Darling's AVFoundation
// headers have no Clang module and are mostly bare class declarations, so the overlay imports these
// instead. The error domain and user-info keys are the ones Darling's AVFoundation exports (its
// AVError.h); the classes and protocol follow https://developer.apple.com/documentation/avfoundation/
// avasynchronouskeyvalueloading. CMTime and the other Core Media types come from the CoreMedia
// overlay's shim module.
#ifndef DARLING_AVFOUNDATION_SHIMS_H
#define DARLING_AVFOUNDATION_SHIMS_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import <CoreGraphics/CGAffineTransform.h>
#include "DarlingCoreMediaShims.h"

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const AVFoundationErrorDomain;
extern NSString *const AVErrorDeviceKey;
extern NSString *const AVErrorFileSizeKey;
extern NSString *const AVErrorMediaSubTypeKey;
extern NSString *const AVErrorMediaTypeKey;
extern NSString *const AVErrorTimeKey;
extern NSString *const AVErrorPIDKey;
extern NSString *const AVErrorRecordingSuccessfullyFinishedKey;
extern NSString *const AVErrorPresentationTimeStampKey;
extern NSString *const AVErrorPersistentTrackIDKey;
extern NSString *const AVErrorFileTypeKey;

// The overlay names no error code; Clang rejects an enum without enumerators, so it carries one
// unavailable placeholder instead of Apple's codes. Darling's Foundation has no NS_ERROR_ENUM, so the
// error-domain enum is spelled out; the attribute is what makes Swift synthesize the AVError struct.
typedef enum AVError : NSInteger AVError;
enum __attribute__((ns_error_domain(AVFoundationErrorDomain))) AVError : NSInteger {
	AVErrorDarlingPlaceholder NS_SWIFT_UNAVAILABLE("placeholder") = 0,
};

typedef NSString *AVMediaType NS_TYPED_ENUM;
typedef NSString *AVFileType NS_TYPED_EXTENSIBLE_ENUM;

typedef NS_ENUM(NSInteger, AVKeyValueStatus) {
	AVKeyValueStatusUnknown,
	AVKeyValueStatusLoading,
	AVKeyValueStatusLoaded,
	AVKeyValueStatusFailed,
	AVKeyValueStatusCancelled
};

@protocol AVAsynchronousKeyValueLoading
- (AVKeyValueStatus)statusOfValueForKey:(NSString *)key error:(NSError *_Nullable *_Nullable)outError;
- (void)loadValuesAsynchronouslyForKeys:(NSArray<NSString *> *)keys
                      completionHandler:(nullable void (^)(void))handler;
@end

@interface AVAsset : NSObject <AVAsynchronousKeyValueLoading>
@end

@interface AVURLAsset : AVAsset
@end

@interface AVAssetTrack : NSObject <AVAsynchronousKeyValueLoading>
@end

@interface AVAssetTrackSegment : NSObject
@end

@interface AVMetadataItem : NSObject <AVAsynchronousKeyValueLoading>
@end

@interface AVCaptureDevice : NSObject
@end

@interface AVCaptureVideoDataOutput : NSObject
@property (nonatomic, readonly) NSArray<NSNumber *> *availableVideoCVPixelFormatTypes NS_REFINED_FOR_SWIFT;
@end

@interface NSValue (AVFoundationTime)
+ (NSValue *)valueWithCMTime:(CMTime)time;
@property (readonly) CMTime CMTimeValue;
+ (NSValue *)valueWithCMTimeRange:(CMTimeRange)timeRange;
@property (readonly) CMTimeRange CMTimeRangeValue;
+ (NSValue *)valueWithCMTimeMapping:(CMTimeMapping)timeMapping;
@property (readonly) CMTimeMapping CMTimeMappingValue;
@end

NS_ASSUME_NONNULL_END

#endif
