import Foundation

/// Original nominal: ThirdPartySourcePlatform; descriptor inferred from IPA cases.
public enum ThirdPartySourcePlatform_2_0_3: CaseIterable, Hashable, Sendable {
    case all, netease, qq, kugou, kuwo, migu, qishui, bilibili
}

/// Original nominal: BeansExclusiveIDBadgeStyle; IPA exposes two cases.
public enum BeansExclusiveIDBadgeStyle_2_0_3: CaseIterable, Hashable, Sendable {
    case blackPurpleGold, classicGold
}

/// Original nominal: ThirdPartySourceDraft; fields decoded directly from IPA metadata.
public struct ThirdPartySourceDraft_2_0_3 {
    public var id: String
    public var name: String
    public var kind: String
    public var template: String
    public var urlPath: String
    public var headersText: String
    public var quality: String
    public var scriptText: String
    public var sourceDescription: String
    public var version: String
    public var author: String
    public var homepage: String
    public var sourceURL: String?
    public var enabled: Bool
    public var platform: ThirdPartySourcePlatform_2_0_3

    public init(id: String = "", name: String = "", kind: String = "", template: String = "",
                urlPath: String = "", headersText: String = "", quality: String = "",
                scriptText: String = "", sourceDescription: String = "", version: String = "",
                author: String = "", homepage: String = "", sourceURL: String? = nil,
                enabled: Bool = false, platform: ThirdPartySourcePlatform_2_0_3 = .all) {
        self.id = id; self.name = name; self.kind = kind; self.template = template
        self.urlPath = urlPath; self.headersText = headersText; self.quality = quality
        self.scriptText = scriptText; self.sourceDescription = sourceDescription
        self.version = version; self.author = author; self.homepage = homepage
        self.sourceURL = sourceURL; self.enabled = enabled; self.platform = platform
    }
}

/// Original nominal: ThirdPartySource; fields decoded directly from IPA metadata.
public struct ThirdPartySource_2_0_3 {
    public var id: String
    public var name: String
    public var kind: String
    public var template: String
    public var urlPath: String
    public var headers: [String: String]
    public var quality: String
    public var script: String?
    public var sourceDescription: String
    public var version: String
    public var author: String
    public var homepage: String
    public var sourceURL: String?
    public var enabled: Bool

    public init(id: String = "", name: String = "", kind: String = "", template: String = "",
                urlPath: String = "", headers: [String: String] = [:], quality: String = "",
                script: String? = nil, sourceDescription: String = "", version: String = "",
                author: String = "", homepage: String = "", sourceURL: String? = nil,
                enabled: Bool = false) {
        self.id = id; self.name = name; self.kind = kind; self.template = template
        self.urlPath = urlPath; self.headers = headers; self.quality = quality
        self.script = script; self.sourceDescription = sourceDescription
        self.version = version; self.author = author; self.homepage = homepage
        self.sourceURL = sourceURL; self.enabled = enabled
    }
}

/// Original nominal: BackendResponse; all optional scalar fields are decoded exactly.
public struct BackendResponse_2_0_3 {
    public var ok: Bool?
    public var message: String?
    public var publicUserID: String?
    public var exclusiveID: Bool?
    public var exclusiveBadgeStyle: BeansExclusiveIDBadgeStyle_2_0_3?
    public var listeningSeconds: Int?
    public var listeningPlayCount: Int?
    public var blocked: Bool?
    public var downloadUnlocked: Bool?
    public var downloadGlobalEnabled: Bool?
    public var feedbackID: String?
    public var submittedAt: String?
    /// Element type remains symbolic in the IPA; the array container is known.
    public var feedbackReplies: [Any]

    public init(ok: Bool? = nil, message: String? = nil, publicUserID: String? = nil,
                exclusiveID: Bool? = nil,
                exclusiveBadgeStyle: BeansExclusiveIDBadgeStyle_2_0_3? = nil,
                listeningSeconds: Int? = nil, listeningPlayCount: Int? = nil,
                blocked: Bool? = nil, downloadUnlocked: Bool? = nil,
                downloadGlobalEnabled: Bool? = nil, feedbackID: String? = nil,
                submittedAt: String? = nil, feedbackReplies: [Any] = []) {
        self.ok = ok; self.message = message; self.publicUserID = publicUserID
        self.exclusiveID = exclusiveID; self.exclusiveBadgeStyle = exclusiveBadgeStyle
        self.listeningSeconds = listeningSeconds; self.listeningPlayCount = listeningPlayCount
        self.blocked = blocked; self.downloadUnlocked = downloadUnlocked
        self.downloadGlobalEnabled = downloadGlobalEnabled; self.feedbackID = feedbackID
        self.submittedAt = submittedAt; self.feedbackReplies = feedbackReplies
    }
}

/// Original nominal: BeansExclusiveAccessRecord; field types decoded directly.
public struct BeansExclusiveAccessRecord_2_0_3 {
    public var userID: String
    public var publicUserID: String?
    public var deviceModel: String
    public var deviceName: String
    public var systemName: String
    public var systemVersion: String
    public var appVersion: String
    public var appBuild: String
    public var lastSeenAt: String
    public var enabled: Bool
    public var badgeStyle: BeansExclusiveIDBadgeStyle_2_0_3?
    public var changedAt: String

    public init(userID: String = "", publicUserID: String? = nil, deviceModel: String = "",
                deviceName: String = "", systemName: String = "", systemVersion: String = "",
                appVersion: String = "", appBuild: String = "", lastSeenAt: String = "",
                enabled: Bool = false, badgeStyle: BeansExclusiveIDBadgeStyle_2_0_3? = nil,
                changedAt: String = "") {
        self.userID = userID; self.publicUserID = publicUserID; self.deviceModel = deviceModel
        self.deviceName = deviceName; self.systemName = systemName
        self.systemVersion = systemVersion; self.appVersion = appVersion
        self.appBuild = appBuild; self.lastSeenAt = lastSeenAt; self.enabled = enabled
        self.badgeStyle = badgeStyle; self.changedAt = changedAt
    }
}

/// Original nominal: BeansDownloadAccessRecord; field types decoded directly.
public struct BeansDownloadAccessRecord_2_0_3 {
    public var userID: String
    public var publicUserID: String?
    public var deviceModel: String
    public var deviceName: String
    public var systemName: String
    public var systemVersion: String
    public var appVersion: String
    public var appBuild: String
    public var lastSeenAt: String
    public var enabled: Bool
    public var changedAt: String
    public init(userID: String = "", publicUserID: String? = nil, deviceModel: String = "",
                deviceName: String = "", systemName: String = "", systemVersion: String = "",
                appVersion: String = "", appBuild: String = "", lastSeenAt: String = "",
                enabled: Bool = false, changedAt: String = "") {
        self.userID = userID; self.publicUserID = publicUserID; self.deviceModel = deviceModel
        self.deviceName = deviceName; self.systemName = systemName
        self.systemVersion = systemVersion; self.appVersion = appVersion
        self.appBuild = appBuild; self.lastSeenAt = lastSeenAt; self.enabled = enabled
        self.changedAt = changedAt
    }
}

/// Original nominal: ServerUpdateRecord; field types decoded directly.
public struct ServerUpdateRecord_2_0_3 {
    public var version: String
    public var title: String
    public var notes: [String]
    public var ipaURL: String?
    public var notesImageURL: String?
    public var notesTextColor: String?
    public var build: String?
    public var channel: String?
    public var minIOS: String?
    public var maxIOS: String?
    public var status: String?
    public init(version: String = "", title: String = "", notes: [String] = [], ipaURL: String? = nil,
                notesImageURL: String? = nil, notesTextColor: String? = nil, build: String? = nil,
                channel: String? = nil, minIOS: String? = nil, maxIOS: String? = nil,
                status: String? = nil) {
        self.version = version; self.title = title; self.notes = notes; self.ipaURL = ipaURL
        self.notesImageURL = notesImageURL; self.notesTextColor = notesTextColor
        self.build = build; self.channel = channel; self.minIOS = minIOS
        self.maxIOS = maxIOS; self.status = status
    }
}
