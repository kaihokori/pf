import SwiftUI

struct HeaderComponent: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showCalendar: Bool
    @Binding var selectedDate: Date
    var onProfileTap: (() -> Void)? = nil
    @EnvironmentObject private var account: Account
    @AppStorage("isPro") private var isPro: Bool = true

    var body: some View {
        HStack(alignment: .center) {
            if themeManager.selectedTheme == .multiColour {
                Image("logo")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 28)
                    .padding(.leading, 4)
                    .offset(y: 6)
                Button(action: { isPro.toggle() }) {
                    Text("Pro")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(isPro ? .white : .primary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isPro ? themeManager.selectedTheme.accent(for: colorScheme) : Color.secondary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                .offset(y: 6)
            } else {
                Image("logo")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(themeManager.selectedTheme.accent(for: colorScheme))
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 28)
                    .padding(.leading, 4)
                    .offset(y: 6)
                Button(action: { isPro.toggle() }) {
                    Text("Pro")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(isPro ? .white : .primary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isPro ? themeManager.selectedTheme.accent(for: colorScheme) : Color.secondary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                .offset(y: 6)
            }

            Spacer()

            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Self.dayOfWeek(selectedDate))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.trailing)
                    HStack(spacing: 6) {
                        Text(Self.formattedDate(selectedDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { showCalendar = true }
                .nutritionTip(.dateSelector)

                ThemeSwitcherButton(
                    selectedTheme: themeManager.selectedTheme,
                    colorScheme: colorScheme,
                    onSelectTheme: { themeManager.setTheme($0) }
                )
                .nutritionTip(.themeSelector)
            }
            .offset(y: 6)
        }
        .overlay(alignment: .center) {
            profileAvatar
                .nutritionTip(.profile)
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var profileAvatar: some View {
        Circle()
            .fill(account.avatarGradient)
            .frame(width: 58, height: 58)
            .overlay {
                if let avatarImage = account.avatarImage {
                    avatarImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())
                } else {
                    Text(account.avatarInitials)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
            .contentShape(Circle())
            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
            .onTapGesture { onProfileTap?() }
    }

    static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM, yyyy"
        return formatter.string(from: date)
    }

    static func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

private struct ThemeSwitcherButton: View {
    var selectedTheme: AppTheme
    var colorScheme: ColorScheme
    var onSelectTheme: (AppTheme) -> Void

    var body: some View {
        Menu {
            ForEach(AppTheme.allCases) { theme in
                Button(action: { onSelectTheme(theme) }) {
                    HStack {
                        Text(theme.displayName)
                        Spacer(minLength: 8)
                        if theme == selectedTheme {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } label: {
            ThemePreviewRow(theme: selectedTheme, colorScheme: colorScheme)
        }
        .menuStyle(.button)
        .contentShape(Rectangle())
    }
}

struct ThemePreviewRow: View {
    var theme: AppTheme
    var colorScheme: ColorScheme

    private var isMultiColour: Bool { theme == .multiColour }

    private var nutritionColors: [Color] {
        [
            Color.purple.opacity(0.18),
            Color.blue.opacity(0.14),
            Color.indigo.opacity(0.18)
        ]
    }

    private var subtleRainbowGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.99, green: 0.45, blue: 0.45).opacity(0.8),
                Color(red: 1.00, green: 0.72, blue: 0.32).opacity(0.8),
                Color(red: 0.42, green: 0.85, blue: 0.55).opacity(0.8),
                Color(red: 0.36, green: 0.70, blue: 0.99).opacity(0.8),
                Color(red: 0.63, green: 0.48, blue: 0.96).opacity(0.8)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var swatchBackground: LinearGradient {
        if isMultiColour {
            LinearGradient(
                gradient: Gradient(colors: nutritionColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            theme.previewBackground(for: colorScheme)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(swatchBackground)
                .overlay {
                    if isMultiColour {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(subtleRainbowGradient, lineWidth: 1.5)
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(theme.accent(for: colorScheme), lineWidth: 1.5)
                    }
                }
                .frame(width: 20, height: 40)
                .overlay {
                    if isMultiColour {
                        Circle()
                            .fill(subtleRainbowGradient)
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(theme.accent(for: colorScheme))
                            .frame(width: 8, height: 8)
                    }
                }
        }
    }
}

#Preview {
    HeaderComponent(showCalendar: .constant(false), selectedDate: .constant(Date()))
        .environmentObject(ThemeManager())
}
