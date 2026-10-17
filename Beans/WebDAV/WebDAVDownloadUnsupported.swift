import Foundation

struct WebDAVDownloadUnsupported: LocalizedError {
    var errorDescription: String? { "WebDAV 歌曲使用原文件播放缓存，不支持平台音质下载。" }
}
