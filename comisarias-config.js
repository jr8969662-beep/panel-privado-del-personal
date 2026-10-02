/*
  DATOS REALES de dependencias de la Policía de la Provincia de Salta
  (Comisarías, Sub Comisarías, Destacamentos y Puestos Policiales),
  con sus coordenadas reales, tomados del mapa oficial de la Policía de Salta
  "DEPENDENCIAS POLICIA PROVINCIA DE SALTA" (zona Capital y alrededores).

  Cómo funciona la asignación automática:
  1. La persona escribe su domicilio en el formulario.
  2. Ese texto se convierte en coordenadas (latitud/longitud) usando un
     servicio gratuito de geocodificación (Nominatim / OpenStreetMap).
  3. Se calcula cuál de las dependencias de la lista de abajo está más
     cerca de esas coordenadas, y esa es la que se asigna al trámite.

  Importante: esto es una APROXIMACIÓN por cercanía geográfica, no la
  jurisdicción oficial exacta (que depende de límites de barrio definidos
  por la Policía, no solo de la distancia). Si en algún caso el personal
  ve que la asignación no es la correcta, puede reasignarla manualmente.
*/

const DEPENDENCIAS_POLICIALES = [
  { nombre: "Comisaria N°105 - Hipolito Irigoyen Nº 841 - La Merced", lat: -24.970175, lon: -65.489828 },
  { nombre: "Comisaria N°106 - Etapa 5-Mza. 5 Casa 1 - Av. Ralle s/nº - Limache", lat: -24.852619, lon: -65.431589 },
  { nombre: "Comisaria N°108 - Avda. 9 de Julio Nº 358 - Campo Quijano", lat: -24.9079653, lon: -65.6423614 },
  { nombre: "Comisaria N°100 - Juan Carlos Davalos y B.Mitre - San Lorenzo", lat: -24.73125, lon: -65.490778 },
  { nombre: "Comisaria N°11 - Rivadavia 246 - Gral. Güemes", lat: -24.675149, lon: -65.047344 },
  { nombre: "Comisaria N°12 - Avda. 4 - Calle 5 - Santa Ana I - Salta", lat: -24.857336, lon: -65.470575 },
  { nombre: "Comisaria N°13 - Egidio Bonato N° 235 - Cerrillos", lat: -24.903533, lon: -65.487753 },
  { nombre: "Comisaria N°14 - Mariano Moreno N° 7 - Rosario de Lerma", lat: -24.984603, lon: -65.578833 },
  { nombre: "Comisaria N°15 - Mar Mediterraneo 223 - B° San Remo", lat: -24.829231, lon: -65.423578 },
  { nombre: "Comisaria N°16 - Julio Cornejo N° 192 - B° El Centro - Campo Santo", lat: -24.681389, lon: -65.1032 },
  { nombre: "Comisaria N°8 - Calle 6 Medidor 300 - B° Santa Lucia", lat: -24.807981, lon: -65.439922 },
  { nombre: "Comisaria N°7 - La Razon s/n esquina Los Andes - B° El tribuno", lat: -24.846625, lon: -65.441169 },
  { nombre: "Comisaria N°6 - Tte.Mayol s/n - Ciudad del Milagro", lat: -24.723614, lon: -65.408431 },
  { nombre: "Comisaria N°3 - Los Guayacanes Nº 244 - B° Tres Cerritos", lat: -24.764263, lon: -65.399474 },
  { nombre: "Comisaria N°4 - Pompilio Guzmán - V° Mitre", lat: -24.816072, lon: -65.378484 },
  { nombre: "Comisaria N°10 - Calle Felipe Varela N° 500 - B° Santa Cecilia", lat: -24.829139, lon: -65.397831 },
  { nombre: "Comisaria N°9 - Gomez Recio Nº 632 - Portezuelo Sur", lat: -24.796094, lon: -65.394222 },
  { nombre: "Comisaria N°101 - Los Tarcos 800 esq. Cebiles - Bº Santa Rita - La Banda", lat: -24.663811, lon: -65.038328 },
  { nombre: "Comisaria N°102 - San Rafael - Atocha II - San Lorenzo", lat: -24.811761, lon: -65.459939 },
  { nombre: "Comisaria N°104 - Palermo - Avda. Jockey - Bº Palermo I", lat: -24.787304, lon: -65.459397 },
  { nombre: "Comisaria N°17 - Mza 450 A Lote 1 - Bº Solidaridad", lat: -24.843314, lon: -65.396283 },
  { nombre: "Comisaria N°1 - Gral. Guemes Nº 405", lat: -24.786744, lon: -65.408122 },
  { nombre: "Comisaria N°5 - Calle Rivadavia, entre Junín y República de Siria", lat: -24.7807724, lon: -65.4274511 },
  { nombre: "Comisaria N°2 - Pellegrini Nº 752", lat: -24.799021, lon: -65.416157 },
  { nombre: "Destacamento 20 de Febrero - Acceso a predio Antenas", lat: -24.786131, lon: -65.392531 },
  { nombre: "Destacamento Atocha - César Perdiguero S/N°", lat: -24.817547, lon: -65.478836 },
  { nombre: "Destacamento Betania - Ruta Provincial Nº 160", lat: -24.686431, lon: -65.146236 },
  { nombre: "Destacamento Cobos - Avda. Julio Cornejo s/nº", lat: -24.740256, lon: -65.083097 },
  { nombre: "Destacamento Delmi - Martin Cornejo esq. O'higuins", lat: -24.775619, lon: -65.421961 },
  { nombre: "Destacamento Docente - Mza 8 Casa 1 - B° Docente", lat: -24.844689, lon: -65.460928 },
  { nombre: "Destacamento La Silleta - Islas Malvinas N° 999", lat: -24.874681, lon: -65.589781 },
  { nombre: "Destacamento Los Alamos - Mza. 12 B Lote 4", lat: -24.863158, lon: -65.462336 },
  { nombre: "Destacamento Parque Industrial - R. Nac. Nº 34 Km. 1134", lat: -24.692428, lon: -65.040922 },
  { nombre: "Destacamento La Isla - Bº Santa Rita 1 (Ruta 26 km. 3 1/2)", lat: -24.876379, lon: -65.394297 },
  { nombre: "Destacamento San Antonio - Ruta 51 km. 10 - La Silleta", lat: -24.865282, lon: -65.564011 },
  { nombre: "Destacamento San Agustin - Martinez Saravia s/nº", lat: -24.995942, lon: -65.441222 },
  { nombre: "Destacamento San Bernardo - Guardia Hospital San Bernardo", lat: -24.790825, lon: -65.399414 },
  { nombre: "Destacamento San Carlos - Mza. 57 C 7 - Bº San Carlos", lat: -24.855319, lon: -65.437408 },
  { nombre: "Destacamento San Ignacio - Mors y Castro Mza 43", lat: -24.833422, lon: -65.383267 },
  { nombre: "Destacamento Tribunales - Avda. Bolivia nº 4671 - Ciudad Judicial", lat: -24.728386, lon: -65.411872 },
  { nombre: "Destacamento Villa Palacios - Mza. 37 C13 - Av. Contreras esq. Saavedra", lat: -24.810319, lon: -65.429642 },
  { nombre: "Puesto Policial Bicentenario - Parque Bicentenario", lat: -24.73014, lon: -65.416426 },
  { nombre: "Puesto Policial Catolica - Avda. Patron Costa (al Final)", lat: -24.741556, lon: -65.395803 },
  { nombre: "Puesto Policial Cofruthos - Av. Ragone S/N°", lat: -24.823782, lon: -65.426048 },
  { nombre: "Puesto Policial Martearena - Estadio Padre Martearena", lat: -24.820408, lon: -65.419717 },
  { nombre: "Puesto Policial Puente Blanco", lat: -24.816517, lon: -65.406458 },
  { nombre: "Puesto Policial Sanidad - Leloir y calle 233 - Bº Sanidad I", lat: -24.849027, lon: -65.402504 },
  { nombre: "Puesto Policial Terminal Omnibus Ciudad Gral. Guemes", lat: -24.667878, lon: -65.051619 },
  { nombre: "Puesto Policial Terminal Omnibus Salta Capital", lat: -24.795444, lon: -65.398511 },
  { nombre: "Comisaria N°18 - Pje Sarmiento Nº 55 - Chicoana", lat: -25.102669, lon: -65.536167 },
  { nombre: "Puesto Policial Vicente Solá - Mitre N° 2550", lat: -24.757231, lon: -65.410836 },
  { nombre: "Sub Comisaría Lola Mora - Lola Mora N° 850", lat: -24.804325, lon: -65.425658 },
  { nombre: "Sub Comisaria San Jorge - Hernán F. Reyes y Dávalos - B° S. Jorge", lat: -24.984531, lon: -65.565731 },
  { nombre: "Sub Comisaria San Luis - Mza 22 Pcla Nº 5 - R. Nac 51 Km 8 1/2", lat: -24.84755, lon: -65.512757 },
  { nombre: "Sub Comisaria Vaqueros - San Martin s/n - R.Nac. Nº 9 Km 1610", lat: -24.695778, lon: -65.409728 },
  { nombre: "Sub Comisaria Asuncion - Mza. N° 22 - Villa Asunción", lat: -24.795886, lon: -65.446858 },
  { nombre: "Comisaria N°19 - Gral. Güemes Nº 975 - El Carril", lat: -25.077181, lon: -65.488851 },
  { nombre: "Sub Comisaria Autodromo - Oscar Cabalen N° 530 - B° Autódromo", lat: -24.796439, lon: -65.371367 },
  { nombre: "Sub Comisaria Campo Castañares - B° Universitario", lat: -24.732989, lon: -65.400703 },
  { nombre: "Sub Comisaria El Bordo - Bº San Antonio", lat: -24.657875, lon: -65.102372 },
  { nombre: "Sub Comisaria Finca Las Costas - Km 3 - R.P. 150", lat: -24.773922, lon: -65.493103 },
  { nombre: "Sub Comisaria Grand Bourg - Avda. Di Pasquo 3100", lat: -24.775905, lon: -65.445818 },
  { nombre: "Sub Comisaria La Caldera - Avda. Gral. Güemes Nº 007", lat: -24.6065, lon: -65.382714 },
  { nombre: "Sub Comisaria Los Pinares - Bº Los Pinares", lat: -24.860542, lon: -65.399197 },
  { nombre: "Sub Comisaria Villa El Sol - Avda. Fco. de Gurruchaga Nº 250", lat: -24.818622, lon: -65.3918 },
  { nombre: "Sub Comisaria Villa Lavalle - Int. San Miguel Nº 2449", lat: -24.821367, lon: -65.404258 },
  { nombre: "Comisaria N°103 - Bº 17 de Octubre - Salta", lat: -24.71865, lon: -65.398062 },
  { nombre: "Puesto Policial Viñaco", lat: -25.1717395, lon: -65.4965437 },
  { nombre: "Puesto Policial El Circulo", lat: -24.836051, lon: -65.4190408 },
];

/* Distancia entre dos puntos (fórmula de Haversine), en kilómetros */
function distanciaKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/* Dada una latitud/longitud, devuelve la dependencia policial más cercana */
function dependenciaMasCercana(lat, lon) {
  let mejor = null;
  let mejorDistancia = Infinity;
  for (const dep of DEPENDENCIAS_POLICIALES) {
    const d = distanciaKm(lat, lon, dep.lat, dep.lon);
    if (d < mejorDistancia) {
      mejorDistancia = d;
      mejor = dep;
    }
  }
  return { dependencia: mejor, distanciaKm: mejorDistancia };
}

/*
  Convierte un domicilio escrito en texto a coordenadas, usando el
  servicio gratuito Nominatim (OpenStreetMap). No requiere API key.
  Devuelve {lat, lon, direccionEncontrada} o null si no se pudo ubicar.
*/
async function geocodificarDireccion(domicilio) {
  const consulta = `${domicilio}, Salta, Argentina`;
  const url = `https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=ar&q=${encodeURIComponent(consulta)}`;
  try {
    const resp = await fetch(url, { headers: { 'Accept-Language': 'es' } });
    const data = await resp.json();
    if (!data || !data.length) return null;
    return {
      lat: parseFloat(data[0].lat),
      lon: parseFloat(data[0].lon),
      direccionEncontrada: data[0].display_name,
    };
  } catch (err) {
    console.error('Error geocodificando:', err);
    return null;
  }
}

/*
  Función principal: recibe el domicilio en texto y devuelve
  { comisaria, distanciaKm, direccionEncontrada } o null si no se pudo
  determinar (por ejemplo, dirección no encontrada).
*/
async function asignarComisariaPorDireccion(domicilio) {
  if (!domicilio) return null;
  const ubicacion = await geocodificarDireccion(domicilio);
  if (!ubicacion) return null;
  const { dependencia, distanciaKm: dist } = dependenciaMasCercana(ubicacion.lat, ubicacion.lon);
  if (!dependencia) return null;
  return {
    comisaria: dependencia.nombre,
    distanciaKm: dist,
    direccionEncontrada: ubicacion.direccionEncontrada,
  };
}

/* ------------------------------------------------------------
   NOMBRES OFICIALES DE DEPENDENCIAS
   Convierte el nombre técnico del KML (ej. "DUR1-S3-Cría 11° (Ex-cria 103)")
   en un nombre legible ("Comisaría N°11 - 17 de Octubre (DDP 1)").
   El sufijo de barrio se toma de DEPENDENCIAS_POLICIALES solo cuando el match
   es confiable (por número viejo "Ex" o por número actual); si no, se omite.
   ------------------------------------------------------------ */

function tipoDeDependencia(texto) {
  if (/^sub\s*comisar/i.test(texto)) return 'Subcomisaría';
  if (/^comisar/i.test(texto)) return 'Comisaría';
  if (/destacamento/i.test(texto)) return 'Destacamento';
  if (/^puesto/i.test(texto)) return 'Puesto';
  return null;
}

/* Número de una entrada de DEPENDENCIAS_POLICIALES, solo si va pegado al tipo
   ("Comisaria N°11 - ..."). No toma números de nombres ("Destacamento 20 de Febrero"). */
function numeroEnDependencias(texto) {
  const m = String(texto).match(/^\s*(?:sub\s*)?(?:comisaria|comisar[íi]a|destacamento|puesto(?:\s+policial)?)\s*n?[°º]?\.?\s*(\d{1,3})\b/i);
  if (!m) return null;
  if (/^\s*de\s/i.test(String(texto).slice(m.index + m[0].length))) return null;
  return m[1];
}

let _mapaDependenciasPorNumero = null;
function dependenciasPorNumero() {
  if (_mapaDependenciasPorNumero) return _mapaDependenciasPorNumero;
  const mapa = {};
  for (const dep of DEPENDENCIAS_POLICIALES) {
    const num = numeroEnDependencias(dep.nombre);
    if (num && !(num in mapa)) mapa[num] = dep.nombre;
  }
  _mapaDependenciasPorNumero = mapa;
  return mapa;
}

/* Toma el barrio/localidad del final de una entrada, descartando calles. */
function descriptorDeDependencia(entrada) {
  const segmentos = String(entrada).split(' - ').map((s) => s.trim());
  const esCalle = (s) => /N[°º]|\bs\/n\b|\bkm\b|\bentre\b|\by\b/i.test(s) || /^salta$/i.test(s);
  for (let i = segmentos.length - 1; i >= 1; i--) {
    if (!esCalle(segmentos[i])) return segmentos[i].replace(/^(b[°º]|barrio|v[°º]|villa)\s+/i, '').trim();
  }
  return null;
}

function normalizarNombreDependencia(nombre, ddp) {
  let n = String(nombre || '').trim();
  if (!n) return '';
  n = n.replace(/^DUR\s*[I1]?\d*\s*-\s*S\s*\d*\s*-\s*/i, '').trim();

  const tipos = [
    [/^sub\s*[-\s]?\s*cr[íi]as?\.?\s*/i, 'Subcomisaría'],
    [/^sub\s*comisar[íi]as?\.?\s*/i, 'Subcomisaría'],
    [/^cr[íi]as?\.?\s*/i, 'Comisaría'],
    [/^comisar[íi]as?\.?\s*/i, 'Comisaría'],
    [/^destacamento\.?\s*/i, 'Destacamento'],
    [/^dsto\.?\s*/i, 'Destacamento'],
    [/^dest\.?\s*/i, 'Destacamento'],
    [/^pto\.?\s*pol\.?\s*/i, 'Puesto Policial'],
    [/^puesto\s+pol\.?\s*/i, 'Puesto Policial'],
    [/^puesto\s+/i, 'Puesto'],
    [/^base\s+op(?:erativa)?\.?\s*/i, 'Base Operativa'],
  ];
  let tipo = null;
  let resto = n;
  for (const [re, etiqueta] of tipos) {
    if (re.test(n)) { tipo = etiqueta; resto = n.replace(re, '').trim(); break; }
  }

  // Referencia vieja "(Ex ...)": solo sirve si es numérica.
  const exRaw = (n.match(/\(\s*ex[^)]*\)/i) || [])[0] || null;
  const exNumero = exRaw ? ((exRaw.match(/(\d{1,3})/) || [])[1] || null) : null;
  const exNoNumerico = !!exRaw && !exNumero;

  // Número propio: no se toma si va seguido de " de " (evita "9 de Julio").
  let numero = null;
  const m = resto.match(/^n?[°º]?\s*(\d{1,3})\s*°?\.?\s*/i);
  if (m) {
    const sobrante = resto.slice(m[0].length);
    if (!/^de\s/i.test(sobrante)) { numero = m[1]; resto = sobrante.trim(); }
  }
  resto = resto.replace(/\s*\(\s*ex[^)]*\)\s*/gi, ' ').replace(/\s+/g, ' ').trim();

  const clave = exNumero || numero;
  const entradaDep = (!exNoNumerico && clave) ? dependenciasPorNumero()[String(clave)] : null;

  let base;
  let descriptor = null;
  if (entradaDep) {
    const tipoDep = tipoDeDependencia(entradaDep);
    if (tipo && tipoDep && tipoDep !== tipo) {
      // Manda el tipo de DEPENDENCIAS_POLICIALES (lista oficial)
      const nombreDep = String(entradaDep).split(' - ')[0]
        .replace(/^(sub\s*comisaria|comisaria|destacamento|puesto\s*policial|puesto)\s*/i, '').trim();
      base = `${tipoDep} ${nombreDep}`.replace(/\s+/g, ' ').trim();
    } else {
      base = (tipo && numero) ? `${tipo} N°${numero}${resto ? ' ' + resto : ''}` : (tipo || resto || n);
      if (tipo && !numero && resto) base = `${tipo} ${resto}`;
      descriptor = descriptorDeDependencia(entradaDep);
    }
  } else {
    base = (tipo && numero) ? `${tipo} N°${numero}${resto ? ' ' + resto : ''}` : (tipo || resto || n);
    if (tipo && !numero && resto) base = `${tipo} ${resto}`;
  }

  if (descriptor) base += ' - ' + descriptor;
  return ddp ? `${base} (DDP ${ddp})` : base;
}

/* Tipo de dependencia a partir de un nombre ya sea técnico u oficial. */
function tipoDependencia(nombre) {
  const n = normalizarNombreDependencia(String(nombre || '').trim());
  if (/^subcomisar/i.test(n)) return 'Subcomisaría';
  if (/^comisar/i.test(n)) return 'Comisaría';
  if (/^destacamento/i.test(n)) return 'Destacamento';
  if (/^puesto/i.test(n)) return 'Puesto';
  if (/^base operativa/i.test(n)) return 'Base Operativa';
  return 'Otro';
}
