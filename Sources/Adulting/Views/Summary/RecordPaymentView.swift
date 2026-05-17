import SwiftUI
import SwiftData

struct RecordPaymentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let preselectedUser: AppUser?
    @Query(sort: \AppUser.createdAt) private var users: [AppUser]

    @State private var selectedUsers: [AppUser] = []
    @State private var amountText = ""
    @State private var notes = ""

    private var parsedAmount: Decimal? { Decimal(string: amountText) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    UserTagPicker(users: users, selected: $selectedUsers, singleSelect: true)
                        .padding(.vertical, 4)
                }

                Section("Amount Paid") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section("Notes (optional)") {
                    TextField("e.g. Venmo transfer", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(selectedUsers.isEmpty || parsedAmount == nil)
                }
            }
            .onAppear {
                if let user = preselectedUser { selectedUsers = [user] }
            }
        }
    }

    private func save() {
        guard let user = selectedUsers.first, let amount = parsedAmount else { return }
        let payment = Payment(
            user: user,
            amount: amount,
            notes: notes.isEmpty ? nil : notes
        )
        context.insert(payment)
        dismiss()
    }
}
