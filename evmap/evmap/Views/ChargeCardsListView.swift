//
//  ChargeCardsListView.swift
//  evmap
//
//  Vollständige Liste der akzeptierten Ladekarten/-tarife einer Station.
//

import SwiftUI

struct ChargeCardsListView: View {
    let cards: [GEChargeCard]
    @State private var search = ""

    private var filtered: [GEChargeCard] {
        guard !search.isEmpty else { return cards }
        return cards.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List(filtered, id: \.id) { card in
            if let url = fullURL(card.url) {
                Link(destination: url) {
                    HStack {
                        Text(card.name).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(card.name)
            }
        }
        .searchable(text: $search, prompt: "Ladekarte suchen")
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .navigationTitle("Ladekarten")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// GE liefert protokoll-relative URLs ("//www.goingelectric.de/…").
    private func fullURL(_ raw: String) -> URL? {
        guard !raw.isEmpty else { return nil }
        let s = raw.hasPrefix("//") ? "https:\(raw)" : raw
        guard let url = URL(string: s), url.scheme?.hasPrefix("http") == true else { return nil }
        return url
    }
}
