-- =====================================================================
--  MI COMISARÍA - Seguridad de la web de administrador
--   * Registro de todo lo que hace el administrador (tabla acciones_admin)
--  Requiere haber ejecutado administrador.sql. Se puede ejecutar más de una vez.
--  Supabase > SQL Editor > New query > pegar todo > Run.
-- =====================================================================
begin;

do $$ begin
  if to_regprocedure('public.admin_listar_personal()') is null then
    raise exception 'Primero ejecutá administrador.sql';
  end if;
end $$;

-- Interruptor de MFA obligatorio (empieza APAGADO para que no te quedes afuera)
create table if not exists public.config_admin (clave text primary key, valor text not null);
alter table public.config_admin enable row level security;
revoke all on public.config_admin from anon, authenticated;
insert into public.config_admin (clave, valor) values ('mfa_obligatorio', 'false') on conflict (clave) do nothing;

-- Administrador con la seguridad que corresponda (si el MFA es obligatorio, exige haberlo pasado)
create or replace function public.admin_ok()
returns boolean language sql stable security definer set search_path = public as $$
  select public.es_admin()
     and ( not exists (select 1 from public.config_admin where clave = 'mfa_obligatorio' and valor = 'true')
           or coalesce(auth.jwt() ->> 'aal', '') = 'aal2' );
$$;
revoke all on function public.admin_ok() from public, anon;
grant execute on function public.admin_ok() to authenticated;

-- Registro de acciones del administrador
create table if not exists public.acciones_admin (
  id          bigserial primary key,
  fecha       timestamptz not null default now(),
  admin_email text,
  accion      text not null,
  detalle     jsonb not null default '{}'::jsonb
);
create index if not exists acciones_admin_fecha_idx on public.acciones_admin (fecha desc);
alter table public.acciones_admin enable row level security;
revoke all on public.acciones_admin from anon, authenticated;
grant select on public.acciones_admin to authenticated;
drop policy if exists "Solo administradores ven acciones" on public.acciones_admin;
create policy "Solo administradores ven acciones"
on public.acciones_admin for select to authenticated using (public.admin_ok());

create or replace function public.admin_registrar_accion(p_accion text, p_detalle jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = public, auth as $$
declare v_mail text;
begin
  if not public.es_admin() then raise exception 'Solo administradores' using errcode = '42501'; end if;
  if p_accion is null or char_length(p_accion) > 60 then raise exception 'Acción inválida'; end if;
  select email into v_mail from auth.users where id = auth.uid();
  insert into public.acciones_admin (admin_email, accion, detalle)
  values (v_mail, p_accion, coalesce(left(p_detalle::text, 2000)::jsonb, '{}'::jsonb));
end $$;
revoke all on function public.admin_registrar_accion(text, jsonb) from public, anon;
grant execute on function public.admin_registrar_accion(text, jsonb) to authenticated;

-- Pedidos de clave: solo administrador "completo"
drop policy if exists "Solo administradores ven pedidos de clave" on public.pedidos_clave;
create policy "Solo administradores ven pedidos de clave"
on public.pedidos_clave for select to authenticated using (public.admin_ok());

-- Funciones de administrador, ahora con admin_ok()
create or replace function public.admin_listar_personal()
returns table (user_id uuid, email text, nombre text, rol text, comisarias text[], activo boolean,
               created_at timestamptz, ultimo_ingreso timestamptz)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.admin_ok() then raise exception 'Solo administradores' using errcode = '42501'; end if;
  return query
    select p.user_id, p.email, p.nombre, p.rol, p.comisarias, p.activo, p.created_at, u.last_sign_in_at
    from public.personal p left join auth.users u on u.id = p.user_id
    order by p.rol, lower(coalesce(p.nombre, p.email));
end $$;

-- Editar nombre, comisarías y alta/baja (no cambia el rol ni se puede dar de baja a uno mismo)
create or replace function public.admin_actualizar_personal(p_user_id uuid, p_nombre text, p_comisarias text[], p_activo boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.admin_ok() then raise exception 'Solo administradores' using errcode = '42501'; end if;
  if p_user_id = auth.uid() and not p_activo then
    raise exception 'No podés darte de baja a vos mismo';
  end if;
  if p_nombre is not null and char_length(p_nombre) > 120 then raise exception 'Nombre demasiado largo'; end if;
  if coalesce(array_length(p_comisarias, 1), 0) > 50 then raise exception 'Demasiadas comisarías'; end if;
  update public.personal
     set nombre = coalesce(nullif(trim(p_nombre), ''), nombre),
         comisarias = coalesce(p_comisarias, comisarias),
         activo = p_activo
   where user_id = p_user_id;
  if not found then raise exception 'Persona inexistente'; end if;
end $$;

-- Dar de alta a alguien que YA creaste en Authentication > Users
create or replace function public.admin_alta_personal(p_email text, p_nombre text, p_comisarias text[])
returns void language plpgsql security definer set search_path = public, auth as $$
declare v_uid uuid;
begin
  if not public.admin_ok() then raise exception 'Solo administradores' using errcode = '42501'; end if;
  select id into v_uid from auth.users where lower(email) = lower(trim(p_email));
  if v_uid is null then
    raise exception 'Ese correo todavía no existe en Authentication > Users. Creá primero el usuario ("Auto Confirm User").';
  end if;
  insert into public.personal (user_id, email, nombre, rol, comisarias, activo)
  values (v_uid, lower(trim(p_email)), left(trim(coalesce(p_nombre,'')), 120), 'comisaria', coalesce(p_comisarias, '{}'), true)
  on conflict (user_id) do update
    set nombre = excluded.nombre, comisarias = excluded.comisarias, activo = true
    where public.personal.rol <> 'admin';
end $$;

-- Marcar un pedido de contraseña como atendido
create or replace function public.admin_atender_pedido(p_id uuid, p_estado text, p_nota text default null)
returns void language plpgsql security definer set search_path = public, auth as $$
declare v_mail text;
begin
  if not public.admin_ok() then raise exception 'Solo administradores' using errcode = '42501'; end if;
  if p_estado not in ('enviado','rechazado','pendiente') then raise exception 'Estado inválido'; end if;
  select email into v_mail from auth.users where id = auth.uid();
  update public.pedidos_clave
     set estado = p_estado, nota = left(coalesce(p_nota, ''), 300),
         atendido_por = v_mail, atendido_en = case when p_estado = 'pendiente' then null else now() end
   where id = p_id;
  if not found then raise exception 'Pedido inexistente'; end if;
end $$;

-- Estadísticas para el tablero
create or replace function public.admin_estadisticas()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r jsonb;
begin
  if not public.admin_ok() then raise exception 'Solo administradores' using errcode = '42501'; end if;
  select jsonb_build_object(
    'total',       (select count(*) from public.solicitudes),
    'pendientes',  (select count(*) from public.solicitudes where estado = 'pendiente'),
    'por_tramite', coalesce((select jsonb_agg(jsonb_build_object('clave', t, 'n', n) order by n desc)
                             from (select coalesce(tramite_titulo, tramite) t, count(*) n from public.solicitudes group by 1) x), '[]'::jsonb),
    'por_estado',  coalesce((select jsonb_agg(jsonb_build_object('clave', e, 'n', n) order by n desc)
                             from (select estado e, count(*) n from public.solicitudes group by 1) x), '[]'::jsonb),
    'por_comisaria', coalesce((select jsonb_agg(jsonb_build_object('clave', c, 'n', n) order by n desc)
                             from (select coalesce(comisaria_asignada, '(sin asignar)') c, count(*) n from public.solicitudes group by 1 order by 2 desc limit 30) x), '[]'::jsonb),
    'por_dia',     coalesce((select jsonb_agg(jsonb_build_object('clave', d, 'n', n) order by d)
                             from (select to_char(created_at at time zone 'America/Argentina/Salta', 'YYYY-MM-DD') d, count(*) n
                                   from public.solicitudes where created_at > now() - interval '30 days' group by 1) x), '[]'::jsonb),
    'pedidos_pendientes', (select count(*) from public.pedidos_clave where estado = 'pendiente'),
    'personal_activo', (select count(*) from public.personal where activo)
  ) into r;
  return r;
end $$;


commit;

