# 🛠️ Guía de Configuración y Despliegue (Setup)

Seguí estos pasos para poner el proyecto en marcha desde cero o migrarlo a un nuevo entorno de producción.

## 1. Requisitos del Sistema
-   **Flutter SDK**: ^3.8.1
-   **Dart SDK**: ^3.x
-   **Supabase CLI** (opcional, para migraciones locales).
-   **Firebase CLI** (para gestión de notificaciones push).

## 2. Configuración del Backend (Supabase)
1.  Creá un nuevo proyecto en [Supabase](https://supabase.com).
2.  Ejecutá los scripts SQL que se encuentran en `/supabase/migrations` en el editor SQL de Supabase (o usá el CLI para aplicarlos).
3.  **Edge Functions**: Desplegá la función de notificaciones push:
    ```bash
    supabase functions deploy push-notification
    ```
4.  **Habilitar Realtime**: Asegurate de que la publicación `supabase_realtime` incluya las tablas `scans`, `rewards` y `loyalty_cards`.

## 3. Configuración del Frontend (Flutter)
1.  Actualizá las credenciales en `lib/core/config/supabase_config.dart`:
    ```dart
    static const String supabaseUrl = 'TU_URL_DE_SUPABASE';
    static const String supabaseAnonKey = 'TU_ANON_KEY';
    ```
2.  **Firebase (Push)**: 
    -   Configurá un proyecto en Firebase Console.
    -   Descargá `google-services.json` (Android) y `GoogleService-Info.plist` (iOS).
    -   Ejecutá `flutterfire configure` para regenerar `lib/firebase_options.dart`.

## 4. Notas de Entrega y Pendientes (Handover)

### ⚠️ Migración de Categorías
Como se detalla en el `informe_tecnico.txt`, estamos en un estado de transición.
-   **Estado actual**: Se usa `category_id` (relacional). El campo `category` (texto) en la tabla `businesses` sigue ahí por retrocompatibilidad temporal.
-   **Tarea pendiente**: Una vez que se confirme que todos los negocios tienen un `category_id` válido, se debe ejecutar:
    ```sql
    ALTER TABLE public.businesses DROP COLUMN category;
    ```

### 📈 Escalabilidad
El sistema está diseñado para soportar miles de escaneos simultáneos gracias al uso de triggers en lugar de lógica pesada en el cliente. Para escalar masivamente, se recomienda monitorear el uso de las Edge Functions de Supabase.

---
> [!IMPORTANT]
> No olvides configurar los secretos de Supabase (`FIREBASE_SERVICE_ACCOUNT`) para que las Edge Functions puedan enviar notificaciones push.
