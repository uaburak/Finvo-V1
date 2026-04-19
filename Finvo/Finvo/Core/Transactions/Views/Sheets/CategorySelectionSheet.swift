//
//  CategorySelectionSheet.swift
//  Finvo
//

import SwiftUI

struct CategorySelectionSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    let categories: [CategoryModel]
    @Binding var selectedMainCategory: CategoryModel?
    @Binding var selectedSubCategory: SubCategoryModel?

    var body: some View {
        NavigationStack {
            List(categories) { category in
                NavigationLink(destination: subCategoryView(for: category)) {
                    Label(category.name, systemImage: category.icon)
                        .foregroundStyle(theme.labelPrimary)
                }
                .listRowBackground(theme.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(theme.background1)
            .navigationTitle(L10n("Kategori Seçin"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n("Kapat")) { dismiss() }
                }
            }
        }
    }

    private func subCategoryView(for category: CategoryModel) -> some View {
        List(category.subCategories) { sub in
            Button {
                selectedMainCategory = category
                selectedSubCategory = sub
                dismiss()
            } label: {
                Label(sub.name, systemImage: sub.icon)
                    .foregroundStyle(theme.labelPrimary)
            }
            .listRowBackground(theme.cardBackground)
        }
        .scrollContentBackground(.hidden)
        .background(theme.background1)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
