import SwiftUI
import SwiftData

struct SummaryView: View {
    @Query(sort: \AppUser.createdAt) private var users: [AppUser]
    @Query private var sessions: [ExpenseSession]
    @Query private var payments: [Payment]

    @State private var paymentTarget: AppUser?

    private var balances: [(user: AppUser, tagged: Decimal, paid: Decimal, balance: Decimal)] {
        var tagged: [UUID: Decimal] = [:]
        for session in sessions {
            for item in session.lineItems {
                let share = item.perPersonAmount
                for user in item.taggedUsers {
                    tagged[user.id, default: 0] += share
                }
            }
        }

        var paid: [UUID: Decimal] = [:]
        for payment in payments {
            if let uid = payment.user?.id {
                paid[uid, default: 0] += payment.amount
            }
        }

        return users.map { user in
            let t = tagged[user.id, default: 0]
            let p = paid[user.id, default: 0]
            return (user: user, tagged: t, paid: p, balance: t - p)
        }
        .sorted { abs($0.balance) > abs($1.balance) }
    }

    var body: some View {
        NavigationStack {
            List {
                if balances.isEmpty {
                    ContentUnavailableView(
                        "No Data Yet",
                        systemImage: "chart.bar",
                        description: Text("Add expenses and tag people to see their balances here.")
                    )
                } else {
                    Section {
                        ForEach(balances, id: \.user.id) { entry in
                            balanceRow(entry)
                        }
                    } header: {
                        Text("Outstanding Balances")
                    } footer: {
                        Text("Balance = total tagged in expenses minus recorded payments.")
                    }
                }
            }
            .navigationTitle("Summary")
            .sheet(item: $paymentTarget) { user in
                RecordPaymentView(preselectedUser: user)
            }
        }
    }

    @ViewBuilder
    private func balanceRow(_ entry: (user: AppUser, tagged: Decimal, paid: Decimal, balance: Decimal)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(entry.user.name)
                            .fontWeight(.medium)
                        if entry.user.isSelf {
                            Text("(You)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 12) {
                        Label(entry.tagged.formatted(.currency(code: "USD")), systemImage: "arrow.up.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Label(entry.paid.formatted(.currency(code: "USD")), systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.balance, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                        .foregroundStyle(balanceColor(entry.balance))
                    Text(balanceLabel(entry.balance))
                        .font(.caption2)
                        .foregroundStyle(balanceColor(entry.balance))
                }
            }
            if !entry.user.isSelf && entry.balance > 0 {
                Button {
                    paymentTarget = entry.user
                } label: {
                    Label("Record Payment", systemImage: "dollarsign.circle")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private func balanceColor(_ balance: Decimal) -> Color {
        if abs(balance) < 0.01 { return .secondary }
        return balance > 0 ? .orange : .green
    }

    private func balanceLabel(_ balance: Decimal) -> String {
        if abs(balance) < 0.01 { return "Settled" }
        return balance > 0 ? "Owes" : "Credit"
    }
}

extension AppUser: Identifiable {}
