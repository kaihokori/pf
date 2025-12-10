import FirebaseFirestore
import Foundation

class AccountFirestoreService {
    private let db = Firestore.firestore()
    private let collection = "accounts"

    func fetchAccount(withId id: String, completion: @escaping (Account?) -> Void) {
        db.collection(collection).document(id).getDocument { snapshot, error in
            guard let data = snapshot?.data(), error == nil else {
                completion(nil)
                return
            }
            let account = Account(
                id: id,
                profileImage: nil, // Handle image separately
                profileAvatar: data["profileAvatar"] as? String,
                name: data["name"] as? String,
                gender: data["gender"] as? String,
                dateOfBirth: (data["dateOfBirth"] as? Timestamp)?.dateValue(),
                height: data["height"] as? Double,
                weight: data["weight"] as? Double,
                theme: data["theme"] as? String,
                unitSystem: data["unitSystem"] as? String,
                startWeekOn: data["startWeekOn"] as? String
            )
            completion(account)
        }
    }

    func saveAccount(_ account: Account, completion: @escaping (Bool) -> Void) {
        guard let id = account.id else {
            completion(false)
            return
        }
        let data: [String: Any] = [
            "profileAvatar": account.profileAvatar ?? "",
            "name": account.name ?? "",
            "gender": account.gender ?? "",
            "dateOfBirth": account.dateOfBirth ?? Date(),
            "height": account.height ?? 0,
            "weight": account.weight ?? 0,
            "theme": account.theme ?? "",
            "unitSystem": account.unitSystem ?? "",
            "startWeekOn": account.startWeekOn ?? ""
        ]
        db.collection(collection).document(id).setData(data) { error in
            completion(error == nil)
        }
    }
}