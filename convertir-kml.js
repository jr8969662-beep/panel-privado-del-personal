/*
  convertir-kml.js
  ----------------
  Lee los KML de dependencias policiales y genera DDP-1.json ... DDP-14.json
  con la estructura que espera formularios-tramites.html:

    { "poligonos": [ { "n": "Nombre", "c": [[lat, lon], ...], "h": [[[lat,lon], ...], ...] }, ... ] }

  Uso:
    node convertir-kml.js [carpetaOrigen] [carpetaDestino]

  Por defecto:
    origen  = C:/Users/Usuario/Downloads/salida_ddp_completa
    destino = C:/Users/Usuario/repo-oficial

  Notas:
  - En KML las coordenadas son "lon,lat,alt". Acá se invierten a [lat, lon].
  - Se extraen los anillos EXTERNOS ("c") y los huecos ("h", opcional, uno por
    cada innerBoundaryIs). Un punto cae en la jurisdicción si está dentro del
    anillo externo y FUERA de todos los huecos.
  - Los Placemark de tipo Point (marcadores sueltos) se ignoran.
*/

const fs = require('fs');
const path = require('path');

const ORIGEN = process.argv[2] || 'C:/Users/Usuario/Downloads/salida_ddp_completa';
const DESTINO = process.argv[3] || 'C:/Users/Usuario/repo-oficial';
const MAX_DDP = 14;
const DECIMALES = 6;

function leerTexto(archivo) {
  let texto = fs.readFileSync(archivo, 'utf8');
  if (texto.charCodeAt(0) === 0xfeff) texto = texto.slice(1);
  return texto;
}

function limpiarNombre(bruto) {
  return String(bruto || '')
    .replace(/<!\[CDATA\[/g, '')
    .replace(/\]\]>/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function redondear(n) {
  return Number(n.toFixed(DECIMALES));
}

function parsearCoordenadas(texto) {
  const puntos = [];
  for (const token of texto.trim().split(/\s+/)) {
    if (!token) continue;
    const partes = token.split(',');
    const lon = parseFloat(partes[0]);
    const lat = parseFloat(partes[1]);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
    puntos.push([redondear(lat), redondear(lon)]);
  }
  return puntos;
}

function extraerPoligonos(xml) {
  const placemarks = xml.match(/<Placemark\b[\s\S]*?<\/Placemark>/g) || [];
  const poligonos = [];
  let huecos = 0;
  let puntos = 0;

  for (const placemark of placemarks) {
    const nombre = limpiarNombre((placemark.match(/<name>([\s\S]*?)<\/name>/) || [])[1]);
    const bloques = placemark.match(/<Polygon\b[\s\S]*?<\/Polygon>/g) || [];

    if (!bloques.length) {
      if (/<Point\b/.test(placemark)) puntos++;
      continue;
    }

    huecos += (placemark.match(/<innerBoundaryIs>/g) || []).length;

    for (const bloque of bloques) {
      const externo = bloque.match(/<outerBoundaryIs>[\s\S]*?<coordinates>([\s\S]*?)<\/coordinates>/);
      if (!externo) continue;
      const anillo = parsearCoordenadas(externo[1]);
      if (anillo.length < 3) continue;

      // Anillos internos (huecos) del mismo polígono.
      const huecosDelPoligono = (bloque.match(/<innerBoundaryIs>[\s\S]*?<\/innerBoundaryIs>/g) || [])
        .map((h) => {
          const c = h.match(/<coordinates>([\s\S]*?)<\/coordinates>/);
          return c ? parsearCoordenadas(c[1]) : [];
        })
        .filter((anilloInterno) => anilloInterno.length >= 3);

      const poligono = { n: nombre, c: anillo };
      if (huecosDelPoligono.length) poligono.h = huecosDelPoligono;
      poligonos.push(poligono);
    }
  }
  return { poligonos, huecos, puntos, placemarks: placemarks.length };
}

function validar(poligonos) {
  let peor = 0;
  for (const p of poligonos) {
    for (const anillo of [p.c, ...(p.h || [])]) {
      for (const [lat, lon] of anillo) {
        peor = Math.max(peor, Math.abs(lat));
        if (Math.abs(lat) > 90 || Math.abs(lon) > 180) {
          return { ok: false, motivo: `coordenada fuera de rango: [${lat}, ${lon}]` };
        }
      }
    }
  }
  // En Salta la latitud ronda -22..-27. Si el "lat" fuera una longitud, daría ~60.
  if (peor > 45) return { ok: false, motivo: `latitud sospechosa (max abs = ${peor}); ¿coordenadas invertidas?` };
  return { ok: true, maxAbsLat: peor };
}

function main() {
  if (!fs.existsSync(ORIGEN)) {
    console.error(`No existe la carpeta de origen: ${ORIGEN}`);
    process.exit(1);
  }
  if (!fs.existsSync(DESTINO)) {
    console.error(`No existe la carpeta de destino: ${DESTINO}`);
    process.exit(1);
  }

  let totalPoligonos = 0;
  let totalPuntos = 0;
  const resumen = [];

  for (let i = 1; i <= MAX_DDP; i++) {
    const kml = path.join(ORIGEN, `DDP-${i}`, `DDP-${i}.kml`);
    if (!fs.existsSync(kml)) {
      console.warn(`DDP-${i}: falta ${kml} (se omite)`);
      continue;
    }

    const { poligonos, huecos, puntos, placemarks } = extraerPoligonos(leerTexto(kml));
    const chequeo = validar(poligonos);
    if (!chequeo.ok) {
      console.error(`DDP-${i}: ${chequeo.motivo}. No se generó el JSON.`);
      process.exitCode = 2;
      continue;
    }

    const salida = path.join(DESTINO, `DDP-${i}.json`);
    fs.writeFileSync(salida, JSON.stringify({ poligonos }), 'utf8');

    const kb = (fs.statSync(salida).size / 1024).toFixed(0);
    totalPoligonos += poligonos.length;
    totalPuntos += puntos;
    resumen.push({ ddp: i, placemarks, poligonos: poligonos.length, huecos, puntos, kb: Number(kb), maxAbsLat: chequeo.maxAbsLat });
  }

  console.log('DDP | placemarks | poligonos | huecos_incluidos | puntos_omitidos | tamaño | max|lat|');
  for (const r of resumen) {
    console.log(
      `  ${String(r.ddp).padStart(2)} | ${String(r.placemarks).padStart(10)} | ${String(r.poligonos).padStart(9)} | ${String(r.huecos).padStart(15)} | ${String(r.puntos).padStart(15)} | ${String(r.kb + ' KB').padStart(7)} | ${r.maxAbsLat}`
    );
  }
  console.log(`\nTotal: ${resumen.length} archivos, ${totalPoligonos} polígonos, ${totalPuntos} puntos descartados.`);
  console.log(`Destino: ${DESTINO}`);
}

main();
