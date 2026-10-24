-- =====================================================================
--  MI COMISARÍA - Cerrar la tabla de ubicaciones guardadas
--  Problema: hoy el público (sin login) puede LEER y MODIFICAR todas las filas de
--  public.ubicaciones_ciudadanos (DNI, nombre, domicilio, coordenadas).
--
--  Solución:
--   * El público ya no toca la tabla. Solo puede usar dos funciones acotadas:
--       buscar_ubicacion(dni)  -> devuelve LA ubicación de ESE dni (sin nombre ni DNI)
--       guardar_ubicacion(...) -> guarda/actualiza, validando los datos, y NO reactiva
--                                 ubicaciones que el personal invalidó.
--   * El personal ve y actualiza solo las de su comisaría (el administrador, todas).
--
--  Requiere haber ejecutado antes seguridad-por-comisaria.sql (usa puede_ver_comisaria y es_admin).
--  Ejecutar completo en Supabase > SQL Editor. Es seguro repetirlo.
-- =====================================================================
begin;

-- 0) Verificación: que exista lo que necesitamos
do $$
begin
  if to_regprocedure('public.puede_ver_comisaria(text)') is null then
    raise exception 'Primero ejecutá seguridad-por-comisaria.sql';
  end if;
  if to_regclass('public.ubicaciones_ciudadanos') is null then
    raise exception 'No existe la tabla ubicaciones_ciudadanos';
  end if;
end $$;

-- 1) Sacar el acceso directo del público
drop policy if exists anon_select_ubicaciones on public.ubicaciones_ciudadanos;
drop policy if exists anon_insert_ubicaciones on public.ubicaciones_ciudadanos;
drop policy if exists anon_update_ubicaciones on public.ubicaciones_ciudadanos;
alter table public.ubicaciones_ciudadanos enable row level security;
revoke all on public.ubicaciones_ciudadanos from anon;

-- 2) Personal logueado: solo lo de su comisaría
grant select, update on public.ubicaciones_ciudadanos to authenticated;

drop policy if exists "Personal ve ubicaciones de su comisaria" on public.ubicaciones_ciudadanos;
create policy "Personal ve ubicaciones de su comisaria"
on public.ubicaciones_ciudadanos for select to authenticated
using (public.puede_ver_comisaria(comisaria_asignada));

drop policy if exists "Personal actualiza ubicaciones de su comisaria" on public.ubicaciones_ciudadanos;
create policy "Personal actualiza ubicaciones de su comisaria"
on public.ubicaciones_ciudadanos for update to authenticated
using (public.puede_ver_comisaria(comisaria_asignada))
with check (public.puede_ver_comisaria(comisaria_asignada));

-- 3) Buscar la ubicación guardada de un DNI (público, acotado)
create or replace function public.buscar_ubicacion(p_dni text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r record;
begin
  if p_dni is null or p_dni !~ '^[0-9]{6,9}$' then return null; end if;
  select lat, lon, domicilio_texto, localidad, zona, comisaria_asignada, estado
    into r
    from public.ubicaciones_ciudadanos
   where dni = p_dni and coalesce(estado, 'activa') = 'activa';
  if not found then return null; end if;
  return jsonb_build_object(
    'lat', r.lat, 'lon', r.lon, 'domicilio_texto', r.domicilio_texto,
    'localidad', r.localidad, 'zona', r.zona,
    'comisaria_asignada', r.comisaria_asignada, 'estado', 'activa');
end $$;

-- 4) Guardar/actualizar la ubicación de un DNI (público, validado)
create or replace function public.guardar_ubicacion(
  p_dni text, p_nombre text, p_lat double precision, p_lon double precision,
  p_comisaria text, p_zona text, p_domicilio text, p_localidad text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if p_dni is null or p_dni !~ '^[0-9]{6,9}$' then return false; end if;
  -- coordenadas dentro de la provincia de Salta
  if p_lat is null or p_lon is null
     or p_lat not between -27.0 and -21.5 or p_lon not between -69.0 and -62.0 then return false; end if;
  if char_length(coalesce(p_nombre,'')) > 200 or char_length(coalesce(p_comisaria,'')) > 300
     or char_length(coalesce(p_zona,'')) > 50 or char_length(coalesce(p_domicilio,'')) > 300
     or char_length(coalesce(p_localidad,'')) > 100 then return false; end if;

  insert into public.ubicaciones_ciudadanos
    (dni, nombre, lat, lon, comisaria_asignada, zona, domicilio_texto, localidad, actualizado_en, estado, motivo_rechazo)
  values
    (p_dni, p_nombre, p_lat, p_lon, p_comisaria, p_zona, p_domicilio, p_localidad, now(), 'activa', null)
  on conflict (dni) do update set
    nombre = excluded.nombre, lat = excluded.lat, lon = excluded.lon,
    comisaria_asignada = excluded.comisaria_asignada, zona = excluded.zona,
    domicilio_texto = excluded.domicilio_texto, localidad = excluded.localidad,
    actualizado_en = now()
  -- NO reactivar lo que el personal invalidó o marcó como sospechoso
  where coalesce(public.ubicaciones_ciudadanos.estado, 'activa') = 'activa';
  return true;
end $$;

revoke all on function public.buscar_ubicacion(text) from public;
revoke all on function public.guardar_ubicacion(text,text,double precision,double precision,text,text,text,text) from public;
grant execute on function public.buscar_ubicacion(text) to anon, authenticated;
grant execute on function public.guardar_ubicacion(text,text,double precision,double precision,text,text,text,text) to anon, authenticated;

commit;

-- =====================================================================
--  AUDITORÍA: ver TODO lo que el público (anon) puede hacer hoy en la base.
--  Ejecutalo aparte y revisá que solo aparezca lo esperado
--  (solicitudes: INSERT; ubicaciones_ciudadanos: nada).
--
--  select schemaname, tablename, policyname, cmd, roles, qual, with_check
--  from pg_policies where roles @> '{anon}' or roles @> '{public}' order by 1,2;
--
--  select table_schema, table_name, privilege_type
--  from information_schema.role_table_grants
--  where grantee = 'anon' and table_schema = 'public' order by 2,3;
-- =====================================================================
