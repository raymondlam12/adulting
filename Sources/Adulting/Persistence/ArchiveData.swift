import Foundation

struct ArchiveData: Codable {
    var exportedAt: Date
    var users: [ArchivedUser]
    var sessions: [ArchivedSession]
    var payments: [ArchivedPayment]
}

struct ArchivedUser: Codable {
    var id: UUID
    var name: String
    var isSelf: Bool
    var createdAt: Date
}

struct ArchivedSession: Codable {
    var id: UUID
    var title: String?
    var date: Date
    var totalAmount: String
    var paidByUserId: UUID?
    var receiptPhotoFilename: String?
    var isComplete: Bool
    var notes: String?
    var lineItems: [ArchivedLineItem]
}

struct ArchivedLineItem: Codable {
    var id: UUID
    var index: Int
    var name: String
    var amount: String
    var taggedUserIds: [UUID]
}

struct ArchivedPayment: Codable {
    var id: UUID
    var userId: UUID?
    var amount: String
    var date: Date
    var notes: String?
}
