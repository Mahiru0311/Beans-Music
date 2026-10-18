import Foundation

// Endpoint string catalog extracted from the supplied Beans 2.0.3 build 2 executable.
// These are literal-string evidence records; the IPA does not preserve a unique source-level call-site for every URL.
public enum Beans203EndpointCatalog {
    /// Mach-O/Ghidra address: 0x100799970; exact URL string evidence.
    public static let kuwoSearch = "https://search.kuwo.cn/r.s"
    /// Mach-O/Ghidra address: 0x100799d50; exact URL string evidence.
    public static let kugouRetrySpecialSearch = "https://msearchretry.kugou.com/api/v3/search/special"
    /// Mach-O/Ghidra address: 0x1007a3a60; exact URL string evidence.
    public static let kugouMixedSearch = "https://gateway.kugou.com/complexsearch/v3/search/mixed"
    /// Mach-O/Ghidra address: 0x1007a3860; exact URL string evidence.
    public static let kugouSongSearch = "https://songsearch.kugou.com/song_search_v2"
    /// Mach-O/Ghidra address: 0x10079c160; exact URL string evidence.
    public static let bilibiliAPIBase = "https://api.bilibili.com"
    /// Mach-O/Ghidra address: 0x10079bd80; exact URL string evidence.
    public static let bilibiliWeb = "https://www.bilibili.com"
    /// Mach-O/Ghidra address: 0x1007aa650; exact URL string evidence.
    public static let neteaseInterfaceBase = "https://interface.music.163.com"
    /// Mach-O/Ghidra address: 0x1007ae570; exact URL string evidence.
    public static let neteasePlaylistDetail = "https://music.163.com/api/v6/playlist/detail"
    /// Mach-O/Ghidra address: 0x1007a1120; exact URL string evidence.
    public static let qqWeb = "https://y.qq.com/"
    /// Mach-O/Ghidra address: 0x1007b1d50; exact URL string evidence.
    public static let qqMusicAPI = "https://u.y.qq.com/cgi-bin/musicu.fcg"
    /// Mach-O/Ghidra address: 0x1007b2020; exact URL string evidence.
    public static let qqSearch = "https://c.y.qq.com/soso/fcgi-bin/search_for_qq_cp"
    /// Mach-O/Ghidra address: 0x100799b40; exact URL string evidence.
    public static let miguSearch = "https://jadeite.migu.cn/music_search/v3/search/searchAll"
    /// Mach-O/Ghidra address: 0x10079f5b0; exact URL string evidence.
    public static let beansBackend = "http://189.24.78.193/beans"
    /// Mach-O/Ghidra address: 0x1007b3a40; exact URL string evidence.
    public static let qishuiBackend = "http://189.24.78.193/qishui"
    /// Mach-O/Ghidra address: 0x1007b6050; exact URL string evidence.
    public static let webDAVPlaceholder = "https://webdav.invalid/root/"
    /// Mach-O/Ghidra address: 0x1007b5ee0; exact URL string evidence.
    public static let githubLatestRelease = "https://github.com/XIaodou0416/Beans-Music/releases/latest"
}
