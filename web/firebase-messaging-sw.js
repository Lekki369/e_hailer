/* Public configuration is generated locally from the validated client .env. */
importScripts('firebase-client-config.js');

if (!self.E_HAILER_FIREBASE_EMULATORS) {
  // Keep the worker on the exact SDK version selected by firebase_core_web.
  const version = self.E_HAILER_FIREBASE_SDK_VERSION;
  if (!/^\d+\.\d+\.\d+$/.test(version)) {
    throw new Error('Firebase worker SDK configuration is missing.');
  }
  importScripts(`https://www.gstatic.com/firebasejs/${version}/firebase-app-compat.js`);
  importScripts(`https://www.gstatic.com/firebasejs/${version}/firebase-messaging-compat.js`);
  firebase.initializeApp(self.E_HAILER_FIREBASE_CONFIG);
  // Firebase displays notification payloads itself. Do not duplicate them,
  // log message bodies or persist unrelated notification contents here.
  firebase.messaging();
}
