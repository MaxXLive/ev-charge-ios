//
//  DataSourcePicker.swift
//  evcharge
//
//  Auswahl der Charger-Datenquelle(n) (Onboarding + Einstellungen).
//  Mehrfachauswahl erlaubt; bei erster Mehrfachauswahl einmaliger Hinweis-Alert.
//

import SwiftUI

/// In NavigationStack gepushte Variante (Einstellungen).
struct DataSourcePicker: View {
    var body: some View {
        DataSourceList()
            .navigationTitle("Datenquellen")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Reine Auswahlliste (auch im Onboarding ohne Navigation nutzbar).
struct DataSourceList: View {
    @AppStorage("dataSources") private var dataSourcesRaw: String = ""
    @AppStorage("multiSourceAlertShown") private var alertShown = false
    @State private var showAlert = false

    private var selectedSources: Set<DataSourceID> {
        // dataSourcesRaw referenzieren damit SwiftUI re-rendert wenn sich der Wert ändert.
        let raw = dataSourcesRaw
        let ids = raw.split(separator: ",").compactMap { DataSourceID(rawValue: String($0)) }
        return ids.isEmpty ? [DataSourceID.selected] : Set(ids)
    }

    var body: some View {
        List {
            Section {
                ForEach(DataSourceID.allCases) { source in
                    row(source)
                }
            } footer: {
                if selectedSources.count > 1 {
                    Text("Mehrere Quellen aktiv: Einträge können doppelt erscheinen. Nicht von allen Quellen unterstützte Filter werden ausgegraut angezeigt.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Weitere Quellen werden ergänzt, sobald ihre Anbindung verfügbar ist.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .alert("Mehrere Datenquellen", isPresented: $showAlert) {
            Button("Verstanden", role: .cancel) { alertShown = true }
        } message: {
            Text("Mit mehreren aktiven Quellen können Ladestationen doppelt auf der Karte erscheinen, da verschiedene Quellen dieselbe Station führen können. Außerdem stehen nur Filter zur Verfügung, die alle gewählten Quellen gemeinsam unterstützen.")
        }
    }

    private func row(_ source: DataSourceID) -> some View {
        Button {
            guard source.isAvailable else { return }
            toggle(source)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(source.displayName)
                            .foregroundStyle(source.isAvailable ? .primary : .secondary)
                        if !source.isAvailable {
                            Text("bald")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.secondary.opacity(0.2), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(source.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedSources.contains(source) {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
        .disabled(!source.isAvailable)
    }

    private func toggle(_ source: DataSourceID) {
        var newSet = selectedSources
        if newSet.contains(source) {
            if newSet.count > 1 { newSet.remove(source) }
        } else {
            newSet.insert(source)
            if newSet.count > 1 && !alertShown { showAlert = true }
        }
        DataSourceID.selectedSet = newSet
    }
}
