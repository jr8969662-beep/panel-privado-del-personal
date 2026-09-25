/*
  Reemplazá estos valores por los de TU proyecto de Firebase.
  Los encontrás en: Firebase Console > Configuración del proyecto (ícono de
  engranaje) > Tus apps > app Web > "Config" (SDK setup and configuration).
*/
const firebaseConfig = {
  apiKey: "TU_API_KEY",
  authDomain: "tu-proyecto.firebaseapp.com",
  projectId: "tu-proyecto",
  storageBucket: "tu-proyecto.appspot.com",
  messagingSenderId: "000000000000",
  appId: "1:000000000000:web:xxxxxxxxxxxxxxxxxxxxxxxx",
};

firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();
const auth = firebase.auth();
