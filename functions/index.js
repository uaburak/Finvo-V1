const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * Firestore'daki 'notifications' koleksiyonuna yeni bir davet veya yetki isteği eklendiğinde
 * tetiklenir ve ilgili alıcı kullanıcının FCM token'ına anlık push bildirimi gönderir. (v1 Compatibility API)
 */
exports.sendNotificationPush = functions.firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data) return null;

    const receiverUsername = data.receiverUsername;
    const senderUsername = data.senderUsername || "";
    const walletName = data.walletName || "";
    const type = data.type; // 'invitation' veya 'role_request'

    if (typeof receiverUsername !== "string" || !receiverUsername) {
      console.log("Notification has no valid receiverUsername, skipping.");
      return null;
    }

    console.log(`New notification created. Sender: ${senderUsername}, Receiver: ${receiverUsername}, Type: ${type}`);

    // catch bloğunda geçersiz token temizliği için dışarıda tutuluyor
    let receiverDocRef = null;

    try {
      // 1. Alıcı kullanıcının FCM Token adresini Firestore'dan çekelim
      const userQuery = await admin.firestore().collection("users")
        .where("username", "==", receiverUsername.toLowerCase())
        .limit(1)
        .get();

      if (userQuery.empty) {
        console.log(`Receiver user document not found for username: ${receiverUsername}`);
        return null;
      }

      const receiverDoc = userQuery.docs[0];
      receiverDocRef = receiverDoc.ref;
      const receiverData = receiverDoc.data();
      const fcmToken = receiverData.fcmToken;

      if (!fcmToken) {
        console.log(`Receiver user has no registered fcmToken: ${receiverUsername}`);
        return null;
      }

      // 2. Bildirim başlık ve gövdesini oluştur
      let title = "";
      let body = "";

      if (type === "invitation") {
        title = "Cüzdan Daveti 💼";
        body = `@${senderUsername} seni "${walletName}" cüzdanına davet etti.`;
      } else if (type === "role_request") {
        title = "Yetki İsteği 🔑";
        body = `@${senderUsername}, "${walletName}" cüzdanı için yetki istiyor.`;
      } else {
        title = "Yeni Bildirim";
        body = `@${senderUsername} sana bir bildirim gönderdi.`;
      }

      // 3. APNs & FCM mesaj paketi hazırlama
      // FCM data payload'ında tüm değerler string olmak zorundadır; undefined/null bir alan
      // gönderimin tamamen hata vermesine yol açar (ör. walletId olmayan bir bildirim kaydı).
      const payloadData = {};
      if (type) payloadData.type = String(type);
      if (data.walletId) payloadData.walletId = String(data.walletId);
      if (senderUsername) payloadData.senderUsername = String(senderUsername);

      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body
        },
        data: payloadData,
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1
            }
          }
        }
      };

      // 4. Push Bildirimini gönder
      const response = await admin.messaging().send(message);
      console.log(`Successfully sent push notification to ${receiverUsername}:`, response);
      return response;

    } catch (error) {
      // Cihaz uygulamayı silmiş / token geçersizse kaydı temizle, aksi halde
      // her bildirimde aynı ölü token'a gönderim denenmeye devam eder.
      // Not: "messaging/invalid-argument" bilerek listede değil — token dışındaki
      // hatalı alanlar için de dönebiliyor ve geçerli bir token'ı silmemize yol açardı.
      const invalidTokenCodes = [
        "messaging/registration-token-not-registered",
        "messaging/invalid-registration-token"
      ];

      if (invalidTokenCodes.includes(error.code) && receiverDocRef) {
        console.log(`Removing invalid fcmToken for ${receiverUsername} (${error.code})`);
        await receiverDocRef.update({
          fcmToken: admin.firestore.FieldValue.delete()
        }).catch((cleanupError) => {
          console.error("Error cleaning up invalid fcmToken:", cleanupError);
        });
        return null;
      }

      console.error("Error triggering push notification cloud function:", error);
      return null;
    }
  });
