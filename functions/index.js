/**
 * Firebase Cloud Functions for MyGolfPlanner
 * 채팅 메시지 FCM 푸시 알림 발송
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Firestore에 메시지가 추가되면 자동으로 FCM 푸시 알림 발송
 */
exports.sendChatNotification = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const messageId = context.params.messageId;
    
    console.log('🔔 [Cloud Functions] 새 메시지 감지:', messageId);
    console.log('🔔 [Cloud Functions] 메시지 데이터:', message);
    
    // 회원이 보낸 메시지인 경우 관리자에게 알림 발송
    // 관리자가 보낸 메시지인 경우 회원에게 알림 발송
    // 자신이 보낸 메시지에 대한 FCM 푸시는 발송하지 않음 (클라이언트에서 처리)
    
    const branchId = message.branchId;
    const senderId = message.senderId;
    const senderType = message.senderType;
    const chatRoomId = message.chatRoomId;
    
    console.log('🔔 [Cloud Functions] 새 메시지 감지:', {
      senderType,
      senderId,
      branchId,
      chatRoomId
    });
    
    if (senderType === 'member') {
      // 회원이 보낸 메시지 - 관리자에게 알림 발송
      console.log('🔔 [Cloud Functions] 회원 메시지 - 관리자에게 알림 발송');
      
      try {
        // 관리자 FCM 토큰 조회 (여러 관리자가 있을 수 있으므로)
        // 일단 해당 지점의 관리자 토큰을 조회
        const adminTokensSnapshot = await admin.firestore()
          .collection('fcmTokens')
          .where('branchId', '==', branchId)
          .where('isAdmin', '==', true)
          .get();
        
        if (adminTokensSnapshot.empty) {
          console.log('⚠️ [Cloud Functions] 관리자 FCM 토큰을 찾을 수 없음');
          return null;
        }
        
        const tokens = adminTokensSnapshot.docs.map(doc => doc.data().token).filter(Boolean);
        
        if (tokens.length === 0) {
          console.log('⚠️ [Cloud Functions] 유효한 관리자 토큰이 없음');
          return null;
        }
        
        console.log('🔔 [Cloud Functions] 관리자 토큰 개수:', tokens.length);
        
        // 채팅방 정보 가져오기
        const chatRoomDoc = await admin.firestore()
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
        
        const chatRoom = chatRoomDoc.data();
        const memberName = chatRoom?.memberName || '회원';
        
        // FCM 메시지 생성
        const notification = {
          title: `${memberName}님의 메시지`,
          body: message.message.length > 50 
            ? message.message.substring(0, 50) + '...' 
            : message.message,
        };
        
        const payload = {
          notification: notification,
          data: {
            type: 'chat',
            chatRoomId: chatRoomId,
            branchId: branchId,
            memberId: memberId,
            senderId: memberId, // 자신이 보낸 메시지인지 확인용
            messageId: messageId,
            senderName: memberName,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'chat_notifications',
              sound: 'default',
              priority: 'high',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        };
        
        // 여러 토큰에 일괄 발송
        const response = await admin.messaging().sendToDevice(tokens, payload);
        
        console.log('✅ [Cloud Functions] FCM 푸시 알림 발송 완료');
        console.log('✅ [Cloud Functions] 성공:', response.results.filter(r => r.error === undefined).length);
        console.log('⚠️ [Cloud Functions] 실패:', response.results.filter(r => r.error !== undefined).length);
        
        // 실패한 토큰 정리
        const failedTokens = [];
        response.results.forEach((result, index) => {
          if (result.error) {
            console.error('❌ [Cloud Functions] 토큰 발송 실패:', tokens[index], result.error);
            if (result.error.code === 'messaging/invalid-registration-token' ||
                result.error.code === 'messaging/registration-token-not-registered') {
              failedTokens.push(tokens[index]);
            }
          }
        });
        
        // 유효하지 않은 토큰 삭제
        if (failedTokens.length > 0) {
          const batch = admin.firestore().batch();
          adminTokensSnapshot.docs.forEach(doc => {
            if (failedTokens.includes(doc.data().token)) {
              batch.delete(doc.ref);
            }
          });
          await batch.commit();
          console.log('🗑️ [Cloud Functions] 유효하지 않은 토큰 삭제:', failedTokens.length);
        }
        
        return null;
      } catch (error) {
        console.error('❌ [Cloud Functions] FCM 푸시 알림 발송 실패:', error);
        return null;
      }
    }
    
    // 관리자가 보낸 메시지인 경우 회원에게 알림 발송
    if (message.senderType === 'admin') {
      const branchId = message.branchId;
      const chatRoomId = message.chatRoomId;
      
      console.log('🔔 [Cloud Functions] 관리자 메시지 - 회원에게 알림 발송');
      console.log('🔔 [Cloud Functions] branchId:', branchId, 'chatRoomId:', chatRoomId);
      
      try {
        // 채팅방 정보 가져오기 (memberId 확인용)
        const chatRoomDoc = await admin.firestore()
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
        
        if (!chatRoomDoc.exists) {
          console.log('⚠️ [Cloud Functions] 채팅방을 찾을 수 없음');
          return null;
        }
        
        const chatRoom = chatRoomDoc.data();
        const memberId = chatRoom?.memberId;
        const branchName = chatRoom?.branchName || '골프연습장';
        
        if (!memberId) {
          console.log('⚠️ [Cloud Functions] 채팅방에 회원 ID가 없음');
          return null;
        }
        
        // 회원 FCM 토큰 조회
        const memberTokenDoc = await admin.firestore()
          .collection('fcmTokens')
          .doc(`${branchId}_${memberId}`)
          .get();
        
        if (!memberTokenDoc.exists) {
          console.log('⚠️ [Cloud Functions] 회원 FCM 토큰을 찾을 수 없음');
          return null;
        }
        
        const token = memberTokenDoc.data().token;
        
        if (!token) {
          console.log('⚠️ [Cloud Functions] 유효한 회원 토큰이 없음');
          return null;
        }
        
        // FCM 메시지 생성
        const notification = {
          title: `${branchName}과의 1:1대화`,
          body: message.message.length > 50 
            ? message.message.substring(0, 50) + '...' 
            : message.message,
        };
        
        const payload = {
          notification: notification,
          data: {
            type: 'chat',
            chatRoomId: chatRoomId,
            branchId: branchId,
            memberId: memberId,
            senderId: message.senderId || 'admin', // 자신이 보낸 메시지인지 확인용
            messageId: messageId,
            senderName: message.senderName || '관리자',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'chat_notifications',
              sound: 'default',
              priority: 'high',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
          token: token,
        };
        
        // 단일 토큰에 발송
        await admin.messaging().send(payload);
        
        console.log('✅ [Cloud Functions] 회원에게 FCM 푸시 알림 발송 완료');
        
        return null;
      } catch (error) {
        console.error('❌ [Cloud Functions] 회원 FCM 푸시 알림 발송 실패:', error);
        
        // 유효하지 않은 토큰인 경우 삭제
        if (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') {
          const chatRoomDoc = await admin.firestore()
            .collection('chatRooms')
            .doc(chatRoomId)
            .get();
          
          if (chatRoomDoc.exists) {
            const chatRoom = chatRoomDoc.data();
            const memberId = chatRoom?.memberId;
            if (memberId) {
              await admin.firestore()
                .collection('fcmTokens')
                .doc(`${branchId}_${memberId}`)
                .delete();
              console.log('🗑️ [Cloud Functions] 유효하지 않은 토큰 삭제');
            }
          }
        }
        
        return null;
      }
    }
    
    return null;
  });

