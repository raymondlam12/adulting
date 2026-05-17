import Foundation
import SwiftData

@Model
final class ExpenseSession {
    var id: UUID
    var title: String?
    var date: Date
    var totalAmount: Decimal
    var paidByUser: AppUser?
    var receiptPhotoFilename: String?
    var isComplete: Bool
    var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \LineItem.expenseSession)
    var lineItems: [LineItem] = []

    var lineItemsSum: Decimal {
        lineItems.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var isSumMatchingTotal: Bool {
        abs(lineItemsSum - totalAmount) < Decimal(0.01)
    }

    var displayTitle: String {
        title ?? DateFormatter.sessionDisplay.string(from: date)
    }

    init(title: String? = nil, totalAmount: Decimal, paidByUser: AppUser? = nil, receiptPhotoFilename: String? = nil, notes: String? = nil) {
        self.id = UUID()
        self.title = title
        self.date = Date()
        self.totalAmount = totalAmount
        self.paidByUser = paidByUser
        self.receiptPhotoFilename = receiptPhotoFilename
        self.isComplete = false
        self.notes = notes
    }
}

extension DateFormatter {
    static let sessionDisplay: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
