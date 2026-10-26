-- =====================================================================
--  MI COMISARÍA - Consulta pública del trámite (código o DNI)
--  El público NO puede leer la tabla solicitudes. Estas dos funciones validan
--  adentro y devuelven SOLO datos mínimos (estado, comisaría, fechas, motivo).
--  Nunca devuelven fotos, domicilio, email ni el contenido del formulario.
--  Es seguro ejecutarlo más de una vez.
-- =====================================================================
drop function if exists public.consultar_tramite_codigo(text);
drop function if exists public.consultar_tramites_dni(text);

create function public.consultar_tramite_codigo(p_codigo text)
returns table (
  codigo text, tramite text, tramite_titulo text, estado text, comisaria_asignada text,
  created_at timestamptz, fecha_expiracion timestamptz, motivo_denegacion text,
  retirado boolean, zona text
)
language sql stable security definer set search_path = public as $$
  select s.codigo, s.tramite, s.tramite_titulo, s.estado, s.comisaria_asignada,
         s.created_at, s.fecha_expiracion, s.motivo_denegacion,
         coalesce(s.retirado, false), s.datos->>'zona'
  from public.solicitudes s
  where s.codigo = p_codigo and p_codigo ~ '^[0-9]{8}$'
  limit 1;
$$;

-- Por DNI del solicitante: hasta 5 trámites, los más recientes primero
create function public.consultar_tramites_dni(p_dni text)
returns table (
  codigo text, tramite text, tramite_titulo text, estado text, comisaria_asignada text,
  created_at timestamptz, fecha_expiracion timestamptz, motivo_denegacion text,
  retirado boolean, zona text
)
language sql stable security definer set search_path = public as $$
  select s.codigo, s.tramite, s.tramite_titulo, s.estado, s.comisaria_asignada,
         s.created_at, s.fecha_expiracion, s.motivo_denegacion,
         coalesce(s.retirado, false), s.datos->>'zona'
  from public.solicitudes s
  where p_dni ~ '^[0-9]{7,8}$'
    and regexp_replace(coalesce(s.datos->>'dni', s.datos->>'dniSolicitante',
                                s.datos->>'dniMenor', s.datos->>'dniProgenitor', ''), '\D', '', 'g') = p_dni
  order by s.created_at desc
  limit 5;
$$;

revoke all on function public.consultar_tramite_codigo(text) from public;
revoke all on function public.consultar_tramites_dni(text) from public;
grant execute on function public.consultar_tramite_codigo(text) to anon, authenticated;
grant execute on function public.consultar_tramites_dni(text) to anon, authenticated;
