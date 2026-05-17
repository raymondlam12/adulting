import SwiftUI

struct ReceiptPhotoView: View {
    let filename: String?
    var fullscreen: Bool = false

    private var image: UIImage? {
        guard let filename else { return nil }
        // Use lastPathComponent to strip any directory traversal sequences
        let safeName = URL(fileURLWithPath: filename).lastPathComponent
        guard !safeName.isEmpty else { return nil }
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(safeName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        if let img = image {
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .if(!fullscreen) { $0.frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 12)) }
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(height: 160)
                .overlay {
                    Label("No Receipt", systemImage: "receipt")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}
