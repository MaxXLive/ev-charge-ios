//
//  Filters.swift
//  evmap
//
//  Portiert aus EVMap (Android, MIT) – model/FiltersModel.kt
//

import Foundation

// Spezielle Profil-IDs (siehe Android FILTERS_*).
enum FilterProfileID {
    static let disabled: Int64 = -2
    static let custom: Int64 = -1
    static let favorites: Int64 = -3
}

/// Definition eines Filters (Metadaten, quellenspezifisch erzeugt).
enum Filter: Identifiable, Sendable, Hashable {
    case boolean(key: String, name: String)
    case multipleChoice(
        key: String,
        name: String,
        choices: [String: String],
        commonChoices: Set<String>?,
        manyChoices: Bool
    )
    /// Slider über Index 0…max. `steps` bildet den Index auf den angezeigten Wert ab
    /// (z.B. Leistungsstufen); nil = Identität.
    case slider(
        key: String,
        name: String,
        min: Int,
        max: Int,
        steps: [Int]?,
        unit: String?
    )

    var id: String { key }

    var key: String {
        switch self {
        case let .boolean(key, _): return key
        case let .multipleChoice(key, _, _, _, _): return key
        case let .slider(key, _, _, _, _, _): return key
        }
    }

    var name: String {
        switch self {
        case let .boolean(_, name): return name
        case let .multipleChoice(_, name, _, _, _): return name
        case let .slider(_, name, _, _, _, _): return name
        }
    }

    var defaultValue: FilterValue {
        switch self {
        case let .boolean(key, _):
            return .boolean(key: key, value: false)
        case let .multipleChoice(key, _, _, _, _):
            return .multipleChoice(key: key, values: [], all: true)
        case let .slider(key, _, min, _, _, _):
            return .slider(key: key, value: min)
        }
    }
}

/// Konkreter Wert eines Filters.
enum FilterValue: Sendable, Hashable {
    case boolean(key: String, value: Bool)
    case multipleChoice(key: String, values: Set<String>, all: Bool)
    case slider(key: String, value: Int)

    var key: String {
        switch self {
        case let .boolean(key, _): return key
        case let .multipleChoice(key, _, _): return key
        case let .slider(key, _): return key
        }
    }

    func hasSameValue(as other: FilterValue) -> Bool {
        switch (self, other) {
        case let (.boolean(_, a), .boolean(_, b)):
            return a == b
        case let (.multipleChoice(_, aVals, aAll), .multipleChoice(_, bVals, bAll)):
            return bAll ? aAll : (!aAll && aVals == bVals)
        case let (.slider(_, a), .slider(_, b)):
            return a == b
        default:
            return false
        }
    }

    /// Serialisierung (für Profil-Speicherung / Vergleich), analog Android.
    func serialized() -> String {
        switch self {
        case let .boolean(_, value):
            return String(value)
        case let .multipleChoice(_, values, all):
            if all { return "ALL" }
            let encoded = values.sorted().map {
                $0.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0
            }
            return "[" + encoded.joined(separator: ",") + "]"
        case let .slider(_, value):
            return String(value)
        }
    }
}

/// Filter + aktueller Wert.
struct FilterWithValue: Sendable, Hashable {
    let filter: Filter
    var value: FilterValue
}

typealias FilterValues = [FilterWithValue]

extension Array where Element == FilterWithValue {
    private nonisolated func value(for key: String) -> FilterValue? {
        first { $0.value.key == key }?.value
    }

    nonisolated func booleanValue(_ key: String) -> Bool? {
        if case let .boolean(_, v)? = value(for: key) { return v }
        return nil
    }

    nonisolated func sliderValue(_ key: String) -> Int? {
        if case let .slider(_, v)? = value(for: key) { return v }
        return nil
    }

    nonisolated func multipleChoiceValue(_ key: String) -> (values: Set<String>, all: Bool)? {
        if case let .multipleChoice(_, vals, all)? = value(for: key) { return (vals, all) }
        return nil
    }

    nonisolated func multipleChoiceFilter(_ key: String) -> Filter? {
        first { $0.value.key == key }?.filter
    }

    /// Stabile Serialisierung der gesamten Filterwerte (für Vergleich „Standard vs. aktiv").
    nonisolated func serialized() -> String {
        sorted { $0.value.key < $1.value.key }
            .map { $0.value.key + "=" + $0.value.serialized() }
            .joined(separator: ",")
    }
}
