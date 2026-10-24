# Panel privado del personal — Mi Comisaría

Solo para el personal policial. **No contiene el sitio público** (ese está en el repositorio `MI-COMISARIA`).

| Archivo | Para qué sirve |
|---|---|
| `panel.html` | Panel: ver, validar y denegar trámites |
| `supabase-config.js` | Conexión a Supabase (misma base que el sitio público) |
| `comisarias-config.js` | Zonas/nombres de comisarías que usa el panel |
| `supabase/seguridad-por-comisaria.sql` | **Reglas de seguridad**: cada comisaría ve solo lo suyo |
| `supabase/nombres-de-comisarias.txt` | Nombres exactos de cada comisaría (para asignar personal) |
| `README-supabase.md` | Guía de instalación de Supabase |

## Quién ve qué
- El **público** solo puede crear trámites (no puede leer nada).
- El **personal** ve, valida y deniega solo los trámites de **sus comisarías** (tabla `personal`).
- El **administrador** ve todo.
- Las reglas las aplica Supabase: aunque alguien abra esta página, sin usuario autorizado no ve datos.

## Alta de una comisaría nueva
1. Supabase → Authentication → Users → *Add user* (marcar "Auto Confirm User").
2. SQL Editor → ejecutar el ejemplo del final de `supabase/seguridad-por-comisaria.sql` con su email
   y el nombre exacto de la comisaría (ver `supabase/nombres-de-comisarias.txt`).
