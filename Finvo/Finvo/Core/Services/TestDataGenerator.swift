import Foundation
import FirebaseFirestore
import FirebaseAuth

class TestDataGenerator {
    
    static func generate(currentUsername: String?) async throws {
        let db = Firestore.firestore()
        
        let burakkocUid = "hWeCA4y4CaadGPTWmBD656fSByu1"
        let burakUid = "sZTVNgeFX3SBub29ORGrukcU2Je2"
        
        // 1. Ensure user profiles exist
        var burakkocProfile = try? await FirestoreService.shared.getUserProfile(uid: burakkocUid)
        if burakkocProfile == nil {
            burakkocProfile = UserModel(
                uid: burakkocUid,
                email: "burakkoc@finvo.app",
                firstName: "Burak",
                lastName: "Koç",
                username: "burakkoc",
                photoUrl: nil,
                isPro: true,
                ibans: nil
            )
        } else {
            burakkocProfile?.isPro = true
            burakkocProfile?.username = "burakkoc"
        }
        try db.collection("users").document(burakkocUid).setData(from: burakkocProfile!)
        
        var burakProfile = try? await FirestoreService.shared.getUserProfile(uid: burakUid)
        if burakProfile == nil {
            burakProfile = UserModel(
                uid: burakUid,
                email: "burak@finvo.app",
                firstName: "Burak",
                lastName: "Özkan",
                username: "burak",
                photoUrl: nil,
                isPro: true,
                ibans: nil
            )
        } else {
            burakProfile?.isPro = true
            burakProfile?.username = "burak"
        }
        try db.collection("users").document(burakUid).setData(from: burakProfile!)
        
        // 2. Find or create a shared wallet
        let walletsQuery = try await db.collection("wallets")
            .whereField("members", arrayContains: "burakkoc")
            .getDocuments()
        
        var sharedWallet: WalletModel? = nil
        for doc in walletsQuery.documents {
            if let w = try? doc.data(as: WalletModel.self),
               w.type == .shared,
               w.members.contains("burak") {
                sharedWallet = w
                break
            }
        }
        
        var members = ["burakkoc", "burak"]
        var permissions = [
            "burakkoc": WalletRole.owner.rawValue,
            "burak": WalletRole.admin.rawValue
        ]
        
        if let current = currentUsername, !current.isEmpty, !members.contains(current) {
            members.append(current)
            permissions[current] = WalletRole.admin.rawValue
        }
        
        if sharedWallet == nil {
            let docRef = db.collection("wallets").document()
            let newWallet = WalletModel(
                id: docRef.documentID,
                name: "Test Ortak Cüzdan",
                ownerId: "burakkoc",
                type: .shared,
                context: .general,
                members: members,
                permissions: permissions,
                monthlyLimit: nil,
                monthlyLimitCurrency: nil,
                savingsGoal: nil,
                savingsAccounts: nil
            )
            try docRef.setData(from: newWallet)
            sharedWallet = newWallet
        } else {
            // Update to ensure all members and permissions are set (including the current user)
            var needsUpdate = false
            for m in members {
                if !sharedWallet!.members.contains(m) {
                    sharedWallet!.members.append(m)
                    needsUpdate = true
                }
            }
            for (k, v) in permissions {
                if sharedWallet!.permissions[k] != v {
                    sharedWallet!.permissions[k] = v
                    needsUpdate = true
                }
            }
            if needsUpdate {
                try db.collection("wallets").document(sharedWallet!.id!).setData(from: sharedWallet!, merge: true)
            }
        }
        
        let walletId = sharedWallet!.id!
        
        // 3. Initialize default categories
        let categoriesQuery = try await db.collection("wallets").document(walletId).collection("categories").getDocuments()
        if categoriesQuery.isEmpty {
            try await FirestoreService.shared.initializeDefaultCategories(walletId: walletId, categories: CategoriesMockData.data)
        }
        let categories = try await FirestoreService.shared.fetchCategories(walletId: walletId)
        
        // 4. Delete old test transactions in this wallet
        let txQuery = try await db.collection("wallets").document(walletId).collection("transactions").getDocuments()
        let deleteBatch = db.batch()
        for doc in txQuery.documents {
            if let tx = try? doc.data(as: TransactionModel.self) {
                if tx.createdBy == "burakkoc" || tx.createdBy == "burak" || tx.note?.contains("[TEST]") == true {
                    deleteBatch.deleteDocument(doc.reference)
                }
            }
        }
        try await deleteBatch.commit()
        
        // 5. Generate test transactions
        let calendar = Calendar.current
        let today = Date()
        
        func dateOffset(days: Int) -> Date {
            return calendar.date(byAdding: .day, value: days, to: today) ?? today
        }
        
        func getCatDetails(mainName: String, subName: String) -> (mainId: String, subId: String, icon: String, color: String) {
            let main = categories.first(where: { $0.name.lowercased() == mainName.lowercased() })
            let sub = main?.subCategories.first(where: { $0.name.lowercased() == subName.lowercased() })
            return (
                mainId: main?.id ?? mainName.lowercased(),
                subId: sub?.id ?? subName.lowercased(),
                icon: sub?.icon ?? main?.icon ?? "questionmark",
                color: sub?.color ?? main?.color ?? "blue"
            )
        }
        
        // --- TRANSACTIONS FOR BURAKKOC ---
        
        // Market & Mutfak / Süpermarket
        let marketDetails = getCatDetails(mainName: "Market & Mutfak", subName: "Süpermarket")
        let burakkocMarketTxs = [
            (-80, 950.0, "[TEST] Haftalık Market Alışverişi"),
            (-50, 1100.0, "[TEST] Carrefour Alışverişi"),
            (-20, 1350.0, "[TEST] Macrocenter Alışverişi"),
            (-5, 800.0, "[TEST] A101 Manav"),
            (25, 1200.0, "[TEST] Migros Sanal Market"),
            (55, 1400.0, "[TEST] Haftalık Market Alışverişi"),
            (85, 1500.0, "[TEST] Market Alışverişi")
        ]
        
        for (offset, amt, note) in burakkocMarketTxs {
            let tx = TransactionModel(
                walletId: walletId,
                type: .expense,
                amount: amt,
                currency: .tryCurrency,
                mainCategoryName: "Market & Mutfak",
                mainCategoryId: marketDetails.mainId,
                subCategoryName: "Süpermarket",
                subCategoryId: marketDetails.subId,
                categoryIcon: marketDetails.icon,
                categoryColor: marketDetails.color,
                date: dateOffset(days: offset),
                note: note,
                createdBy: "burakkoc",
                createdAt: today,
                appCurrencyAmountAtCreation: amt
            )
            try FirestoreService.shared.createTransaction(tx)
        }
        
        // Debt (Borç) - Bank Loan
        let bankDetails = getCatDetails(mainName: "Banka & Finans", subName: "İhtiyaç Kredisi")
        let loanRef = db.collection("wallets").document(walletId).collection("transactions").document()
        let loanId = loanRef.documentID
        
        let originalLoan = TransactionModel(
            id: loanId, // Set the id
            walletId: walletId,
            type: .expense,
            amount: 60000.0,
            currency: .tryCurrency,
            mainCategoryName: "Banka & Finans",
            mainCategoryId: bankDetails.mainId,
            subCategoryName: "İhtiyaç Kredisi",
            subCategoryId: bankDetails.subId,
            categoryIcon: bankDetails.icon,
            categoryColor: bankDetails.color,
            date: dateOffset(days: -120),
            note: "[TEST] 12 Aylık İhtiyaç Kredisi",
            createdBy: "burakkoc",
            createdAt: dateOffset(days: -120),
            appCurrencyAmountAtCreation: 60000.0,
            isDebt: true,
            debtContact: "Garanti BBVA",
            totalInstallments: 12,
            paidInstallments: 4,
            dueDay: 15,
            isPaid: false,
            parentDebtId: nil,
            installmentNumber: nil
        )
        try loanRef.setData(from: originalLoan)
        
        // Paid installments for burakkoc's loan
        let installmentDays = [-120, -90, -60, -30]
        for i in 1...4 {
            let instTx = TransactionModel(
                walletId: walletId,
                type: .expense,
                amount: 5000.0,
                currency: .tryCurrency,
                mainCategoryName: "Banka & Finans",
                mainCategoryId: bankDetails.mainId,
                subCategoryName: "\(i). Taksit",
                subCategoryId: nil,
                categoryIcon: bankDetails.icon,
                categoryColor: bankDetails.color,
                date: dateOffset(days: installmentDays[i-1]),
                note: "[TEST] 12 Aylık İhtiyaç Kredisi",
                createdBy: "burakkoc",
                createdAt: today,
                appCurrencyAmountAtCreation: 5000.0,
                isDebt: false,
                debtContact: "Garanti BBVA",
                totalInstallments: 12,
                paidInstallments: i,
                isPaid: true,
                parentDebtId: loanId,
                installmentNumber: i
            )
            try FirestoreService.shared.createTransaction(instTx)
        }
        
        // Recurring (Tekrarlayan) - Netflix
        let subDetails = getCatDetails(mainName: "Abonelikler", subName: "Netflix")
        let netflixRef = db.collection("wallets").document(walletId).collection("transactions").document()
        let netflixId = netflixRef.documentID
        
        let netflixOriginal = TransactionModel(
            id: netflixId,
            walletId: walletId,
            type: .expense,
            amount: 229.99,
            currency: .tryCurrency,
            mainCategoryName: "Abonelikler",
            mainCategoryId: subDetails.mainId,
            subCategoryName: "Netflix",
            subCategoryId: subDetails.subId,
            categoryIcon: subDetails.icon,
            categoryColor: subDetails.color,
            date: dateOffset(days: -95),
            note: "[TEST] Netflix Aboneliği",
            createdBy: "burakkoc",
            createdAt: dateOffset(days: -95),
            appCurrencyAmountAtCreation: 229.99,
            isDebt: false,
            isRecurring: true,
            recurrenceInterval: .monthly,
            recurrenceEndDate: nil,
            lastGeneratedDate: dateOffset(days: -5),
            parentRecurringId: nil
        )
        try netflixRef.setData(from: netflixOriginal)
        
        // Netflix copies in the past
        let netflixOffsets = [-65, -35, -5]
        for offset in netflixOffsets {
            let netflixCopy = TransactionModel(
                walletId: walletId,
                type: .expense,
                amount: 229.99,
                currency: .tryCurrency,
                mainCategoryName: "Abonelikler",
                mainCategoryId: subDetails.mainId,
                subCategoryName: "Netflix",
                subCategoryId: subDetails.subId,
                categoryIcon: subDetails.icon,
                categoryColor: subDetails.color,
                date: dateOffset(days: offset),
                note: "[TEST] Netflix Aboneliği",
                createdBy: "burakkoc",
                createdAt: today,
                appCurrencyAmountAtCreation: 229.99,
                isDebt: false,
                isRecurring: false,
                parentRecurringId: netflixId
            )
            try FirestoreService.shared.createTransaction(netflixCopy)
        }
        
        
        // --- TRANSACTIONS FOR BURAK ---
        
        // Yeme İçme & Sosyal / Restoran & Yemek & Kahve & Çay
        let dineDetails = getCatDetails(mainName: "Yeme İçme & Sosyal", subName: "Restoran & Yemek")
        let coffeeDetails = getCatDetails(mainName: "Yeme İçme & Sosyal", subName: "Kahve & Çay")
        let burakFoodTxs = [
            (-75, 450.0, "[TEST] Starbucks Kahve", coffeeDetails),
            (-45, 1200.0, "[TEST] Akşam Yemeği", dineDetails),
            (-15, 350.0, "[TEST] Espresso Lab", coffeeDetails),
            (15, 850.0, "[TEST] Kahve & Tatlı", coffeeDetails),
            (45, 1500.0, "[TEST] Dostlarla Akşam Yemeği", dineDetails),
            (75, 600.0, "[TEST] Kafe Harcaması", dineDetails)
        ]
        
        for (offset, amt, note, details) in burakFoodTxs {
            let tx = TransactionModel(
                walletId: walletId,
                type: .expense,
                amount: amt,
                currency: .tryCurrency,
                mainCategoryName: "Yeme İçme & Sosyal",
                mainCategoryId: details.mainId,
                subCategoryName: details.subId == coffeeDetails.subId ? "Kahve & Çay" : "Restoran & Yemek",
                subCategoryId: details.subId,
                categoryIcon: details.icon,
                categoryColor: details.color,
                date: dateOffset(days: offset),
                note: note,
                createdBy: "burak",
                createdAt: today,
                appCurrencyAmountAtCreation: amt
            )
            try FirestoreService.shared.createTransaction(tx)
        }
        
        // Debt (Borç) - Home Renovation
        let homeDetails = getCatDetails(mainName: "Ev & Yaşam", subName: "Ev Tamirat & Tadilat")
        let homeDebtRef = db.collection("wallets").document(walletId).collection("transactions").document()
        let homeDebtId = homeDebtRef.documentID
        
        let originalHomeDebt = TransactionModel(
            id: homeDebtId,
            walletId: walletId,
            type: .expense,
            amount: 15000.0,
            currency: .tryCurrency,
            mainCategoryName: "Ev & Yaşam",
            mainCategoryId: homeDetails.mainId,
            subCategoryName: "Ev Tamirat & Tadilat",
            subCategoryId: homeDetails.subId,
            categoryIcon: homeDetails.icon,
            categoryColor: homeDetails.color,
            date: dateOffset(days: -45),
            note: "[TEST] Ev Boyama Badana Taksitleri",
            createdBy: "burak",
            createdAt: dateOffset(days: -45),
            appCurrencyAmountAtCreation: 15000.0,
            isDebt: true,
            debtContact: "Ahmet Usta (Boya)",
            totalInstallments: 3,
            paidInstallments: 1,
            dueDay: 5,
            isPaid: false,
            parentDebtId: nil,
            installmentNumber: nil
        )
        try homeDebtRef.setData(from: originalHomeDebt)
        
        // Paid installments for burak's tadilat debt
        let homeInstTx = TransactionModel(
            walletId: walletId,
            type: .expense,
            amount: 5000.0,
            currency: .tryCurrency,
            mainCategoryName: "Ev & Yaşam",
            mainCategoryId: homeDetails.mainId,
            subCategoryName: "1. Taksit",
            subCategoryId: nil,
            categoryIcon: homeDetails.icon,
            categoryColor: homeDetails.color,
            date: dateOffset(days: -45),
            note: "[TEST] Ev Boyama Badana Taksitleri",
            createdBy: "burak",
            createdAt: today,
            appCurrencyAmountAtCreation: 5000.0,
            isDebt: false,
            debtContact: "Ahmet Usta (Boya)",
            totalInstallments: 3,
            paidInstallments: 1,
            isPaid: true,
            parentDebtId: homeDebtId,
            installmentNumber: 1
        )
        try FirestoreService.shared.createTransaction(homeInstTx)
        
        // Recurring (Tekrarlayan) - YouTube Premium
        let ytDetails = getCatDetails(mainName: "Abonelikler", subName: "YouTube Premium")
        let ytRef = db.collection("wallets").document(walletId).collection("transactions").document()
        let ytId = ytRef.documentID
        
        let ytOriginal = TransactionModel(
            id: ytId,
            walletId: walletId,
            type: .expense,
            amount: 79.99,
            currency: .tryCurrency,
            mainCategoryName: "Abonelikler",
            mainCategoryId: ytDetails.mainId,
            subCategoryName: "YouTube Premium",
            subCategoryId: ytDetails.subId,
            categoryIcon: ytDetails.icon,
            categoryColor: ytDetails.color,
            date: dateOffset(days: -75),
            note: "[TEST] YouTube Premium Aile",
            createdBy: "burak",
            createdAt: dateOffset(days: -75),
            appCurrencyAmountAtCreation: 79.99,
            isDebt: false,
            isRecurring: true,
            recurrenceInterval: .monthly,
            recurrenceEndDate: nil,
            lastGeneratedDate: dateOffset(days: -15),
            parentRecurringId: nil
        )
        try ytRef.setData(from: ytOriginal)
        
        // YouTube Premium copies in the past
        let ytOffsets = [-45, -15]
        for offset in ytOffsets {
            let ytCopy = TransactionModel(
                walletId: walletId,
                type: .expense,
                amount: 79.99,
                currency: .tryCurrency,
                mainCategoryName: "Abonelikler",
                mainCategoryId: ytDetails.mainId,
                subCategoryName: "YouTube Premium",
                subCategoryId: ytDetails.subId,
                categoryIcon: ytDetails.icon,
                categoryColor: ytDetails.color,
                date: dateOffset(days: offset),
                note: "[TEST] YouTube Premium Aile",
                createdBy: "burak",
                createdAt: today,
                appCurrencyAmountAtCreation: 79.99,
                isDebt: false,
                isRecurring: false,
                parentRecurringId: ytId
            )
            try FirestoreService.shared.createTransaction(ytCopy)
        }
    }
}
