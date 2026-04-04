cat << 'INNER_EOF' > /tmp/tm_patch.swift
    func recalculateTotals(for currency: CurrencyType) {
        let baseCurrency = currency
        
        let income = transactions.filter { $0.type == .income && !$0.isDebt }.reduce(0) { total, tx in
            total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
        }
        let expense = transactions.filter { $0.type == .expense && !$0.isDebt }.reduce(0) { total, tx in
            total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
        }
        
        let today = Date()
        let calendar = Calendar.current
        let todaysTx = transactions.filter { calendar.isDate($0.date, inSameDayAs: today) }
        
        let tIncome = todaysTx.filter { $0.type == .income && !$0.isDebt }.reduce(0) { total, tx in
            total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
        }
        let tExpense = todaysTx.filter { $0.type == .expense && !$0.isDebt }.reduce(0) { total, tx in
            total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
        }
        let profit = tIncome - tExpense
        
        let expenseOnly = transactions.filter { $0.type == .expense && !$0.isDebt }
        let expenseDict = Dictionary(grouping: expenseOnly, by: { $0.mainCategoryId ?? $0.mainCategoryName })
        let topEntry = expenseDict.max(by: { a, b in 
            a.value.reduce(0) { $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: baseCurrency) } < 
            b.value.reduce(0) { $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: baseCurrency) } 
        })
        let topId = topEntry?.key
        let topName = topEntry?.value.first?.mainCategoryName ?? "-"
        
        self.totalIncome = income
        self.totalExpense = expense
        self.todaysProfit = profit
        self.topExpenseCategoryId = topId
        self.topExpenseCategoryName = topName
    }
INNER_EOF
