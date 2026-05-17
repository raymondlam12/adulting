import Foundation
import SwiftData

@Model
final class LineItem {
    var id: UUID
    var index: Int
    var name: String
    var amount: Decimal
    var taggedUsers: [AppUser]
    var expenseSession: ExpenseSession?

    var perPersonAmount: Decimal {
        guard !taggedUsers.isEmpty else { return amount }
        return amount / Decimal(taggedUsers.count)
    }

    init(index: Int, name: String, amount: Decimal, taggedUsers: [AppUser] = []) {
        self.id = UUID()
        self.index = index
        self.name = name
        self.amount = amount
        self.taggedUsers = taggedUsers
    }
}
