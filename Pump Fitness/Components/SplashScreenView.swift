//
//  SplashScreenView.swift
//  Trackerio
//
//  Created by Copilot on 06/01/2026.
//

import SwiftUI

struct SplashScreenView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating: Bool = false
    @State private var showDots: Bool = false
    @State private var showSlowConnectionMessage: Bool = false

    var body: some View {
        let background: Color = colorScheme == .dark ? .black : .white
        let accentOverride: Color? = themeManager.selectedTheme == .multiColour ? nil : themeManager.selectedTheme.accent(for: colorScheme)
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                if let accentOverride {
                    Image("logo")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(accentOverride)
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .opacity(0.92)
                } else {
                    Image("logo")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .opacity(0.92)
                }

                // Buffering / loading indicator (pulsing dots) placed directly below the logo.
                // Dots exist initially but are invisible; reveal and start pulsing after 1.5s.
                HStack(spacing: 10) {
                    ForEach(0..<3) { idx in
                        Circle()
                            .fill((accentOverride ?? Color.primary).opacity(0.9))
                            .frame(width: 8, height: 8)
                            .scaleEffect(isAnimating ? 1.0 : 0.4)
                            .opacity(showDots ? (isAnimating ? 1.0 : 0.35) : 0)
                            .animation(.easeIn(duration: 0.18), value: showDots)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(idx) * 0.12),
                                value: isAnimating
                            )
                    }
                }
                .padding(.top, 8)

                if showSlowConnectionMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Your internet connection may be slow")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                    .padding(.top, 20)
                }

                Spacer()
            }
        }
        .onAppear {
            // Delay revealing and starting the pulsing animation so only the logo
            // is visible on first paint. Preserves layout by keeping the dots
            // in the view hierarchy with zero opacity until shown.
            DispatchQueue.main.async {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        showDots = true
                    }

                    // Start the pulsing after a tiny delay so the reveal animation completes first.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isAnimating = true
                    }
                }
                
                // Show slow connection message if loading takes longer than 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    withAnimation {
                        showSlowConnectionMessage = true
                    }
                }
            }
        }
    }
}
