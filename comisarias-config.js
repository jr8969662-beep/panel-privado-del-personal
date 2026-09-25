/*
  CONFIG_COMISARIAS
  ------------------
  Lista APROXIMADA de zonas/barrios de Salta capital y la comisaría asignada
  a cada una. Esto NO son datos oficiales verificados: es un punto de partida
  para que el personal lo ajuste con la información real de jurisdicciones.

  Cómo ajustar:
  - Cambiá el nombre de "comisaria" por el número/nombre real de cada dependencia.
  - Agregá o quitá barrios de cada zona según corresponda.
  - Podés agregar más zonas si hace falta.
  - El campo "zona" es el que ve la persona que completa el formulario
    (aparece como opción en el desplegable "Barrio / zona").
*/

const CONFIG_COMISARIAS = {
  zonas: [
    {
      zona: "Centro",
      comisaria: "Comisaría 1ª - Centro",
      barrios: ["Centro", "San Bernardo", "Balcarce", "Ciudad Vieja"],
    },
    {
      zona: "Norte",
      comisaria: "Comisaría 4ª - Zona Norte",
      barrios: ["Grand Bourg", "Vicente Solá", "Castañares", "Ciudad del Milagro", "Solidaridad"],
    },
    {
      zona: "Sur",
      comisaria: "Comisaría 6ª - Zona Sur",
      barrios: ["El Huaico", "Autódromo", "Limache", "Santa Ana"],
    },
    {
      zona: "Este",
      comisaria: "Comisaría 3ª - Zona Este",
      barrios: ["Tres Cerritos", "Santa Lucía", "Grand Bourg Este"],
    },
    {
      zona: "Oeste",
      comisaria: "Comisaría 8ª - Zona Oeste",
      barrios: ["San Remo", "Portezuelo", "Villa Mitre", "Villa Soledad"],
    },
    {
      zona: "Otra / no estoy seguro",
      comisaria: "Mesa de entradas central (a reasignar por el personal)",
      barrios: [],
    },
  ],
};

// Devuelve el objeto {zona, comisaria} según la zona elegida en el formulario.
function asignarComisaria(zonaElegida) {
  const encontrada = CONFIG_COMISARIAS.zonas.find(z => z.zona === zonaElegida);
  return encontrada || CONFIG_COMISARIAS.zonas[CONFIG_COMISARIAS.zonas.length - 1];
}
