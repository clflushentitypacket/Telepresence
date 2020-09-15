import WebRTC

// The following code is from https://github.com/stasel/WebRTC-iOS

extension RTCIceConnectionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .new:          return "New"
        case .checking:     return "Checking"
        case .connected:    return "Connected"
        case .completed:    return "Completed"
        case .failed:       return "Failed"
        case .disconnected: return "Disconnected"
        case .closed:       return "Closed"
        case .count:        return "Count"
        @unknown default:   return "Unknown \(self.rawValue)"
        }
    }
}

extension RTCPeerConnectionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .new:          return "New"
        case .connecting:   return "Connecting"
        case .connected:    return "Connected"
        case .disconnected: return "Disconnected"
        case .failed:       return "Failed"
        case .closed:       return "Closed"
        @unknown default:   return "Unknown \(self.rawValue)"
        }
    }
}

extension RTCSignalingState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .stable:               return "Stable"
        case .haveLocalOffer:       return "Have Local Offer"
        case .haveLocalPrAnswer:    return "Have Local PrAnswer"
        case .haveRemoteOffer:      return "Have Remote Offer"
        case .haveRemotePrAnswer:   return "Have Remote PrAnswer"
        case .closed:               return "closed"
        @unknown default:   return "Unknown \(self.rawValue)"
        }
    }
}

extension RTCIceGatheringState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .new:          return "New"
        case .gathering:    return "Gathering"
        case .complete:     return "Complete"
        @unknown default:   return "Unknown \(self.rawValue)"
        }
    }
}


extension RTCDataChannelState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connecting:   return "Connecting"
        case .open:         return "Open"
        case .closing:      return "Closing"
        case .closed:       return "Closed"
        @unknown default:   return "Unknown \(self.rawValue)"
        }
    }
}
