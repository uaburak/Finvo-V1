import AppIntents
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

/// Siri / Kısayollar ile hızlı işlem ekleme.
/// Örnek: "Finvo ile harcama ekle" → tutar ve kategori sorulur, son kullanılan cüzdana kaydedilir.
enum IntentTransactionType: String, AppEnum {
    case expense
    case income

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "İşlem Türü"
    static let caseDisplayRepresentations: [IntentTransactionType: DisplayRepresentation] = [
        .expense: "Gider",
        .income: "Gelir"
    ]
}

struct AddTransactionIntent: AppIntent {
    static let title: LocalizedStringResource = "İşlem Ekle"
    static let description = IntentDescription("Finvo'daki son kullandığınız cüzdana gelir veya gider ekler.")

    @Parameter(title: "Tutar", requestValueDialog: "Ne kadar?")
    var amount: Double

    @Parameter(title: "Tür", default: .expense)
    var type: IntentTransactionType

    @Parameter(title: "Kategori", requestValueDialog: "Hangi kategori? (ör. Market)")
    var category: String?

    @Parameter(title: "Not")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$amount) tutarında \(\.$type) ekle") {
            \.$category
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            throw IntentError.message("Tutar sıfırdan büyük olmalı.")
        }
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        guard let uid = Auth.auth().currentUser?.uid else {
            throw IntentError.message("Önce Finvo uygulamasında oturum açın.")
        }

        let db = Firestore.firestore()
        guard let profile = try? await db.collection("users").document(uid).getDocument().data(as: UserModel.self),
              !profile.username.isEmpty else {
            throw IntentError.message("Profil bilgileriniz bulunamadı. Uygulamayı açıp tekrar deneyin.")
        }
        let username = profile.username

        let wallet = try await resolveWallet(db: db, username: username)
        guard let walletId = wallet.id else { throw IntentError.message("Cüzdan bulunamadı.") }
        guard wallet.canWrite(username) else {
            throw IntentError.message("Bu cüzdana işlem ekleme yetkiniz yok.")
        }

        let txType: TransactionType = type == .income ? .income : .expense
        let categories = await loadCategories(db: db, walletId: walletId).filter { $0.type == txType && $0.isOn }
        let matched = matchCategory(category, in: categories)
        guard let mainCategory = matched.main ?? categories.first(where: { $0.name.localizedCaseInsensitiveContains("Diğer") }) ?? categories.first else {
            throw IntentError.message("Kategori bulunamadı.")
        }

        let currency = UserDefaults.standard.string(forKey: "appCurrency").flatMap { CurrencyType(rawValue: $0) } ?? .tryCurrency
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let transaction = TransactionModel(
            walletId: walletId,
            type: txType,
            amount: amount,
            currency: currency,
            mainCategoryName: mainCategory.name,
            mainCategoryId: mainCategory.id,
            subCategoryName: matched.sub?.name,
            subCategoryId: matched.sub?.id,
            categoryIcon: matched.sub?.icon ?? mainCategory.icon,
            categoryColor: matched.sub?.color ?? mainCategory.color,
            date: Date(),
            note: (trimmedNote?.isEmpty ?? true) ? nil : trimmedNote,
            createdBy: username,
            createdAt: Date()
        )

        // Yazma yerel önbelleğe hemen alınır; ağ yoksa uygulama açılınca gönderilir.
        // Sunucu onayını en fazla birkaç saniye bekliyoruz ki Siri yanıtı gecikmesin.
        let ref = db.collection("wallets").document(walletId).collection("transactions").document()
        let data = try Firestore.Encoder().encode(transaction)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { try? await ref.setData(data) }
            group.addTask { try? await Task.sleep(nanoseconds: 4_000_000_000) }
            await group.next()
            group.cancelAll()
        }

        let money = "\(currency.symbol)\(AmountInput.display(AmountInput.string(from: amount)))"
        let categoryTitle = (matched.sub?.name ?? mainCategory.name).localized
        let typeTitle = txType == .income ? "gelir".localized : "gider".localized
        return .result(dialog: "\(money) \(categoryTitle) \(typeTitle) olarak \(wallet.name) cüzdanına eklendi.")
    }

    /// Son seçilen cüzdan; yoksa kullanıcının üyesi olduğu ilk cüzdan
    @MainActor
    private func resolveWallet(db: Firestore, username: String) async throws -> WalletModel {
        let lastId = UserDefaults.standard.string(forKey: "lastActiveWalletId") ?? ""
        if !lastId.isEmpty,
           let wallet = try? await db.collection("wallets").document(lastId).getDocument().data(as: WalletModel.self),
           wallet.members.contains(username) {
            return wallet
        }
        let snapshot = try await db.collection("wallets").whereField("members", arrayContains: username).getDocuments()
        let wallets = snapshot.documents.compactMap { try? $0.data(as: WalletModel.self) }
            .filter { $0.permissions[username] != WalletRole.pending.rawValue }
        guard let wallet = wallets.first(where: { $0.type == .personal }) ?? wallets.first else {
            throw IntentError.message("Cüzdan bulunamadı. Uygulamadan bir cüzdan oluşturun.")
        }
        return wallet
    }

    @MainActor
    private func loadCategories(db: Firestore, walletId: String) async -> [CategoryModel] {
        let fetched = (try? await db.collection("wallets").document(walletId).collection("categories").getDocuments())?
            .documents.compactMap { try? $0.data(as: CategoryModel.self) } ?? []
        return fetched.isEmpty ? CategoriesMockData.data : fetched
    }

    /// Kategori adını ana veya alt kategoriyle (kayıtlı ve çevrilmiş adıyla) eşleştirir
    @MainActor
    private func matchCategory(_ query: String?, in categories: [CategoryModel]) -> (main: CategoryModel?, sub: SubCategoryModel?) {
        guard let query = query?.trimmingCharacters(in: .whitespaces), !query.isEmpty else { return (nil, nil) }
        func matches(_ name: String) -> Bool {
            name.localizedCaseInsensitiveContains(query) || name.localized.localizedCaseInsensitiveContains(query)
        }
        for category in categories {
            if let sub = category.subCategories.first(where: { $0.isOn && matches($0.name) }) {
                return (category, sub)
            }
        }
        if let main = categories.first(where: { matches($0.name) }) {
            return (main, nil)
        }
        return (nil, nil)
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case message(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let text): return LocalizedStringResource(stringLiteral: text)
        }
    }
}

struct FinvoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTransactionIntent(),
            phrases: [
                "\(.applicationName) ile işlem ekle",
                "\(.applicationName) ile harcama ekle",
                "\(.applicationName)'ya harcama ekle",
                "Add a transaction in \(.applicationName)",
                "Add an expense in \(.applicationName)"
            ],
            shortTitle: "İşlem Ekle",
            systemImageName: "plus.circle.fill"
        )
    }
}
