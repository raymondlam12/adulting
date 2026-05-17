import SwiftUI

struct UserTagPicker: View {
    let users: [AppUser]
    @Binding var selected: [AppUser]
    var singleSelect: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(users) { user in
                    let isSelected = selected.contains(where: { $0.id == user.id })
                    Button {
                        toggle(user)
                    } label: {
                        Group {
                            if user.isUnassigned {
                                Label("? \(user.name)", systemImage: "questionmark.circle")
                                    .font(.subheadline)
                            } else {
                                Text(user.name)
                                    .font(.subheadline)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            isSelected ? Color.accentColor
                                       : (user.isUnassigned ? Color.gray.opacity(0.2) : Color(.systemGray5))
                        )
                        .foregroundStyle(
                            isSelected ? .white
                                       : (user.isUnassigned ? Color.secondary : Color.primary)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func toggle(_ user: AppUser) {
        if singleSelect {
            selected = [user]
            return
        }
        if let idx = selected.firstIndex(where: { $0.id == user.id }) {
            selected.remove(at: idx)
        } else {
            selected.append(user)
        }
    }
}
