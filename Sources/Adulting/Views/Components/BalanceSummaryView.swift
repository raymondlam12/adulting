import SwiftUI

struct BalanceSummaryView: View {
    let session: ExpenseSession

    private var balances: [(user: AppUser, owes: Decimal)] {
        var totals: [UUID: (AppUser, Decimal)] = [:]
        for item in session.lineItems {
            guard !item.taggedUsers.isEmpty else { continue }
            let share = item.perPersonAmount
            for user in item.taggedUsers {
                if let existing = totals[user.id] {
                    totals[user.id] = (user, existing.1 + share)
                } else {
                    totals[user.id] = (user, share)
                }
            }
        }
        return totals.values
            .sorted { $0.0.name < $1.0.name }
            .map { (user: $0.0, owes: $0.1) }
    }

    var body: some View {
        Section("Who Owes What") {
            ForEach(balances, id: \.user.id) { entry in
                HStack {
                    Text(entry.user.name)
                    Spacer()
                    Text(entry.owes, format: .currency(code: "USD"))
                        .fontWeight(.medium)
                }
            }
        }
    }
}
