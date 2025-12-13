// Firebase Cloud Messaging Service Worker for CRM
// 이 파일은 백그라운드 푸시 알림을 처리합니다.

importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

// Firebase 초기화 - autogolfcrm-messaging 프로젝트 (MyXPlanner, crm_lite_pro와 동일)
firebase.initializeApp({
  apiKey: "AIzaSyAkuYPyMcgTJ4FBl8wJ4-ZctIshxAz505M",
  authDomain: "autogolfcrm-messaging.firebaseapp.com",
  projectId: "autogolfcrm-messaging",
  storageBucket: "autogolfcrm-messaging.firebasestorage.app",
  messagingSenderId: "101436238734",
  appId: "1:101436238734:web:3a082e5d671e4d39ff92df"
});

const messaging = firebase.messaging();

// 백그라운드 메시지 처리
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] 백그라운드 메시지 수신:', payload);

  const notificationTitle = payload.notification?.title || '새 메시지';
  const notificationOptions = {
    body: payload.notification?.body || '새로운 알림이 있습니다.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.chat_room_id || 'default',
    data: payload.data,
    requireInteraction: true, // 사용자가 클릭할 때까지 알림 유지
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// 알림 클릭 처리
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] 알림 클릭:', event);
  
  event.notification.close();

  // 채팅방으로 이동 (data에 chat_room_id가 있으면)
  const chatRoomId = event.notification.data?.chat_room_id;
  const urlToOpen = chatRoomId 
    ? `${self.location.origin}/#/crm7Communication?tab=3&chatRoomId=${chatRoomId}`
    : `${self.location.origin}/#/crm7Communication?tab=3`;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      // 이미 열려있는 창이 있으면 포커스
      for (const client of windowClients) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.focus();
          client.navigate(urlToOpen);
          return;
        }
      }
      // 열려있는 창이 없으면 새 창 열기
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});

console.log('[firebase-messaging-sw.js] Service Worker 등록 완료');
