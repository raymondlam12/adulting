import Vision
import UIKit
import Foundation

final class VisionReceiptOCR: ReceiptOCRProvider {

    func extractLineItems(from imageURL: URL) async throws -> [ExtractedLineItem] {
        let strings = try await recognizeText(from: imageURL)
        guard !strings.isEmpty else { throw ReceiptOCRError.noTextFound }
        let items = parseLineItems(from: strings)
        return items
    }

    // MARK: - Raw text extraction (reusable by FoundationModelsReceiptOCR)

    func recognizeText(from imageURL: URL) async throws -> [String] {
        guard let image = UIImage(contentsOfFile: imageURL.path),
              let cgImage = image.cgImage else {
            throw ReceiptOCRError.imageLoadFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                // Vision uses bottom-left origin; sort descending by minY → top-to-bottom reading order
                let sorted = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
                let strings = sorted.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: strings)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Heuristic line-item parser

    private func parseLineItems(from lines: [String]) -> [ExtractedLineItem] {
        // Matches an optional $ then digits.2digits at a word boundary, e.g. 12.99 or $4.50
        let priceRegex = try! NSRegularExpression(pattern: #"\$?\s*(\d{1,6}[.,]\d{2})\b"#)

        var items: [ExtractedLineItem] = []

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = priceRegex.firstMatch(in: line, range: range),
                  let priceRange = Range(match.range(at: 1), in: line) else { continue }

            let rawPrice = String(line[priceRange]).replacingOccurrences(of: ",", with: ".")
            guard let amount = Decimal(string: rawPrice), amount > 0, amount < 1000 else { continue }

            // Everything before the price match is the item name
            let beforePrice = line[line.startIndex ..< priceRange.lowerBound]
                .replacingOccurrences(of: "$", with: "")
                .trimmingCharacters(in: .whitespaces)

            guard !beforePrice.isEmpty, !isNoiseLine(beforePrice) else { continue }

            items.append(ExtractedLineItem(name: beforePrice, amount: amount))
        }

        // Fallback: if nothing parsed, try treating the whole line as name+price
        if items.isEmpty {
            for line in lines {
                let range = NSRange(line.startIndex..., in: line)
                guard let match = priceRegex.firstMatch(in: line, range: range),
                      let priceRange = Range(match.range(at: 1), in: line) else { continue }
                let rawPrice = String(line[priceRange]).replacingOccurrences(of: ",", with: ".")
                guard let amount = Decimal(string: rawPrice), amount > 0, amount < 1000 else { continue }
                let name = line.replacingOccurrences(of: String(line[priceRange]), with: "")
                    .replacingOccurrences(of: "$", with: "")
                    .trimmingCharacters(in: .whitespaces)
                guard name.count >= 2 else { continue }
                items.append(ExtractedLineItem(name: name, amount: amount))
            }
        }

        return items
    }

    private func isNoiseLine(_ text: String) -> Bool {
        let noisePatterns = [
            "subtotal", "sub total", "sub-total",
            "total", "grand total",
            "tax", "hst", "gst", "pst", "vat",
            "tip", "gratuity",
            "change", "cash", "visa", "mastercard",
            "debit", "credit", "amex", "discover",
            "thank you", "receipt", "store #", "order #",
            "server", "table", "cashier", "clerk"
        ]
        let lower = text.lowercased()
        if noisePatterns.contains(where: { lower.contains($0) }) { return true }
        // Date pattern: 01/12 or 2024-01-12
        if text.range(of: #"\d{1,2}[/\-]\d{1,2}"#, options: .regularExpression) != nil { return true }
        // Time pattern: 14:32
        if text.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) != nil { return true }
        return false
    }
}
