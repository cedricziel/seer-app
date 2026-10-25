import CoreLocation
import SeerCore
import SwiftUI

struct InternalURLSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let config: ServerConfiguration

    @State private var internalURLString: String
    @State private var networkSSIDs: [String]
    @State private var newSSID: String = ""
    @State private var showingAddNetworkAlert = false
    @State private var urlValidationError: String?

    @StateObject private var wifiMonitor = WiFiSSIDMonitor.shared

    init(config: ServerConfiguration) {
        self.config = config
        _internalURLString = State(initialValue: config.internalJellyfinURL?.absoluteString ?? "")
        _networkSSIDs = State(initialValue: config.internalNetworkSSIDs)
    }

    var body: some View {
        Form {
            Section {
                TextField("Internal URL", text: $internalURLString)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onChange(of: internalURLString) {
                        if urlValidationError != nil {
                            validateInternalURL()
                        }
                    }

                if let urlValidationError {
                    Text(urlValidationError)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("internalURLValidationError")
                }
            } header: {
                Text("Internal URL")
            } footer: {
                Text("The URL to use when connected to your home network (e.g., http://192.168.1.100:8096)")
            }

            Section {
                ForEach(networkSSIDs, id: \.self) { ssid in
                    HStack {
                        Image(systemName: "wifi")
                            .foregroundStyle(.secondary)
                        Text(ssid)
                        Spacer()
                        if ssid == wifiMonitor.currentSSID {
                            Text("Connected")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .onDelete(perform: deleteSSIDs)

                Button {
                    showingAddNetworkAlert = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Network")
                    }
                }

                if let currentSSID = wifiMonitor.currentSSID,
                   !networkSSIDs.contains(currentSSID) {
                    Button {
                        addCurrentNetwork()
                    } label: {
                        HStack {
                            Image(systemName: "wifi.circle.fill")
                            Text("Add Current Network (\(currentSSID))")
                        }
                    }
                }
            } header: {
                Text("Home Networks")
            } footer: {
                if wifiMonitor.hasLocationPermission {
                    Text("When connected to any of these WiFi networks, the internal URL will be used.")
                } else {
                    Text("Location permission is required to detect your WiFi network name.")
                }
            }

            if !wifiMonitor.hasLocationPermission {
                Section {
                    switch wifiMonitor.locationAuthorizationStatus {
                    case .denied:
                        Button("Open Settings", systemImage: "gear") {
                            openLocationSettings()
                        }
                    case .restricted:
                        Text(
                            "Location access is restricted. Check device restrictions to allow WiFi network detection."
                        )
                    case .notDetermined:
                        Button("Grant Location Permission", systemImage: "location.fill") {
                            wifiMonitor.requestLocationPermission()
                        }
                    default:
                        EmptyView()
                    }
                } footer: {
                    Text(
                        "Location access enables WiFi detection. Manual URL and network entry remain available."
                    )
                }
            }

            if config.hasInternalURL {
                Section {
                    Button(role: .destructive) {
                        clearInternalSettings()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove Internal URL Settings")
                        }
                    }
                }
            }
        }
        .navigationTitle("Internal URL")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
                .fontWeight(.semibold)
            }
        }
        .alert("Add Network", isPresented: $showingAddNetworkAlert) {
            TextField("WiFi Network Name", text: $newSSID)
            Button("Cancel", role: .cancel) {
                newSSID = ""
            }
            Button("Add") {
                addNetwork(newSSID)
                newSSID = ""
            }
        } message: {
            Text("Enter the name (SSID) of your home WiFi network.")
        }
    }

    private func openLocationSettings() {
        #if canImport(UIKit)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        #elseif os(macOS)
            if let url =
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                openURL(url)
            }
        #endif
    }

    private func deleteSSIDs(at offsets: IndexSet) {
        networkSSIDs.remove(atOffsets: offsets)
    }

    private func addCurrentNetwork() {
        guard let currentSSID = wifiMonitor.currentSSID,
              !networkSSIDs.contains(currentSSID)
        else {
            return
        }
        networkSSIDs.append(currentSSID)
    }

    private func addNetwork(_ ssid: String) {
        let trimmed = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !networkSSIDs.contains(trimmed) else { return }
        networkSSIDs.append(trimmed)
    }

    private func clearInternalSettings() {
        internalURLString = ""
        networkSSIDs = []
        saveChanges()
    }

    private func validateInternalURL() {
        do {
            _ = try InternalServerURL.parse(internalURLString)
            urlValidationError = nil
        } catch {
            urlValidationError = error.localizedDescription
        }
    }

    private func saveChanges() {
        let internalURL: URL?
        do {
            internalURL = try InternalServerURL.parse(internalURLString)
            urlValidationError = nil
        } catch {
            urlValidationError = error.localizedDescription
            return
        }

        config.internalJellyfinURL = internalURL
        config.internalNetworkSSIDs = networkSSIDs
        appState.updateServer(config)
        dismiss()
    }
}
