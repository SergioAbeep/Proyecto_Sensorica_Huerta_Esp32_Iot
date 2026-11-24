// =====================================================================
// HUERTA URBANA INTELIGENTE - ANALISIS EXPERIMENTAL DE SENSORES
// ESP32 + DHT22 + HW-390 | Scilab 6.1 o superior
// Datos fisicos del 24/11/2026. Ejecutar desde SciNotes con F5.
// El archivo debe guardarse en scilab/, junto a datos_experimentales/.
// IMPORTANTE: las condiciones del suelo son cualitativas, no % calibrados.
// =====================================================================
clear;
clc;


// 1. Rutas relativas al propio programa

base = fullfile(get_absolute_file_path("analisis_experimental.sce"), "..");

archivo = fullfile(base, "datos_experimentales", "mediciones_experimentales.csv");

referencia = fullfile(base, "datos_experimentales", "resumen_estadistico.csv");

salida = fullfile(base, "graficas");

if ~isfile(archivo) then
    error("No se encontro el CSV: " + archivo);
end

if ~isdir(salida) then
    mkdir(salida);
end


// 2. Lectura del CSV. Se omite la cabecera; columnas de texto -> NaN.
// 1 fecha, 2 prueba, 3 condicion, 4 muestra, 5 tiempo ESP32 (ms),
// 6 tiempo relativo (s), 7 temperatura (C), 8 humedad ambiente (%HR), 9 ADC.
D = csvRead(archivo, ",", ".", "double", [], [], [], 1);
if size(D, 2) <> 9 | size(D, 1) == 0 then
    error("El CSV debe tener 9 columnas y al menos una medicion.");
end
V = D(:, [2, 4, 5, 6, 7, 8, 9]);
if or(isnan(V)) | or(isinf(V)) then
    error("Existen campos numericos invalidos en las mediciones.");
end
prueba = D(:, 2);
ms = D(:, 5);
t_rel = D(:, 6);
T = D(:, 7);
HR = D(:, 8);
ADC = D(:, 9);
if or(prueba < 1 | prueba > 5 | prueba <> floor(prueba)) then
    error("Los identificadores de prueba deben ser enteros de 1 a 5.");
end
if or(ADC < 0 | ADC > 4095) then
    error("Se encontraron lecturas fuera del rango ADC de 12 bits.");
end
nombres = ["Aire"; "Tierra seca"; "Lig. humeda"; "Mod. humeda"; "Muy humeda"];
x = (1:5)';
N = zeros(5, 1); duracion = N; media = N; sigma = N;
minimo = N; maximo = N; rango = N; cv = N;
mt = N; st = N; mint = N; maxt = N;
mh = N; sh = N; minh = N; maxh = N;

// 3. Estadistica por condicion. Desviacion muestral (n-1).
function s = desv_muestral(v)
    n = size(v, "*");
    s = sqrt(sum((v - mean(v)).^2) / (n - 1));
endfunction
for k = 1:5
    idx = find(prueba == k);
    N(k) = size(idx, "*");
    if N(k) < 2 then
        error("Se necesitan al menos 2 mediciones en la prueba " + string(k));
    end
    a = ADC(idx); t = T(idx); h = HR(idx);
    duracion(k) = max(t_rel(idx)) - min(t_rel(idx));
    media(k) = mean(a); sigma(k) = desv_muestral(a);
    minimo(k) = min(a); maximo(k) = max(a);
    rango(k) = maximo(k) - minimo(k);
    cv(k) = 100 * sigma(k) / media(k);
    mt(k) = mean(t); st(k) = desv_muestral(t);
    mint(k) = min(t); maxt(k) = max(t);
    mh(k) = mean(h); sh(k) = desv_muestral(h);
    minh(k) = min(h); maxh(k) = max(h);
end
R = [N duracion media sigma minimo maximo rango cv mt st mint maxt mh sh minh maxh];
mprintf("\nHUERTA URBANA - RESULTADOS EXPERIMENTALES\n");
mprintf("Total de mediciones: %d\n\n", size(D,1));
mprintf("Condicion           n      ADC medio    SD ADC     CV(%%)    T(C)     HR(%%)\n");
for k = 1:5
    mprintf("%-18s %3d %13.2f %9.2f %9.3f %8.2f %9.2f\n", ..
        nombres(k), N(k), media(k), sigma(k), cv(k), mt(k), mh(k));
end

// Comparacion con el resumen previo, sin modificar ese archivo.
if isfile(referencia) then
    ref = csvRead(referencia, ",", ".", "double", [], [], [], 1);
    if size(ref,1) == 5 & size(ref,2) == 18 then
        if and(ref(:,1) == x) & ~or(isnan(ref(:,3:18))) then
            diferencia = max(abs(R - ref(:,3:18)));
            mprintf("\nDiferencia maxima con el resumen CSV: %.8f\n", diferencia);
            if diferencia < 0.00001 then
                mprintf("Resumen estadistico verificado.\n");
            else
                mprintf("AVISO: existen diferencias con el resumen anterior.\n");
            end
        end
    end
end
mprintf("\nReduccion ADC aire a muy humeda: %.2f %%\n", 100*(media(1)-media(5))/media(1));
mprintf("Reduccion ADC seca a muy humeda: %.2f %%\n", 100*(media(2)-media(5))/media(2));
mprintf("\nCambios entre condiciones (no son sensibilidad ADC/%% humedad):\n");
for k = 1:4
    mprintf("%s -> %s: %.2f ADC\n", nombres(k), nombres(k+1), media(k+1)-media(k));
end

// 4. Funciones graficas auxiliares
function nueva_figura(id)
    scf(id);
    clf();
    f = gcf();
    f.figure_size = [1100 700];
    f.background = color("white");
endfunction
function etiquetas_condicion(nombres)
    ax = gca();
    ax.x_ticks = tlist(["ticks", "locations", "labels"], (1:5)', nombres);
endfunction

// 5. Promedio y barras de dispersion +/- 1 desviacion muestral.
nueva_figura(101);
bar(x, media);
errbar(x, media, sigma, sigma);
xtitle("HW-390: respuesta experimental por condicion", "Condicion cualitativa del suelo", "Lectura media (ADC) +/- 1 SD");
etiquetas_condicion(nombres);
ax = gca(); ax.data_bounds = [0.5, 0; 5.5, 4095];
xgrid();
xs2png(101, fullfile(salida,"01_respuesta_hw390.png"));

// 6. Series temporales con marcadores, sin interpolar entre pruebas
// ni completar los 7 registros ausentes de la prueba 3.
// El origen temporal es la primera medicion del CSV, no el arranque.
tiempo = (ms - min(ms)) / 1000;
nueva_figura(102);
plot2d(tiempo, ADC, -4);
xtitle("HW-390: lecturas reales en el tiempo", "Tiempo desde primera muestra (s)", "Lectura ADC");
xgrid();
xs2png(102, fullfile(salida,"02_serie_suelo.png"));

nueva_figura(103);
plot2d(tiempo, T, -4);
xtitle("DHT22: temperatura ambiental", "Tiempo desde primera muestra (s)", "Temperatura (C)");
xgrid();
xs2png(103, fullfile(salida,"03_serie_temperatura.png"));

nueva_figura(104);
plot2d(tiempo, HR, -4);
xtitle("DHT22: humedad relativa ambiental", "Tiempo desde primera muestra (s)", "Humedad relativa (% HR)");
xgrid();
xs2png(104, fullfile(salida,"04_serie_humedad_ambiental.png"));

// 7. Repetibilidad a corto plazo: CV de la salida ADC.
nueva_figura(105);
bar(x, cv);
xtitle("HW-390: dispersion relativa de las mediciones", "Condicion cualitativa", "Coeficiente de variacion (%)");
etiquetas_condicion(nombres);
ax = gca(); ax.data_bounds = [0.5, 0; 5.5, 1];
xgrid();
xs2png(105, fullfile(salida,"05_repetibilidad.png"));

// 8. Distribucion 3D: conteo de lecturas ADC por condicion y clase.
// Filas: cinco condiciones. Columnas: intervalos ADC de 100 cuentas.
// Las barras vacias representan cero observaciones, no ADC cero.
bordes = 1700:100:3500;
H = zeros(5, length(bordes)-1);
for k = 1:5
    for j = 1:length(bordes)-1
        H(k,j) = size(find(prueba == k & ADC >= bordes(j) & ADC < bordes(j+1)), "*");
    end
end

// Grafica tridimensional corregida

nueva_figura(106);

// Numero de condiciones e intervalos ADC
[nCond, nIntervalos] = size(H);

// Coordenadas con escalas comparables
x3d = 0.5:1:(nCond + 0.5);
y3d = 0.5:1:(nIntervalos + 0.5);

// Generar barras tridimensionales
bar3d(list(H, x3d, y3d), ...
      theta=45, alpha=60, ...
      leg="Condicion@ADC@Numero de muestras");

// Configuracion de los ejes
ax = gca();

ax.isoview = "off";
ax.cube_scaling = "on";
ax.rotation_angles = [60, 45];

ax.data_bounds = [0.5, 0.5, 0;
                  nCond+0.5, nIntervalos+0.5, max(H)+1];

// Etiquetas del eje X
ax.x_ticks = tlist(["ticks", "locations", "labels"], ...
                   (1:nCond)', ...
                   ["Aire"; "Seca"; "Lig. humeda"; ...
                    "Mod. humeda"; "Muy humeda"]);

// Centros reales de los intervalos ADC
centros = (bordes(1:$-1) + bordes(2:$))/2;

// Seleccionar etiquetas para evitar saturacion visual
indices = 1:2:nIntervalos;

ax.y_ticks = tlist(["ticks", "locations", "labels"], ...
                   matrix(indices, -1, 1), ...
                   string(matrix(centros(indices), -1, 1)));

xtitle("Distribucion de lecturas del HW-390 por condicion");

xgrid();

// Exportar grafica corregida
xs2png(106, fullfile(salida, "06_distribucion_3d.png"));

if sum(H) <> size(D,1) then
    mprintf("AVISO: hay lecturas fuera de los intervalos de la grafica 3D.\n");
end

// 9. Comparacion de cambios de la salida entre pruebas consecutivas.
nueva_figura(107);
cambios = media(1:4) - media(2:5);
bar((1:4)', cambios);
xtitle("Reduccion ADC entre condiciones consecutivas", "Transicion entre pruebas", "Disminucion (ADC)");
ax = gca();
ax.x_ticks = tlist(["ticks","locations","labels"],(1:4)', ["1 a 2";"2 a 3";"3 a 4";"4 a 5"]);
xgrid();
xs2png(107, fullfile(salida,"07_cambios_adc.png"));

mprintf("\nAnalisis finalizado. Graficas guardadas en:\n%s\n", salida);
mprintf("El eje de condiciones es ordinal, no humedad real en porcentaje.\n");
mprintf("La exactitud del DHT22 requiere instrumentos de referencia.\n");
mprintf("La calibracion del HW-390 requiere humedad de suelo conocida.\n");
