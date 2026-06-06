import Foundation
import SwiftData

@MainActor
func makeModelContainer() -> ModelContainer {
    let schema = Schema([AppUser.self, ExpenseSession.self, LineItem.self, Payment.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
        let container = try ModelContainer(for: schema, configurations: [config])
        seedSelfUserIfNeeded(in: container)
        seedUnassignedUserIfNeeded(in: container)
        return container
    } catch {
        fatalError("Failed to create ModelContainer: \(error)")
    }
}

@MainActor
private func seedSelfUserIfNeeded(in container: ModelContainer) {
    let key = "adulting.selfUserSeeded"
    guard !UserDefaults.standard.bool(forKey: key) else { return }

    let me = AppUser(name: "Me", isSelf: true)
    container.mainContext.insert(me)
    try? container.mainContext.save()
    UserDefaults.standard.set(true, forKey: key)
}

@MainActor
private func seedUnassignedUserIfNeeded(in container: ModelContainer) {
    let key = "adulting.unassignedUserSeeded"
    guard !UserDefaults.standard.bool(forKey: key) else { return }

    let unassigned = AppUser(name: "Unassigned", isUnassigned: true)
    // Fixed UUID so archive/restore round-trips preserve taggedUser references
    unassigned.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    // distantPast → sorts first in every @Query(sort: \AppUser.createdAt)
    unassigned.createdAt = Date.distantPast
    container.mainContext.insert(unassigned)
    try? container.mainContext.save()
    UserDefaults.standard.set(true, forKey: key)
}
