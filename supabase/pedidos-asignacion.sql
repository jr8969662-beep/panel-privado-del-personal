-- =====================================================================
--  MI COMISARÍA - Pedido de asignación de comisaría
--  El personal que entra al panel SIN comisaría asignada puede pedirle al administrador
--  que se la asigne. El administrador lo ve en su web y aprueba (se le carga la comisaría)
--  o rechaza.
--  Requiere administrador.sql y legajo-y-jerarquia.sql. Se puede ejecutar más de una vez.
--  Supabase > SQL Editor > New query > pegar todo > Run.
-- =====================================================================
begin;

do $$ begin
  if to_regprocedure('public.admin_listar_personal()') is null then raise exception 'Primero ejecutá administrador.sql'; end if;
end $$;

create table if not exists public.pedidos_asignacion (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  email         text,
  nombre        text,
  comisaria     text not null,
  mensaje       text,
  estado        text not null default 'pendiente' check (estado in ('pendiente','aprobado','rechazado')),
  created_at    timestamptz not null default now(),
  atendido_por  text,
  atendido_en   timestamptz,
  nota          text
);
create index if not exists pedidos_asignacion_estado_idx on public.pedidos_asignacion (estado, created_at desc);
alter table public.pedidos_asignacion enable row level security;
revoke all on public.pedidos_asignacion from anon, authenticated;
grant select on public.pedidos_asignacion to authenticated;
drop policy if exists "Admin ve pedidos de asignacion" on public.pedidos_asignacion;
drop policy if exists "Cada uno ve los suyos" on public.pedidos_asignacion;
create policy "Admin ve pedidos de asignacion" on public.pedidos_asignacion for select to authenticated using (public.es_admin());
create policy "Cada uno ve los suyos" on public.pedidos_asignacion for select to authenticated using (user_id = auth.uid());

-- Lo llama el personal desde el panel (solo cuentas activas del personal)
create or replace function public.pedir_asignacion_comisaria(p_comisaria text, p_mensaje text default null)
returns void language plpgsql security definer set search_path = public, auth as $$
declare v_p public.personal%rowtype;
begin
  select * into v_p from public.personal where user_id = auth.uid() and activo;
  if not found then raise exception 'Tu cuenta no está habilitada' using errcode = '42501'; end if;
  if p_comisaria is null or char_length(trim(p_comisaria)) < 3 or char_length(p_comisaria) > 300 then raise exception 'Elegí una comisaría'; end if;
  if exists (select 1 from public.pedidos_asignacion where user_id = auth.uid() and estado = 'pendiente') then
    raise exception 'Ya tenés un pedido pendiente. Esperá la respuesta del administrador.';
  end if;
  if (select count(*) from public.pedidos_asignacion where user_id = auth.uid() and created_at > now() - interval '24 hours') >= 5 then
    raise exception 'Demasiados pedidos hoy. Probá mañana.';
  end if;
  insert into public.pedidos_asignacion (user_id, email, nombre, comisaria, mensaje)
  values (auth.uid(), v_p.email, trim(coalesce(v_p.jerarquia || ' ', '') || coalesce(v_p.nombre, '') || coalesce(' · Legajo ' || v_p.legajo, '')),
          trim(p_comisaria), left(trim(coalesce(p_mensaje, '')), 300));
end $$;
revoke all on function public.pedir_asignacion_comisaria(text, text) from public, anon;
grant execute on function public.pedir_asignacion_comisaria(text, text) to authenticated;

-- Lo llama el administrador: aprueba (agrega la comisaría a la persona) o rechaza
create or replace function public.admin_resolver_asignacion(p_id uuid, p_aprobar boolean, p_comisaria text default null, p_nota text default null)
returns void language plpgsql security definer set search_path = public, auth as $$
declare v_ped public.pedidos_asignacion%rowtype; v_com text; v_mail text;
begin
  if not public.es_admin() then raise exception 'Solo administradores' using errcode = '42501'; end if;
  select * into v_ped from public.pedidos_asignacion where id = p_id;
  if not found then raise exception 'Pedido inexistente'; end if;
  if v_ped.estado <> 'pendiente' then raise exception 'Ese pedido ya fue atendido'; end if;
  v_com := coalesce(nullif(trim(coalesce(p_comisaria, '')), ''), v_ped.comisaria);
  select email into v_mail from auth.users where id = auth.uid();
  if p_aprobar then
    update public.personal set comisarias = case when v_com = any (comisarias) then comisarias else comisarias || v_com end
     where user_id = v_ped.user_id;
    if not found then raise exception 'La persona ya no está en el personal'; end if;
  end if;
  update public.pedidos_asignacion
     set estado = case when p_aprobar then 'aprobado' else 'rechazado' end,
         comisaria = v_com, nota = left(coalesce(p_nota, ''), 300), atendido_por = v_mail, atendido_en = now()
   where id = p_id;
end $$;
revoke all on function public.admin_resolver_asignacion(uuid, boolean, text, text) from public, anon;
grant execute on function public.admin_resolver_asignacion(uuid, boolean, text, text) to authenticated;

commit;
