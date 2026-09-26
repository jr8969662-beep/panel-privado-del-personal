# Configuración de Supabase para "Mi Comisaría"

Este proyecto usa **Supabase** (gratis, sin pedir tarjeta) como backend:
- **Base de datos (Postgres)**: una sola tabla `solicitudes` guarda todos los trámites,
  incluidas las fotos de DNI (comprimidas, como texto).
- **Authentication**: login del personal en `panel.html`, con usuario y contraseña.

## 1. Crear el proyecto
1. Entrá a https://supabase.com y creá una cuenta (podés usar tu cuenta de GitHub).
2. **"New project"** → elegí un nombre (ej: `mi-comisaria`), una contraseña para la base
   (guardala, no es la que van a usar los usuarios del panel) y una región cercana
   (`South America (São Paulo)` si aparece).
3. Esperá un par de minutos a que se cree el proyecto.

## 2. Crear la tabla de solicitudes
1. En el menú izquierdo: **SQL Editor → New query**.
2. Pegá esto y hacé clic en **"Run"**:

```sql
create table solicitudes (
  id uuid primary key default gen_random_uuid(),
  tramite text not null,
  tramite_titulo text,
  comisaria_asignada text,
  estado text default 'pendiente',
  datos jsonb,
  created_at timestamptz default now()
);

alter table solicitudes enable row level security;

create policy "Cualquiera puede crear solicitudes"
on solicitudes for insert
to anon
with check (true);

create policy "Personal logueado puede ver solicitudes"
on solicitudes for select
to authenticated
using (true);

create policy "Personal logueado puede actualizar solicitudes"
on solicitudes for update
to authenticated
using (true);
```

Esto crea la tabla y las reglas de seguridad: cualquiera puede **enviar** un trámite (como
hace la gente desde `formularios-tramites.html`), pero solo el personal logueado puede
**ver y actualizar** las solicitudes (desde `panel.html`).

## 3. Activar actualización en vivo (opcional pero recomendado)
1. Menú izquierdo → **Database → Replication**.
2. Buscá la publicación `supabase_realtime` y activá el switch de la tabla `solicitudes`.

Con esto, el panel se actualiza solo cuando llega un trámite nuevo, sin que el personal
tenga que apretar "Actualizar" todo el tiempo (igual dejamos ese botón por las dudas).

## 4. Activar el login del personal
1. Menú izquierdo → **Authentication → Providers**.
2. Verificá que **"Email"** esté habilitado (viene activado por defecto).
3. Andá a **Authentication → Users → Add user → Create new user**.
4. Cargá el email y la contraseña de cada persona del personal. Tildá **"Auto Confirm User"**
   para que no haga falta que confirmen el email. Repetí por cada usuario que necesites.

No hay registro público: el personal solo puede entrar con un usuario que vos creaste a mano.

## 5. Copiar las credenciales al proyecto
1. Menú izquierdo → **Configuración del proyecto (ícono de engranaje) → API**.
2. Copiá el **"Project URL"** y la clave **"anon public"**.
3. Pegalos en el archivo `supabase-config.js`, reemplazando los valores de ejemplo.

## 6. Subir los archivos
Estos son los archivos del proyecto (ya no se usa nada de Firebase):
- `formularios-tramites.html` (formulario público)
- `panel.html` (panel privado del personal)
- `supabase-config.js` (tus credenciales)
- `comisarias-config.js` (la lista de zonas → comisaría)

## 7. Ajustar las comisarías reales
Abrí `comisarias-config.js` y reemplazá los nombres de comisaría y los barrios de cada zona
por los datos reales de jurisdicción de la Policía de Salta. La lista que viene por defecto
es aproximada, a modo de ejemplo.

## Cómo queda el flujo
1. La persona completa un formulario, elige su barrio/zona y saca las fotos de DNI necesarias.
2. Al enviar, se crea una fila en la tabla `solicitudes` de Supabase, con `estado: "pendiente"`
   y la comisaría que le corresponde según la zona elegida.
3. El personal entra a `panel.html` con su usuario y contraseña, ve la lista de solicitudes
   (puede filtrar por comisaría, trámite o estado) y marca cada una como "procesado" cuando
   corresponda.

## Costos
El plan gratuito de Supabase incluye 500 MB de base de datos y no pide tarjeta de crédito.
Para este proyecto (texto + fotos comprimidas) alcanza sin problema.
