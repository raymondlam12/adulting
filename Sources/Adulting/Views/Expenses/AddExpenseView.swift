import SwiftUI
import SwiftData
import PhotosUI

struct AddExpenseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \AppUser.createdAt) private var users: [AppUser]

    var editingSession: ExpenseSession?

    // Step tracking
    @State private var step: Step = .photo

    // Photo
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var capturedPhotoFilename: String?

    // Details
    @State private var totalAmountText: String = ""
    @State private var payer: [AppUser] = []
    @State private var titleText: String = ""
    @State private var notesText: String = ""

    // Line items
    @State private var lineItems: [DraftLineItem] = []
    @State private var showLineItemForm = false
    @State private var editingLineItem: DraftLineItem?

    @State private var session: ExpenseSession?

    enum Step { case photo, details, lineItems }

    struct DraftLineItem: Identifiable {
        var id = UUID()
        var index: Int
        var name: String
        var amount: Decimal
        var taggedUsers: [AppUser]
    }

    private var totalAmount: Decimal { Decimal(string: totalAmountText) ?? 0 }
    private var lineItemsSum: Decimal { lineItems.reduce(Decimal(0)) { $0 + $1.amount } }
    private var canComplete: Bool { abs(lineItemsSum - totalAmount) < Decimal(0.01) && totalAmount > 0 }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .photo: photoStep
                case .details: detailsStep
                case .lineItems: lineItemsStep
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { loadEditingSession() }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                capturedPhotoFilename = savePhoto(image)
                showCamera = false
            }
        }
        .sheet(isPresented: $showLineItemForm) {
            LineItemFormView(
                users: users,
                index: (editingLineItem?.index ?? lineItems.count + 1),
                existing: editingLineItem.flatMap { draft in
                    session?.lineItems.first(where: { $0.id == draft.id })
                }
            ) { name, amount, tagged in
                if let editing = editingLineItem {
                    if let idx = lineItems.firstIndex(where: { $0.id == editing.id }) {
                        lineItems[idx] = DraftLineItem(id: editing.id, index: editing.index, name: name, amount: amount, taggedUsers: tagged)
                    }
                } else {
                    lineItems.append(DraftLineItem(index: lineItems.count + 1, name: name, amount: amount, taggedUsers: tagged))
                }
                editingLineItem = nil
            }
        }
    }

    // MARK: - Photo Step

    private var photoStep: some View {
        VStack(spacing: 24) {
            Text("Add Receipt Photo")
                .font(.title2).bold()

            ReceiptPhotoView(filename: capturedPhotoFilename)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button { showCamera = true } label: {
                    Label("Camera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .onChange(of: photoPickerItem) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            capturedPhotoFilename = savePhoto(img)
                        }
                    }
                }
            }
            .padding(.horizontal)

            Spacer()

            Button { step = .details } label: {
                Text(capturedPhotoFilename == nil ? "Skip Photo" : "Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("New Expense")
    }

    // MARK: - Details Step

    private var detailsStep: some View {
        Form {
            Section("Total Amount") {
                TextField("0.00", text: $totalAmountText)
                    .keyboardType(.decimalPad)
            }

            Section("Paid By") {
                UserTagPicker(users: users, selected: $payer, singleSelect: true)
                    .padding(.vertical, 4)
            }

            Section("Optional") {
                TextField("Title", text: $titleText)
                TextField("Notes", text: $notesText, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }

            Section {
                Button("Next: Add Line Items") {
                    upsertSession()
                    step = .lineItems
                }
                .disabled(totalAmountText.isEmpty || payer.isEmpty)
            }
        }
        .navigationTitle("Details")
    }

    // MARK: - Line Items Step

    private var lineItemsStep: some View {
        List {
            Section {
                ReceiptPhotoView(filename: capturedPhotoFilename)
                    .listRowInsets(.init())
            }

            Section {
                HStack {
                    Text("Total")
                    Spacer()
                    Text(totalAmount, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Tagged")
                    Spacer()
                    Text(lineItemsSum, format: .currency(code: "USD"))
                        .foregroundStyle(canComplete ? .green : .orange)
                        .fontWeight(.semibold)
                }
            }

            Section("Line Items") {
                ForEach(lineItems.sorted(by: { $0.index < $1.index })) { item in
                    Button {
                        editingLineItem = item
                        showLineItemForm = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(item.index). \(item.name)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(item.amount, format: .currency(code: "USD"))
                                    .foregroundStyle(.primary)
                            }
                            if !item.taggedUsers.isEmpty {
                                Text(item.taggedUsers.map(\.name).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    let sorted = lineItems.sorted(by: { $0.index < $1.index })
                    let idsToRemove = offsets.map { sorted[$0].id }
                    lineItems.removeAll { idsToRemove.contains($0.id) }
                    reindex()
                }

                Button {
                    editingLineItem = nil
                    showLineItemForm = true
                } label: {
                    Label("Add Line Item", systemImage: "plus")
                }
            }

            Section {
                Button("Save Draft") {
                    saveLineItemsToSession(complete: false)
                    dismiss()
                }

                Button("Mark Complete") {
                    saveLineItemsToSession(complete: true)
                    dismiss()
                }
                .disabled(!canComplete)
            }
        }
        .navigationTitle("Line Items")
    }

    // MARK: - Helpers

    private func loadEditingSession() {
        guard let s = editingSession else { return }
        session = s
        capturedPhotoFilename = s.receiptPhotoFilename
        totalAmountText = "\(s.totalAmount)"
        payer = s.paidByUser.map { [$0] } ?? []
        titleText = s.title ?? ""
        notesText = s.notes ?? ""
        lineItems = s.lineItems.sorted(by: { $0.index < $1.index }).map {
            DraftLineItem(id: $0.id, index: $0.index, name: $0.name, amount: $0.amount, taggedUsers: $0.taggedUsers)
        }
        step = .lineItems
    }

    private func upsertSession() {
        let amount = Decimal(string: totalAmountText) ?? 0
        if let s = session {
            s.totalAmount = amount
            s.paidByUser = payer.first
            s.title = titleText.isEmpty ? nil : titleText
            s.notes = notesText.isEmpty ? nil : notesText
            s.receiptPhotoFilename = capturedPhotoFilename
        } else {
            let s = ExpenseSession(
                title: titleText.isEmpty ? nil : titleText,
                totalAmount: amount,
                paidByUser: payer.first,
                receiptPhotoFilename: capturedPhotoFilename,
                notes: notesText.isEmpty ? nil : notesText
            )
            context.insert(s)
            session = s
        }
    }

    private func saveLineItemsToSession(complete: Bool) {
        upsertSession()
        guard let s = session else { return }

        // Remove deleted items
        let draftIDs = Set(lineItems.map(\.id))
        s.lineItems.filter { !draftIDs.contains($0.id) }.forEach { context.delete($0) }

        // Upsert each draft
        for draft in lineItems {
            if let existing = s.lineItems.first(where: { $0.id == draft.id }) {
                existing.name = draft.name
                existing.amount = draft.amount
                existing.taggedUsers = draft.taggedUsers
                existing.index = draft.index
            } else {
                let item = LineItem(index: draft.index, name: draft.name, amount: draft.amount, taggedUsers: draft.taggedUsers)
                item.expenseSession = s
                context.insert(item)
            }
        }
        s.isComplete = complete
    }

    private func reindex() {
        for (i, id) in lineItems.sorted(by: { $0.index < $1.index }).map(\.id).enumerated() {
            if let idx = lineItems.firstIndex(where: { $0.id == id }) {
                lineItems[idx].index = i + 1
            }
        }
    }

    private func savePhoto(_ image: UIImage) -> String {
        let filename = UUID().uuidString + ".jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url)
        }
        return filename
    }
}
