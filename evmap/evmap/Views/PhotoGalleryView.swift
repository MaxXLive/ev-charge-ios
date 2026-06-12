//
//  PhotoGalleryView.swift
//  evmap
//
//  Vollbild-Fotogalerie mit Zoom (Pinch + Doppeltipp) und Seiten-Indikator.
//

import SwiftUI

struct PhotoGalleryView: View {
    let photos: [ChargerPhoto]
    @State private var selection: Int
    @Environment(\.dismiss) private var dismiss

    init(photos: [ChargerPhoto], initialIndex: Int) {
        self.photos = photos
        _selection = State(initialValue: min(max(initialIndex, 0), max(photos.count - 1, 0)))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                    ZoomableImageView(url: photo.url(size: 1600))
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .padding()
            }
        }
        .statusBarHidden()
    }
}

/// Einzelbild mit Pinch-Zoom, Pan (wenn gezoomt) und Doppeltipp-Zoom.
private struct ZoomableImageView: View {
    let url: URL?

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let maxScale: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnification)
                    .simultaneousGesture(scale > 1 ? panGesture : nil)
                    .onTapGesture(count: 2) { toggleZoom() }
            } placeholder: {
                ProgressView().tint(.white)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 1), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 { resetZoom() }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.spring(duration: 0.3)) {
            if scale > 1 {
                resetZoom()
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }

    private func resetZoom() {
        scale = 1; lastScale = 1
        offset = .zero; lastOffset = .zero
    }
}
