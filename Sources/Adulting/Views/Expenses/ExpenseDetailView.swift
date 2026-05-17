import SwiftUI

struct ExpenseDetailView: View {
    @Environment(\.modelContext) private var context
    let session: ExpenseSession
    @State private var showFullPhoto = false
    @State private var showEdit = false

    var body: some View {
        List {
            Section {
                Button { showFullPhoto = true } label: {
                    ReceiptPhotoView(filename: session.receiptPhotoFilename)
                        .listRowInsets(.init())
                }
                .buttonStyle(.plain)
            }

            Section("Summary") {
                LabeledContent("Date", value: DateFormatter.sessionDisplay.string(from: session.date))
                LabeledContent("Total", value: session.totalAmount, format: .currency(code: "USD"))
                if let payer = session.paidByUser {
                    LabeledContent("Paid By", value: payer.name)
                }
                LabeledContent("Status") {
                    Text(session.isComplete ? "Complete" : "Draft")
                        .foregroundStyle(session.isComplete ? .green : .orange)
                }
                if let notes = session.notes, !notes.isEmpty {
                    LabeledContent("Notes", value: notes)
                }
            }

            Section("Line Items") {
                ForEach(session.lineItems.sorted(by: { $0.index < $1.index })) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(item.index). \(item.name)")
                                .fontWeight(.medium)
                            Spacer()
                            Text(item.amount, format: .currency(code: "USD"))
                        }
                        if !item.taggedUsers.isEmpty {
                            HStack {
                                Text(item.taggedUsers.map(\.name).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if item.taggedUsers.count > 1 {
                                    Text("· \(item.perPersonAmount.formatted(.currency(code: "USD"))) each")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onDelete(perform: deleteItems)
            }

            BalanceSummaryView(session: session)
        }
        .navigationTitle(session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !session.isComplete {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showEdit = true }
                }
            }
        }
        .sheet(isPresented: $showFullPhoto) {
            NavigationStack {
                ScrollView {
                    ReceiptPhotoView(filename: session.receiptPhotoFilename, fullscreen: true)
                        .padding()
                }
                .navigationTitle("Receipt")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showFullPhoto = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddExpenseView(editingSession: session)
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let sorted = session.lineItems.sorted(by: { $0.index < $1.index })
        for i in offsets {
            context.delete(sorted[i])
        }
    }
}
