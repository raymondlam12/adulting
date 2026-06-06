import Foundation

enum ReceiptOCRFactory {
    static func provider() -> any ReceiptOCRProvider {
#if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return FoundationModelsReceiptOCR()
        }
#endif
        return VisionReceiptOCR()
    }
}
