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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let currencyBinding = currencyBinding {
                    HStack {
                        Text("Para Birimi")
                            .foregroundStyle(theme.labelSecondary)
                        Spacer()
                        Picker("Para Birimi", selection: currencyBinding) {
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
                        Text(formatAmountText())
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.labelPrimary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: amount)
                            .allowsHitTesting(false)
                        
                        // Klavyenin ve imlecin (cursor) çalışması için arka planda TextField
                        TextField("", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.clear) // Metin görünmez ama imleç çalışır!
                            .tint(theme.brandPrimary) // İmleç rengi
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
                Text("Tamam")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 24)
        .navigationTitle("Tutar Girin")
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
        }
    }
    
    private func adjustAmount(by value: Double) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            var current: Double = 0
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if let number = formatter.number(from: amount) {
                current = number.doubleValue
            } else {
                let normalized = amount.replacingOccurrences(of: ",", with: ".")
                current = Double(normalized) ?? 0.0
            }
            
            current += value
            if current < 0 { current = 0 }
            
            if current == 0 {
                amount = ""
            } else {
                let isInteger = floor(current) == current
                amount = isInteger ? String(format: "%.0f", current) : "\(current)"
            }
        }
    }
    
    // Yardımcı fonksiyon: Klavyeden girilen metni anlık olarak binlik formatına çevirir
    private func formatAmountText() -> String {
        if amount.isEmpty { return "0" }
        var parsedAmount: Double = 0.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: amount) {
            parsedAmount = number.doubleValue
        } else {
            let normalized = amount.replacingOccurrences(of: ",", with: ".")
            parsedAmount = Double(normalized) ?? 0.0
        }
        
        let hasDecimal = amount.contains(",") || amount.contains(".")
        if hasDecimal {
            let parts = amount.replacingOccurrences(of: ",", with: ".").split(separator: ".", omittingEmptySubsequences: false)
            let decPart = parts.count > 1 ? parts[1] : ""
            let intVal = floor(parsedAmount)
            let formattedInt = intVal.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
            return "\(formattedInt),\(decPart)"
        } else {
            return parsedAmount.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
        }
    }
}
