# ⚖️ Reglas de Negocio Críticas

Este documento detalla las reglas que gobiernan el comportamiento de Fidelity. Muchas de estas reglas están implementadas a nivel de base de datos para máxima seguridad.

## 1. El Ciclo de Recompensa (Puntos ➔ Premios)
-   Cada negocio define sus propios `points_required` (ej: 10 puntos para un café gratis).
-   **Automatización**: Cuando `current_points` llega al límite, el sistema:
    1.  Crea un registro en la tabla `rewards` con estado `pending`.
    2.  Resetea `current_points` a 0.
    3.  Incrementa `rewards_claimed` en el historial de la tarjeta.
-   **Bloqueo de Seguridad**: Un usuario con un premio **pendiente** no puede recibir más puntos de ese negocio hasta que el premio sea marcado como canjeado. Esto evita "acumulación infinita" sin control del local.

## 2. Restricción de Tiempo (Cooldown)
-   Para evitar fraudes, un cliente solo puede realizar un escaneo exitoso cada **X horas** (por defecto 4 horas).
-   Esta validación se hace comparando el `last_scan_at` de la `loyalty_card` con la hora actual.
-   Si el cliente intenta escanear antes, el sistema devuelve un error claro indicando cuánto tiempo falta.

## 3. Puntos Manuales vs. Escaneos QR
-   **QR**: El cliente escanea el código del local. El sistema valida ubicación (opcional) y cooldown.
-   **Manual**: El dueño del negocio puede usar la función `add_manual_points` desde su dashboard. Esto genera automáticamente registros de "escaneos aprobados" en el historial para mantener la trazabilidad de la auditoría.

## 4. Sistema de Notificaciones Push (FCM)
-   **Captura de Token**: Cada vez que un usuario inicia sesión, la app captura su `fcm_token` y lo guarda en su perfil.
-   **Lógica de Envío**: Cuando un premio es generado o un punto es aprobado, una Edge Function de Supabase (o un trigger) dispara una notificación al dispositivo del usuario.

## 5. Roles y Permisos
| Rol | Capacidades |
| :--- | :--- |
| **Client** | Ver sus tarjetas, escanear QRs, ver sus premios, editar su perfil. |
| **Business** | Generar QRs, aprobar escaneos, dar puntos manuales, ver métricas de su local. |
| **Admin** | Dashboard global, exportar reportes CSV de todos los usuarios/negocios, activar/desactivar locales. |

---
> [!WARNING]
> Cualquier cambio en `points_required` en la tabla `businesses` afectará los próximos ciclos de premios, pero no recalculará retroactivamente los premios ya emitidos.
