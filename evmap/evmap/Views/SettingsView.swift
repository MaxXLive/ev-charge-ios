//
//  SettingsView.swift
//  evmap
//

import SwiftUI
import UIKit

enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Hell")
        case .dark: return String(localized: "Dunkel")
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum DistanceUnit: String, CaseIterable, Identifiable {
    case kilometers, miles
    var id: String { rawValue }
    var label: String { self == .kilometers ? String(localized: "Kilometer") : String(localized: "Meilen") }
}

struct SettingsView: View {
    @AppStorage("appearance") private var appearance: AppearanceSetting = .system
    @AppStorage("units") private var units: DistanceUnit = .kilometers
    @AppStorage("onboardingDone") private var onboardingDone = false
    @AppStorage("dataSources") private var dataSourcesRaw: String = ""
    @AppStorage("dataSource") private var selectedRaw = DataSourceID.goingElectric.rawValue
    @Environment(TeslaAuthManager.self) private var teslaAuth
    @State private var teslaError: String?

    private var activeSourcesLabel: String {
        let ids = dataSourcesRaw.split(separator: ",").compactMap { DataSourceID(rawValue: String($0)) }
        if ids.count > 1 { return String(localized: "\(ids.count) Quellen") }
        let single = ids.first ?? DataSourceID(rawValue: selectedRaw) ?? .goingElectric
        return single.displayName
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Darstellung") {
                    Picker("Erscheinungsbild", selection: $appearance) {
                        ForEach(AppearanceSetting.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Einheiten", selection: $units) {
                        ForEach(DistanceUnit.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link(destination: url) {
                            HStack {
                                Text("App-Sprache")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Sprache")
                } footer: {
                    Text("Die Sprache der App folgt den Systemeinstellungen. Über „App-Sprache“ öffnest du die iOS-Einstellungen, um eine andere Sprache nur für EVMap zu wählen.")
                }

                Section("Datenquelle") {
                    NavigationLink {
                        DataSourcePicker()
                    } label: {
                        HStack {
                            Text("Aktive Quelle")
                            Spacer()
                            Text(activeSourcesLabel).foregroundStyle(.secondary)
                        }
                    }
                    if DataSourceID.selectedSet.contains(.goingElectric), !Secrets.hasGoingElectricKey {
                        Label("Kein API-Key hinterlegt (Secrets.plist)", systemImage: "key.fill")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }

                teslaSection

                Section("Über") {
                    NavigationLink("Lizenzen & Credits") { AboutView() }
                    Button("Einführung erneut zeigen") { onboardingDone = false }
                }
            }
            .navigationTitle("Einstellungen")
        }
    }

    @ViewBuilder private var teslaSection: some View {
        Section {
            if teslaAuth.isLoggedIn {
                HStack {
                    Text("Angemeldet als")
                    Spacer()
                    Text(teslaAuth.email ?? "").foregroundStyle(.secondary)
                }
                Button("Abmelden", role: .destructive) { teslaAuth.logout() }
            } else {
                Button {
                    Task {
                        do { try await teslaAuth.login() }
                        catch is CancellationError {}
                        catch {
                            if (error as NSError).domain != "com.apple.AuthenticationServices.WebAuthenticationSession" {
                                teslaError = error.localizedDescription
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("Mit Tesla anmelden")
                        if teslaAuth.isWorking {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(teslaAuth.isWorking)
            }
        } header: {
            Text("Tesla-Konto")
        } footer: {
            Text("Anmelden, um Echtzeitdaten und Preise für Tesla Supercharger zu sehen. Kein Tesla-Fahrzeug nötig.")
        }
        .alert("Anmeldung fehlgeschlagen", isPresented: Binding(
            get: { teslaError != nil }, set: { if !$0 { teslaError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(teslaError ?? "")
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Spacer()
                    Image("WelcomeLogo")
                        .resizable().scaledToFit()
                        .frame(width: 44, height: 44)
                    Text("EVMap iOS").font(.title2.bold())
                    Spacer()
                }
                .listRowBackground(Color.clear)
                Text("EVMap iOS ist eine native SwiftUI-Portierung der quelloffenen Android-App EVMap.")
            }
            Section("Original") {
                Link("EVMap (Android) auf GitHub", destination: URL(string: "https://github.com/ev-map/EVMap")!)
                Text("© 2020–2026 Johan von Forstner und Mitwirkende. Lizenz: MIT.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Daten") {
                Link("GoingElectric.de", destination: URL(string: "https://www.goingelectric.de/")!)
                Text("Ladestationsdaten von der GoingElectric-Community.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Lizenzen & Credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}
