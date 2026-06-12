//
//  FilterValueDTO.swift
//  evmap
//
//  Codable-Repräsentation von Filterwerten zur Persistenz (Filter-Profile).
//

import Foundation

struct FilterValueDTO: Codable, Sendable {
    enum Kind: String, Codable { case boolean, multipleChoice, slider }
    let kind: Kind
    let key: String
    var boolValue: Bool?
    var values: [String]?
    var all: Bool?
    var intValue: Int?

    init(_ value: FilterValue) {
        key = value.key
        switch value {
        case let .boolean(_, v):
            kind = .boolean; boolValue = v
        case let .multipleChoice(_, vals, all):
            kind = .multipleChoice; values = Array(vals); self.all = all
        case let .slider(_, v):
            kind = .slider; intValue = v
        }
    }

    func toFilterValue() -> FilterValue {
        switch kind {
        case .boolean:
            return .boolean(key: key, value: boolValue ?? false)
        case .multipleChoice:
            return .multipleChoice(key: key, values: Set(values ?? []), all: all ?? true)
        case .slider:
            return .slider(key: key, value: intValue ?? 0)
        }
    }
}

enum FilterSnapshot {
    static func encode(_ values: FilterValues) -> Data {
        (try? JSONEncoder().encode(values.map { FilterValueDTO($0.value) })) ?? Data()
    }

    static func decode(_ data: Data) -> [FilterValue] {
        guard let dtos = try? JSONDecoder().decode([FilterValueDTO].self, from: data) else { return [] }
        return dtos.map { $0.toFilterValue() }
    }
}
