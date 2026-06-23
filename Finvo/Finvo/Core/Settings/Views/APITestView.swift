import SwiftUI

struct APITestView: View {
    @State private var logs: String = "Test'i başlatmak için butona basın...\n"
    @State private var isRunning: Bool = false
    
    var body: some View {
        VStack {
            Button(action: {
                runTest()
            }) {
                Text(isRunning ? "İstek Atılıyor..." : "Piyasa Kurlarını Test Et")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .disabled(isRunning)
            .padding()
            
            ScrollView {
                Text(logs)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("API Test")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func runTest() {
        isRunning = true
        logs += "\n----------------------\n"
        logs += "[*] İstek hazırlanıyor...\n"
        
        Task {
            let urlString = "https://finans.truncgil.com/today.json"
            
            logs += "URL: \(urlString)\n"
            
            guard let url = URL(string: urlString) else {
                logs += "[HATA] URL geçersiz.\n"
                isRunning = false
                return
            }
            
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                
                logs += "[*] İstek atılıyor...\n"
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    logs += "[*] HTTP Status Code: \(httpResponse.statusCode)\n"
                    if let headers = httpResponse.allHeaderFields as? [String: Any] {
                        logs += "[*] Response Headers:\n"
                        for (key, val) in headers {
                            logs += "    \(key): \(val)\n"
                        }
                    }
                }
                
                logs += "[*] Yanıt verisi yükleniyor (Bytes: \(data.count))...\n"
                
                if let str = String(data: data, encoding: .utf8) {
                    logs += "[*] Yanıt İçeriği (İlk 500 karakter):\n"
                    logs += String(str.prefix(500)) + (str.count > 500 ? "..." : "") + "\n"
                } else {
                    logs += "[HATA] Yanıt string'e çevrilemedi.\n"
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    logs += "\n[*] Ayrıştırma (Parse) Testi:\n"
                    
                    if let usdDict = json["USD"] as? [String: String], let satisStr = usdDict["Satış"] {
                        logs += "USD (Ham): \(satisStr) -> "
                        let cleanStr = satisStr.replacingOccurrences(of: ",", with: ".")
                        logs += "(\(cleanStr))\n"
                    } else {
                        logs += "USD: Bulunamadı\n"
                    }
                    
                    if let eurDict = json["EUR"] as? [String: String], let satisStr = eurDict["Satış"] {
                        logs += "EUR (Ham): \(satisStr) -> "
                        let cleanStr = satisStr.replacingOccurrences(of: ",", with: ".")
                        logs += "(\(cleanStr))\n"
                    } else {
                        logs += "EUR: Bulunamadı\n"
                    }
                    
                    if let goldDict = json["gram-altin"] as? [String: String], let satisStr = goldDict["Satış"] {
                        logs += "ALTIN (Ham): \(satisStr) -> "
                        let cleanStr = satisStr.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                        logs += "(\(cleanStr))\n"
                    } else {
                        logs += "ALTIN: Bulunamadı\n"
                    }
                } else {
                    logs += "[HATA] JSON parse edilemedi veya kök obje Dict değil.\n"
                }
                
            } catch {
                logs += "[HATA] İstek gönderilirken hata oluştu:\n\(error.localizedDescription)\n"
            }
            
            isRunning = false
        }
    }
}
