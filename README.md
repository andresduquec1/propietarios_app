# Residencial App 🏠🚗

Una aplicación Flutter para la gestión de residentes y vehículos en conjuntos residenciales, diseñada para facilitar la comunicación en caso de bloqueos de parqueadero.

## ✨ Características Principales

- **Gestión de Perfil:** Los residentes pueden registrar sus datos personales, dirección (Unidad, Torre, Apartamento) y foto de perfil tomada directamente desde la cámara.
- **Sincronización en la Nube:** Los datos se guardan localmente en SQLite y se sincronizan con una API REST (Laravel).
- **Contactos de Emergencia:** Módulo para agregar múltiples contactos que serán notificados en caso de problemas con un vehículo.
- **Gestión de Vehículos:** Registro de carros y motos asociados a un contacto de emergencia específico.
- **Consulta de Placas:** Módulo de seguridad que permite buscar un vehículo por su placa para obtener rápidamente el contacto del propietario y llamarlo o escribirle por WhatsApp.
- **Panel de Administración:**
    - **Gestión de Unidades:** Crear, editar, buscar y habilitar/inhabilitar conjuntos residenciales.
    - **Gestión de Usuarios:** Buscador avanzado por nombre, unidad o placa. Visualización detallada de vehículos y contactos de emergencia. Control de activación de cuentas y permisos de historial.

## 📱 Capturas de Pantalla (Próximamente)
*(Aquí puedes añadir imágenes de la app)*

---

## 🗄️ Documentación de la Base de Datos

La aplicación utiliza un sistema híbrido: **SQLite** para persistencia offline y una **API REST** para almacenamiento centralizado.

### Estructura de Tablas (Local y Remota)

#### 1. Tabla: `users` (Residentes)
| Campo | Tipo | Descripción |
| :--- | :--- | :--- |
| `id` | INTEGER | Clave primaria. |
| `email` | TEXT | Correo electrónico (Único). |
| `password` | TEXT | Contraseña de acceso. |
| `firstName` | TEXT | Nombres del residente. |
| `lastName` | TEXT | Apellidos del residente. |
| `phone` | TEXT | Teléfono principal. |
| `unit_id` | INTEGER | ID de la Unidad residencial (FK). |
| `tower` | TEXT | Torre / Bloque. |
| `apartment` | TEXT | Número de apto. |
| `profileImagePath`| TEXT | Ruta/URL de la foto de perfil. |

#### 2. Tabla: `units` (Conjuntos Residenciales)
| Campo | Tipo | Descripción |
| :--- | :--- | :--- |
| `id` | INTEGER | Clave primaria. |
| `name` | TEXT | Nombre del conjunto. |
| `description`| TEXT | Descripción opcional. |

#### 3. Tabla: `emergency_contacts`
| Campo | Tipo | Descripción |
| :--- | :--- | :--- |
| `id` | INTEGER | Clave primaria. |
| `user_id` | INTEGER | Relación con el usuario (FK). |
| `name` | TEXT | Nombre del contacto. |
| `phone` | TEXT | Teléfono de contacto. |
| `has_whatsapp` | INTEGER | Indica si tiene WhatsApp (0/1). |

#### 3. Tabla: `vehicles`
| Campo | Tipo | Descripción |
| :--- | :--- | :--- |
| `id` | INTEGER | Clave primaria. |
| `user_id` | INTEGER | Propietario (FK). |
| `type` | TEXT | Tipo ('Carro' o 'Moto'). |
| `brand` | TEXT | Marca del vehículo. |
| `color` | TEXT | Color. |
| `plate` | TEXT | Placa (Normalizada en MAYÚSCULAS). |
| `emergency_contact_id`| INTEGER | Contacto asignado (FK). |

---

## 🛠️ Tecnologías y Dependencias

- **Flutter SDK:** ^3.11.4
- **sqflite:** Gestión de base de datos local.
- **http:** Comunicación con la API REST.
- **image_picker:** Captura de fotos con la cámara.
- **url_launcher:** Llamadas y WhatsApp.

## 🚀 Cómo Ejecutar el Proyecto

1. Clona este repositorio.
2. Configura el endpoint del servidor en `lib/api_service.dart`.
3. Ejecuta los siguientes comandos:

```bash
flutter pub get
flutter run
```

---

## ⚖️ Licencia
Este proyecto es de uso libre bajo la licencia MIT.
