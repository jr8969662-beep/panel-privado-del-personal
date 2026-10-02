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

## 2. Crear la tabla y las reglas de seguridad
1. En el menú izquierdo: **SQL Editor → New query**.
2. Pegá esto y hacé clic en **"Run"**:

```sql
-- Tablas (si ya existen, no hace nada)
create table if not exists public.solicitudes (
  id uuid primary key default gen_random_uuid(),
  tramite text not null,
  tramite_titulo text,
  comisaria_asignada text,
  estado text not null default 'pendiente',
  datos jsonb,
  codigo text,
  urgente boolean default false,
  retirado boolean default false,
  retirado_en timestamptz,
  validado_por text,
  validado_en timestamptz,
  fecha_expiracion timestamptz,
  motivo_denegacion text,
  created_at timestamptz default now(),
  constraint solicitudes_tramite_check check (tramite in
    ('residencia','convivencia','carencia','autorizacion','antecedentes','domicilio','extravio','supervivencia','estadia')),
  constraint solicitudes_estado_check check (estado in ('pendiente','procesado','denegado'))
);

create table if not exists public.logs_accesos (
  id uuid primary key default gen_random_uuid(),
  fecha timestamptz default now(),
  email text,
  tipo text,
  user_agent text,
  dispositivo text
);

-- Reglas de seguridad
alter table public.solicitudes enable row level security;
alter table public.logs_accesos enable row level security;

-- El público (anon) SOLO puede CREAR solicitudes, y solo en estado "pendiente".
-- No puede leerlas, modificarlas ni borrarlas. Los topes de tamaño evitan que
-- alguien use la tabla como almacenamiento gratis.
drop policy if exists "Cualquiera puede crear solicitudes" on public.solicitudes;
create policy "Cualquiera puede crear solicitudes"
on public.solicitudes for insert to anon
with check (
  estado = 'pendiente'
  and coalesce(pg_column_size(datos), 0) <= 6000000
  and char_length(coalesce(comisaria_asignada, '')) <= 300
  and char_length(coalesce(tramite_titulo, '')) <= 200
);

-- Personal logueado: ver, actualizar y borrar solicitudes
drop policy if exists "Personal logueado puede ver solicitudes" on public.solicitudes;
create policy "Personal logueado puede ver solicitudes"
on public.solicitudes for select to authenticated using (true);

drop policy if exists "Personal logueado puede actualizar solicitudes" on public.solicitudes;
create policy "Personal logueado puede actualizar solicitudes"
on public.solicitudes for update to authenticated using (true);

drop policy if exists "Personal logueado puede borrar solicitudes" on public.solicitudes;
create policy "Personal logueado puede borrar solicitudes"
on public.solicitudes for delete to authenticated using (true);

-- Auditoría: solo el personal logueado ve y escribe
drop policy if exists "Personal logueado registra accesos" on public.logs_accesos;
create policy "Personal logueado registra accesos"
on public.logs_accesos for insert to authenticated with check (true);

drop policy if exists "Personal logueado ve accesos" on public.logs_accesos;
create policy "Personal logueado ve accesos"
on public.logs_accesos for select to authenticated using (true);
```

Esto crea las tablas y las reglas: cualquiera puede **enviar** un trámite (desde
`formularios-tramites.html`), pero solo en estado `pendiente` y con topes de tamaño; y solo el
personal logueado puede **ver, actualizar y borrar** las solicitudes (desde `panel.html`).

La clave `anon` es pública por diseño, así que **estas políticas son lo único que separa los
datos del público: no las desactives.** Si ya tenías la tabla creada, volvé a correr igual este
bloque: es idempotente (`create table if not exists` + `drop policy if exists`).

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
- `comisarias-config.js` (dependencias + nombres oficiales + CORRECCIONES_BARRIO)
- `DDP-1.json` … `DDP-14.json` (polígonos de las jurisdicciones)
- `convertir-kml.js` (opcional: regenera los DDP-*.json a partir de los KML)

Los `DDP-*.json` son imprescindibles: sin ellos no se puede asignar la comisaría.

## 7. Cómo se asigna la comisaría
La asignación es **por jurisdicción (punto-en-polígono)**, no por cercanía a un punto:
1. Se toma el domicilio y la localidad que escribió la persona.
2. Si el domicilio menciona un barrio cargado en `CORRECCIONES_BARRIO`
   (barrio → comisaría, generado automáticamente desde OpenStreetMap), se asigna esa dependencia.
3. Si no, se geocodifica el domicilio con Nominatim/OpenStreetMap (quitando "mza/lote", que
   Nominatim no entiende) y se busca en qué polígono de `DDP-*.json` cae el punto.
4. El nombre que se muestra y se guarda es el oficial, ej.
   `Comisaría N°12 - Palermo I (ex N°104) (DDP 1)`.

En el mapa de confirmación el ciudadano puede **arrastrar el marcador** para ajustar su ubicación
exacta; la comisaría se recalcula al soltarlo. Si no se puede determinar, el trámite se guarda
igual como "a asignar por el personal" para que lo resuelva el personal.

La ubicación usada y de dónde salió la asignación (`poligono`, `correccion_barrio`, `manual`)
quedan guardadas en `datos.__geo` de la solicitud.

## Cómo queda el flujo
1. La persona completa un formulario con su domicilio y saca las fotos de DNI necesarias.
2. Al enviar, se crea una fila en la tabla `solicitudes` de Supabase, con `estado: "pendiente"`
   y la comisaría que corresponde por jurisdicción (o por barrio).
3. El personal entra a `panel.html` con su usuario y contraseña, ve la lista de solicitudes
   (puede filtrar por comisaría, trámite o estado) y marca cada una como "procesado" cuando
   corresponda.

## Costos
El plan gratuito de Supabase incluye 500 MB de base de datos y no pide tarjeta de crédito.
Para este proyecto (texto + fotos comprimidas) alcanza sin problema.
