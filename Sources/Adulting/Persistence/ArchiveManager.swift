import Foundation
import SwiftData

enum ArchiveError: LocalizedError {
    case invalidAmount(String)

    var errorDescription: String? {
        switch self {
        case .invalidAmount(let s): return "Archive contains an invalid amount: \"\(s)\""
        }
    }
}

struct ArchiveManager {
    static var archivesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Archives")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Export

    @discardableResult
    @MainActor
    static func export(context: ModelContext) throws -> URL {
        let users = try context.fetch(FetchDescriptor<AppUser>())
        let sessions = try context.fetch(FetchDescriptor<ExpenseSession>())
        let payments = try context.fetch(FetchDescriptor<Payment>())

        let archive = ArchiveData(
            exportedAt: Date(),
            users: users.map {
                ArchivedUser(id: $0.id, name: $0.name, isSelf: $0.isSelf, isUnassigned: $0.isUnassigned, createdAt: $0.createdAt)
            },
            sessions: sessions.map { session in
                ArchivedSession(
                    id: session.id,
                    title: session.title,
                    date: session.date,
                    totalAmount: session.totalAmount.description,
                    paidByUserId: session.paidByUser?.id,
                    receiptPhotoFilename: session.receiptPhotoFilename,
                    isComplete: session.isComplete,
                    notes: session.notes,
                    lineItems: session.lineItems.map { item in
                        ArchivedLineItem(
                            id: item.id,
                            index: item.index,
                            name: item.name,
                            amount: item.amount.description,
                            taggedUserIds: item.taggedUsers.map(\.id)
                        )
                    }
                )
            },
            payments: payments.map {
                ArchivedPayment(
                    id: $0.id,
                    userId: $0.user?.id,
                    amount: $0.amount.description,
                    date: $0.date,
                    notes: $0.notes
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(archive)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let filename = "archive-\(formatter.string(from: Date())).json"
        let url = archivesDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    // MARK: - List

    static func listArchives() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: archivesDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    // MARK: - Delete archive file

    static func deleteArchive(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Restore

    @MainActor
    static func restore(from url: URL, context: ModelContext) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(ArchiveData.self, from: data)

        // clearAll runs before any inserts, so restored IDs never collide with live records
        clearAll(context: context)

        var userMap: [UUID: AppUser] = [:]
        for au in archive.users {
            let user = AppUser(name: au.name, isSelf: au.isSelf, isUnassigned: au.isUnassigned)
            user.id = au.id
            user.createdAt = au.createdAt
            context.insert(user)
            userMap[au.id] = user
        }

        for as_ in archive.sessions {
            let session = ExpenseSession(
                title: as_.title,
                totalAmount: try parseDecimal(as_.totalAmount),
                paidByUser: as_.paidByUserId.flatMap { userMap[$0] },
                receiptPhotoFilename: as_.receiptPhotoFilename,
                notes: as_.notes
            )
            session.id = as_.id
            session.date = as_.date
            session.isComplete = as_.isComplete
            context.insert(session)

            for al in as_.lineItems {
                let item = LineItem(
                    index: al.index,
                    name: al.name,
                    amount: try parseDecimal(al.amount),
                    taggedUsers: al.taggedUserIds.compactMap { userMap[$0] }
                )
                item.id = al.id
                item.expenseSession = session
                context.insert(item)
            }
        }

        for ap in archive.payments {
            guard let userId = ap.userId, let user = userMap[userId] else { continue }
            let payment = Payment(
                user: user,
                amount: try parseDecimal(ap.amount),
                notes: ap.notes
            )
            payment.id = ap.id
            payment.date = ap.date
            context.insert(payment)
        }

        try context.save()
    }

    private static func parseDecimal(_ string: String) throws -> Decimal {
        guard let value = Decimal(string: string), value >= 0 else {
            throw ArchiveError.invalidAmount(string)
        }
        return value
    }

    // MARK: - Reset (archive then clear expenses/payments; keep people)

    @MainActor
    static func reset(context: ModelContext) throws {
        try export(context: context)
        let sessions = (try? context.fetch(FetchDescriptor<ExpenseSession>())) ?? []
        let payments = (try? context.fetch(FetchDescriptor<Payment>())) ?? []
        sessions.forEach { context.delete($0) }
        payments.forEach { context.delete($0) }
        try context.save()
    }

    // MARK: - Private

    @MainActor
    private static func clearAll(context: ModelContext) {
        let users = (try? context.fetch(FetchDescriptor<AppUser>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<ExpenseSession>())) ?? []
        let payments = (try? context.fetch(FetchDescriptor<Payment>())) ?? []
        users.forEach { context.delete($0) }
        sessions.forEach { context.delete($0) }
        payments.forEach { context.delete($0) }
    }
}
