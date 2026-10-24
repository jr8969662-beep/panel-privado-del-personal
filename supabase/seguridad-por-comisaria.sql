-- =====================================================================
--  MI COMISARÍA - Seguridad por comisaría
--  Cada usuario del personal ve, valida y deniega SOLO los trámites de
--  las comisarías que tiene asignadas. Los administradores ven todo.
--
--  CÓMO USARLO (Supabase > SQL Editor > New query):
--   1) Reemplazá TU_EMAIL_DE_ADMIN (abajo) por el email con el que entrás al panel.
--   2) Ejecutalo completo ("Run"). Si el email no existe en Authentication > Users,
--      el script se frena SIN cambiar nada (así no te quedás afuera).
--   3) Después cargá al personal de cada comisaría (ver el ejemplo al final).
--
--  Es seguro ejecutarlo más de una vez.
-- =====================================================================
begin;

-- 1) Quién es quién ---------------------------------------------------
create table if not exists public.personal (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  email      text,
  nombre     text,
  rol        text not null default 'comisaria' check (rol in ('admin','comisaria')),
  comisarias text[] not null default '{}',   -- nombres EXACTOS (ver nombres-de-comisarias.txt)
  activo     boolean not null default true,
  created_at timestamptz default now()
);
alter table public.personal enable row level security;
revoke all on public.personal from anon, authenticated;
grant select on public.personal to authenticated;   -- solo lectura (y filtrada por la regla de abajo)

-- Cada persona solo puede leer SU propia fila. Nadie puede escribir desde la web:
-- el alta/baja se hace desde el SQL Editor o desde el panel de Supabase.
drop policy if exists "Personal ve su propio perfil" on public.personal;
create policy "Personal ve su propio perfil"
on public.personal for select to authenticated using (user_id = auth.uid());

-- 2) Funciones de permiso (security definer para evitar recursión con RLS) --
create or replace function public.es_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.personal p
                 where p.user_id = auth.uid() and p.activo and p.rol = 'admin');
$$;

create or replace function public.puede_ver_comisaria(c text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.personal p
                 where p.user_id = auth.uid() and p.activo
                   and (p.rol = 'admin' or (c is not null and c = any (p.comisarias))));
$$;

revoke all on function public.es_admin() from public, anon;
revoke all on function public.puede_ver_comisaria(text) from public, anon;
grant execute on function public.es_admin() to authenticated;
grant execute on function public.puede_ver_comisaria(text) to authenticated;

-- 3) Primer administrador (OBLIGATORIO, antes de cambiar las reglas) -----------
insert into public.personal (user_id, email, nombre, rol)
select id, email, 'Administrador', 'admin'
from auth.users
where lower(email) = lower('TU_EMAIL_DE_ADMIN')
on conflict (user_id) do update set rol = 'admin', activo = true;

do $$
begin
  if not exists (select 1 from public.personal where rol = 'admin' and activo) then
    raise exception 'No hay ningún administrador: revisá el email y que exista en Authentication > Users. No se cambió nada.';
  end if;
end $$;

-- 4) Reglas de solicitudes ------------------------------------------------
alter table public.solicitudes enable row level security;

-- (El público sigue pudiendo SOLO crear solicitudes: la regla de insert no se toca.)

drop policy if exists "Personal logueado puede ver solicitudes" on public.solicitudes;
drop policy if exists "Personal ve solicitudes de su comisaria" on public.solicitudes;
create policy "Personal ve solicitudes de su comisaria"
on public.solicitudes for select to authenticated
using (public.puede_ver_comisaria(comisaria_asignada));

-- Puede validar/denegar los de su comisaría. Para DERIVAR un trámite a otra comisaría
-- se usa la función derivar_solicitud (más abajo): una actualización común no puede
-- sacar la fila de su propia vista.
drop policy if exists "Personal logueado puede actualizar solicitudes" on public.solicitudes;
drop policy if exists "Personal actualiza solicitudes de su comisaria" on public.solicitudes;
create policy "Personal actualiza solicitudes de su comisaria"
on public.solicitudes for update to authenticated
using (public.puede_ver_comisaria(comisaria_asignada))
with check (public.puede_ver_comisaria(comisaria_asignada));

-- Derivar un trámite a otra comisaría (ej. el ciudadano pidió corregir su jurisdicción).
-- Solo quien hoy tiene permiso sobre ese trámite puede derivarlo.
create or replace function public.derivar_solicitud(p_id uuid, p_comisaria text)
returns void language plpgsql security definer set search_path = public as $$
declare v_actual text;
begin
  select comisaria_asignada into v_actual from public.solicitudes where id = p_id;
  if not found then raise exception 'Solicitud inexistente'; end if;
  if not public.puede_ver_comisaria(v_actual) then
    raise exception 'Sin permiso sobre esta solicitud' using errcode = '42501';
  end if;
  if p_comisaria is null or char_length(p_comisaria) = 0 or char_length(p_comisaria) > 300 then
    raise exception 'Comisaría inválida';
  end if;
  update public.solicitudes set comisaria_asignada = p_comisaria where id = p_id;
end $$;
revoke all on function public.derivar_solicitud(uuid, text) from public, anon;
grant execute on function public.derivar_solicitud(uuid, text) to authenticated;

-- Borrar: el administrador cualquiera; el personal SOLO los ya procesados y vencidos
-- de su comisaría (es la limpieza automática que hace el panel).
drop policy if exists "Personal logueado puede borrar solicitudes" on public.solicitudes;
drop policy if exists "Borrado controlado de solicitudes" on public.solicitudes;
create policy "Borrado controlado de solicitudes"
on public.solicitudes for delete to authenticated
using (
  public.es_admin()
  or (public.puede_ver_comisaria(comisaria_asignada)
      and estado = 'procesado' and retirado = false and fecha_expiracion < now())
);

-- 5) Registro de accesos: solo administradores lo leen ------------------------
drop policy if exists "Personal logueado ve accesos" on public.logs_accesos;
drop policy if exists "Solo administradores ven accesos" on public.logs_accesos;
create policy "Solo administradores ven accesos"
on public.logs_accesos for select to authenticated using (public.es_admin());

commit;

-- =====================================================================
--  CARGAR PERSONAL DE UNA COMISARÍA (ejecutar cuando haga falta)
--  1. Creá el usuario en Authentication > Users (Add user, "Auto Confirm User").
--  2. Ejecutá esto con SU email y los nombres EXACTOS de su comisaría:
--
--  insert into public.personal (user_id, email, nombre, rol, comisarias)
--  select id, email, 'Nombre y apellido', 'comisaria',
--         array['DUR1-S3-Cría 11° (Ex-cria 103)']   -- Comisaría 11° (17 de Octubre)
--  from auth.users where lower(email) = lower('email.del.personal@ejemplo.com')
--  on conflict (user_id) do update
--    set comisarias = excluded.comisarias, activo = true, rol = 'comisaria';
--
--  Dar de baja:     update public.personal set activo = false where email = '...';
--  Ver quién tiene qué: select email, rol, comisarias, activo from public.personal;
--  Ver nombres que ya existen en trámites:
--    select comisaria_asignada, count(*) from public.solicitudes group by 1 order by 2 desc;
--
--  VOLVER ATRÁS (todo el personal vuelve a ver todo):
--    drop policy "Personal ve solicitudes de su comisaria" on public.solicitudes;
--    create policy "Personal logueado puede ver solicitudes" on public.solicitudes
--      for select to authenticated using (true);
--    (idem update / delete como en README-supabase.md)
-- =====================================================================
