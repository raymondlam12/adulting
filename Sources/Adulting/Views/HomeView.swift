import SwiftUI

struct HomeView: View {
    @State private var showSettings = false

    var body: some View {
        TabView {
            Tab("Expenses", systemImage: "receipt") {
                ExpenseListView()
            }
            Tab("Summary", systemImage: "chart.bar.xaxis") {
                SummaryView()
            }
            Tab("People", systemImage: "person.2") {
                PeopleListView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}
