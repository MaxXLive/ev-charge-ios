//
//  Resource.swift
//  evmap
//
//  Portiert aus EVMap (Android, MIT) – viewmodel/Resource.kt
//  Zustand eines asynchronen Ladevorgangs: lädt / erfolgreich / Fehler.
//

import Foundation

enum Resource<T: Sendable>: Sendable {
    /// Lädt – optional mit bereits vorhandenen (veralteten) Daten.
    case loading(T?)
    case success(T)
    /// Fehler mit optionaler Meldung und optionalen Restdaten.
    case error(String?, T?)

    var value: T? {
        switch self {
        case let .loading(v): return v
        case let .success(v): return v
        case let .error(_, v): return v
        }
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var errorMessage: String? {
        if case let .error(msg, _) = self { return msg }
        return nil
    }

    static func loading() -> Resource<T> { .loading(nil) }

    func map<U: Sendable>(_ transform: (T) -> U) -> Resource<U> {
        switch self {
        case let .loading(v): return .loading(v.map(transform))
        case let .success(v): return .success(transform(v))
        case let .error(msg, v): return .error(msg, v.map(transform))
        }
    }
}
