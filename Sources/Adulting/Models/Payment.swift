import Foundation
import SwiftData

@Model
final class Payment {
    var id: UUID
    var user: AppUser?
    var amount: Decimal
    var date: Date
    var notes: String?

    init(user: AppUser, amount: Decimal, notes: String? = nil) {
        self.id = UUID()
        self.user = user
        self.amount = amount
        self.date = Date()
        self.notes = notes
    }
}
