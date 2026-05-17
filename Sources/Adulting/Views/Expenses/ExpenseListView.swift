import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Query(sort: \ExpenseSession.date, order: .reverse) private var sessions: [ExpenseSession]
    @Environment(\.modelContext) private var context

    @State private var showAddExpense = false
    @State private var editMode: EditMode = .inactive
    @State private var selected: Set<PersistentIdentifier> = []

    private var drafts: [ExpenseSession] { sessions.filter { !$0.isComplete } }
    private var completed: [ExpenseSession] { sessions.filter { $0.isComplete } }

    var body: some View {
        NavigationStack {
            List(selection: $selected) {
                if !drafts.isEmpty {
                    Section("Drafts") {
                        ForEach(drafts) { session in
                            NavigationLink(value: session) {
                                sessionRow(session)
                            }
                        }
                        .onDelete { delete(from: drafts, at: $0) }
                    }
                }

                if !completed.isEmpty {
                    Section("Completed") {
                        ForEach(completed) { session in
                            NavigationLink(value: session) {
                                sessionRow(session)
                            }
                        }
                        .onDelete { delete(from: completed, at: $0) }
                    }
                }

                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Expenses Yet",
                        systemImage: "receipt",
                        description: Text("Tap + to add your first expense.")
                    )
                }
            }
            .navigationTitle("Expenses")
            .navigationDestination(for: ExpenseSession.self) { session in
                ExpenseDetailView(session: session)
            }
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddExpense = true } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(editMode == .active)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if editMode == .active {
                        Button("Delete (\(selected.count))", role: .destructive) {
                            deleteSelected()
                        }
                        .disabled(selected.isEmpty)
                    } else {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView()
            }
            .onChange(of: editMode) { _, mode in
                if mode == .inactive { selected.removeAll() }
            }
        }
    }

    @ViewBuilder
    private func sessionRow(_ session: ExpenseSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.displayTitle)
                    .fontWeight(.medium)
                Spacer()
                Text(session.totalAmount, format: .currency(code: "USD"))
                    .fontWeight(.semibold)
            }
            HStack {
                if let payer = session.paidByUser {
                    Text("Paid by \(payer.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(session.isComplete ? "Complete" : "Draft")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(session.isComplete ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundStyle(session.isComplete ? .green : .orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private func delete(from list: [ExpenseSession], at offsets: IndexSet) {
        for i in offsets {
            context.delete(list[i])
        }
    }

    private func deleteSelected() {
        let toDelete = sessions.filter { selected.contains($0.persistentModelID) }
        toDelete.forEach { context.delete($0) }
        selected.removeAll()
        editMode = .inactive
    }
}
