-- =====================================================================
--  MI COMISARÍA - Legajo personal (5 dígitos) y jerarquía del personal
--   * Agrega "legajo" (único, 5 números) y "jerarquia" a la tabla personal.
--   * El panel pide el legajo al ingresar y lo compara con el cargado acá.
--  Requiere haber ejecutado administrador.sql. Se puede ejecutar más de una vez.
--  Supabase > SQL Editor > New query > pegar todo > Run.
-- =====================================================================
begin;

do $$ begin
  if to_regclass('public.personal') is null then raise exception 'Primero ejecutá seguridad-por-comisaria.sql'; end if;
  if to_regprocedure('public.admin_listar_personal()') is null then raise exception 'Primero ejecutá administrador.sql'; end if;
end $$;

alter table public.personal add column if not exists legajo text;
alter table public.personal add column if not exists jerarquia text;
alter table public.personal drop constraint if exists personal_legajo_5_digitos;
alter table public.personal add constraint personal_legajo_5_digitos check (legajo is null or legajo ~ '^[0-9]{5}$');
create unique index if not exists personal_legajo_unico on public.personal (legajo) where legajo is not null;

-- El panel llama a esto después de la contraseña: ¿el legajo escrito es el de ESTA cuenta?
create or replace function public.verificar_legajo(p_legajo text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.personal p
                 where p.user_id = auth.uid() and p.activo and p.legajo is not null and p.legajo = trim(coalesce(p_legajo, '')));
$$;
revoke all on function public.verificar_legajo(text) from public, anon;
grant execute on function public.verificar_legajo(text) to authenticated;

-- Funciones de administrador con legajo y jerarquía
drop function if exists public.admin_listar_personal();
create function public.admin_listar_personal()
returns table (user_id uuid, email text, nombre text, rol text, comisarias text[], activo boolean,
               created_at timestamptz, ultimo_ingreso timestamptz, legajo text, jerarquia text)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.es_admin() then raise exception 'Solo administradores' using errcode = '42501'; end if;
  return query
    select p.user_id, p.email, p.nombre, p.rol, p.comisarias, p.activo, p.created_at, u.last_sign_in_at, p.legajo, p.jerarquia
    from public.personal p left join auth.users u on u.id = p.user_id
    order by p.rol, lower(coalesce(p.nombre, p.email));
end $$;

drop function if exists public.admin_actualizar_personal(uuid, text, text[], boolean);
drop function if exists public.admin_actualizar_personal(uuid, text, text[], boolean, text, text);
create function public.admin_actualizar_personal(p_user_id uuid, p_nombre text, p_comisarias text[], p_activo boolean,
                                                 p_legajo text default null, p_jerarquia text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_leg text := nullif(trim(coalesce(p_legajo, '')), '');
begin
  if not public.es_admin() then raise exception 'Solo administradores' using errcode = '42501'; end if;
  if p_user_id = auth.uid() and not p_activo then raise exception 'No podés darte de baja a vos mismo'; end if;
  if p_nombre is not null and char_length(p_nombre) > 120 then raise exception 'Nombre demasiado largo'; end if;
  if coalesce(array_length(p_comisarias, 1), 0) > 50 then raise exception 'Demasiadas comisarías'; end if;
  if v_leg is not null and v_leg !~ '^[0-9]{5}$' then raise exception 'El legajo debe tener exactamente 5 números'; end if;
  if v_leg is not null and exists (select 1 from public.personal where legajo = v_leg and user_id <> p_user_id) then
    raise exception 'Ese legajo ya está asignado a otra persona';
  end if;
  update public.personal
     set nombre = coalesce(nullif(trim(p_nombre), ''), nombre),
         comisarias = coalesce(p_comisarias, comisarias),
         activo = p_activo,
         legajo = v_leg,
         jerarquia = left(nullif(trim(coalesce(p_jerarquia, '')), ''), 60)
   where user_id = p_user_id;
  if not found then raise exception 'Persona inexistente'; end if;
end $$;

drop function if exists public.admin_alta_personal(text, text, text[]);
drop function if exists public.admin_alta_personal(text, text, text[], text, text);
create function public.admin_alta_personal(p_email text, p_nombre text, p_comisarias text[],
                                           p_legajo text default null, p_jerarquia text default null)
returns void language plpgsql security definer set search_path = public, auth as $$
declare v_uid uuid; v_leg text := nullif(trim(coalesce(p_legajo, '')), '');
begin
  if not public.es_admin() then raise exception 'Solo administradores' using errcode = '42501'; end if;
  if v_leg is null or v_leg !~ '^[0-9]{5}$' then raise exception 'El legajo debe tener exactamente 5 números'; end if;
  select id into v_uid from auth.users where lower(email) = lower(trim(p_email));
  if v_uid is null then
    raise exception 'Ese correo todavía no existe en Authentication > Users. Creá primero el usuario ("Auto Confirm User").';
  end if;
  if exists (select 1 from public.personal where legajo = v_leg and user_id <> v_uid) then
    raise exception 'Ese legajo ya está asignado a otra persona';
  end if;
  insert into public.personal (user_id, email, nombre, rol, comisarias, activo, legajo, jerarquia)
  values (v_uid, lower(trim(p_email)), left(trim(coalesce(p_nombre,'')), 120), 'comisaria', coalesce(p_comisarias, '{}'), true,
          v_leg, left(nullif(trim(coalesce(p_jerarquia, '')), ''), 60))
  on conflict (user_id) do update
    set nombre = excluded.nombre, comisarias = excluded.comisarias, activo = true,
        legajo = excluded.legajo, jerarquia = excluded.jerarquia
    where public.personal.rol <> 'admin';
end $$;

revoke all on function public.admin_listar_personal() from public, anon;
revoke all on function public.admin_actualizar_personal(uuid, text, text[], boolean, text, text) from public, anon;
revoke all on function public.admin_alta_personal(text, text, text[], text, text) from public, anon;
grant execute on function public.admin_listar_personal() to authenticated;
grant execute on function public.admin_actualizar_personal(uuid, text, text[], boolean, text, text) to authenticated;
grant execute on function public.admin_alta_personal(text, text, text[], text, text) to authenticated;

commit;

-- =====================================================================
--  TU PROPIO LEGAJO Y JERARQUÍA (el administrador también entra al panel del personal).
--  Cambiá los datos y ejecutá esto una vez:
--
--  update public.personal set legajo = '12345', jerarquia = 'OFICIAL PRINCIPAL', nombre = 'Apellido Nombre'
--  where lower(email) = lower('TU_CORREO_DE_ADMIN');
-- =====================================================================
