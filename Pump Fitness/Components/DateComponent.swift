import SwiftUI

struct DateComponent: View {
    @Binding var date: Date
    let range: ClosedRange<Date>
    var isError: Bool = false
    @State private var isPresentingPicker = false

    var body: some View {
        Button {
            isPresentingPicker = true
        } label: {
            HStack {
                Text(formattedDate)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "calendar")
                    .font(.body)
                    .foregroundStyle(PumpPalette.secondaryText)
            }
            .pumpInputStyle(isError: isError)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresentingPicker) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker(
                        "Birth date",
                        selection: $date,
                        in: range,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    Spacer()
                }
                .padding(.horizontal)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isPresentingPicker = false
                        }
                        .font(.headline)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresentingPicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var formattedDate: String {
        DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
    }
}

struct PumpPalette {
    static let secondaryText = Color.secondary.opacity(0.8)
    static let cardBorder = Color.white.opacity(0.16)
}

struct PumpInputModifier: ViewModifier {
    var isError: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isError ? Color.red : PumpPalette.cardBorder, lineWidth: isError ? 1.5 : 1)
                    )
            )
    }
}

extension View {
    func pumpInputStyle(isError: Bool = false) -> some View {
        modifier(PumpInputModifier(isError: isError))
    }
}

enum PumpDateRange {
    static var birthdate: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()
        let maxDate = calendar.date(byAdding: .year, value: -13, to: now) ?? now
        let minComponents = DateComponents(year: 1900, month: 1, day: 1)
        let minDate = calendar.date(from: minComponents) ?? calendar.date(byAdding: .year, value: -120, to: now) ?? now
        return minDate...maxDate
    }
}
