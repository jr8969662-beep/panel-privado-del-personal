-- =====================================================================
--  MI COMISARÍA - Fotos de DNI (bucket "fotos-tramites")
--   * Límite de 5 MB y solo imágenes JPEG (el formulario ya sube JPEG comprimido).
--   * El público solo puede SUBIR con el formato de nombre que usa el formulario
--     (no puede subir cualquier archivo ni con cualquier nombre).
--   * El personal solo ve las fotos de los trámites de SU comisaría
--     (el administrador, todas). Antes cualquier personal veía todas.
--  Requiere haber ejecutado antes seguridad-por-comisaria.sql. Es seguro repetirlo.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.puede_ver_comisaria(text)') is null then
    raise exception 'Primero ejecutá el script de seguridad por comisaría';
  end if;
end $$;

update storage.buckets
   set file_size_limit = 5242880,
       allowed_mime_types = array['image/jpeg']
 where id = 'fotos-tramites';

-- Subida pública: solo con el nombre que genera el formulario
drop policy if exists "subir fotos publico" on storage.objects;
drop policy if exists "Subir fotos con formato valido" on storage.objects;
create policy "Subir fotos con formato valido"
on storage.objects for insert to anon
with check (
  bucket_id = 'fotos-tramites'
  and name ~ '^(residencia|convivencia|carencia|autorizacion|antecedentes|domicilio|extravio|supervivencia|estadia)/[0-9]{13}-[a-z0-9]{0,8}-foto_(solicitante|testigo1|testigo2|menor|progenitor|acompanante|conviviente[0-9]?)\.jpg$'
);

-- Lectura: solo fotos de trámites que el usuario puede ver
drop policy if exists "Solo personal logueado puede ver fotos" on storage.objects;
drop policy if exists "Personal ve fotos de su comisaria" on storage.objects;
create policy "Personal ve fotos de su comisaria"
on storage.objects for select to authenticated
using (
  bucket_id = 'fotos-tramites'
  and (
    public.es_admin()
    or exists (
      select 1 from public.solicitudes s
      where public.puede_ver_comisaria(s.comisaria_asignada)
        and exists (
          select 1 from jsonb_each_text(s.datos) e
          where e.key like 'foto\_%' and e.value = name
        )
    )
  )
);

-- Registro de accesos: el público solo puede insertar filas razonables
drop policy if exists "Cualquiera puede insertar logs" on public.logs_accesos;
drop policy if exists "Insertar logs con limites" on public.logs_accesos;
create policy "Insertar logs con limites"
on public.logs_accesos for insert to anon, authenticated
with check (
  char_length(coalesce(email,'')) <= 200 and char_length(coalesce(tipo,'')) <= 50
  and char_length(coalesce(user_agent,'')) <= 500 and char_length(coalesce(dispositivo,'')) <= 100
);

commit;
