// Edge Function: recordatorio-vencimiento
// Busca los trámites "procesado" sin retirar cuyo plazo vence en los próximos 3 días
// y les manda un email de recordatorio (EmailJS). La dispara pg_cron una vez por día.
//
// Variables de entorno:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  -> las inyecta Supabase automáticamente.
//   CRON_SECRET, EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_ID, EMAILJS_PUBLIC_KEY -> se setean con `supabase secrets set`.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const CRON_SECRET = Deno.env.get('CRON_SECRET') ?? '';
const EMAILJS_SERVICE_ID = Deno.env.get('EMAILJS_SERVICE_ID') ?? '';
const EMAILJS_TEMPLATE_ID = Deno.env.get('EMAILJS_TEMPLATE_ID') ?? '';
const EMAILJS_PUBLIC_KEY = Deno.env.get('EMAILJS_PUBLIC_KEY') ?? '';

const DIA_MS = 24 * 60 * 60 * 1000;

function responder(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return responder({ error: 'Método no permitido' }, 405);
  if (!CRON_SECRET || req.headers.get('x-cron-secret') !== CRON_SECRET) {
    return responder({ error: 'No autorizado' }, 401);
  }
  if (!EMAILJS_SERVICE_ID || !EMAILJS_TEMPLATE_ID || !EMAILJS_PUBLIC_KEY) {
    return responder({ error: 'Faltan variables de EmailJS' }, 500);
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false },
  });

  const ahora = new Date();
  const limite = new Date(ahora.getTime() + 3 * DIA_MS);

  const { data, error } = await supabase
    .from('solicitudes')
    .select('id, codigo, tramite_titulo, comisaria_asignada, fecha_expiracion, datos')
    .eq('estado', 'procesado')
    .not('retirado', 'is', true)
    .not('recordatorio_enviado', 'is', true)
    .not('fecha_expiracion', 'is', null)
    .gt('fecha_expiracion', ahora.toISOString())
    .lt('fecha_expiracion', limite.toISOString());

  if (error) return responder({ error: 'No se pudo consultar: ' + error.message }, 500);

  const solicitudes = data ?? [];
  let enviados = 0;
  const errores: Array<Record<string, unknown>> = [];

  for (const s of solicitudes) {
    const email = s.datos?.email;
    if (!email) continue;

    const nombre = s.datos?.nombre || s.datos?.nombreSolicitante ||
      s.datos?.nombreProgenitor || s.datos?.nombreMenor || 'ciudadano/a';
    const expira = new Date(s.fecha_expiracion);
    const dias = Math.max(0, Math.ceil((expira.getTime() - ahora.getTime()) / DIA_MS));
    const fechaLimite = expira.toLocaleDateString('es-AR', {
      day: '2-digit', month: '2-digit', year: 'numeric',
    });
    const mensajeExtra =
      `Te recordamos que tenés tiempo hasta el ${fechaLimite} (${dias} día${dias === 1 ? '' : 's'}) ` +
      `para retirar tu certificado en ${s.comisaria_asignada || 'la comisaría asignada'}. ` +
      `Pasada esa fecha se elimina automáticamente.`;

    try {
      const resp = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          service_id: EMAILJS_SERVICE_ID,
          template_id: EMAILJS_TEMPLATE_ID,
          user_id: EMAILJS_PUBLIC_KEY,
          template_params: {
            email,
            nombre,
            tramite: s.tramite_titulo || '',
            estado: 'RECORDATORIO DE RETIRO',
            codigo: s.codigo || '',
            comisaria: s.comisaria_asignada || '',
            fecha_limite: fechaLimite,
            dias: String(dias),
            mensaje_extra: mensajeExtra,
            bloque_codigo: '',
            bloque_fecha_limite: '',
          },
        }),
      });

      if (!resp.ok) {
        errores.push({ id: s.id, status: resp.status, detalle: await resp.text() });
        continue;
      }

      const { error: errorUpdate } = await supabase
        .from('solicitudes')
        .update({ recordatorio_enviado: true, fecha_recordatorio: new Date().toISOString() })
        .eq('id', s.id);

      if (errorUpdate) {
        errores.push({ id: s.id, detalle: errorUpdate.message });
        continue;
      }
      enviados++;
    } catch (e) {
      errores.push({ id: s.id, detalle: e instanceof Error ? e.message : String(e) });
    }
  }

  return responder({ total: solicitudes.length, enviados, errores });
});
