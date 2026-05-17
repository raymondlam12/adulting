import Foundation
import SwiftData

@Model
final class AppUser {
    var id: UUID
    var name: String
    var isSelf: Bool
    var isUnassigned: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ExpenseSession.paidByUser)
    var paidSessions: [ExpenseSession] = []

    @Relationship(deleteRule: .cascade, inverse: \Payment.user)
    var payments: [Payment] = []

    init(name: String, isSelf: Bool = false, isUnassigned: Bool = false) {
        self.id = UUID()
        self.name = name
        self.isSelf = isSelf
        self.isUnassigned = isUnassigned
        self.createdAt = Date()
    }
}
