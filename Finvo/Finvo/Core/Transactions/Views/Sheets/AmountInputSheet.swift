//
//  AmountInputSheet.swift
//  Finvo
//

import SwiftUI

struct AmountInputSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @StateObject private var exchangeRateManager = ExchangeRateManager.shared
    @Binding var amount: String
    var currencyBinding: Binding<CurrencyType>? = nil
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let currencyBinding = currencyBinding {
                    HStack {
                        Text(L10n("Para Birimi"))
                            .foregroundStyle(theme.labelSecondary)
                        Spacer()
                        Picker(L10n("Para Birimi"), selection: currencyBinding) {
                            ForEach(exchangeRateManager.allCurrencies.filter { $0.assetType == "Döviz" }, id: \.self) { currency in
                                Text(currency.code).tag(currency)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(theme.brandPrimary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
                
                VStack(spacing: 16) {
                // Main Amount Row with +/- 100
                HStack(spacing: 16) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        adjustAmount(by: -100)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(theme.expense)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.glass)
                    
                    ZStack {
                        // Animasyonun çalışması için sadece okunabilir Text ekliyoruz
                        Text(formatAmountText(amount))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.labelPrimary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: amount)
                            .allowsHitTesting(false)
                        
                        // Klavyenin ve imlecin (cursor) çalışması için arka planda TextField
                        TextField("", text: formattedAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.clear) // Metin görünmez ama imleç çalışır!
                            .tint(theme.brandPrimary) // İmleç rengi
                            .focused($isAmountFocused)
                    }
                    .frame(minWidth: 120)
                    
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        adjustAmount(by: 100)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(theme.income)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.glass)
                }
                
                // Secondary Buttons for +/- 50
                HStack(spacing: 16) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        adjustAmount(by: -50)
                    } label: {
                        Text("-50")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(theme.expense)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glass)
                    
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        adjustAmount(by: 50)
                    } label: {
                        Text("+50")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(theme.income)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(.horizontal, 16)
            
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dismiss()
            } label: {
                Text(L10n("Tamam"))
                    .font(.headline)
                    .foregroundStyle(theme.onBrandPrimary)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 24)
        .navigationTitle(L10n("Tutar Girin"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.bold)
                        .foregroundStyle(theme.labelPrimary)
                }
            }
        }
        .onAppear {
            // Modal açıldığında klavyenin otomatik açılması için focus veriyoruz
            isAmountFocused = true
        }
        }
    }
    
    private func adjustAmount(by value: Double) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            var current = AmountInput.parse(amount)
            
            current += value
            if current < 0 { current = 0 }
            
            if current == 0 {
                amount = ""
            } else {
                amount = AmountInput.string(from: current)
            }
        }
    }
    
    // Bindings ve yardımcı formatlama metodları (imleç ve animasyon uyumu için)
    private var formattedAmount: Binding<String> {
        Binding<String>(
            get: { AmountInput.display(amount) },
            set: { newValue in
                amount = AmountInput.raw(fromEdited: newValue, previousRaw: amount)
            }
        )
    }
    
    private func formatAmountText(_ value: String) -> String {
        AmountInput.display(value)
    }

}
