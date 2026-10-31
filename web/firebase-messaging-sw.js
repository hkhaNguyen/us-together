// Shows the other one's news while the app is closed. Firebase Messaging
// looks for this file at the site root; the config matches
// DefaultFirebaseOptions.web in lib/firebase_options.dart.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBepdWALgPLK_Z13bIbKjWKs4FaijRktHI',
  appId: '1:81386949637:web:61f4cbe7be704f701ca06c',
  messagingSenderId: '81386949637',
  projectId: 'us-together-a1e30',
  authDomain: 'us-together-a1e30.firebaseapp.com',
  storageBucket: 'us-together-a1e30.firebasestorage.app',
});

firebase.messaging();
