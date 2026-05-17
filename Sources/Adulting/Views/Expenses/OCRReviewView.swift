import SwiftUI

struct OCRReviewView: View {
    let imageFilename: String
    let onConfirm: ([ExtractedLineItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var state: OCRState = .loading

    private enum OCRState {
        case loading
        case results([EditableItem])
        case error(String)
    }

    private struct EditableItem: Identifiable {
        var id = UUID()
        var name: String
        var amountText: String
        var isSelected: Bool = true

        var parsedAmount: Decimal? { Decimal(string: amountText) }
        var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedAmount != nil }
    }

    private var selectedItems: [EditableItem] {
        guard case .results(let items) = state else { return [] }
        return items.filter(\.isSelected)
    }

    private var canConfirm: Bool {
        !selectedItems.isEmpty && selectedItems.allSatisfy(\.isValid)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    loadingView
                case .results:
                    resultsList
                case .error(let message):
                    errorView(message)
                }
            }
            .navigationTitle("Review Scanned Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if case .results = state {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add to Expense") { confirm() }
                            .disabled(!canConfirm)
                    }
                }
            }
        }
        .task { await runExtraction() }
    }

    // MARK: - Sub-views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning receipt…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        guard case .results(let items) = state else { return AnyView(EmptyView()) }
        return AnyView(
            List {
                Section {
                    ForEach(items) { item in
                        itemRow(item)
                    }
                } header: {
                    Text("Tap a row to deselect it")
                } footer: {
                    Text("Edit names and amounts before adding. Items will be tagged Unassigned.")
                }
            }
        )
    }

    @ViewBuilder
    private func itemRow(_ item: EditableItem) -> some View {
        let binding = binding(for: item)
        HStack(spacing: 12) {
            Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isSelected ? Color.accentColor : Color.secondary)
                .onTapGesture { binding.wrappedValue.isSelected.toggle() }

            VStack(alignment: .leading, spacing: 4) {
                TextField("Item name", text: binding.name)
                    .font(.body)
                TextField("Amount", text: binding.amountText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .keyboardType(.decimalPad)
            }
        }
        .opacity(item.isSelected ? 1 : 0.4)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Could not scan receipt")
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Dismiss") { dismiss() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func runExtraction() async {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeName = URL(fileURLWithPath: imageFilename).lastPathComponent
        let imageURL = docsDir.appendingPathComponent(safeName)

        do {
            let extracted = try await ReceiptOCRFactory.provider().extractLineItems(from: imageURL)
            if extracted.isEmpty {
                state = .error("No line items could be found on this receipt. Try adding them manually.")
            } else {
                state = .results(extracted.map {
                    EditableItem(name: $0.name, amountText: "\($0.amount)")
                })
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func confirm() {
        guard case .results(let items) = state else { return }
        let confirmed = items
            .filter { $0.isSelected && $0.isValid }
            .compactMap { item -> ExtractedLineItem? in
                guard let amount = item.parsedAmount else { return nil }
                return ExtractedLineItem(name: item.name.trimmingCharacters(in: .whitespaces),
                                        amount: amount)
            }
        onConfirm(confirmed)
        dismiss()
    }

    // MARK: - Binding helper

    private func binding(for item: EditableItem) -> Binding<EditableItem> {
        Binding {
            if case .results(let items) = state {
                return items.first(where: { $0.id == item.id }) ?? item
            }
            return item
        } set: { newValue in
            if case .results(var items) = state,
               let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx] = newValue
                state = .results(items)
            }
        }
    }
}
