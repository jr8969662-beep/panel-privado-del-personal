-- Deja en "telefonos" SOLO números (sin etiqueta):
--   * si la dependencia tiene números Red WIN -> quedan solo los Red WIN
--   * si NO tiene Red WIN                      -> quedan los fijos
update public.dependencias_contacto
set telefonos = coalesce((
  select jsonb_agg(n order by n)
  from (
    select distinct e->>'numero' as n
    from jsonb_array_elements(telefonos) e
    where jsonb_typeof(e) = 'object'
      and e->>'medio' = case when exists (select 1 from jsonb_array_elements(telefonos) w
                                          where jsonb_typeof(w) = 'object' and w->>'medio' = 'Red WIN')
                             then 'Red WIN' else 'Fijo' end
  ) x
), '[]'::jsonb)
where exists (select 1 from jsonb_array_elements(telefonos) e where jsonb_typeof(e) = 'object');
