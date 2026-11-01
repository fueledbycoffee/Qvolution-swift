//===----------------------------------------------------------------------===//
//
// NWBrowser, written for Darling from https://developer.apple.com/documentation/network/nwbrowser.
// Darling has no Bonjour (mDNSResponder) backend behind libnetwork's nw_browser functions, so a
// started browser finds nothing: it moves to .failed with the DNS-SD error
// kDNSServiceErr_ServiceNotRunning ("Background daemon not running", <dns_sd.h>) and never
// reports results. Result carries endpoint and interfaces; its metadata (NWTXTRecord) and the
// changed(old:new:flags:) change are left out, as nothing can produce them.
//
//===----------------------------------------------------------------------===//

import Dispatch
import Foundation

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public final class NWBrowser : CustomDebugStringConvertible {

	/// A description of the service to browse for.
	public enum Descriptor {
		/// Bonjour services of a type, in a domain (nil for the default domains).
		case bonjour(type: String, domain: String?)
		/// Bonjour services of a type, in a domain, with their TXT records.
		case bonjourWithTXTRecord(type: String, domain: String?)
		/// Application services with a name.
		case applicationService(name: String)
	}

	/// The states a browser moves through.
	public enum State : Equatable {
		/// The browser has been created but not started.
		case setup
		/// The browser is browsing.
		case ready
		/// The browser has failed with an unrecoverable error.
		case failed(NWError)
		/// The browser has been cancelled.
		case cancelled
		/// The browser is waiting for the network.
		case waiting(NWError)
	}

	/// A service found by a browser.
	public struct Result : Hashable {
		/// The endpoint of the service.
		public let endpoint: NWEndpoint
		/// The interfaces on which the service was found.
		public let interfaces: [NWInterface]

		/// A change to the set of results between two updates.
		public enum Change : Hashable {
			/// The result did not change.
			case identical
			/// The result was added.
			case added(NWBrowser.Result)
			/// The result was removed.
			case removed(NWBrowser.Result)
		}
	}

	/// The descriptor the browser was created with.
	public let descriptor: NWBrowser.Descriptor

	/// The parameters the browser was created with.
	public let parameters: NWParameters

	/// The current state of the browser.
	public private(set) var state: NWBrowser.State = .setup

	/// The services found so far.
	public private(set) var browseResults: Set<NWBrowser.Result> = []

	/// The queue the browser was started on, nil before start(queue:).
	public private(set) var queue: DispatchQueue?

	/// A handler called on the browser's queue with each new state.
	public var stateUpdateHandler: ((_ newState: NWBrowser.State) -> Void)?

	/// A handler called on the browser's queue when the set of results changes.
	public var browseResultsChangedHandler: ((_ newResults: Set<NWBrowser.Result>, _ changes: Set<NWBrowser.Result.Change>) -> Void)?

	public var debugDescription: String {
		return "NWBrowser \(self.descriptor)"
	}

	/// Creates a browser for a service descriptor with parameters.
	public init(for descriptor: NWBrowser.Descriptor, using parameters: NWParameters) {
		self.descriptor = descriptor
		self.parameters = parameters
	}

	/// Starts browsing, delivering updates on a queue.
	public func start(queue: DispatchQueue) {
		guard self.queue == nil else {
			return
		}
		self.queue = queue
		queue.async {
			self.update(.failed(.dns(DNSServiceErrorType(kDNSServiceErr_ServiceNotRunning))))
		}
	}

	/// Stops browsing.
	public func cancel() {
		guard let queue = self.queue else {
			self.update(.cancelled)
			return
		}
		queue.async {
			self.update(.cancelled)
		}
	}

	private func update(_ newState: NWBrowser.State) {
		if self.state == .cancelled || self.state == newState {
			return
		}
		self.state = newState
		self.stateUpdateHandler?(newState)
	}
}
