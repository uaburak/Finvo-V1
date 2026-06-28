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
    const senderUsername = data.senderUsername;
    const walletName = data.walletName;
    const type = data.type; // 'invitation' veya 'role_request'

    console.log(`New notification created. Sender: ${senderUsername}, Receiver: ${receiverUsername}, Type: ${type}`);

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
      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body
        },
        data: {
          type: type,
          walletId: data.walletId,
          senderUsername: senderUsername
        },
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
      console.error("Error triggering push notification cloud function:", error);
      return null;
    }
  });
