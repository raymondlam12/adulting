#if canImport(FoundationModels)
import FoundationModels
import Foundation

@available(iOS 26, *)
final class FoundationModelsReceiptOCR: ReceiptOCRProvider {

    func extractLineItems(from imageURL: URL) async throws -> [ExtractedLineItem] {
        // Stage 1: Vision extracts raw text (no heuristic parsing)
        let visionOCR = VisionReceiptOCR()
        let rawLines = try await visionOCR.recognizeText(from: imageURL)
        guard !rawLines.isEmpty else { throw ReceiptOCRError.noTextFound }

        let rawText = rawLines.joined(separator: "\n")

        // Stage 2: Gate on Apple Intelligence availability
        guard SystemLanguageModel.default.isAvailable else {
            // Silently degrade — user may have disabled Apple Intelligence
            return try await visionOCR.extractLineItems(from: imageURL)
        }

        let session = LanguageModelSession()
        let prompt = """
        The following is raw OCR text from a receipt. \
        Extract each purchased line item. \
        Ignore subtotal, tax, tip, total, payment method, server name, \
        table number, date, time, and greeting lines.

        Receipt text:
        \(rawText)
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: ReceiptExtractionResult.self
            )
            return response.content.items.compactMap { item in
                let trimmedName = item.name.trimmingCharacters(in: .whitespaces)
                guard !trimmedName.isEmpty,
                      let amount = Decimal(string: item.priceString),
                      amount > 0 else { return nil }
                return ExtractedLineItem(name: trimmedName, amount: amount)
            }
        } catch {
            // Model assets may be unavailable (e.g. simulator, Apple Intelligence disabled
            // at OS level) even when isAvailable returns true. Fall back to Vision.
            return try await visionOCR.extractLineItems(from: imageURL)
        }
    }
}

// MARK: - Generable output types

@available(iOS 26, *)
@Generable
struct ReceiptExtractionResult {
    @Guide(description: "The individual purchased items found on the receipt")
    var items: [GeneratedLineItem]
}

@available(iOS 26, *)
@Generable
struct GeneratedLineItem {
    @Guide(description: "Product or menu item name, clean and concise, no price included")
    var name: String

    @Guide(description: "Item price as a decimal string, e.g. \"12.99\"")
    var priceString: String
}
#endif
