//
//  OnboardingView.swift
//  evcharge
//

import SwiftUI

struct OnboardingView: View {
    let onDone: () -> Void
    @State private var page = 0

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            pageIndicator
                .padding(.top, 20)

            TabView(selection: $page) {
                welcome.tag(0)
                legend.tag(1)
                carPlay.tag(2)
                dataSource.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            Button(page < pageCount - 1 ? "Weiter" : "Los geht's") {
                if page < pageCount - 1 { withAnimation { page += 1 } } else { onDone() }
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 32)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == page ? 22 : 8, height: 8)
                    .animation(.spring(duration: 0.3), value: page)
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            Image("WelcomeLogo")
                .resizable().scaledToFit()
                .frame(width: 150, height: 150)
            Text("Willkommen bei EV Charge").font(.title.bold()).multilineTextAlignment(.center)
            Text("Finde Ladestationen für Elektroautos in deiner Nähe")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .padding(32)
    }

    private var legend: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                legendPin(150)
                legendPin(50)
                legendPin(22)
                legendPin(15)
                legendPin(5)
            }
            Text("Auf die Leistung kommt es an").font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Die Farbe einer Ladestation zeigt dir die maximale Ladeleistung")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private var carPlay: some View {
        onboardPage(
            icon: "car.fill",
            title: String(localized: "Apple CarPlay"),
            text: String(localized: "EV Charge unterstützt Apple CarPlay. Verbinde dein iPhone mit dem Autodisplay und finde Ladestationen direkt auf der Fahrt – ohne dein Telefon zu berühren.")
        )
    }

    private var dataSource: some View {
        VStack(spacing: 12) {
            Text("Datenquelle").font(.title.bold())
            Text("Bitte wähle eine Datenquelle für Ladestationen aus. Du kannst sie später in den Einstellungen der App ändern.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            DataSourceList()
        }
        .padding(.top, 32)
    }

    /// Pin in der jeweiligen Leistungsfarbe mit kW-Label (wie Android-Legende).
    private func legendPin(_ power: Double) -> some View {
        VStack(spacing: 6) {
            ChargerPinView(power: power, size: 30)
            Text(label(forPower: power))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func label(forPower power: Double) -> String {
        switch power {
        case 100...: return "≥ 100 kW"
        case 43..<100: return "≥ 43 kW"
        case 20..<43: return "≥ 20 kW"
        case 11..<20: return "≥ 11 kW"
        default: return "< 11 kW"
        }
    }

    private func onboardPage(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: icon).font(.system(size: 64)).foregroundStyle(.tint)
            Text(title).font(.title.bold()).multilineTextAlignment(.center)
            Text(text).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .padding(32)
    }

    private func legendRow(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 16, height: 16)
            Text(label)
        }
    }
}
