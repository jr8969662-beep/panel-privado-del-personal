-- =====================================================================
--  Dejar en "telefonos" SOLO los números Red WIN (sin etiqueta ni medio)
-- =====================================================================
update public.dependencias_contacto
set telefonos = coalesce((
  select jsonb_agg(n order by n)
  from (select distinct e->>'numero' as n
        from jsonb_array_elements(telefonos) e
        where jsonb_typeof(e) = 'object' and e->>'medio' = 'Red WIN') x
), '[]'::jsonb)
where exists (select 1 from jsonb_array_elements(telefonos) e where jsonb_typeof(e) = 'object');
