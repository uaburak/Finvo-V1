//
//  AddTransactionSheet.swift
//  Finvo
//
//  Created by Burak KOÇ on 16.03.2026.
//

import SwiftUI

// MARK: - Step Tanımı
enum AddTransactionStep: Int, CaseIterable {
    case transactionType = 1
    case mainCategory    = 2
    case subCategory     = 3
    case details         = 4

    var title: String {
        switch self {
        case .transactionType: return "İşlem Türü"
        case .mainCategory:    return "Ana Kategori"
        case .subCategory:     return "Alt Kategori"
        case .details:         return "İşlem Detayları"
        }
    }
}

// MARK: - Sheet View
struct AddTransactionSheet: View {
    @Environment(\.dismiss) var dismiss

    @State private var currentStep: AddTransactionStep = .transactionType
    @State private var navigateToCategories = false
    @State private var selectedType: TransactionType? = nil  // Seçilen işlem türü
    @State private var selectedDetent: PresentationDetent = .height(240)

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Step İçeriği ─────────────────────────────────────────────
                switch currentStep {
                case .transactionType:
                    Step1View { type in
                        selectedType = type
                        haptic(.medium)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = .mainCategory
                            selectedDetent = .medium
                        }
                    }
                case .mainCategory:
                    Step2View()
                case .subCategory:
                    Step3View()
                case .details:
                    Step4View()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.25), value: currentStep)
            .onAppear { haptic(.light) }  // Sheet açılışında
            // ── Native Navigation ────────────────────────────────────────────
            .navigationTitle(currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Sol: ilk adımda Kategoriler, diğer adımlarda Geri
                ToolbarItem(placement: .topBarLeading) {
                    if currentStep == .transactionType {
                        Button {
                            haptic(.light)
                            navigateToCategories = true
                        } label: {
                            Image(systemName: "square.grid.2x2")
                        }
                        .navigationDestination(isPresented: $navigateToCategories) {
                            CategoriesListView()
                        }
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if let prev = AddTransactionStep(rawValue: currentStep.rawValue - 1) {
                                    currentStep = prev
                                    haptic(.light)
                                    if prev == .transactionType {
                                        selectedDetent = .height(240)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }

                // Sağ: Kapat butonu
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        haptic(.medium) // Kapatırken
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

            }
            .safeAreaInset(edge: .bottom) {
                // İleri / Kaydet butonu — ilk adımda kartlar otomatik ilerletiyor, gizle
                if currentStep != .transactionType {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if let next = AddTransactionStep(rawValue: currentStep.rawValue + 1) {
                                currentStep = next
                                haptic(.medium)
                                selectedDetent = .medium
                            } else {
                                haptic(.heavy)
                                dismiss()
                            }
                        }
                    } label: {
                        Text(currentStep == .details ? "Kaydet" : "İleri")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
        }
        // ── Sheet Görünümü
        .presentationDetents(
            [.height(240), .medium, .large],
            selection: $selectedDetent
        )
        .presentationDragIndicator(.visible)
    }


}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddTransactionSheet()
        }
}
