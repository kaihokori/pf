import SwiftUI

struct HeaderComponent: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showCalendar: Bool
    @Binding var selectedDate: Date
    var profileImage: Image? = nil
    var onProfileTap: (() -> Void)? = nil

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.dayOfWeek(selectedDate))
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(Self.formattedDate(selectedDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .padding(.leading, 5)
            }
            .contentShape(Rectangle())
            .onTapGesture { showCalendar = true }
            Spacer()
            ThemeSwitcherButton(
                selectedTheme: themeManager.selectedTheme,
                colorScheme: colorScheme,
                onSelectTheme: { themeManager.setTheme($0) }
            )
        }
        .overlay(alignment: .center) {
            profileAvatar
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var profileAvatar: some View {
        (profileImage ?? Image(systemName: "person.crop.circle"))
            .resizable()
            .aspectRatio(1, contentMode: .fill)
            .frame(width: 52, height: 52)
            .clipShape(Circle())
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(swatchBackground)
                .overlay {
                    if isMultiColour {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(subtleRainbowGradient, lineWidth: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.accent(for: colorScheme), lineWidth: 1)
                    }
                }
                .frame(width: 56, height: 36)
                .overlay {
                    if isMultiColour {
                        Circle()
                            .fill(subtleRainbowGradient)
                            .frame(width: 12, height: 12)
                    } else {
                        Circle()
                            .fill(theme.accent(for: colorScheme))
                            .frame(width: 12, height: 12)
                    }
                }
        }
    }
}

#Preview {
    HeaderComponent(showCalendar: .constant(false), selectedDate: .constant(Date()))
        .environmentObject(ThemeManager())
}
