import Foundation

/// Original nominal: RemotePlatforms; each platform flag is optional Bool.
public struct RemotePlatforms_2_0_3 {
    public var netease: Bool?
    public var qq: Bool?
    public var kugou: Bool?
    public init(netease: Bool? = nil, qq: Bool? = nil, kugou: Bool? = nil) {
        self.netease = netease; self.qq = qq; self.kugou = kugou
    }
}

/// Original nominal: RemoteConfig.
public struct RemoteConfig_2_0_3 {
    public var enabled: Bool
    public var announcement: String
    public var announcementEnabled: Bool
    public var announcementImageURL: String?
    public var announcementMediaURL: String?
    public var announcementMediaType: String?
    public var announcementTextColor: String?
    public var updatedAt: String?
    public var platforms: RemotePlatforms_2_0_3?
    public init(enabled: Bool = false, announcement: String = "",
                announcementEnabled: Bool = false, announcementImageURL: String? = nil,
                announcementMediaURL: String? = nil, announcementMediaType: String? = nil,
                announcementTextColor: String? = nil, updatedAt: String? = nil,
                platforms: RemotePlatforms_2_0_3? = nil) {
        self.enabled = enabled; self.announcement = announcement
        self.announcementEnabled = announcementEnabled
        self.announcementImageURL = announcementImageURL
        self.announcementMediaURL = announcementMediaURL
        self.announcementMediaType = announcementMediaType
        self.announcementTextColor = announcementTextColor; self.updatedAt = updatedAt
        self.platforms = platforms
    }
}

/// Original nominal: ReleaseInfo.
public struct ReleaseInfo_2_0_3 {
    public var version: String
    public var name: String
    public var body: String
    public var htmlURL: URL
    public var assetURL: URL?
    public var notesImageURL: URL?
    public var notesTextColorHex: String?
    public var build: String
    public var channel: String
    public var minimumOSVersion: String
    public var maximumOSVersionExclusive: String?
    public init(version: String = "", name: String = "", body: String = "",
                htmlURL: URL = URL(fileURLWithPath: "/"), assetURL: URL? = nil,
                notesImageURL: URL? = nil, notesTextColorHex: String? = nil,
                build: String = "", channel: String = "", minimumOSVersion: String = "",
                maximumOSVersionExclusive: String? = nil) {
        self.version = version; self.name = name; self.body = body; self.htmlURL = htmlURL
        self.assetURL = assetURL; self.notesImageURL = notesImageURL
        self.notesTextColorHex = notesTextColorHex; self.build = build; self.channel = channel
        self.minimumOSVersion = minimumOSVersion
        self.maximumOSVersionExclusive = maximumOSVersionExclusive
    }
}

/// Original nominal: VersionLog.
public struct VersionLog_2_0_3 {
    public var id: String
    public var version: String
    public var title: String
    public var notices: [String]
    public var features: [String]
    public var fixes: [String]
    public var imageURL: URL?
    public var textColorHex: String?
    public init(id: String = "", version: String = "", title: String = "",
                notices: [String] = [], features: [String] = [], fixes: [String] = [],
                imageURL: URL? = nil, textColorHex: String? = nil) {
        self.id = id; self.version = version; self.title = title; self.notices = notices
        self.features = features; self.fixes = fixes; self.imageURL = imageURL
        self.textColorHex = textColorHex
    }
}

/// Original nominal: Status; IPA exposes two cases for source checks.
public enum SourceCheckStatus_2_0_3: CaseIterable, Hashable, Sendable {
    case available, unavailable
}

/// Original nominal: SourceCheckResult.
public struct SourceCheckResult_2_0_3 {
    public var status: SourceCheckStatus_2_0_3
    public var message: String
    public var detail: String
    public init(status: SourceCheckStatus_2_0_3 = .unavailable, message: String = "",
                detail: String = "") {
        self.status = status; self.message = message; self.detail = detail
    }
}
