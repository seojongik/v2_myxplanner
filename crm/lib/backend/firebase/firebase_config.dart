import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    // autogolfcrm-messaging 프로젝트 (MyXPlanner, crm_lite_pro와 동일)
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyAkuYPyMcgTJ4FBl8wJ4-ZctIshxAz505M",
            authDomain: "autogolfcrm-messaging.firebaseapp.com",
            projectId: "autogolfcrm-messaging",
            storageBucket: "autogolfcrm-messaging.firebasestorage.app",
            messagingSenderId: "101436238734",
            appId: "1:101436238734:web:3a082e5d671e4d39ff92df"));
  } else {
    await Firebase.initializeApp();
  }
}
