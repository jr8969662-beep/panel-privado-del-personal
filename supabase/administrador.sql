-- =====================================================================
--  MI COMISARÍA - Web de administrador + "Olvidé mi contraseña"
--
--  Qué agrega:
--   * Tabla pedidos_clave: pedidos de restablecer contraseña del personal.
--   * pedir_restablecer_clave(): lo llama el panel (sin sesión). Solo guarda el pedido si
--     el correo es de una persona ACTIVA del personal, con límites contra el spam,
--     y SIEMPRE responde igual (no revela si el correo existe).
--   * Funciones solo para administradores: listar/editar personal, atender pedidos
--     y estadísticas.
--
--  Requiere haber ejecutado antes seguridad-por-comisaria.sql (usa es_admin()).
--  Es seguro ejecutarlo más de una vez.
--  CÓMO USARLO: Supabase > SQL Editor > New query > pegar todo > Run.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.es_admin()') is null then
    raise exception 'Primero ejecutá el script de seguridad por comisaría (seguridad-por-comisaria.sql)';
  end if;
end $$;

-- 1) Pedidos de restablecer contraseña ----------------------------------
create table if not exists public.pedidos_clave (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade,
  email       text not null,
  nombre      text,
  comentario  text,
  estado      text not null default 'pendiente' check (estado in ('pendiente','enviado','rechazado')),
  created_at  timestamptz not null default now(),
  atendido_por text,
  atendido_en  timestamptz,
  nota        text
);
create index if not exists pedidos_clave_estado_idx on public.pedidos_clave (estado, created_at desc);
create index if not exists pedidos_clave_email_idx  on public.pedidos_clave (lower(email), created_at desc);

alter table public.pedidos_clave enable row level security;
revoke all on public.pedidos_clave from anon, authenticated;
grant select on public.pedidos_clave to authenticated;

drop policy if exists "Solo administradores ven pedidos de clave" on public.pedidos_clave;
create policy "Solo administradores ven pedidos de clave"
on public.pedidos_clave for select to authenticated using (public.es_admin());

-- 2) Pedido desde el panel (público, con límites) ------------------------
create or replace function public.pedir_restablecer_clave(p_email text, p_nombre text default null, p_comentario text default null)
returns void language plpgsql security definer set search_path = public, auth as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_uid   uuid;
begin
  -- formato básico y largo razonable
  if char_length(v_email) < 6 or char_length(v_email) > 200 or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    return;
  end if;

  -- tope global: como mucho 200 pedidos por hora (contra ataques masivos)
  if (select count(*) from public.pedidos_clave where created_at > now() - interval '1 hour') >= 200 then
    return;
  end if;

  -- solo personas activas del personal
  select p.user_id into v_uid
  from public.personal p
  where lower(p.email) = v_email and p.activo
  limit 1;
  if v_uid is null then return; end if;

  -- no repetir: si ya hay uno pendiente, o más de 3 en 24 horas, no se guarda otro
  if exists (select 1 from public.pedidos_clave where user_id = v_uid and estado = 'pendiente') then return; end if;
  if (select count(*) from public.pedidos_clave where user_id = v_uid and created_at > now() - interval '24 hours') >= 3 then return; end if;

  insert into public.pedidos_clave (user_id, email, nombre, comentario)
  values (v_uid, v_email, left(trim(coalesce(p_nombre, '')), 120), left(trim(coalesce(p_comentario, '')), 300));
end $$;
revoke all on function public.pedir_restablecer_clave(text, text, text) from public;
grant execute on function public.pedir_restablecer_clave(text, text, text) to anon, authenticated;

-- 3) Funciones SOLO para administradores ----------------------------------
create or replace function public.admin_listar_personal()
returns table (user_id uuid, email text, nombre text, rol text, comisarias text[], activo boolean,
               created_at timestamptz, ultimo_ingreso timestamptz)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.es_admin() then raise exception 'Solo administradores' using errcode = '42501'; end if;
  return query
    select p.user_id, p.email, p.nombre, p.rol, p.comisarias, p.activo, p.created_at, u.last_sign_in_at
    from public.personal p left join auth.users u on u.id = p.user_id
    order by p.rol, lower(coalesce(p.nombre, p.email));
end $$;

-- Editar nombre, comisarías y alta/baja (no cambia el rol ni se puede dar de baja a uno mismo)
create or replace function public.admin_actualizar_personal(p_user_id uuid, p_nombre text, p_comisarias text[], p_activo boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.es_admin() then raise exception 'Solo administradores' using errcode = '42501'; end if;
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
  if not public.es_admin() then raise exception 'Solo administradores' using errcode = '42501'; end if;
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
  if not public.es_admin() then raise exception 'Solo administradores' using errcode = '42501'; end if;
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
  if not public.es_admin() then raise exception 'Solo administradores' using errcode = '42501'; end if;
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

revoke all on function public.admin_listar_personal() from public, anon;
revoke all on function public.admin_actualizar_personal(uuid, text, text[], boolean) from public, anon;
revoke all on function public.admin_alta_personal(text, text, text[]) from public, anon;
revoke all on function public.admin_atender_pedido(uuid, text, text) from public, anon;
revoke all on function public.admin_estadisticas() from public, anon;
grant execute on function public.admin_listar_personal() to authenticated;
grant execute on function public.admin_actualizar_personal(uuid, text, text[], boolean) to authenticated;
grant execute on function public.admin_alta_personal(text, text, text[]) to authenticated;
grant execute on function public.admin_atender_pedido(uuid, text, text) to authenticated;
grant execute on function public.admin_estadisticas() to authenticated;

commit;
