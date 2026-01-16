import DownloadClient
import SwiftUI

/// Settings view for download preferences
struct DownloadSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DownloadManager.self) private var downloadManager: DownloadManager?

    @AppStorage("downloadQuality") private var downloadQuality: String = DownloadQuality.high.rawValue
    @AppStorage("wifiOnlyDownloads") private var wifiOnlyDownloads: Bool = true
    @AppStorage("deleteWhenWatched") private var deleteWhenWatched: Bool = false
    @AppStorage("maxStorageGB") private var maxStorageGB: Double = 0 // 0 = unlimited

    @State private var availableStorage: Int64 = 0
    @State private var usedStorage: Int64 = 0

    var body: some View {
        NavigationStack {
            Form {
                // Quality Section
                Section {
                    Picker("Download Quality", selection: $downloadQuality) {
                        ForEach(DownloadQuality.allCases, id: \.rawValue) { quality in
                            Text(quality.displayName)
                                .tag(quality.rawValue)
                        }
                    }
                } header: {
                    Text("Quality")
                } footer: {
                    Text("Higher quality uses more storage space.")
                }

                // Network Section
                Section {
                    Toggle("WiFi Only", isOn: $wifiOnlyDownloads)
                        .onChange(of: wifiOnlyDownloads) { _, newValue in
                            Task {
                                await downloadManager?.setWiFiOnlyEnabled(newValue)
                            }
                        }
                } header: {
                    Text("Network")
                } footer: {
                    Text("When enabled, downloads will only start on WiFi connections.")
                }

                // Storage Section
                Section {
                    HStack {
                        Text("Used by Downloads")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: usedStorage, countStyle: .file))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Available")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: availableStorage, countStyle: .file))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Storage Limit")
                            Spacer()
                            Text(maxStorageGB == 0 ? "Unlimited" : "\(Int(maxStorageGB)) GB")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $maxStorageGB, in: 0 ... 100, step: 5)
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Set a maximum storage limit for downloads. Set to 0 for unlimited.")
                }

                // Cleanup Section
                Section {
                    Toggle("Delete When Watched", isOn: $deleteWhenWatched)
                } header: {
                    Text("Cleanup")
                } footer: {
                    Text("Automatically delete downloaded episodes after watching.")
                }

                // Auto-Download Section
                Section {
                    NavigationLink {
                        AutoDownloadRulesView()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.dotted")
                            Text("Auto-Download Rules")
                        }
                    }
                } header: {
                    Text("Automation")
                } footer: {
                    Text("Configure automatic downloading of new episodes.")
                }

                // Clear All Section
                Section {
                    Button(role: .destructive) {
                        clearAllDownloads()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Downloads")
                        }
                    }
                }
            }
            .navigationTitle("Download Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadStorageInfo()
                // Sync WiFi-only setting with download manager on load
                await downloadManager?.setWiFiOnlyEnabled(wifiOnlyDownloads)
            }
        }
    }

    private func loadStorageInfo() async {
        if let manager = downloadManager {
            usedStorage = manager.totalDownloadedSize
        }

        // Get available storage
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let resourceValues = try documentsPath
                .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            availableStorage = resourceValues.volumeAvailableCapacityForImportantUsage ?? 0
        } catch {
            availableStorage = 0
        }
    }

    private func clearAllDownloads() {
        guard let manager = downloadManager else { return }

        Task {
            for download in manager.downloads {
                try? await manager.deleteDownload(download.id)
            }
        }
    }
}

/// View for managing auto-download rules
struct AutoDownloadRulesView: View {
    var body: some View {
        List {
            Section {
                ContentUnavailableView(
                    "Coming Soon",
                    systemImage: "clock",
                    description: Text("Auto-download rules will be available in a future update.")
                )
            }
        }
        .navigationTitle("Auto-Download Rules")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    DownloadSettingsView()
}
