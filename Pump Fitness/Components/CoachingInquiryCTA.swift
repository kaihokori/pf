import SwiftUI

public struct CoachingInquiryCTA: View {
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var instagram: String = ""
    @State private var submitted: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack {
            ZStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Interested In Being Featured as One of Our Coaches?")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                    Text("Join Us In a Future Update!")
                        .font(.subheadline)
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .padding(.top, -12)
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.footnote)
                                .foregroundStyle(.white)
                                TextField("", text: $name, prompt: Text("Enter your name").foregroundColor(.primary.opacity(0.7)))
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                                .surfaceCard(10)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.footnote)
                                .foregroundStyle(.white)
                                TextField("", text: $email, prompt: Text("Enter your email").foregroundColor(.primary.opacity(0.7)))
                                .keyboardType(.emailAddress)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                                .surfaceCard(10)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instagram")
                                .font(.footnote)
                                .foregroundStyle(.white)
                                TextField("", text: $instagram, prompt: Text("Enter your Instagram").foregroundColor(.primary.opacity(0.7)))
                                .textInputAutocapitalization(.none)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                                .surfaceCard(10)
                        }
                    }
                    .padding(.vertical, 4)
                    Button(action: {
                        submitted = true
                        // TODO: Hook up backend submission
                    }) {
                        Label(submitted ? "Submitted!" : "Submit", systemImage: "paperplane.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(submitted ? Color.green.opacity(0.7) : Color.gray.opacity(0.3))
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    .disabled(submitted || name.isEmpty || email.isEmpty)
                }
                .padding(20)
                .background(
                    ZStack {
                        Image("gym")
                            .resizable()
                            .scaledToFill()
                            .clipped()
                            .blur(radius: 2)
                        Color.black.opacity(0.45)
                    }
                )
            }
            .frame(minHeight: 260)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
    }
}

#Preview {
    CoachingInquiryCTA()
}
