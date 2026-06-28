# Firebase Cloud Messaging (FCM) & APNs Push Bildirim Kurulum Kılavuzu

Bu kılavuz, Finvo uygulamasında cüzdan davetleri ve yetki taleplerinin anlık olarak (uygulama kapalıyken bile) telefonlara bildirim olarak düşmesini sağlayan **Uzak Bildirim (Push Notification)** sisteminin kurulum adımlarını açıklar.

---

## 1. Adım: Apple Developer Portal Ayarları

Uygulamanın push bildirimlerini alabilmesi için Apple Geliştirici Hesabınızda aşağıdaki işlemleri yapmanız gerekir:

1. **Apple Developer Portal**'a [developer.apple.com](https://developer.apple.com) gidin.
2. **Certificates, Identifiers & Profiles** bölümüne tıklayın.
3. **Identifiers** (Uygulama ID'leri) sekmesine gelin ve uygulamanızın **Bundle ID**'sine tıklayın.
4. **Capabilities** (Yetenekler) listesinde **Push Notifications** seçeneğini bulun ve yanındaki kutucuğu işaretleyip **Save** diyerek kaydedin.
5. Soldaki menüden **Keys** sekmesine tıklayın ve yeni bir anahtar (`+` butonuyla) oluşturun:
   - Anahtar ismi: `FCM Push Key` gibi bir isim verin.
   - Listeden **Apple Push Notifications service (APNs)** seçeneğini aktif edin.
   - **Continue** -> **Register** diyerek tamamlayın.
   - Oluşturulan **Key ID** değerini kopyalayın (Firebase'de gerekecek).
   - **Download** diyerek `.p8` uzantılı anahtar dosyasını bilgisayarınıza indirin (**Önemli:** Bu dosya sadece bir kez indirilebilir, güvenli bir yerde saklayın).

---

## 2. Adım: Firebase Console Ayarları

Apple bildirim sunucusu (APNs) ile Firebase'i birbirine bağlamak için:

1. **Firebase Console**'a [console.firebase.google.com](https://console.firebase.google.com) gidin ve projenizi açın.
2. Sol üstteki çark (Ayarlar) simgesine tıklayıp **Project Settings** (Proje Ayarları) bölümüne gidin.
3. Üstteki sekmelerden **Cloud Messaging** bölümünü açın.
4. Sayfanın altındaki **Apple app shares** / **Apple app configuration** bölümünde **APNs Authentication Key** alanındaki **Upload** butonuna tıklayın:
   - `.p8` uzantılı indirdiğiniz anahtar dosyasını yükleyin.
   - Apple Developer Key ID'nizi girin.
   - Apple Developer Team ID'nizi girin (Portalın sağ üst köşesinde adınızın yanında yer alan 10 haneli kod).
   - **Upload** diyerek işlemi kaydedin.

---

## 3. Adım: Firebase Cloud Functions Kurulumu ve Dağıtımı

Uygulama kapalıyken Firestore'daki değişiklikleri yakalayıp bildirimi tetikleyecek sunucu kodunu (Cloud Function) yüklemek için:

1. Terminali açın ve projenin ana dizininde aşağıdaki komutla Firebase CLI'yi başlatın (Eğer yüklü değilse `npm install -g firebase-tools` yapın):
   ```bash
   firebase login
   ```
2. Projenin bulunduğu klasörde fonksiyonları başlatın:
   ```bash
   firebase init functions
   ```
   - Çıkan sorularda mevcut Firebase projenizi seçin.
   - Dil seçeneği olarak **JavaScript** seçin.
   - `ESLint` kullanmak istiyor musunuz sorusuna `N` diyebilirsiniz.
   - Bağımlılıkları şimdi yüklemek istiyor musunuz sorusuna `Y` deyin.
3. Bu işlem bittiğinde projenizin ana dizininde `functions` adında yeni bir klasör oluşacaktır.
4. Bu klasör içindeki `index.js` dosyasının içeriğini, bu dizindeki `cloud-functions/index.js` dosyasının içeriği ile tamamen değiştirin.
5. Aşağıdaki komutla Cloud Function kodunu Firebase'e yükleyin:
   ```bash
   firebase deploy --only functions
   ```

Tebrikler! Artık biri davet gönderdiğinde, arka planda tetiklenen bu fonksiyon alıcının FCM Token adresini bularak anlık bir push bildirimi gönderecektir.
