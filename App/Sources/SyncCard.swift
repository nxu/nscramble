import SwiftUI

/// Bottom of the stats sidebar: "Sync now", status, and access to the sync settings.
struct SyncCard: View {
    @Environment(AppModel.self) private var model
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 10) {
            Button {
                Task { await model.syncNow() }
            } label: {
                Text(model.syncStatus == .syncing ? "Syncing…" : "Sync now")
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .background(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            }
            .buttonStyle(.plain)
            .disabled(model.syncStatus == .syncing)

            HStack(alignment: .firstTextBaseline) {
                statusText
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("API key") { showingSettings = true }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 11, design: .monospaced))
        }
        .padding(20)
        .overlay(alignment: .top) { Divider() }
        .sheet(isPresented: $showingSettings) {
            SyncSettingsSheet()
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch model.syncStatus {
        case .never:
            Text(model.hasAPIKey ? "Not synced yet" : "No API key")
                .foregroundStyle(.tertiary)
        case .syncing:
            Text("Syncing…")
                .foregroundStyle(.tertiary)
        case .synced(let date):
            Text("Synced \(date, format: .dateTime.hour().minute())")
                .foregroundStyle(.tertiary)
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
        }
    }
}

/// Server URL (UserDefaults) and API key (Keychain).
struct SyncSettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var apiKey = ""
    @State private var autoSync = true
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sync")
                .font(.system(size: 17, weight: .semibold, design: .monospaced))

            VStack(alignment: .leading, spacing: 6) {
                Text("Server URL").foregroundStyle(.secondary)
                TextField("https://sync.example.com", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("API key").foregroundStyle(.secondary)
                SecureField(model.hasAPIKey ? "Saved in Keychain – enter to replace" : "API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("Sync automatically (on launch and every 2 hours)", isOn: $autoSync)

            if let error {
                Text(error).foregroundStyle(.red)
            }

            HStack {
                if model.hasAPIKey {
                    Button("Remove key", role: .destructive) {
                        model.removeAPIKey()
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(url.isEmpty || (!model.hasAPIKey && apiKey.isEmpty))
            }
        }
        .font(.system(size: 13, design: .monospaced))
        .padding(24)
        .frame(minWidth: 420)
        .onAppear {
            url = model.syncURL
            autoSync = model.autoSync
        }
    }

    private func save() {
        do {
            try model.saveSyncSettings(url: url, apiKey: apiKey)
            model.autoSync = autoSync
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
