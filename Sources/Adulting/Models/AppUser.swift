import Foundation
import SwiftData

@Model
final class AppUser {
    var id: UUID
    var name: String
    var isSelf: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ExpenseSession.paidByUser)
    var paidSessions: [ExpenseSession] = []

    @Relationship(deleteRule: .cascade, inverse: \Payment.user)
    var payments: [Payment] = []

    init(name: String, isSelf: Bool = false) {
        self.id = UUID()
        self.name = name
        self.isSelf = isSelf
        self.createdAt = Date()
    }
}
