import SwiftUI
import UIKit
import FirebaseAuth

// MARK: - Snapshots

struct WellnessMetricSnapshot: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let unit: String
    let icon: String // SF Symbol
    let color: Color
}

struct BodyInjurySnapshot: Identifiable {
    let id = UUID()
    let name: String
    let bodyPart: String
    let severity: String
    let status: String // e.g., "Active", "Recovering"
    let dateOccurred: Date
    let color: Color
}

struct RecoverySessionSnapshot: Identifiable {
    let id = UUID()
    let name: String // e.g., "Sauna", "Cold Plunge"
    let detail: String // e.g., "20 min • 180°F"
    let icon: String
    let color: Color
}

struct SleepSnapshot {
    let nightText: String
    let napText: String
    let totalText: String
    let score: String? // "8h 15m" etc.
}

// MARK: - Sheet

struct WellnessShareSheet: View {
    var accentColor: Color
    var date: Date
    var dailyCheckIn: String? // Optional check-in text if applicable
    
    // Data
    var metrics: [WellnessMetricSnapshot]
    var injuries: [BodyInjurySnapshot]
    var recoverySessions: [RecoverySessionSnapshot]
    var sleep: SleepSnapshot

    @Environment(\.dismiss) private var dismiss

    // Toggles
    @State private var showMetrics = true
    @State private var showInjuries = true
    @State private var showRecovery = true
    @State private var showSleep = true
    
    @State private var sharePayload: WellnessSharePayload?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)

                    Text("Share Wellness Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white)
                            WellnessShareCard(
                                accentColor: accentColor,
                                date: date,
                                dailyCheckIn: dailyCheckIn,
                                metrics: metrics,
                                injuries: injuries,
                                recoverySessions: recoverySessions,
                                sleep: sleep,
                                showMetrics: showMetrics,
                                showInjuries: showInjuries,
                                showRecovery: showRecovery,
                                showSleep: showSleep,
                                isExporting: false
                            )
                        }
                        .dynamicTypeSize(.medium)
                        .environment(\.sizeCategory, .medium)
                        .environment(\.colorScheme, .light)
                        .frame(maxWidth: 480)
                        .padding(.horizontal, 20)
                        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 8)
                        
                        VStack(spacing: 0) {
                            ToggleRow(title: "Daily Summary", isOn: $showMetrics, icon: "chart.bar.fill", color: .purple)
                            Divider().padding(.leading, 44)
                            ToggleRow(title: "Injuries", isOn: $showInjuries, icon: "cross.med.fill", color: .red)
                            Divider().padding(.leading, 44)
                            ToggleRow(title: "Recovery", isOn: $showRecovery, icon: "figure.mind.and.body", color: .blue)
                            Divider().padding(.leading, 44)
                            ToggleRow(title: "Sleep", isOn: $showSleep, icon: "bed.double.fill", color: .indigo)
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 60)
                }
                
                // Button
                VStack {
                    Button {
                        shareCurrentCard()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                            Text("Share")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            LinearGradient(colors: [accentColor, accentColor.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 20)
                .background(Color(UIColor.systemBackground).ignoresSafeArea())
            }
        }
        .background(Color(UIColor.systemBackground))
        .presentationDetents([.large])
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: payload.items)
        }
    }

    @MainActor
    private func renderCurrentCard() -> UIImage? {
        let width: CGFloat = 350

        let renderView = ZStack {
            Rectangle()
                .fill(Color.white)
            WellnessShareCard(
                accentColor: accentColor,
                date: date,
                dailyCheckIn: dailyCheckIn,
                metrics: metrics,
                injuries: injuries,
                recoverySessions: recoverySessions,
                sleep: sleep,
                showMetrics: showMetrics,
                showInjuries: showInjuries,
                showRecovery: showRecovery,
                showSleep: showSleep,
                isExporting: true
            )
        }
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true)
        .dynamicTypeSize(.medium)
        .environment(\.sizeCategory, .medium)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 3.0
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func shareCurrentCard() {
        guard let image = renderCurrentCard() else { return }
        let itemSource = ShareImageItemSource(image: image)
        sharePayload = WellnessSharePayload(items: [itemSource])
    }
}

// MARK: - Card

private struct WellnessShareCard: View {
    var accentColor: Color
    var date: Date
    var dailyCheckIn: String?
    
    var metrics: [WellnessMetricSnapshot]
    var injuries: [BodyInjurySnapshot]
    var recoverySessions: [RecoverySessionSnapshot]
    var sleep: SleepSnapshot
    
    var showMetrics: Bool
    var showInjuries: Bool
    var showRecovery: Bool
    var showSleep: Bool
    
    var isExporting: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WELLNESS CHECK-IN")
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundStyle(accentColor)
                        .tracking(0.5)
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                PumpBranding()
                    .scaleEffect(0.85)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color(UIColor.secondarySystemBackground))
            
            VStack(spacing: 18) {
                if showMetrics && !metrics.isEmpty {
                    WellnessMetricsSection(metrics: metrics, color: accentColor)
                }
                
                if showInjuries && !injuries.isEmpty {
                    InjuriesSection(injuries: injuries, color: accentColor)
                }
                
                if showRecovery && !recoverySessions.isEmpty {
                    RecoverySection(sessions: recoverySessions, color: accentColor)
                }
                
                if showSleep {
                    SleepSection(sleep: sleep, color: accentColor)
                }
            }
            .padding(20)
        }
        .background {
            GradientBackground(theme: .other)
        }
        .cornerRadius(isExporting ? 0 : 24)
        .overlay(
            RoundedRectangle(cornerRadius: isExporting ? 0 : 24)
                .strokeBorder(accentColor.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Sections

private struct WellnessSectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.black)
            Spacer()
        }
    }
}

private struct WellnessMetricsSection: View {
    var metrics: [WellnessMetricSnapshot]
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WellnessSectionHeader(title: "DAILY SUMMARY", icon: "chart.bar.fill", color: color)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(metrics) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(metric.name)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: metric.icon)
                                .font(.caption2)
                                .foregroundStyle(metric.color.opacity(0.8))
                        }
                        HStack(spacing: 2) {
                            Text(metric.value)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(metric.unit)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

private struct InjuriesSection: View {
    var injuries: [BodyInjurySnapshot]
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WellnessSectionHeader(title: "ACTIONABLE INJURIES", icon: "cross.med.fill", color: color)
            
            VStack(spacing: 8) {
                ForEach(injuries) { injury in
                    HStack {
                        Circle()
                            .fill(injury.color)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(injury.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("\(injury.bodyPart) • \(injury.status)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(injury.dateOccurred.formatted(date: .numeric, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

private struct RecoverySection: View {
    var sessions: [RecoverySessionSnapshot]
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WellnessSectionHeader(title: "RECOVERY SESSIONS", icon: "figure.mind.and.body", color: color)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(sessions) { session in
                    HStack(spacing: 12) {
                        Image(systemName: session.icon) // e.g. "flame.fill"
                             .font(.title3)
                             .foregroundStyle(session.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                             Text(session.detail) // "20m"
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

private struct SleepSection: View {
    var sleep: SleepSnapshot
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WellnessSectionHeader(title: "SLEEP & REST", icon: "bed.double.fill", color: color)
            
            HStack(spacing: 8) {
                // Total
                VStack(alignment: .leading) {
                    Text("Total Duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(sleep.totalText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Parts
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .font(.caption2)
                            .foregroundStyle(.indigo)
                        Text("Night: \(sleep.nightText)")
                            .font(.caption.weight(.medium))
                    }
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("Nap: \(sleep.napText)")
                            .font(.caption.weight(.medium))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

private struct WellnessSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
