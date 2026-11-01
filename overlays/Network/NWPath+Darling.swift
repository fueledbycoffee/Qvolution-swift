//===----------------------------------------------------------------------===//
//
// NWPath API from SDKs newer than the Swift 5.2.2 Network overlay, written for Darling from
// https://developer.apple.com/documentation/network/nwpath: isConstrained and unsatisfiedReason.
//
//===----------------------------------------------------------------------===//

import _SwiftNetworkOverlayShims

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension NWPath {
	/// Checks if the path uses an NWInterface in Low Data Mode.
	public var isConstrained: Bool {
		if let path = self.nw {
			return nw_path_is_constrained(path)
		}
		return false
	}
}

@available(macOS 11.0, iOS 14.2, watchOS 7.1, tvOS 14.2, *)
extension NWPath {
	/// A reason a path is unsatisfied.
	public enum UnsatisfiedReason : Equatable, Hashable {
		/// No reason is given.
		case notAvailable
		/// The user has disabled cellular.
		case cellularDenied
		/// The user has disabled Wi-Fi.
		case wifiDenied
		/// The user has disabled local network access.
		case localNetworkDenied
		/// A required VPN is not active.
		case vpnInactive
	}

	/// The reason the path is unsatisfied. Darling applies no per-app network policy
	/// (cellular, Wi-Fi, local network or VPN), so no path is ever denied by one.
	public var unsatisfiedReason: NWPath.UnsatisfiedReason {
		return .notAvailable
	}
}
