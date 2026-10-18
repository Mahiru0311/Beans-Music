import SwiftUI
import Beans203RecoveredCore

// UI-only reconstruction from Beans 2.0.3 build 2 Swift field metadata and
// the WebDAVView.swift source-path/string literals in Beans.app/Beans.
// Stored-property names are direct; property wrapper/value types are marked inferred.

struct WebDAVView_2_0_3: View {
    @Environment(\.dismiss) private var dismiss
    let store: WebDAVStore_2_0_3
    @State private var section = ""
    @State private var showConnection = false
    @State private var confirmClear = false
    @State private var message: String?
    @State private var showPlayer = false

    var body: some View {
        List {
            Section {
                Button("beans.webdav.connect") { showConnection = true }
                if let message { Text(message) }
            }
            Section {
                Button("beans.webdav.backup") { }
            }
        }
        .sheet(isPresented: $showConnection) {
            WebDAVConnectionView_2_0_3(store: store)
        }
        .navigationTitle("webDAV")
    }
}

struct WebDAVConnectionView_2_0_3: View {
    @Environment(\.dismiss) private var dismiss
    let store: WebDAVStore_2_0_3
    @State private var draft = WebDAVConnection_2_0_3(
        id: UUID(), address: "", username: "", allowHTTP: false
    )
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    @State private var confirmHTTP = false
    @State private var confirmDisconnect = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        Form {
            Section {
                TextField("beans.webdav.address", text: $draft.address)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
#endif
                TextField("beans.webdav.username", text: $draft.username)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                SecureField("beans.webdav.password", text: $password)
                Toggle("beans.webdav.http", isOn: $draft.allowHTTP)
            }
            Section {
                Button("beans.webdav.test") { }
                    .accessibilityIdentifier("beans.webdav.test")
                Button("beans.webdav.save") { }
                    .accessibilityIdentifier("beans.webdav.save")
                if let message { Text(message) }
            }
        }
        .navigationTitle("webDAV")
        .toolbar { Button("beans.webdav.close") { dismiss() } }
    }
}

struct WebDAVBackupView_2_0_3: View {
    @Environment(\.dismiss) private var dismiss
    let store: WebDAVStore_2_0_3
    @State private var entries: [WebDAVEntry_2_0_3] = []
    @State private var busy = false
    @State private var message: String?
    // The concrete preview element type is not preserved in the IPA metadata.
    @State private var preview: [String] = []
    @State private var includeSettings = true
    @State private var showPreview = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        List(entries, id: \.url) { entry in
            Text(entry.name)
        }
        .navigationTitle("beans.webdav.backup")
        .toolbar {
            Button("beans.webdav.backup-record") { }
        }
        // Direct decompilation shows refreshable/task and sheet construction;
        // the transfer closure body remains unresolved.
        .refreshable { }
        .sheet(isPresented: $showPreview) {
            List(preview, id: \.self) { Text($0) }
        }
    }
}

struct WebDAVBrowserView_2_0_3: View {
    let directory: WebDAVEntry_2_0_3
    let store: WebDAVStore_2_0_3
    @State private var entries: [WebDAVEntry_2_0_3] = []
    @State private var busy = false
    @State private var message: String?
    @State private var favorite = false
    @State private var search = ""

    var body: some View {
        List(filteredEntries, id: \.url) { entry in
            Text(entry.name)
        }
        .searchable(text: $search)
        .navigationTitle(directory.name)
    }

    /// The binary's filter function lowercases path extensions and applies a
    /// case-insensitive search predicate. The supported-extension set itself
    /// is not uniquely recoverable from the stripped binary, so this scaffold
    /// preserves the directly observable search behavior.
    private var filteredEntries: [WebDAVEntry_2_0_3] {
        guard !search.isEmpty else { return entries }
        return entries.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }
}
