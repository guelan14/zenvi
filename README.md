# Zervi

Marketplace de servicios que conecta **clientes** con **profesionales**. Los profesionales publican sus servicios, los clientes publican trabajos que necesitan resolver, y ambos coordinan por chat en tiempo real, agendan turnos y se califican entre sí al terminar.

Construido con **Flutter** (Android, iOS y Web) sobre **Supabase**.

> **Estado:** proyecto personal finalizado y sin mantenimiento. Lo dejo público como muestra de trabajo.

---

## Funcionalidades

**Descubrimiento**
- Feed doble: *Servicios* (ofertas de profesionales) y *Trabajos* (pedidos de clientes), con filtro por categoría.
- Mapa con geolocalización del usuario, marcadores circulares dibujados en canvas y estilo oscuro propio.
- Detalle de publicación con slider de imágenes, datos del autor y su calificación.

**Publicación**
- Asistente de 6 pasos: título y categoría → descripción → precio y modalidad (presencial / virtual / híbrida) → ubicación en mapa → disponibilidad semanal → preferencias.
- Los invitados pueden completar todo el formulario; el login se pide recién al publicar, sin perder lo cargado.

**Mensajería y turnos**
- Chat en tiempo real con Supabase Realtime (`.stream()` sobre Postgres).
- Pedido de turno desde el chat, agenda con calendario y estados (pendiente, confirmado, completado, cancelado).
- **Confirmación mutua**: un turno se cierra solo cuando el profesional y el cliente confirman que terminó.
- **Calificaciones bidireccionales**: cada parte califica a la otra, una vez por turno. Un trigger en Postgres recalcula el promedio por separado para el rol de profesional y el de cliente.

**Herramientas para profesionales**
- Modo dual: el mismo usuario cambia entre perfil cliente y profesional.
- Panel de métricas: ingresos totales y semanales, trabajos realizados, turnos pendientes, calificación y servicios destacados.
- Cartera de clientes: el profesional puede dar de alta a un cliente que todavía no tiene cuenta y agendarle turnos. Cuando esa persona se registra con el mismo email, su historial se vincula automáticamente.

**General**
- Login con email y con Google Sign-In nativo (`signInWithIdToken`).
- Tema claro y oscuro, skeleton loaders y analítica de eventos con PostHog.

## Stack

| Capa | Tecnología |
|---|---|
| UI | Flutter, Material 3, Google Fonts (Manrope), `animations`, `shimmer` |
| Estado | Riverpod 3 |
| Navegación | GoRouter, con rutas protegidas y redirect post-login |
| Backend | Supabase: Postgres, Auth, Realtime, RLS, funciones y triggers en PL/pgSQL |
| Mapas | `google_maps_flutter`, `geolocator` |
| Analítica | PostHog |
| Config | `flutter_dotenv` |

## Arquitectura

El código está organizado **por feature**, y cada feature separa capas de datos, dominio y presentación:

```
lib/
├── core/                 # Infraestructura transversal
│   ├── router/           # GoRouter + guard de autenticación
│   ├── supabase/         # Inicialización del cliente
│   ├── analytics/        # Wrapper de PostHog
│   ├── shell/            # Shell con bottom navigation
│   └── theme/            # Tema claro/oscuro, estilos de mapa
├── features/
│   ├── auth/
│   ├── home/             # Feed, detalle y mapa
│   ├── publish/          # Asistente de publicación
│   ├── messages/         # Conversaciones y chat realtime
│   ├── appointments/     # Turnos y calificaciones
│   └── profile/          # Perfil, métricas, cartera de clientes
│       ├── data/         # Repositorios (acceso a Supabase)
│       ├── domain/       # Modelos y providers de Riverpod
│       └── presentation/ # Pantallas y widgets
└── shared/               # Modelos y widgets reutilizables
```

- **Repositorios** encapsulan las consultas a Supabase; la UI nunca habla directo con el cliente.
- **Providers de Riverpod** exponen los datos a la UI (`FutureProvider` y `StreamProvider` para el realtime).
- **La seguridad vive en la base de datos**: todas las tablas tienen Row Level Security, y la lógica sensible (creación de perfil al registrarse, recálculo de calificaciones, vinculación de clientes invitados) corre en triggers y funciones de Postgres, no en el cliente.

### Modelo de datos

Tablas principales: `profiles`, `categories`, `listings`, `availability`, `conversations`, `messages`, `appointments`, `user_ratings`, `professional_clients`.

Los scripts están en [`supabase/`](supabase/):
- `schema.sql`: esquema completo, enums, políticas RLS, funciones y triggers.
- `migration_ratings.sql`: migración del sistema de calificaciones a calificaciones por turno con confirmación mutua.

## Cómo correrlo

**Requisitos:** Flutter SDK (Dart `^3.11`), un proyecto de Supabase y una API key de Google Maps.

1. Clonar e instalar dependencias:
   ```bash
   git clone https://github.com/guelan14/zenvi.git
   cd zenvi
   flutter pub get
   ```
2. Copiar `.env.example` a `.env` y completar los valores:
   | Variable | Para qué se usa |
   |---|---|
   | `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Conexión a Supabase |
   | `POSTHOG_KEY`, `POSTHOG_HOST` | Analítica (opcional) |
   | `GOOGLE_MAPS_API_KEY` | Mapas en Android (vía `build.gradle.kts`) e iOS (vía `AppDelegate.swift`) |
   | `GOOGLE_WEB_CLIENT_ID` | Google Sign-In |
3. **Web:** en `web/index.html`, reemplazar `[TU_GOOGLE_MAPS_API_KEY]` por tu clave.
4. **Base de datos:** en el SQL Editor de Supabase, ejecutar `supabase/schema.sql` y después `supabase/migration_ratings.sql`.
5. Ejecutar:
   ```bash
   flutter run
   ```

> Restringí la API key de Maps por dominio o por package name en Google Cloud Console: en la build web siempre termina visible en el navegador.

## Limitaciones conocidas

- Los pagos están **simulados**; no hay integración con una pasarela real.
- Casi no hay tests: solo el `widget_test.dart` por defecto.
- El `.env` se empaqueta como asset de Flutter, así que solo debe contener claves pensadas para ser públicas (como la anon key de Supabase, protegida por RLS).
- La función `create_invited_user_in_auth` es `SECURITY DEFINER`. En un despliegue real habría que restringir quién puede ejecutarla.
- El nombre del paquete (`zenvi`) y el de la app (`Zervi`) quedaron distintos por razones históricas.

## Autor

**Miguel Angel Neumann** · [@guelan14](https://github.com/guelan14)
