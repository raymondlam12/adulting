import SwiftUI
import SwiftData

struct LineItemFormView: View {
    @Environment(\.dismiss) private var dismiss

    let users: [AppUser]
    let index: Int
    var existing: LineItem?
    let onSave: (String, Decimal, [AppUser]) -> Void

    @State private var name: String
    @State private var amountText: String
    @State private var taggedUsers: [AppUser]

    init(users: [AppUser], index: Int, existing: LineItem? = nil, onSave: @escaping (String, Decimal, [AppUser]) -> Void) {
        self.users = users
        self.index = index
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _amountText = State(initialValue: existing.map { "\($0.amount)" } ?? "")
        _taggedUsers = State(initialValue: existing?.taggedUsers ?? [])
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText)
    }

    private var perPersonText: String? {
        guard let amount = parsedAmount, !taggedUsers.isEmpty else { return nil }
        let share = amount / Decimal(taggedUsers.count)
        return share.formatted(.currency(code: "USD"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item \(index)") {
                    TextField("Description", text: $name)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section("Tag People") {
                    UserTagPicker(users: users, selected: $taggedUsers)
                        .padding(.vertical, 4)
                    if let split = perPersonText {
                        HStack {
                            Text("Per person")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(split)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = parsedAmount else { return }
                        onSave(name.trimmingCharacters(in: .whitespaces), amount, taggedUsers)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || parsedAmount == nil)
                }
            }
        }
    }
}
