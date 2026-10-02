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
- `consultar-tramite.html` (consulta de estado para el ciudadano)
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

## 8. Consultar mi trámite (consulta pública)
La página `consultar-tramite.html` deja que el ciudadano vea el estado con su **código de 8 dígitos**
y los **últimos 4 del DNI**. Como el público (anon) **no puede leer** la tabla `solicitudes`, la
consulta se hace con una función que valida adentro y devuelve solo campos mínimos. Corré esto una vez
en **SQL Editor**:

```sql
create or replace function public.consultar_tramite(p_codigo text, p_dni4 text)
returns table (
  codigo text, tramite text, tramite_titulo text, estado text, comisaria_asignada text,
  fecha_recepcion timestamptz, fecha_expiracion timestamptz, motivo_denegacion text,
  dias_restantes int, retirado boolean
)
language sql security definer
set search_path = public
as $$
  select s.codigo, s.tramite, s.tramite_titulo, s.estado, s.comisaria_asignada,
         s.created_at, s.fecha_expiracion, s.motivo_denegacion,
         case when s.fecha_expiracion is not null
              then greatest(0, ceil(extract(epoch from (s.fecha_expiracion - now())) / 86400.0))::int
              else null end,
         coalesce(s.retirado, false)
  from public.solicitudes s
  where s.codigo = p_codigo
    and right(regexp_replace(
          coalesce(s.datos->>'dni', s.datos->>'dniSolicitante',
                   s.datos->>'dniProgenitor', s.datos->>'dniMenor'), '\D', '', 'g'), 4) = p_dni4
  limit 1;
$$;

revoke all on function public.consultar_tramite(text, text) from public;
grant execute on function public.consultar_tramite(text, text) to anon, authenticated;
```

Devuelve **0 filas** tanto si el código no existe como si el DNI no coincide, y **nunca** expone
`datos` (fotos, email, domicilio).

## 9. Recordatorio por email antes del vencimiento
Cuando un trámite pasa a **procesado**, se le asigna `fecha_expiracion` (5 días hábiles).
Esta función manda un email **~2 días antes** de que venza, para que el ciudadano retire su
certificado. Corre **1 vez por día** con **pg_cron**.

### 9.1 Columnas nuevas (SQL Editor, una vez)
```sql
alter table public.solicitudes add column if not exists recordatorio_enviado boolean default false;
alter table public.solicitudes add column if not exists fecha_recordatorio timestamptz;

create index if not exists solicitudes_recordatorio_idx
  on public.solicitudes (fecha_expiracion)
  where estado = 'procesado' and retirado is not true and recordatorio_enviado is not true;
```

### 9.2 Desplegar la Edge Function
Requiere la CLI de Supabase (`npm i -g supabase`, luego `supabase login`).
```bash
supabase functions deploy recordatorio-vencimiento --no-verify-jwt
supabase secrets set CRON_SECRET=un-texto-largo-y-aleatorio \
  EMAILJS_SERVICE_ID=service_8etpsse \
  EMAILJS_TEMPLATE_ID=template_sk1q9yr \
  EMAILJS_PUBLIC_KEY=64rdi6i-PC71o8Yqh
```
`SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` las inyecta Supabase solas; el resto son las que
seteás arriba. La función exige el header `x-cron-secret` (si no coincide, responde 401).

### 9.3 Activar pg_cron y pg_net
1. Supabase → **Database → Extensions**.
2. Activá **`pg_cron`** y **`pg_net`** (o por SQL: `create extension if not exists pg_cron; create extension if not exists pg_net;`).
3. Programá el job (SQL Editor) — reemplazá `<PROJECT-REF>` (está en `supabase-config.js`) y `<TU_CRON_SECRET>`:
```sql
select cron.schedule(
  'recordatorio-vencimiento-diario',
  '0 12 * * *',   -- 12:00 UTC = 09:00 en Argentina (UTC-3)
  $$
  select net.http_post(
    url     := 'https://<PROJECT-REF>.supabase.co/functions/v1/recordatorio-vencimiento',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'x-cron-secret', '<TU_CRON_SECRET>'
    ),
    body    := '{}'::jsonb
  );
  $$
);
```

### 9.4 Verificar / probar
```sql
select * from cron.job;                                                   -- el job programado
select * from cron.job_run_details order by start_time desc limit 5;      -- historial
select status, content from net._http_response order by created desc;      -- respuesta de la función
select cron.unschedule('recordatorio-vencimiento-diario');                 -- borrarlo
```
Prueba manual (sin esperar al cron):
```bash
curl -i -X POST "https://<PROJECT-REF>.supabase.co/functions/v1/recordatorio-vencimiento" \
  -H "x-cron-secret: <TU_CRON_SECRET>"
```
Debe responder `200` con `{ "total": N, "enviados": M, "errores": [] }`.

> Notas: EmailJS tiene tope (~200 emails/mes) y quizás debas agregar `{{fecha_limite}}`/`{{dias}}`
> (o usar `{{mensaje_extra}}`) en la plantilla `template_sk1q9yr`. El `CRON_SECRET` queda guardado
> en la tabla de cron de la base (necesario para que pg_net lo envíe). No se usa la service_role en el SQL.

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
