import Combine
import Foundation

// Matches the observed connection preference key; commits only after credentials are saved.
@MainActor
final class WebDAVStore: ObservableObject {
    static let shared = WebDAVStore()
    @Published private(set) var connection: WebDAVConnection?
    private let defaults: UserDefaults
    private let key = "beans.webdav.connection.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key) { connection = try? JSONDecoder().decode(WebDAVConnection.self, from: data) }
    }

    func save(_ connection: WebDAVConnection, password: String) throws {
        _ = try WebDAVPaths.root(for: connection)
        let data = try JSONEncoder().encode(connection)
        try WebDAVCredentialStore.save(password: password, id: connection.id)
        defaults.set(data, forKey: key)
        if let previous = self.connection, previous.id != connection.id { try? WebDAVCredentialStore.remove(id: previous.id) }
        self.connection = connection
    }

    func disconnect() throws {
        if let connection { try WebDAVCredentialStore.remove(id: connection.id) }
        defaults.removeObject(forKey: key)
        connection = nil
    }

    func client(for track: WebDAVTrack? = nil) throws -> WebDAVClient {
        guard let connection else { throw WebDAVError.missingConnection }
        if let track { guard track.connectionID == connection.id, track.accountKey == connection.accountKey else { throw WebDAVError.missingConnection } }
        return try WebDAVClient(connection: connection)
    }
}
