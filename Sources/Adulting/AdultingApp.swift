import SwiftUI
import SwiftData

@main
struct AdultingApp: App {
    private let container: ModelContainer = makeModelContainer()

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(container)
    }
}
