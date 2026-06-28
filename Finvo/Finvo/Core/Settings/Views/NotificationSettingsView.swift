import SwiftUI
import UserNotifications
import FirebaseFirestore

struct NotificationSettingsView: View {
    @Environment(\.theme) var theme
    @StateObject private var localNotificationManager = LocalNotificationManager.shared
    @EnvironmentObject var transactionManager: TransactionManager
    
    let dayOptions = [
        (0, "Aynı Gün"),
        (1, "1 Gün Önce"),
        (2, "2 Gün Önce"),
        (3, "3 Gün Önce"),
        (5, "5 Gün Önce"),
        (7, "1 Hafta Önce")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - İzin Kontrol Paneli
                if !localNotificationManager.isAuthorized {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.badge.slash.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(theme.expense)
                        
                        Text("Bildirim İzni Devre Dışı")
                            .font(.headline)
                            .foregroundStyle(theme.labelPrimary)
                        
                        Text("Uygulamadan yaklaşan borç ve tekrarlayan işlem bildirimlerini alabilmek için cihaz ayarlarından bildirimlere izin vermeniz gerekmektedir.")
                            .font(.subheadline)
                            .foregroundStyle(theme.labelSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Cihaz Ayarlarını Aç")
                                .font(.subheadline.bold())
                                .foregroundStyle(theme.onBrandPrimary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(theme.brandPrimary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal)
                }
                
                // MARK: - Genel Ayarlar Grubu
                VStack(spacing: 16) {
                    Toggle(isOn: $localNotificationManager.localNotificationsEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.fill")
                                .font(.title3)
                                .foregroundStyle(theme.brandPrimary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bildirimleri Etkinleştir")
                                    .font(.headline)
                                    .foregroundStyle(theme.labelPrimary)
                                Text("Uygulama bildirimlerini açar veya kapatır.")
                                    .font(.caption)
                                    .foregroundStyle(theme.labelSecondary)
                            }
                        }
                    }
                    .tint(theme.brandPrimary)
                    .disabled(!localNotificationManager.isAuthorized)
                    
                    if localNotificationManager.localNotificationsEnabled && localNotificationManager.isAuthorized {
                        Divider().background(theme.separator)
                        
                        // Saat Seçimi
                        HStack {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.fill")
                                    .font(.title3)
                                    .foregroundStyle(theme.brandPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Bildirim Saati")
                                        .font(.headline)
                                        .foregroundStyle(theme.labelPrimary)
                                    Text("Hatırlatıcıların geleceği saat.")
                                        .font(.caption)
                                        .foregroundStyle(theme.labelSecondary)
                                }
                            }
                            Spacer()
                            DatePicker("", selection: notificationTimeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(theme.brandPrimary)
                        }
                    }
                }
                .padding()
                .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)
                
                // MARK: - Gider & Gelir Detay Ayarları
                if localNotificationManager.localNotificationsEnabled && localNotificationManager.isAuthorized {
                    // Gider Ayarları
                    VStack(spacing: 16) {
                        Toggle(isOn: $localNotificationManager.expenseNotificationsEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.up.right.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(theme.expense)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Gider Hatırlatıcıları")
                                        .font(.headline)
                                        .foregroundStyle(theme.labelPrimary)
                                    Text("Ödemesi yaklaşan fatura, borç ve giderler.")
                                        .font(.caption)
                                        .foregroundStyle(theme.labelSecondary)
                                }
                            }
                        }
                        .tint(theme.brandPrimary)
                        
                        if localNotificationManager.expenseNotificationsEnabled {
                            Divider().background(theme.separator)
                            
                            HStack {
                                Text("Ne Zaman Bildirilsin?")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.labelPrimary)
                                Spacer()
                                Picker("", selection: $localNotificationManager.expenseNotificationDays) {
                                    ForEach(dayOptions, id: \.0) { option in
                                        Text(option.1).tag(option.0)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(theme.brandPrimary)
                            }
                        }
                    }
                    .padding()
                    .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal)
                    
                    // Gelir Ayarları
                    VStack(spacing: 16) {
                        Toggle(isOn: $localNotificationManager.incomeNotificationsEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.down.left.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(theme.income)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Gelir Hatırlatıcıları")
                                        .font(.headline)
                                        .foregroundStyle(theme.labelPrimary)
                                    Text("Maaş ve gelecek diğer gelir bildirimleri.")
                                        .font(.caption)
                                        .foregroundStyle(theme.labelSecondary)
                                }
                            }
                        }
                        .tint(theme.brandPrimary)
                        
                        if localNotificationManager.incomeNotificationsEnabled {
                            Divider().background(theme.separator)
                            
                            HStack {
                                Text("Ne Zaman Bildirilsin?")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.labelPrimary)
                                Spacer()
                                Picker("", selection: $localNotificationManager.incomeNotificationDays) {
                                    ForEach(dayOptions, id: \.0) { option in
                                        Text(option.1).tag(option.0)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(theme.brandPrimary)
                            }
                        }
                    }
                    .padding()
                    .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal)
                }
                
                // MARK: - Test Bölümü
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                            .foregroundStyle(theme.brandPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Anlık Push Testi")
                                .font(.headline)
                                .foregroundStyle(theme.labelPrimary)
                            Text("Kendinize test bildirimi tetikleyin.")
                                .font(.caption)
                                .foregroundStyle(theme.labelSecondary)
                        }
                    }
                    
                    Divider().background(theme.separator)
                    
                    Button {
                        let feedback = UIImpactFeedbackGenerator(style: .medium)
                        feedback.impactOccurred()
                        
                        guard let myUsername = AuthenticationManager.shared.currentUserProfile?.username else { return }
                        
                        let db = FirebaseFirestore.Firestore.firestore()
                        let testDoc: [String: Any] = [
                            "senderUsername": "TestBot",
                            "receiverUsername": myUsername,
                            "walletName": "Test Cüzdanı",
                            "type": "invitation",
                            "status": "pending",
                            "createdAt": FirebaseFirestore.FieldValue.serverTimestamp(),
                            "walletId": "test_wallet_id"
                        ]
                        
                        db.collection("notifications").addDocument(data: testDoc) { error in
                            if let error = error {
                                print("Test belgesi yazılırken hata: \(error)")
                            } else {
                                print("Test belgesi başarıyla yazıldı!")
                            }
                        }
                    } label: {
                        Text("Kendime Test Bildirimi Gönder")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.brandPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    Text("Bu buton Firestore'a sizin adınıza bir davet kaydı ekler. Cloud Function tetiklenerek size push bildirimi göndermeye çalışır. Lütfen uygulamayı arka plana alıp test edin.")
                        .font(.caption2)
                        .foregroundStyle(theme.labelSecondary)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(theme.background1.ignoresSafeArea())
        .navigationTitle("Bildirim Ayarları")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            localNotificationManager.checkAuthorizationStatus()
            // İzin isteriz eğer ilk defa açılıyorsa
            Task {
                _ = await localNotificationManager.requestAuthorization()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            localNotificationManager.checkAuthorizationStatus()
        }
        .onChange(of: localNotificationManager.localNotificationsEnabled) { _, _ in reschedule() }
        .onChange(of: localNotificationManager.expenseNotificationsEnabled) { _, _ in reschedule() }
        .onChange(of: localNotificationManager.expenseNotificationDays) { _, _ in reschedule() }
        .onChange(of: localNotificationManager.incomeNotificationsEnabled) { _, _ in reschedule() }
        .onChange(of: localNotificationManager.incomeNotificationDays) { _, _ in reschedule() }
    }
    
    // Binding helper for custom Time Picker
    private var notificationTimeBinding: Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day], from: Date())
                components.hour = localNotificationManager.notificationHour
                components.minute = localNotificationManager.notificationMinute
                return calendar.date(from: components) ?? Date()
            },
            set: { newDate in
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: newDate)
                localNotificationManager.notificationHour = components.hour ?? 9
                localNotificationManager.notificationMinute = components.minute ?? 0
                reschedule()
            }
        )
    }
    
    private func reschedule() {
        localNotificationManager.scheduleNotifications(for: transactionManager.transactions)
    }
}
