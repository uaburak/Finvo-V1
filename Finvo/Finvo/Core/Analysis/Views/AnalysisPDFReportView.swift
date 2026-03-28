import SwiftUI
import Charts

struct AnalysisPDFReportView: View {
    let flowData: [FlowData]
    let categorySummaries: [CategorySummary]
    let biggestTransaction: TransactionModel?
    let totalRecurring: Double
    let timeFrame: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Finvo")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.blue)
                    
                    Text("Finansal Analiz Raporu")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(timeFrame)
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text(Date().formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Divider()
            
            // Net Akış Özeti
            let totalValue = flowData.reduce(0.0) { $0 + $1.netAmount }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Akış Özeti")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("\(totalValue >= 0 ? "+" : "")₺\(totalValue.formatted(.number.precision(.fractionLength(0))))")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(totalValue >= 0 ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Rekor İşlem")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("₺\((biggestTransaction?.amount ?? 0).formatted(.number.precision(.fractionLength(0))))")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.black)
                    if let tx = biggestTransaction { Text((tx.note ?? "").isEmpty ? tx.mainCategoryName : tx.note!).font(.caption).foregroundColor(.gray) }
                }
            }
            
            // Kategoriler
            VStack(alignment: .leading, spacing: 16) {
                Text("Kategori Dağılımı")
                    .font(.title2.bold())
                    .foregroundColor(.black)
                
                if categorySummaries.isEmpty {
                    Text("Bu dönemde veri yok.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(categorySummaries.prefix(8)) { summary in
                        HStack {
                            Text(summary.name)
                                .font(.body.bold())
                                .foregroundColor(.black)
                            Spacer()
                            Text("\(summary.transactionCount) İşlem")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("₺\(summary.amount.formatted(.number.precision(.fractionLength(0))))")
                                .font(.body.bold())
                                .foregroundColor(.black)
                            Text("(%\(summary.percentage.formatted(.number.precision(.fractionLength(0)))))")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
            
            Spacer()
            
            // Footer
            HStack {
                Text("Abonelik İşlemleri: ₺\(totalRecurring.formatted(.number.precision(.fractionLength(0))))")
                    .font(.subheadline.bold())
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("Finvo tarafından otomatik oluşturulmuştur.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(40)
        .frame(width: 595, height: 842) // A4 Boyutu (72 DPI)
        .background(Color.white)
    }
}
