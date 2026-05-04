import SwiftUI

struct AIAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                // Placeholder for chat history or voice visulization
                Image(systemName: "waveform")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .foregroundColor(.purple.opacity(0.5))
                    .padding()
                
                Text("How can I help you today?")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Input and Voice controls
                HStack(spacing: 12) {
                    TextField("Message...", text: $inputText)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    
                    if inputText.isEmpty {
                        Button(action: {
                            // TODO: Add voice recording logic
                        }) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Circle().fill(Color.purple))
                        }
                    } else {
                        Button(action: {
                            // TODO: Add send message logic
                        }) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Circle().fill(Color.blue))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.8), .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    AIAssistantView()
}
