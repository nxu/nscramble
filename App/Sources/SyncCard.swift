import SwiftUI

/// Bottom of the stats sidebar: "Sync now", status, and access to the sync settings.
struct SyncCard: View {
    /// The sidebar separates the card from the stats above it; the Sync tab doesn't need that.
    var showsTopDivider = true

    @Environment(AppModel.self) private var model
    @State private var showingSettings = false

    private static let buttonHeight: CGFloat = 40
    private static let buttonBorder = RoundedRectangle(cornerRadius: 8).strokeBorder(.separator)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    Task { await model.syncNow() }
                } label: {
                    Text(model.syncStatus == .syncing ? "Syncing…" : "Sync now")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .background(Self.buttonBorder)
                }
                .buttonStyle(.plain)
                .disabled(model.syncStatus == .syncing)

                Button {
                    showingSettings = true
                } label: {
                    Image("cog")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.secondary)
                        .frame(width: Self.buttonHeight, height: Self.buttonHeight)
                        .contentShape(Rectangle())
                        .background(Self.buttonBorder)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sync settings")
                .help("Server URL and API key")
            }
            .frame(height: Self.buttonHeight)

            statusText
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .overlay(alignment: .top) {
            if showsTopDivider {
                Divider()
            }
        }
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
        content
            .onAppear {
                url = model.syncURL
                autoSync = model.autoSync
            }
    }

    private var canSave: Bool {
        !url.isEmpty && (model.hasAPIKey || !apiKey.isEmpty)
    }

    private var apiKeyPrompt: String {
        model.hasAPIKey ? "Saved in Keychain – enter to replace" : "API key"
    }

    #if os(iOS)
    /// iPhone/iPad: a native grouped form with toolbar buttons.
    private var content: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://sync.example.com", text: $url)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Server URL")
                }

                Section {
                    SecureField(apiKeyPrompt, text: $apiKey)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("API key")
                } footer: {
                    Text("Stored in the Keychain on this device.")
                }

                Section {
                    Toggle("Sync automatically", isOn: $autoSync)
                } footer: {
                    Text("On launch, every hour while the app is open, and after every 10 solves.")
                }

                if let error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }

                if model.hasAPIKey {
                    Section {
                        Button("Remove API key", role: .destructive) {
                            model.removeAPIKey()
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }
    #else
    /// Mac: a compact panel.
    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sync")
                .font(.system(size: 17, weight: .semibold, design: .monospaced))

            VStack(alignment: .leading, spacing: 6) {
                Text("Server URL").foregroundStyle(.secondary)
                TextField("https://sync.example.com", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("API key").foregroundStyle(.secondary)
                SecureField(apiKeyPrompt, text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("Sync automatically (on launch, hourly, and every 10 solves)", isOn: $autoSync)

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
                    .disabled(!canSave)
            }
        }
        .font(.system(size: 13, design: .monospaced))
        .padding(24)
        .frame(minWidth: 420)
    }
    #endif

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
