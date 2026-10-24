import Foundation

/// 歌单广场分类。remoteID 由对应平台接口提供，全部分类使用 nil。
struct PlaylistSquareCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let remoteID: Int?

    static let all = PlaylistSquareCategory(id: "all", name: "全部", remoteID: nil)
}
