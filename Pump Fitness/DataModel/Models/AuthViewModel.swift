import Foundation
import FirebaseAuth
import AuthenticationServices
import GoogleSignIn
import Combine
import FirebaseCore
import FirebaseFirestore

class AuthViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var isLoading = false

    // Apple Sign-In
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, completion: @escaping (Bool) -> Void) {
        guard let tokenData = credential.identityToken,
              let tokenString = String(data: tokenData, encoding: .utf8) else {
            completion(false)
            return
        }
        
        self.isLoading = true
        
        // Use the correct Swift API for OAuthProvider credential
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nil,
            fullName: credential.fullName
        )
        Auth.auth().signIn(with: firebaseCredential) { result, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let user = result?.user {
                    UserDefaults.standard.set(user.uid, forKey: "currentUserID")
                    if let displayName = user.displayName {
                        UserDefaults.standard.set(displayName, forKey: "currentUserName")
                    }
                    print("Signed in with Apple:")
                    print("UID: \(user.uid)")
                    print("Email: \(user.email ?? "N/A")")
                    print("Display Name: \(user.displayName ?? "N/A")")
                    print("Provider: Apple")
                }
                completion(error == nil)
            }
        }
    }

    // Google Sign-In
    func signInWithGoogle(presenting: UIViewController, completion: @escaping (Bool) -> Void) {
        guard FirebaseApp.app()?.options.clientID != nil else { completion(false); return }
        
        self.isLoading = true
        
        // 1. Initial Sign In (Basic Profile)
        GIDSignIn.sharedInstance.signIn(withPresenting: presenting) { result, error in
            guard let googleUser = result?.user, error == nil else {
                DispatchQueue.main.async { self.isLoading = false }
                completion(false)
                return
            }
            
            // 2. Sign in to Firebase first to identify the user (get their Firebase UID)
            let idToken = googleUser.idToken?.tokenString ?? ""
            let accessToken = googleUser.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let user = authResult?.user {
                        UserDefaults.standard.set(user.uid, forKey: "currentUserID")
                        if let displayName = user.displayName {
                            UserDefaults.standard.set(displayName, forKey: "currentUserName")
                        }
                        print("Signed in with Google (Firebase UID: \(user.uid))")
                    }
                    completion(authResult?.user != nil && error == nil)
                }
            }
        }
    }
    
    // Email/Password
    func signInWithEmail(email: String, password: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                if let user = result?.user {
                    print("Signed in with Email:")
                    print("UID: \(user.uid)")
                    print("Email: \(user.email ?? "N/A")")
                    print("Display Name: \(user.displayName ?? "N/A")")
                    print("Provider: Email/Password")
                }
                completion(error == nil)
            }
        }
    }
}
