import SwiftUI

struct InjuryTrackingSection: View {
    @Binding var injuries: [Injury]
    let theme: String?
    var selectedDate: Date = Date()
    var onSave: (() -> Void)?
    
    @State private var showAddSheet = false
    @State private var injuryToEdit: Injury?
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Injury Tracking")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: { showAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(in: .rect(cornerRadius: 18.0))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
            
            let activeInjuries = injuries.filter { injury in
                // Only show active injuries relative to selectedDate
                // Must have started on or before selectedDate (ignoring time for same-day visibility)
                let calendar = Calendar.current
                let startOfSelected = calendar.startOfDay(for: selectedDate)
                let startOfOccurrence = calendar.startOfDay(for: injury.dateOccurred)
                
                guard startOfOccurrence <= startOfSelected else { return false }
                
                let endDate = calendar.date(byAdding: .day, value: injury.durationDays, to: injury.dateOccurred) ?? injury.dateOccurred
                let endOfInjury = calendar.startOfDay(for: endDate)
                
                // If selectedDate is the end date or after, it's healed
                if startOfSelected >= endOfInjury { return false }
                
                return true
            }.sorted { $0.dateOccurred > $1.dateOccurred }

            if activeInjuries.isEmpty {
                // Empty State
                VStack(alignment: .leading, spacing: 8) {
                    Label("No Active Injuries", systemImage: "checkmark.shield")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("You don't have any injuries tracked for this date. Keep up the good work!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .padding(.horizontal, 18)
            } else {
                // Body View & List
                VStack(spacing: 0) {
                    BodyDiagramView(injuries: injuries, theme: theme, selectedDate: selectedDate)
                        .frame(height: 200)
                    
                    Divider()
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    
                    VStack(spacing: 0) {
                        ForEach(activeInjuries) { injury in
                            InjuryRow(injury: injury)
                            if injury.id != activeInjuries.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .padding(.horizontal, 18)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddInjuryView(injuries: $injuries, injuryToEdit: nil, selectedDate: selectedDate, onSave: onSave)
        }
        .sheet(item: $injuryToEdit) { injury in
            AddInjuryView(injuries: $injuries, injuryToEdit: injury, selectedDate: selectedDate, onSave: onSave)
        }
    }
    
    @ViewBuilder
    func InjuryRow(injury: Injury) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(injury.name)
                    .font(.body)
                    .fontWeight(.medium)
                if let part = injury.bodyPart {
                    Text(part.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Calculate remaining days or progress based on day difference
                let calendar = Calendar.current
                let startOfOccurrence = calendar.startOfDay(for: injury.dateOccurred)
                let startOfSelected = calendar.startOfDay(for: selectedDate)
                let elapsed = calendar.dateComponents([.day], from: startOfOccurrence, to: startOfSelected).day ?? 0
                let remaining = max(0, injury.durationDays - elapsed)
                
                Text("\(remaining) days left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Menu {
                Button {
                    injuryToEdit = injury
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    if let idx = injuries.firstIndex(where: { $0.id == injury.id }) {
                        onSave?()
                        injuries.remove(at: idx)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

