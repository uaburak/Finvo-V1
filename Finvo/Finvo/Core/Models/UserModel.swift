import Foundation
import FirebaseFirestore

struct UserModel: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var uid: String
    var email: String
    var firstName: String
    var lastName: String
    var username: String
    var photoUrl: String?
    var isPro: Bool = false
    var ibans: [IBANModel]?
    
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}
