import SwiftUI
import SwiftData

struct AIAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var inputText: String = ""
    @State private var messages: [String] = []
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages, id: \.self) { msg in
                            Text(msg)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }

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
                            Task { await sendMessage() }
                        }) {
                            if isLoading {
                                ProgressView()
                                    .padding(12)
                                    .background(Circle().fill(Color.blue))
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Circle().fill(Color.blue))
                            }
                        }
                        .disabled(isLoading)
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
            .onAppear {
                if let ctx = modelContext {
                    AssistantCoordinator.shared.startListening(context: ctx)
                }
            }
            .onDisappear {
                AssistantCoordinator.shared.stopListening()
            }
        }
        .presentationDetents([.fraction(0.8), .large])
        .presentationDragIndicator(.visible)
        .alert(errorMessage, isPresented: $showError) {
            Button("OK", role: .cancel) {}
        }
    }

    func sendMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append("You: \(trimmed)")
        isLoading = true
        defer { isLoading = false }

        do {
            // API key stored by user in UserDefaults under 'GeminiAPIKey'.
            let apiKey = UserDefaults.standard.string(forKey: "GeminiAPIKey") ?? ""

            var contextJSON: String? = nil
            if let ctx = modelContext {
                contextJSON = await AssistantContextProvider.snapshotJSON(context: ctx)
            }

            let reply = try await GeminiService.shared.send(prompt: trimmed, context: contextJSON, apiKey: apiKey)
            messages.append("Assistant: \(reply)")

            // Optional: if assistant replies containing structured intent JSON, dispatch it to the app.
            if let data = reply.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], json["action"] != nil {
                NotificationCenter.default.post(name: .assistantActionRequested, object: nil, userInfo: json)
            }

            inputText = ""
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    AIAssistantView()
}
