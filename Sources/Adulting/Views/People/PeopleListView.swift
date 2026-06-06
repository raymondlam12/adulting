import SwiftUI
import SwiftData

struct PeopleListView: View {
    @Query(sort: \AppUser.createdAt) private var users: [AppUser]
    @Environment(\.modelContext) private var context
    @State private var showAddPerson = false

    private var selfUser: AppUser?      { users.first(where: \.isSelf) }
    private var unassignedUser: AppUser? { users.first(where: \.isUnassigned) }
    private var others: [AppUser]       { users.filter { !$0.isSelf && !$0.isUnassigned } }

    var body: some View {
        NavigationStack {
            List {
                if let me = selfUser {
                    Section("You") {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(Color.accentColor)
                            Text(me.name)
                            Spacer()
                            Text("You")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let unassigned = unassignedUser {
                    Section("System") {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.secondary)
                            Text(unassigned.name)
                            Spacer()
                            Text("OCR placeholder")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("People") {
                    ForEach(others) { user in
                        Text(user.name)
                    }
                    .onDelete(perform: deleteOthers)
                }
            }
            .navigationTitle("People")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddPerson = true } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddPerson) {
                AddPersonView()
            }
        }
    }

    private func deleteOthers(at offsets: IndexSet) {
        for i in offsets {
            context.delete(others[i])
        }
    }
}
