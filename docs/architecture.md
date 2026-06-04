# 🏗️ Arquitectura del Frontend (Flutter)

El frontend de Fidelity está diseñado siguiendo principios de **Screaming Architecture** y **Feature-first**, priorizando la cohesión y el desacoplamiento.

## 📂 Estructura de Carpetas

### `lib/core`
El corazón compartido de la aplicación. Contiene código que no pertenece a ninguna funcionalidad específica:
-   **`config/`**: Configuraciones globales (Supabase URL, llaves de API).
-   **`services/`**: Servicios globales que interactúan con APIs externas o el sistema (Notificaciones, Exportación CSV, Transferencia de Premios).
-   **`theme/`**: El sistema de diseño "Pop-Minimalism". Centraliza colores, tipografías (Anton & Poppins) y constantes de animación.
-   **`utils/`**: Helpers para fechas, formateo de moneda, etc.
-   **`validators/`**: Lógica de validación de formularios reutilizable.

### `lib/features`
La aplicación se divide por dominios de negocio. Cada carpeta representa una "Feature" completa:
-   **`auth/`**: Login, Registro y el `AuthWrapper` (quien decide a qué pantalla enviarte según tu rol).
-   **`business/`**: Todo lo relacionado con el dashboard del dueño, gestión de locales y creación de negocios.
-   **`cards/`**: La vista de "Mis Tarjetas" para el cliente.
-   **`scanner/`**: La interfaz de cámara y lógica de procesamiento de QR.
-   **`admin/`**: Panel de control global con métricas y gestión de usuarios/negocios.

## 🎨 Sistema de Diseño y Animaciones

Usamos un estilo **Pop-Minimalist** (inspirado en agencias como Emote). 
-   **Tipografía**: `Anton` para títulos impactantes y `Poppins` para legibilidad en cuerpo de texto.
-   **Animaciones**: Implementamos `flutter_animate` para micro-interacciones. 
    -   *Regla de Oro*: Las animaciones deben ser sutiles (300-600ms) y mejorar la UX, no retrasar al usuario.

## 🔄 Flujo de Datos

1.  **UI (Widgets)**: Escuchan cambios y disparan eventos.
2.  **Supabase SDK**: Actúa como nuestro Repositorio y Data Source.
3.  **Realtime Streams**: Usamos `Supabase.instance.client.from(...).stream(...)` para que la UI se actualice sola cuando algo cambia en la base de datos (ej: el contador de puntos).

---
> [!TIP]
> Si vas a crear una nueva funcionalidad, creá una carpeta dentro de `features/` y tratá de que sea lo más independiente posible del resto.
