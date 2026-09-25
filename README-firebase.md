# Configuración de Firebase para "Mi Comisaría"

Este proyecto usa **Firebase** (gratis para este volumen de uso) como backend:
- **Firestore**: guarda los datos de cada solicitud.
- **Storage**: guarda las fotos de los DNI.
- **Authentication**: login del personal en `panel.html`.

## 1. Crear el proyecto
1. Entrá a https://console.firebase.google.com (con una cuenta de Google).
2. "Agregar proyecto" → ponele nombre (ej: `mi-comisaria`) → seguir los pasos por defecto.

## 2. Habilitar Firestore
1. En el menú lateral: **Compilación → Firestore Database → Crear base de datos**.
2. Elegí **modo producción** y la región más cercana (ej: `southamerica-east1`).
3. Andá a la pestaña **Reglas** y pegá esto:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /solicitudes/{docId} {
      allow create: if true;               // cualquiera puede enviar un trámite
      allow read, update: if request.auth != null;  // solo el personal logueado puede ver/editar
      allow delete: if false;
    }
  }
}
```

## 3. Guardado de fotos (sin Storage, sin tarjeta)
Desde febrero de 2026, Firebase exige el plan pago (Blaze, con tarjeta vinculada) para usar
**Storage**, aunque el uso siga siendo gratis dentro de los límites. Para evitar pedirte una
tarjeta, este proyecto **no usa Storage**: las fotos del DNI se comprimen en el navegador
(ancho máx. 700px, calidad JPEG reducida) y se guardan directamente como parte del mismo
documento en Firestore. Con esa compresión, cada solicitud (hasta 3 fotos) ocupa bastante
menos que el límite de 1 MB por documento de Firestore, así que no hace falta ningún paso
extra acá.

Si en el futuro preferís usar Storage (por ejemplo, si necesitás fotos de mayor calidad),
hay que activar el plan Blaze desde Firebase Console → Configuración del proyecto → Detalles
de uso y facturación.

## 4. Habilitar Authentication (login del personal)
1. **Compilación → Authentication → Comenzar**.
2. Pestaña **Sign-in method** → habilitar **Correo electrónico/contraseña**.
3. Pestaña **Users → Add user**: creá ahí manualmente un usuario por cada persona del personal
   (email + contraseña). No hay registro público: solo vos das de alta usuarios desde acá.

## 5. Copiar las credenciales al proyecto
1. **Configuración del proyecto** (ícono de engranaje) → **Tus apps** → **Agregar app → Web** (ícono `</>`).
2. Copiá el objeto `firebaseConfig` que te muestra.
3. Pegalo en el archivo `firebase-config.js` de este proyecto, reemplazando los valores de ejemplo.

## 6. Subir los archivos
Subí estos archivos a la misma carpeta del sitio (o al repo de GitHub):
- `formularios-tramites.html` (formulario público)
- `panel.html` (panel privado del personal)
- `firebase-config.js` (tus credenciales)
- `comisarias-config.js` (la lista de zonas → comisaría)

## 7. Ajustar las comisarías reales
Abrí `comisarias-config.js` y reemplazá los nombres de comisaría y los barrios de cada zona
por los datos reales de jurisdicción de la Policía de Salta. La lista que viene por defecto
es aproximada, a modo de ejemplo.

## Cómo queda el flujo
1. La persona completa un formulario en `formularios-tramites.html`, elige su barrio/zona
   y saca las fotos de DNI necesarias.
2. Al enviar, los datos y las fotos comprimidas se guardan en Firestore, con `estado: "pendiente"`
   y la comisaría que le corresponde según la zona elegida.
3. El personal entra a `panel.html` con su usuario y contraseña, ve la lista de solicitudes
   (puede filtrar por comisaría, trámite o estado) y marca cada una como "procesado" cuando
   corresponda.

## Costos
El plan gratuito de Firebase (Spark) alcanza sobradamente para este uso (miles de lecturas/
escrituras por día, varios GB de almacenamiento). No hace falta poner tarjeta de crédito.
