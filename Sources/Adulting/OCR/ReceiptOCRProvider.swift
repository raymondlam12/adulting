import Foundation

struct ExtractedLineItem: Identifiable {
    var id = UUID()
    var name: String
    var amount: Decimal
}

protocol ReceiptOCRProvider {
    func extractLineItems(from imageURL: URL) async throws -> [ExtractedLineItem]
}

enum ReceiptOCRError: LocalizedError {
    case imageLoadFailed
    case noTextFound
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .imageLoadFailed:  return "Could not load the receipt image."
        case .noTextFound:      return "No readable text was found in the receipt."
        case .modelUnavailable: return "The AI model is not available on this device."
        }
    }
}
