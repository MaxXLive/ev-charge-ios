//
//  ChargerPinView.swift
//  evmap
//
//  Tropfenförmiger Karten-Pin (wie Android-Marker) – Farbe nach Leistung, weißer Blitz/Label.
//

import SwiftUI

/// Klassische Karten-Pin-Form (Tropfen): runder Kopf oben, Spitze unten.
struct MapPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        let headCenterY = rect.minY + r
        var p = Path()
        p.addArc(
            center: CGPoint(x: rect.midX, y: headCenterY),
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: headCenterY + r * 0.9)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: headCenterY),
            control: CGPoint(x: rect.minX, y: headCenterY + r * 0.9)
        )
        p.closeSubpath()
        return p
    }
}

struct ChargerPinView: View {
    let power: Double?
    var size: CGFloat = 32
    var isFavorite: Bool = false
    var hasFault: Bool = false

    private var pinHeight: CGFloat { size * 1.3 }

    var body: some View {
        ZStack {
            MapPinShape()
                .fill(ChargerStyle.color(forPower: power))
                .overlay(MapPinShape().stroke(.white, lineWidth: 1.5))
                .shadow(radius: 1.5, y: 1)

            head
                .offset(y: -size * 0.15)
        }
        .frame(width: size, height: pinHeight)
        .overlay(alignment: .topTrailing) { badges }
    }

    @ViewBuilder private var head: some View {
        let label = ChargerStyle.powerLabel(power)
        if label.isEmpty {
            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white)
        } else {
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: size * 0.34, weight: .heavy))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("kW")
                    .font(.system(size: size * 0.22, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(width: size * 0.8)
        }
    }

    @ViewBuilder private var badges: some View {
        if isFavorite {
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.34))
                .foregroundStyle(.yellow)
                .background(Circle().fill(.white).frame(width: size * 0.4, height: size * 0.4))
                .offset(x: size * 0.1, y: -size * 0.05)
        } else if hasFault {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: size * 0.3))
                .foregroundStyle(.orange)
                .offset(x: size * 0.1, y: -size * 0.05)
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ChargerPinView(power: 150)
        ChargerPinView(power: 50)
        ChargerPinView(power: 22)
        ChargerPinView(power: 11)
        ChargerPinView(power: 3)
        ChargerPinView(power: 150, isFavorite: true)
    }
    .padding()
}
