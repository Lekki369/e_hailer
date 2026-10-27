/* Firebase Cloud Messaging Service Worker for e-Hailer Web */
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDuKc9u-xCbsfRALpP0wSiYQ14zTZDz5Jg",
  appId: "1:616271910128:web:e236a4cd21862d33171e35",
  messagingSenderId: "616271910128",
  projectId: "e-hailer-e949f",
  authDomain: "e-hailer-e949f.firebaseapp.com",
  storageBucket: "e-hailer-e949f.firebasestorage.app",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification ? payload.notification.title : 'e-Hailer Logistics';
  const notificationOptions = {
    body: payload.notification ? payload.notification.body : '',
    icon: '/favicon.png',
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
