//
//  FilterView.swift
//  evcharge
//
//  Filter-Einstellungen + Filter-Profile (Android-Pendant: FilterFragment / FilterProfilesFragment).
//

import SwiftData
import SwiftUI

struct FilterView: View {
    let model: MapViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FilterProfileEntity.dateCreated, order: .reverse) private var profiles: [FilterProfileEntity]

    @State private var working: FilterValues = []
    @State private var showSaveDialog = false
    @State private var newProfileName = ""
    @State private var unsupportedAlertKey: String? = nil
    @State private var didLoadReferenceData = false

    var body: some View {
        NavigationStack {
            Form {
                if !profiles.isEmpty {
                    Section("Profile") {
                        ForEach(profiles) { profile in
                            Button {
                                working = mergedValues(from: profile.filterValues)
                            } label: {
                                Label(profile.name, systemImage: "slider.horizontal.3")
                            }
                        }
                        .onDelete(perform: deleteProfiles)
                    }
                }

                ForEach(working.indices, id: \.self) { index in
                    let item = working[index]
                    let missingFrom = unsupportedSources(for: item.value.key)
                    filterRow(item, missingFrom: missingFrom)
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zurücksetzen") {
                        working = defaultValues()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Anwenden") { apply() }
                        Button("Als Profil speichern…") { showSaveDialog = true }
                    } label: {
                        Text("Fertig").bold()
                    }
                }
            }
            .alert("Profil speichern", isPresented: $showSaveDialog) {
                TextField("Name", text: $newProfileName)
                Button("Speichern") { saveProfile() }
                Button("Abbrechen", role: .cancel) {}
            }
            .onAppear {
                if working.isEmpty { working = model.currentFilterValues() }
            }
            .task {
                // Nur EINMAL nach RD-Load: sonst würde jedes erneute Erscheinen
                // (z.B. Rück-Navigation aus der Mehrfachauswahl) die laufende Auswahl überschreiben.
                guard !didLoadReferenceData else { return }
                await model.loadReferenceDataIfNeeded()
                didLoadReferenceData = true
                // Filterliste neu aufbauen (Union kann sich erweitern) – bestehende
                // Edits aus `working` dabei erhalten statt zurückzusetzen.
                working = model.availableFilters.map { f in
                    FilterWithValue(filter: f, value: working.first { $0.value.key == f.key }?.value ?? f.defaultValue)
                }
            }
            .alert(
                "Nicht von allen Quellen unterstützt",
                isPresented: Binding(
                    get: { unsupportedAlertKey != nil },
                    set: { if !$0 { unsupportedAlertKey = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                if let key = unsupportedAlertKey,
                   let missing = model.partiallyUnsupportedFilters[key] {
                    let names = missing.joined(separator: ", ")
                    Text("Dieser Filter wird von \(names) nicht bereitgestellt und hat dort keine Wirkung.")
                }
            }
        }
    }

    // MARK: - Filter-Zeilen

    @ViewBuilder private func filterRow(_ item: FilterWithValue, missingFrom: [String]?) -> some View {
        let isPartial = missingFrom != nil
        Group {
            switch item.filter {
            case let .boolean(key, name):
                HStack {
                    Toggle(name, isOn: boolBinding(key))
                        .opacity(isPartial ? 0.4 : 1)
                    if isPartial { infoButton(key: key) }
                }
            case let .slider(key, name, min, max, steps, unit):
                HStack(alignment: .top) {
                    sliderRow(key: key, name: name, min: min, max: max, steps: steps, unit: unit)
                        .opacity(isPartial ? 0.4 : 1)
                    if isPartial { infoButton(key: key) }
                }
            case let .multipleChoice(key, name, choices, _, _):
                HStack {
                    NavigationLink {
                        MultiChoiceView(title: name, choices: choices, selection: multiChoiceBinding(key))
                    } label: {
                        HStack {
                            Text(name).opacity(isPartial ? 0.4 : 1)
                            Spacer()
                            Text(multiChoiceSummary(key)).foregroundStyle(.secondary).opacity(isPartial ? 0.4 : 1)
                        }
                    }
                    if isPartial { infoButton(key: key) }
                }
            }
        }
    }

    private func infoButton(key: String) -> some View {
        Button {
            unsupportedAlertKey = key
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    /// Quellen die diesen Filter-Key NICHT unterstützen (aus hardcoded Mapping).
    private func unsupportedSources(for key: String) -> [String]? {
        let active = DataSourceID.selectedSet
        guard active.count > 1 else { return nil }
        let missing = active
            .filter { !$0.supportedFilterKeys.contains(key) }
            .map { $0.displayName }
            .sorted()
        return missing.isEmpty ? nil : missing
    }

    private func sliderRow(key: String, name: String, min: Int, max: Int, steps: [Int]?, unit: String?) -> some View {
        let binding = sliderBinding(key)
        let raw = Int(binding.wrappedValue)
        let display = steps != nil ? (steps![safe: raw] ?? raw) : raw
        return VStack(alignment: .leading) {
            HStack {
                Text(name)
                Spacer()
                (display == min && steps?.first == 0
                    ? Text("egal")
                    : Text("\(display) \(unit ?? "")"))
                    .foregroundStyle(.secondary)
            }
            Slider(value: binding, in: Double(min)...Double(max), step: 1)
        }
    }

    // MARK: - Bindings

    private func index(of key: String) -> Int? {
        working.firstIndex { $0.value.key == key }
    }

    private func boolBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: {
                if let i = index(of: key), case let .boolean(_, v) = working[i].value { return v }
                return false
            },
            set: { newValue in
                guard let i = index(of: key) else { return }
                working[i].value = .boolean(key: key, value: newValue)
            }
        )
    }

    private func sliderBinding(_ key: String) -> Binding<Double> {
        Binding(
            get: {
                if let i = index(of: key), case let .slider(_, v) = working[i].value { return Double(v) }
                return 0
            },
            set: { newValue in
                guard let i = index(of: key) else { return }
                working[i].value = .slider(key: key, value: Int(newValue))
            }
        )
    }

    private func multiChoiceBinding(_ key: String) -> Binding<(values: Set<String>, all: Bool)> {
        Binding(
            get: {
                if let i = index(of: key), case let .multipleChoice(_, vals, all) = working[i].value {
                    return (vals, all)
                }
                return ([], true)
            },
            set: { newValue in
                guard let i = index(of: key) else { return }
                working[i].value = .multipleChoice(key: key, values: newValue.values, all: newValue.all)
            }
        )
    }

    private func multiChoiceSummary(_ key: String) -> String {
        guard let i = index(of: key), case let .multipleChoice(_, vals, all) = working[i].value else { return "" }
        if all { return String(localized: "Alle") }
        return vals.isEmpty ? String(localized: "Keine") : String(localized: "\(vals.count) ausgewählt")
    }

    // MARK: - Aktionen

    private func defaultValues() -> FilterValues {
        model.availableFilters.map { FilterWithValue(filter: $0, value: $0.defaultValue) }
    }

    private func mergedValues(from values: [FilterValue]) -> FilterValues {
        model.availableFilters.map { f in
            FilterWithValue(filter: f, value: values.first { $0.key == f.key } ?? f.defaultValue)
        }
    }

    private func apply() {
        model.applyFilters(working)
        dismiss()
    }

    private func saveProfile() {
        let trimmed = newProfileName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let data = FilterSnapshot.encode(working)
        modelContext.insert(FilterProfileEntity(name: trimmed, dataSource: model.apiName, data: data))
        newProfileName = ""
        apply()
    }

    private func deleteProfiles(_ offsets: IndexSet) {
        for index in offsets { modelContext.delete(profiles[index]) }
    }
}

// MARK: - Mehrfachauswahl

private struct MultiChoiceView: View {
    let title: String
    let choices: [String: String]
    @Binding var selection: (values: Set<String>, all: Bool)
    @State private var search = ""

    private var sortedChoices: [(key: String, label: String)] {
        choices
            .map { (key: $0.key, label: $0.value) }
            .filter { search.isEmpty || $0.label.localizedCaseInsensitiveContains(search) }
            .sorted { $0.label < $1.label }
    }

    var body: some View {
        List {
            Button {
                selection = ([], true)
            } label: {
                HStack {
                    Text("Alle")
                    Spacer()
                    if selection.all { Image(systemName: "checkmark").foregroundStyle(.tint) }
                }
            }
            .foregroundStyle(.primary)

            ForEach(sortedChoices, id: \.key) { choice in
                Button {
                    toggle(choice.key)
                } label: {
                    HStack {
                        Text(choice.label)
                        Spacer()
                        if !selection.all && selection.values.contains(choice.key) {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .searchable(text: $search)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ key: String) {
        var values = selection.all ? [] : selection.values
        if values.contains(key) { values.remove(key) } else { values.insert(key) }
        selection = (values, false)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
