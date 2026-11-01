// AVFoundation Swift overlay for Darling. It replaces the Swift 5.2.2 x86_64 slice, whose exports it
// keeps (AVError's user-info accessors, the NSValue bridging of CMTime, CMTimeRange and CMTimeMapping,
// AVCaptureVideoDataOutput's pixel format list), and adds the asynchronous property API of macOS 12
// (https://developer.apple.com/documentation/avfoundation/avasyncproperty, avpartialasyncproperty,
// avasynchronouskeyvalueloading). An async property names the key it stands for; its status is the
// documented key-value loading status of that key, and a loaded value is the object's value for it.

import Foundation
import _DarlingCoreMediaShims
@_exported import _DarlingAVFoundationShims

// MARK: AVError

extension AVError {
	public var device: AVCaptureDevice? { userInfo[AVErrorDeviceKey] as? AVCaptureDevice }
	public var time: CMTime? { (userInfo[AVErrorTimeKey] as? NSValue).map { $0.cmTimeValue } }
	public var fileSize: Int64? { (userInfo[AVErrorFileSizeKey] as? NSNumber)?.longLongValue() }
	public var processID: Int? { (userInfo[AVErrorPIDKey] as? NSNumber)?.integerValue() }
	public var recordingSuccessfullyFinished: Bool? {
		(userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? NSNumber)?.boolValue()
	}
	public var mediaType: AVMediaType? { (userInfo[AVErrorMediaTypeKey] as? String).map(AVMediaType.init(rawValue:)) }
	public var mediaSubtypes: [Int]? {
		(userInfo[AVErrorMediaSubTypeKey] as? [NSNumber])?.map { $0.integerValue() }
	}
	public var presentationTimeStamp: CMTime? {
		(userInfo[AVErrorPresentationTimeStampKey] as? NSValue).map { $0.cmTimeValue }
	}
	public var persistentTrackID: Int32? {
		(userInfo[AVErrorPersistentTrackIDKey] as? NSNumber)?.intValue()
	}
	public var fileType: AVFileType? { (userInfo[AVErrorFileTypeKey] as? String).map(AVFileType.init(rawValue:)) }
}

// MARK: NSValue bridging

private func holds(_ value: NSValue, sameTypeAs sample: NSValue) -> Bool {
	strcmp(value.objCType(), sample.objCType()) == 0
}

extension CMTime: @retroactive _ObjectiveCBridgeable {
	public func _bridgeToObjectiveC() -> NSValue { NSValue(cmTime: self) }

	public static func _forceBridgeFromObjectiveC(_ source: NSValue, result: inout CMTime?) {
		result = source.cmTimeValue
	}

	public static func _conditionallyBridgeFromObjectiveC(_ source: NSValue, result: inout CMTime?) -> Bool {
		result = holds(source, sameTypeAs: NSValue(cmTime: CMTime())) ? source.cmTimeValue : nil
		return result != nil
	}

	public static func _unconditionallyBridgeFromObjectiveC(_ source: NSValue?) -> CMTime {
		source?.cmTimeValue ?? CMTime()
	}
}

extension CMTimeRange: @retroactive _ObjectiveCBridgeable {
	public func _bridgeToObjectiveC() -> NSValue { NSValue(cmTimeRange: self) }

	public static func _forceBridgeFromObjectiveC(_ source: NSValue, result: inout CMTimeRange?) {
		result = source.cmTimeRangeValue
	}

	public static func _conditionallyBridgeFromObjectiveC(_ source: NSValue, result: inout CMTimeRange?) -> Bool {
		result = holds(source, sameTypeAs: NSValue(cmTimeRange: CMTimeRange())) ? source.cmTimeRangeValue : nil
		return result != nil
	}

	public static func _unconditionallyBridgeFromObjectiveC(_ source: NSValue?) -> CMTimeRange {
		source?.cmTimeRangeValue ?? CMTimeRange()
	}
}

extension CMTimeMapping: @retroactive _ObjectiveCBridgeable {
	public func _bridgeToObjectiveC() -> NSValue { NSValue(cmTimeMapping: self) }

	public static func _forceBridgeFromObjectiveC(_ source: NSValue, result: inout CMTimeMapping?) {
		result = source.cmTimeMappingValue
	}

	public static func _conditionallyBridgeFromObjectiveC(_ source: NSValue, result: inout CMTimeMapping?) -> Bool {
		result = holds(source, sameTypeAs: NSValue(cmTimeMapping: CMTimeMapping())) ? source.cmTimeMappingValue : nil
		return result != nil
	}

	public static func _unconditionallyBridgeFromObjectiveC(_ source: NSValue?) -> CMTimeMapping {
		source?.cmTimeMappingValue ?? CMTimeMapping()
	}
}

// MARK: AVCaptureVideoDataOutput

extension AVCaptureVideoDataOutput {
	/// The pixel format types the output supports, as four-character codes.
	public var availableVideoPixelFormatTypes: [OSType] {
		__availableVideoCVPixelFormatTypes.map { $0.unsignedIntValue() }
	}

	public var availableVideoCVPixelFormatTypes: [Any]? {
		__availableVideoCVPixelFormatTypes
	}
}

// MARK: Asynchronous properties

/// A property of an asset or track that can be loaded asynchronously, independent of its root and
/// value types.
public class AVAnyAsyncProperty: CustomStringConvertible, @unchecked Sendable {
	internal let key: String

	internal init(key: String) {
		self.key = key
	}

	public var description: String { key }
}

/// An asynchronous property of a root type, independent of its value type.
public class AVPartialAsyncProperty<Root>: AVAnyAsyncProperty, @unchecked Sendable {
	public override var description: String { "\(Root.self).\(key)" }
}

/// An asynchronous property of a root type with a value type.
public final class AVAsyncProperty<Root, Value>: AVPartialAsyncProperty<Root>, @unchecked Sendable {
	/// The loading status of a property.
	public enum Status {
		case notYetLoaded
		case loading
		case loaded(Value)
		case failed(Error)
	}
}

extension AVAsyncProperty.Status: CustomStringConvertible {
	public var description: String {
		switch self {
		case .notYetLoaded: return "notYetLoaded"
		case .loading: return "loading"
		case .loaded(let value): return "loaded(\(value))"
		case .failed(let error): return "failed(\(error))"
		}
	}
}

extension AVAsynchronousKeyValueLoading {
	/// The loading status of a property of this object.
	public func status<T>(of property: AVAsyncProperty<Self, T>) -> AVAsyncProperty<Self, T>.Status {
		var error: NSError?
		switch statusOfValue(forKey: property.key, error: &error) {
		case .loading:
			return .loading
		case .loaded:
			let value = (self as AnyObject).value(forKey: property.key)
			if let value = value as? T {
				return .loaded(value)
			}
			return .failed(error ?? NSError(domain: AVFoundationErrorDomain, code: 0))
		case .failed, .cancelled:
			return .failed(error ?? NSError(domain: AVFoundationErrorDomain, code: 0))
		default:
			return .notYetLoaded
		}
	}
}

extension AVPartialAsyncProperty where Root: AVAsset {
	public static var duration: AVAsyncProperty<Root, CMTime> { .init(key: "duration") }
	public static var isPlayable: AVAsyncProperty<Root, Bool> { .init(key: "playable") }
	public static var metadata: AVAsyncProperty<Root, [AVMetadataItem]> { .init(key: "metadata") }
}

extension AVPartialAsyncProperty where Root: AVURLAsset {
	public static var tracks: AVAsyncProperty<Root, [AVAssetTrack]> { .init(key: "tracks") }
}

extension AVPartialAsyncProperty where Root: AVAssetTrack {
	public static var naturalSize: AVAsyncProperty<Root, CGSize> { .init(key: "naturalSize") }
	public static var minFrameDuration: AVAsyncProperty<Root, CMTime> { .init(key: "minFrameDuration") }
	public static var nominalFrameRate: AVAsyncProperty<Root, Float> { .init(key: "nominalFrameRate") }
	public static var formatDescriptions: AVAsyncProperty<Root, [CMFormatDescription]> {
		.init(key: "formatDescriptions")
	}
	public static var preferredTransform: AVAsyncProperty<Root, CGAffineTransform> {
		.init(key: "preferredTransform")
	}
	public static var segments: AVAsyncProperty<Root, [AVAssetTrackSegment]> { .init(key: "segments") }
}

extension AVAsynchronousKeyValueLoading {
    public func load<T>(_ property: AVAsyncProperty<Self, T>,
                        isolation: isolated (any Actor)? = #isolation) async throws -> T {
        switch status(of: property) {
        case .loaded(let value): return value
        case .failed(let error): throw error
        case .notYetLoaded, .loading:
            // Darling's AVAsset backend cannot complete asynchronous loads yet.
            // Fail explicitly instead of waiting for a no-op completion handler.
            throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError)
        }
    }

    public func load<A, B, each C>(_ first: AVAsyncProperty<Self, A>,
                                  _ second: AVAsyncProperty<Self, B>,
                                  _ rest: repeat AVAsyncProperty<Self, each C>,
                                  isolation: isolated (any Actor)? = #isolation) async throws
        -> (A, B, repeat each C) {
        (try await load(first, isolation: isolation),
         try await load(second, isolation: isolation),
         repeat try await load(each rest, isolation: isolation))
    }
}
