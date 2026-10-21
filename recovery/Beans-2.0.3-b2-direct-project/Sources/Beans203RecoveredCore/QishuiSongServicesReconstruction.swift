import Foundation

/// Direct nominal fields: SongComment 0x7c80a4; URL/Date confirmed by 0x100570f78.
public struct SongComment_2_0_3 {
    public var id: Int
    public var content: String
    public var nickname: String
    public var avatarURL: URL?
    public var time: Date
    public var likedCount: Int
    public var isHot: Bool
}

/// Direct nominal 0x7c83cc; array element type confirmed by the comment mapper.
public struct SongCommentPage_2_0_3 {
    public var total: Int
    public var hot: [SongComment_2_0_3]
    public var comments: [SongComment_2_0_3]
}

extension QishuiAPI_2_0_3 {
    /// 0x100564870 / 0x100564990. Public spelling is a reconstruction seam.
    public func lyrics(for song: Song_2_0_3) async throws -> String? {
        guard let id = song.qishuiID, !id.isEmpty else { return nil }
        let object = try await requestObject("/lyric", query: ["track_id": id])
        return Self.firstString(object, keys: ["lyric", "lyrics", "content", "lrc"])
    }

    /// 0x100566e9c / 0x100566ff4 / 0x1005671b8. Network errors propagate;
    /// /audio/info is requested only when a successful detail response lacks a URL.
    public func playbackURL(for song: Song_2_0_3) async throws -> URL? {
        guard let id = song.qishuiID, !id.isEmpty else { return nil }
        let query = ["track_id": id]
        let detail = try await requestObject("/song/detail", query: query)
        if let url = Self.playbackURL(in: detail) { return url }
        let audio = try await requestObject("/audio/info", query: query)
        return Self.playbackURL(in: audio)
    }

    /// 0x100565048 / 0x1005651dc. Total counts mapped comments, not server total.
    public func comments(for song: Song_2_0_3, limit: Int) async throws -> SongCommentPage_2_0_3 {
        guard let id = song.qishuiID, !id.isEmpty else {
            return SongCommentPage_2_0_3(total: 0, hot: [], comments: [])
        }
        let object = try await requestObject("/comment", query: [
            "track_id": id, "count": String(min(50, max(1, limit)))
        ])
        let comments = dictionaryArray(object["comments"] ?? object["data"] ?? object)
            .compactMap { Self.makeComment($0) }
        return SongCommentPage_2_0_3(total: comments.count, hot: [], comments: comments)
    }

    /// 0x10057065c. Unlike the artwork parser, any non-nil scheme is accepted.
    /// Unkeyed dictionary traversal follows Swift dictionary order as in the binary.
    public static func playbackURL(in object: [String: Any]) -> URL? {
        let keys = ["audio_url", "play_url", "main_url", "backup_url"]
        for key in keys {
            if let text = object[key] as? String, let url = URL(string: text), url.scheme != nil {
                return url
            }
            if let child = object[key] as? [String: Any], let url = playbackURL(in: child) {
                return url
            }
        }
        for value in object.values {
            if let child = value as? [String: Any], let url = playbackURL(in: child) { return url }
            if let children = value as? [[String: Any]] {
                // The original array branch gates on the FIRST preferred key.
                for child in children where child[keys[0]] != nil {
                    if let url = playbackURL(in: child) { return url }
                }
            }
        }
        return nil
    }

    /// Mapper 0x100570f78. now/identifierGenerator permit deterministic offline tests.
    /// Numeric rejection is defensive: the binary traps on unrepresentable like counts.
    public static func makeComment(
        _ object: [String: Any], now: Date = Date(),
        identifierGenerator: () -> String = { UUID().uuidString }
    ) -> SongComment_2_0_3? {
        let identifier = firstString(object, keys: ["id", "comment_id", "commentId"])
            ?? identifierGenerator()
        let nickname = firstString(object, keys: ["user_name", "nickname", "userName"]) ?? "汽水用户"
        guard let content = firstString(object, keys: ["content", "text", "comment_text"]) else { return nil }
        let avatar = firstString(object, keys: ["user_avatar", "avatar_url", "avatarUrl"])
            .flatMap { URL(string: $0) }
        let rawTime = number(object["timestamp"] ?? object["create_time"] ?? object["time"])
        let seconds = rawTime > 10_000_000_000 ? rawTime / 1000 : rawTime
        let time = seconds > 0 ? Date(timeIntervalSince1970: seconds) : now
        let likes = number(object["like_count"] ?? object["likeCount"])
        guard likes.isFinite, likes > Double(Int.min), likes < Double(Int.max) else { return nil }
        return SongComment_2_0_3(id: stableID(identifier), content: content, nickname: nickname,
                                 avatarURL: avatar, time: time, likedCount: Int(likes), isHot: false)
    }
}
