//
//  ReceiptScannerManager.swift
//  Finvo
//

import SwiftUI
import UIKit
import FirebaseAILogic

struct ScannedReceiptResult {
    var amount: Double?
    var date: Date?
    var merchantName: String?
    var suggestedCategory: CategoryModel?
    var suggestedSubCategory: SubCategoryModel?
    var isInstallment: Bool?
    var installmentCount: Int?
    var itemsList: String?
}

class ReceiptScannerManager {
    
    static func scanReceipt(image: UIImage, walletId: String) async -> ScannedReceiptResult? {
        let totalStartTime = CFAbsoluteTimeGetCurrent()
        print("DEBUG: Receipt scanning process started.")
        
        var availableCategories: [CategoryModel] = []
        if !walletId.isEmpty {
            do {
                availableCategories = try await FirestoreService.shared.fetchCategories(walletId: walletId)
                print("DEBUG: Fetched \(availableCategories.count) categories dynamically from Firestore for wallet \(walletId)")
            } catch {
                print("ERROR: Failed to fetch categories for wallet \(walletId): \(error)")
            }
        }
        
        if availableCategories.isEmpty {
            availableCategories = CategoriesMockData.data
            print("DEBUG: Using CategoriesMockData fallback (fetched list was empty or failed).")
        }
        
        do {
            if let result = try await scanReceiptWithFirebaseAI(image: image, availableCategories: availableCategories) {
                let totalElapsed = CFAbsoluteTimeGetCurrent() - totalStartTime
                print("DEBUG: Firebase AI Logic OCR Scanning Succeeded in \(String(format: "%.4f", totalElapsed)) seconds.")
                return result
            }
        } catch {
            print("ERROR: Firebase AI Logic OCR failed with error: \(error)")
        }
        
        let totalElapsed = CFAbsoluteTimeGetCurrent() - totalStartTime
        print("DEBUG: Firebase AI Logic OCR Scanning Failed in \(String(format: "%.4f", totalElapsed)) seconds.")
        return nil
    }
    
    
    // MARK: - Firebase AI Logic (Vertex AI for Firebase) Scanner
    private static func scanReceiptWithFirebaseAI(image: UIImage, availableCategories: [CategoryModel]) async throws -> ScannedReceiptResult? {
        guard let compressedData = await compressImage(image) else {
            return nil
        }
        
        let ai = FirebaseAI.firebaseAI(backend: .vertexAI())
        let thinkingConfig = ThinkingConfig(thinkingBudget: 0)
        let config = GenerationConfig(
            responseMIMEType: "application/json",
            thinkingConfig: thinkingConfig
        )
        let model = ai.generativeModel(
            modelName: "gemini-2.5-flash",
            generationConfig: config
        )
        
        var categoriesPrompt = ""
        let expenseCategories = availableCategories.filter { $0.type == .expense && $0.isOn }
        for cat in expenseCategories {
            let activeSubs = cat.subCategories.filter { $0.isOn }
            let subs = activeSubs.map { "\"\($0.id)\" (\($0.name))" }.joined(separator: ", ")
            categoriesPrompt += "- ID: \"\(cat.id)\", Name: \"\(cat.name)\" (Subcategories: \(subs))\n"
        }
        
        let prompt = """
        You are an expert OCR receipt parsing system. Analyze this receipt or invoice image.
        Extract the following fields and return exactly in this JSON format:
        {
          "amount": 1512,
          "date": "dd.MM.yyyy HH:mm",
          "merchantName": "Merchant Name",
          "suggestedCategoryId": "Category ID",
          "suggestedSubCategoryId": "SubCategory ID",
          "isInstallment": true,
          "installmentCount": 3,
          "itemsList": "1. Ürün Adı - Fiyat\\n2. Ürün Adı - Fiyat"
        }

        Rules:
        1. "amount": The total paid amount, parsed as a Double and rounded to the nearest integer. Do not include currency symbols.
        2. "date": The date and time of purchase formatted exactly as "dd.MM.yyyy HH:mm" (e.g. "22.06.2026 17:30"). Extract the time from the receipt if visible. If no time is visible, default the time portion to "12:00" (e.g., "dd.MM.yyyy 12:00"). If no date is found, return null.
        3. "merchantName": The company or shop name. Ensure it is capitalized and clean.
        4. "suggestedCategoryId" & "suggestedSubCategoryId": Categorize the transaction into one of these available categories and subcategories by selecting their exact ID from the list below:
        \(categoriesPrompt)
        
        CRITICAL RULE: If the receipt does not match any of these categories with high confidence, set BOTH "suggestedCategoryId" and "suggestedSubCategoryId" to null. Do not guess.
        5. "isInstallment": Boolean. Set to true if there is any indication of installment payments, "X Taksit", "Taksitli", "Ödeme Planı", "Taksit Tutarı", etc. Otherwise false.
        6. "installmentCount": Integer. Extract the number of total installments if present (e.g. 3, 6, 9, 12). If not present or not an installment transaction, return null.
        7. "itemsList": A formatted clean multiline string listing all parsed individual items, services, or products purchased on the receipt/invoice, along with their quantities and prices if available. Format it as an ordered list (e.g. "1. URUN A - 100 TL\\n2. URUN B - 50 TL"). If there are too many items, limit list to the first 30 items. If no items can be extracted, return null.
        """
        
        let apiStartTime = CFAbsoluteTimeGetCurrent()
        let imagePart = InlineDataPart(data: compressedData, mimeType: "image/jpeg")
        let response = try await model.generateContent(prompt, imagePart)
        let apiElapsed = CFAbsoluteTimeGetCurrent() - apiStartTime
        print("DEBUG: Firebase AI API Request took \(String(format: "%.4f", apiElapsed)) seconds.")
        
        guard let rawJsonString = response.text else {
            return nil
        }
        
        print("DEBUG: Firebase AI Logic Raw JSON response: \(rawJsonString)")
        
        struct GeminiReceiptResult: Decodable {
            let amount: Double?
            let date: String?
            let merchantName: String?
            let suggestedCategoryId: String?
            let suggestedSubCategoryId: String?
            let isInstallment: Bool?
            let installmentCount: Int?
            let itemsList: String?
        }
        
        let parseStartTime = CFAbsoluteTimeGetCurrent()
        guard let jsonData = rawJsonString.data(using: String.Encoding.utf8) else {
            return nil
        }
        
        let geminiResult = try JSONDecoder().decode(GeminiReceiptResult.self, from: jsonData)
        
        var result = ScannedReceiptResult()
        result.amount = geminiResult.amount
        result.merchantName = geminiResult.merchantName
        result.isInstallment = geminiResult.isInstallment
        result.installmentCount = geminiResult.installmentCount
        result.itemsList = geminiResult.itemsList
        
        // Parse date (tries "dd.MM.yyyy HH:mm" first, falls back to "dd.MM.yyyy")
        if let dateStr = geminiResult.date {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "tr_TR")
            
            formatter.dateFormat = "dd.MM.yyyy HH:mm"
            if let date = formatter.date(from: dateStr) {
                result.date = date
            } else {
                formatter.dateFormat = "dd.MM.yyyy"
                result.date = formatter.date(from: dateStr)
            }
        }
        
        // Match dynamic categories by ID with a name fallback in case AI returned category name
        if let catId = geminiResult.suggestedCategoryId {
            if let mainCat = availableCategories.first(where: { $0.id == catId }) {
                result.suggestedCategory = mainCat
                if let subId = geminiResult.suggestedSubCategoryId {
                    result.suggestedSubCategory = mainCat.subCategories.first(where: { $0.id == subId })
                }
            } else if let mainCat = availableCategories.first(where: { $0.name.lowercased() == catId.lowercased() }) {
                result.suggestedCategory = mainCat
                if let subId = geminiResult.suggestedSubCategoryId {
                    result.suggestedSubCategory = mainCat.subCategories.first(where: { $0.name.lowercased() == subId.lowercased() || $0.id == subId })
                }
            }
        }
        
        let parseElapsed = CFAbsoluteTimeGetCurrent() - parseStartTime
        print("DEBUG: JSON parsing and Category matching took \(String(format: "%.4f", parseElapsed)) seconds.")
        
        return result
    }
    
    private static func compressImage(_ image: UIImage) async -> Data? {
        let startTime = CFAbsoluteTimeGetCurrent()
        let maxSize: CGFloat = 768
        var width = image.size.width
        var height = image.size.height
        
        var targetImage = image
        if width > maxSize || height > maxSize {
            if width > height {
                height = (maxSize / width) * height
                width = maxSize
            } else {
                width = (maxSize / height) * width
                height = maxSize
            }
            
            let size = CGSize(width: width, height: height)
            if let thumbnail = await image.byPreparingThumbnail(ofSize: size) {
                targetImage = thumbnail
            }
        }
        
        let compressedData = targetImage.jpegData(compressionQuality: 0.5)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("DEBUG: Image compression took \(String(format: "%.4f", elapsed)) seconds. Compressed size: \(Double(compressedData?.count ?? 0) / 1024.0) KB")
        return compressedData
    }
}
