// The Core Media C API the CoreMedia Swift overlay wraps, written for Darling. Darling's CoreMedia
// headers have no Clang module, declare CMTime only and its functions as generated `void *f(void)`
// stubs, so the overlay imports these declarations instead. CMTime's layout and flag names are those
// of Darling's CMTime.h; CMTimeRange, CMTimeMapping and the CF types follow the documentation's Swift
// shapes (https://developer.apple.com/documentation/coremedia/cmtimerange, .../cmtimebase).
// CMTimebaseRef, CMSampleBufferRef, CMFormatDescriptionRef and CVBufferRef are CF types, so Swift imports them as classes
// whose members mangle on the Ref typealias, as apps expect (So13CMTimebaseRefa).
#ifndef DARLING_COREMEDIA_SHIMS_H
#define DARLING_COREMEDIA_SHIMS_H

#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>

CF_IMPLICIT_BRIDGING_ENABLED
CF_ASSUME_NONNULL_BEGIN

typedef int64_t CMTimeValue;
typedef int32_t CMTimeScale;
typedef int64_t CMTimeEpoch;
typedef CF_OPTIONS(uint32_t, CMTimeFlags) {
	kCMTimeFlags_Valid = 1UL << 0,
	kCMTimeFlags_HasBeenRounded = 1UL << 1,
	kCMTimeFlags_PositiveInfinity = 1UL << 2,
	kCMTimeFlags_NegativeInfinity = 1UL << 3,
	kCMTimeFlags_Indefinite = 1UL << 4,
	kCMTimeFlags_ImpliedValueFlagsMask = kCMTimeFlags_PositiveInfinity | kCMTimeFlags_NegativeInfinity | kCMTimeFlags_Indefinite
};

typedef struct {
	CMTimeValue value;
	CMTimeScale timescale;
	CMTimeFlags flags;
	CMTimeEpoch epoch;
} CMTime;

typedef struct {
	CMTime start;
	CMTime duration;
} CMTimeRange;

typedef struct {
	CMTimeRange source;
	CMTimeRange target;
} CMTimeMapping;

// The overlay passes rounding methods through and names none; Clang rejects an enum without
// enumerators, so it carries one unavailable placeholder instead of Apple's cases.
typedef CF_ENUM(uint32_t, CMTimeRoundingMethod) {
	kCMTimeRoundingMethod_DarlingPlaceholder CF_SWIFT_UNAVAILABLE("placeholder") = 0,
};

typedef struct CF_BRIDGED_TYPE(id) OpaqueCMTimebase *CMTimebaseRef;
typedef struct CF_BRIDGED_TYPE(id) opaqueCMSampleBuffer *CMSampleBufferRef;
typedef struct CF_BRIDGED_TYPE(id) opaqueCMFormatDescription *CMFormatDescriptionRef;
typedef struct CF_BRIDGED_TYPE(id) __CVBuffer *CVBufferRef;
typedef CVBufferRef CVImageBufferRef;

CMTime CMTimeMake(int64_t value, int32_t timescale);
CMTime CMTimeMakeWithSeconds(Float64 seconds, int32_t preferredTimescale);
Float64 CMTimeGetSeconds(CMTime time);
CMTime CMTimeConvertScale(CMTime time, int32_t newTimescale, CMTimeRoundingMethod method);
CMTime CMTimeAdd(CMTime lhs, CMTime rhs);
CMTime CMTimeSubtract(CMTime lhs, CMTime rhs);
int32_t CMTimeCompare(CMTime time1, CMTime time2);

CMTimeRange CMTimeRangeFromTimeToTime(CMTime start, CMTime end);
CMTime CMTimeRangeGetEnd(CMTimeRange range);
CMTimeRange CMTimeRangeGetUnion(CMTimeRange range, CMTimeRange otherRange);
CMTimeRange CMTimeRangeGetIntersection(CMTimeRange range, CMTimeRange otherRange);
Boolean CMTimeRangeContainsTime(CMTimeRange range, CMTime time);
Boolean CMTimeRangeContainsTimeRange(CMTimeRange range, CMTimeRange otherRange);
Boolean CMTimeRangeEqual(CMTimeRange range1, CMTimeRange range2);

Float64 CMTimebaseGetRate(CMTimebaseRef timebase);
OSStatus CMTimebaseSetRate(CMTimebaseRef timebase, Float64 rate);
OSStatus CMTimebaseSetTime(CMTimebaseRef timebase, CMTime time);
OSStatus CMTimebaseSetRateAndAnchorTime(CMTimebaseRef timebase, Float64 rate, CMTime timebaseTime, CMTime immediateSourceTime);

Boolean CMSampleBufferIsValid(CMSampleBufferRef sbuf);
CVImageBufferRef _Nullable CMSampleBufferGetImageBuffer(CMSampleBufferRef sbuf);
size_t CMSampleBufferGetTotalSampleSize(CMSampleBufferRef sbuf);
CMTime CMSampleBufferGetPresentationTimeStamp(CMSampleBufferRef sbuf);
CMTime CMSampleBufferGetOutputPresentationTimeStamp(CMSampleBufferRef sbuf);
CMTime CMSampleBufferGetDuration(CMSampleBufferRef sbuf);

CF_ASSUME_NONNULL_END
CF_IMPLICIT_BRIDGING_DISABLED

#endif
