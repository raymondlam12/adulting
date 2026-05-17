import Foundation
import SwiftData

@MainActor
func makeModelContainer() -> ModelContainer {
    let schema = Schema([AppUser.self, ExpenseSession.self, LineItem.self, Payment.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
        let container = try ModelContainer(for: schema, configurations: [config])
        seedSelfUserIfNeeded(in: container)
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
