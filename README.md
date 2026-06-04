# 💳 Fidelity - Plataforma de Fidelización Inteligente

Fidelity es una solución integral de fidelización de clientes para negocios locales. Permite a los comercios gestionar programas de recompensas de forma digital y a los usuarios acumular puntos mediante el escaneo de códigos QR, eliminando las tarjetas de cartón físicas.

## 🚀 Arquitectura del Proyecto

El ecosistema Fidelity está dividido en dos grandes pilares:

1.  **Mobile App (Flutter)**: Ubicada en `/fidelity_app`. Implementa **Clean Architecture** para garantizar escalabilidad y testeabilidad.
2.  **Backend (Supabase)**: Ubicado en `/supabase`. Utiliza PostgreSQL como motor, con lógica de negocio pesada ejecutada directamente en la base de datos mediante **Triggers y RPCs (PL/pgSQL)** para asegurar la integridad de los datos.

## 🛠 Tech Stack

-   **Frontend**: Flutter (v3.x) + Provider/Riverpod (State Management).
-   **Backend**: Supabase (Auth, DB, Storage, Edge Functions).
-   **Notificaciones**: Firebase Cloud Messaging (FCM).
-   **Base de Datos**: PostgreSQL (PostgREST para la API).

## 📖 Índice de Documentación Detallada

Para entender a fondo el sistema, revisá los siguientes documentos en la carpeta `/docs`:

-   [Arquitectura y Capas del Frontend](./docs/architecture.md)
-   [Esquema de Base de Datos y Lógica de Servidor](./docs/database.md)
-   [Reglas de Negocio y Flujos Críticos](./docs/business_rules.md)
-   [Guía de Configuración y Despliegue](./docs/setup.md)

## 🏁 Inicio Rápido (Local)

### Requisitos
-   Flutter SDK (^3.x)
-   Cuenta en Supabase

### Pasos
1.  Cloná el repositorio.
2.  Navegá a `fidelity_app/` y ejecutá `flutter pub get`.
3.  Configurá el archivo `lib/core/config/supabase_config.dart` con tus credenciales.
4.  Ejecutá `flutter run`.

---
*Desarrollado con ❤️ para transformar el comercio local.*
