import Foundation

/// Original nominal: BeansNetworkConnectionKind; descriptor: 0x7c3da8; cases: 4.
public enum BeansNetworkConnectionKind_2_0_3: CaseIterable, Hashable, Sendable {
    case wifi, cellular, other, unavailable
}

/// Original type: BeansNetworkStatus; kind: class; descriptor: 0x7c3d6c; fields: 4.
public final class BeansNetworkStatus_2_0_3 {
    /// The monitor typeref remains symbolic in the IPA and is retained as Any.
    public var monitor: Any = ()
    public var lock: NSLock = NSLock()
    public var reachable: Bool = false
    public var currentConnectionKind: BeansNetworkConnectionKind_2_0_3 = .unavailable

    public init() {}
}
