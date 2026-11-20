// =====================================================================
//  CURVAS CARACTERÍSTICAS DE LOS SENSORES DHT22 Y CAPACITIVO V2
//  Proyecto: monitoreo de una huerta urbana con ESP32
//  Lenguaje: Scilab 6.x o superior (abrir/guardar el archivo en UTF-8)
// ---------------------------------------------------------------------
//  AVISO IMPORTANTE
//   * Por defecto se usan DATOS SIMULADOS con modelos HIPOTÉTICOS. No son
//     mediciones, ni una calibración real, ni características garantizadas.
//   * La respuesta de un sensor capacitivo "V2" depende de la versión del
//     módulo, de la alimentación, del tipo de suelo y de las condiciones de
//     medición. No debe asumirse que todos los módulos se comportan igual.
//   * La humedad del suelo calibrada con dos puntos (seco/húmedo) es una
//     ESCALA RELATIVA, no un contenido físico de agua, salvo que exista una
//     referencia experimental (por ejemplo, pesada y secado en horno).
//   * ESPEC_T y ESPEC_HR son valores típicos de hoja de datos del DHT22 y
//     deben verificarse con el documento del fabricante.
//   * Este programa SIMULA, MODELA y ANALIZA datos; no mide en tiempo real.
//
//  USO: abrir en SciNotes y ejecutar (F5), o en la consola:
//       exec("curvas_sensores_DHT22_capacitivoV2.sce", -1)
// =====================================================================

clear; clc;
if ~isempty(winsid()) then xdel(winsid()); end

// =====================================================================
// SECCIÓN 0. FUNCIONES AUXILIARES
// =====================================================================

// ---- Evalúa un polinomio con coeficientes en orden ascendente [c0 c1 c2 ...]
function y = evalpol(c, x)
    y = zeros(x);
    for k = 1:size(c, "*")
        y = y + c(k) * x.^(k - 1);
    end
endfunction

// ---- Respuesta ("sí"/"no") para imprimir booleanos
function s = sino(b)
    if b then s = "sí"; else s = "no"; end
endfunction

// ---- Validación de un par de vectores (evita divisiones por cero y NaN)
function validar_par(nombre, x, y)
    if isempty(x) | isempty(y) then
        error(nombre + ": hay vectores vacíos. Revise la sección 2.");
    end
    if size(x, "*") <> size(y, "*") then
        error(nombre + ": referencia y lectura deben tener el mismo tamaño.");
    end
    if size(x, "*") < 5 then
        error(nombre + ": se requieren al menos 5 puntos para comparar modelos.");
    end
    if or(isnan(x)) | or(isnan(y)) | or(isinf(x)) | or(isinf(y)) then
        error(nombre + ": hay valores NaN o infinitos.");
    end
    if max(x) - min(x) < 1e-9 then
        error(nombre + ": la variable de referencia no varía (división por cero).");
    end
    if max(y) - min(y) < 1e-9 then
        error(nombre + ": la salida del sensor es constante; no se puede ajustar.");
    end
endfunction

// ---- Ajuste por mínimos cuadrados: lineal (grado 1) y cuadrático (grado 2)
//      El modelo cuadrático solo se adopta si cumple VARIOS criterios; no se
//      elige únicamente por tener un R2 mayor (el R2 siempre aumenta al subir
//      el grado del polinomio).
function r = ajustar(x, y)
    x = x(:); y = y(:); n = size(x, "*");

    // Modelo lineal: y = c1(1) + c1(2)*x
    A1  = [ones(n, 1), x];
    c1  = A1 \ y;                          // "\" resuelve mínimos cuadrados
    yh1 = A1 * c1;
    // Modelo cuadrático: y = c2(1) + c2(2)*x + c2(3)*x^2
    A2  = [ones(n, 1), x, x.^2];
    c2  = A2 \ y;
    yh2 = A2 * c2;

    sst  = sum((y - mean(y)).^2);          // > 0 garantizado por validar_par
    sse1 = max(sum((y - yh1).^2), 1e-12);
    sse2 = max(sum((y - yh2).^2), 1e-12);
    R2_1  = 1 - sse1 / sst;
    R2_2  = 1 - sse2 / sst;
    R2a_1 = 1 - (1 - R2_1) * (n - 1) / (n - 2);
    R2a_2 = 1 - (1 - R2_2) * (n - 1) / (n - 3);
    mse1  = sse1 / n;
    mse2  = sse2 / n;
    aic1  = n * log(sse1 / n) + 2 * 2;     // criterio de Akaike (2 parámetros)
    aic2  = n * log(sse2 / n) + 2 * 3;     // criterio de Akaike (3 parámetros)

    // Significancia del término cuadrático (estadístico t aproximado)
    s2  = sse2 / (n - 3);
    cv  = s2 * inv(A2' * A2);
    se3 = sqrt(abs(cv(3, 3)));
    if se3 > 0 then t3 = c2(3) / se3; else t3 = 0; end

    // Monotonía del modelo cuadrático dentro del rango de datos
    d1   = c2(2) + 2 * c2(3) * min(x);
    d2   = c2(2) + 2 * c2(3) * max(x);
    mono = (d1 * d2 > 0);

    // Estructura de los residuos lineales (cambios de signo)
    sg      = sign(y - yh1);
    cambios = sum(bool2s(sg(1:n-1) .* sg(2:n) < 0));

    // Regla de decisión
    usar2 = ((aic1 - aic2) > 2) & (abs(t3) > 2) & mono & (n >= 6);
    if usar2 then
        sel = 2; yhs = yh2; csel = c2; R2s = R2_2; mses = mse2;
    else
        sel = 1; yhs = yh1; csel = c1; R2s = R2_1; mses = mse1;
    end

    r = tlist(["ajuste", "n", "c1", "yh1", "R2_1", "R2a_1", "mse1", "aic1", ..
               "c2", "yh2", "R2_2", "R2a_2", "mse2", "aic2", "t3", "mono", ..
               "cambios", "sel", "yhs", "csel", "R2s", "mses"], ..
               n, c1, yh1, R2_1, R2a_1, mse1, aic1, ..
               c2, yh2, R2_2, R2a_2, mse2, aic2, t3, mono, ..
               cambios, sel, yhs, csel, R2s, mses);
endfunction

// ---- Convierte coeficientes (orden ascendente) en texto de ecuación
function s = txt_ecuacion(c, nx, ny)
    s = ny + " = ";
    n = size(c, "*");
    for k = n:-1:1
        coef = c(k); pot = k - 1;
        if k < n then
            if coef < 0 then s = s + " - "; else s = s + " + "; end
            coef = abs(coef);
        elseif coef < 0 then
            s = s + "-"; coef = abs(coef);
        end
        t = msprintf("%.5g", coef);
        if pot == 0 then
            s = s + t;
        elseif pot == 1 then
            s = s + t + "*" + nx;
        else
            s = s + t + "*" + nx + "^" + string(pot);
        end
    end
endfunction

// ---- Muestra ecuaciones, indicadores y justificación del modelo adoptado
function mostrar_ajuste(titulo, r, nx, ny)
    mprintf("\n--- %s ---\n", titulo);
    mprintf("Modelo lineal     : %s\n", txt_ecuacion(r.c1, nx, ny));
    mprintf("   R2 = %.5f | R2 ajustado = %.5f | MSE = %.5g | RMSE = %.5g | AIC = %.2f\n", ..
            r.R2_1, r.R2a_1, r.mse1, sqrt(r.mse1), r.aic1);
    mprintf("Modelo cuadrático : %s\n", txt_ecuacion(r.c2, nx, ny));
    mprintf("   R2 = %.5f | R2 ajustado = %.5f | MSE = %.5g | RMSE = %.5g | AIC = %.2f\n", ..
            r.R2_2, r.R2a_2, r.mse2, sqrt(r.mse2), r.aic2);
    mprintf("Criterios para aceptar el término cuadrático (deben cumplirse todos):\n");
    mprintf("   a) Mejora de AIC (AIC_lineal - AIC_cuadrático) = %.2f  (se exige > 2): %s\n", ..
            r.aic1 - r.aic2, sino((r.aic1 - r.aic2) > 2));
    mprintf("   b) Estadístico t del coeficiente cuadrático    = %.2f  (se exige |t| > 2): %s\n", ..
            r.t3, sino(abs(r.t3) > 2));
    mprintf("   c) Modelo cuadrático monótono en el rango      : %s\n", sino(r.mono));
    mprintf("   d) Cambios de signo de los residuos lineales   = %d de %d posibles (informativo)\n", ..
            r.cambios, r.n - 1);
    if r.sel == 2 then
        mprintf("MODELO ADOPTADO: CUADRÁTICO. Hay curvatura estadísticamente apreciable; el R2\n");
        mprintf("   no fue el único criterio de decisión.\n");
    else
        mprintf("MODELO ADOPTADO: LINEAL (principio de parsimonia). El término cuadrático no\n");
        mprintf("   cumple todos los criterios, aunque su R2 sea algo mayor.\n");
    end
endfunction

// ---- Errores: e = val - ref; ea = |e|; ep = |e|/|ref|*100 (NaN si |ref| < umbral)
function [e, ea, ep] = calc_errores(val, ref, umbral)
    val = val(:); ref = ref(:);
    e   = val - ref;
    ea  = abs(e);
    ep  = %nan * ones(e);
    idx = find(abs(ref) >= umbral);
    if ~isempty(idx) then ep(idx) = ea(idx) ./ abs(ref(idx)) * 100; end
endfunction

// ---- Resumen de errores (incluye MSE y RMSE)
function resumen_errores(titulo, e, ea, ep, ud)
    idx = find(~isnan(ep));
    if isempty(idx) then epm = %nan; else epm = mean(ep(idx)); end
    mse = mean(e.^2);
    mprintf("\n--- %s ---\n", titulo);
    mprintf("Error medio (sesgo)        : %+.4f %s\n", mean(e), ud);
    mprintf("Error absoluto medio       : %.4f %s\n", mean(ea), ud);
    mprintf("Error absoluto máximo      : %.4f %s\n", max(ea), ud);
    mprintf("Error porcentual medio     : %.4f %%  (solo donde |ref| supera el umbral)\n", epm);
    mprintf("MSE                        : %.5g (%s)^2\n", mse, ud);
    mprintf("RMSE                       : %.4f %s\n", sqrt(mse), ud);
    mprintf("Desviación estándar        : %.4f %s\n", stdev(e), ud);
endfunction

// ---- Sensibilidad local S(x) = dy/dx del modelo adoptado
function s = sens_local(c, x)
    if size(c, "*") == 3 then
        s = c(2) + 2 * c(3) * x;
    else
        s = c(2) * ones(x);
    end
endfunction

// ---- Calibración de dos puntos: ADC -> humedad RELATIVA (0 % seco, 100 % húmedo)
//      Es una escala relativa; no es contenido físico de agua sin referencia.
function H = calibrar_humedad(adc, adc_seco, adc_humedo)
    if abs(adc_seco - adc_humedo) < 1e-9 then
        error("Calibración inválida: ADC_seco y ADC_húmedo no pueden ser iguales.");
    end
    H = (adc_seco - adc) ./ (adc_seco - adc_humedo) * 100;
    H(H < 0)   = 0;      // se limita al intervalo de la escala relativa
    H(H > 100) = 100;
endfunction

// ---- Tabla del sensor capacitivo (datos vs modelos)
function tabla_cap(h, adc, y1, y2, ys)
    mprintf("\n%3s %9s %9s %10s %10s %10s %9s %9s\n", "N", "H_ref(%)", "ADC", "ADC_lin", ..
            "ADC_cuad", "ADC_adopt", "Err_abs", "Err_%");
    for i = 1:size(h, "*")
        ea = abs(ys(i) - adc(i));
        if abs(adc(i)) > 1e-9 then ep = ea / abs(adc(i)) * 100; else ep = %nan; end
        mprintf("%3d %9.1f %9.0f %10.1f %10.1f %10.1f %9.2f %9.2f\n", i, h(i), adc(i), ..
                y1(i), y2(i), ys(i), ea, ep);
    end
    mprintf("(Err_abs y Err_%% = modelo adoptado frente al dato; Err_%% referido al dato ADC)\n");
endfunction

// ---- Tabla del DHT22 (referencia vs indicado vs ideal vs modelo)
function tabla_dht(ref, ind, ym, ud)
    mprintf("\n%3s %10s %10s %10s %10s %10s %10s\n", "N", "Referencia", "Indicado", "Ideal", ..
            "Modelo", "Error", "Err_%");
    for i = 1:size(ref, "*")
        e = ind(i) - ref(i);
        if abs(ref(i)) >= 1 then ep = abs(e) / abs(ref(i)) * 100; else ep = %nan; end
        mprintf("%3d %10.1f %10.1f %10.1f %10.2f %+10.2f %10.2f\n", i, ref(i), ind(i), ref(i), ..
                ym(i), e, ep);
    end
    mprintf("(Unidades: %s | Error = Indicado - Referencia | Err_%% no definido si |Ref| < 1)\n", ud);
endfunction

// ---- Gráfica principal de una curva característica
function graf_curva(win, tit, x, y, r, xl, yl, ideal, lbl)
    scf(win); clf();
    xx = linspace(min(x), max(x), 200)';
    plot(x, y, "bo");
    plot(xx, evalpol(r.csel, xx), "r-");
    if r.sel == 2 then etiq = "Modelo cuadrático adoptado"; else etiq = "Modelo lineal adoptado"; end
    if ideal then
        plot(xx, xx, "k--");
        legend([lbl; etiq; "Respuesta ideal (y = x)"], 2);
    else
        legend([lbl; etiq], 1);
    end
    xgrid();
    xtitle(tit, xl, yl);
endfunction

// ---- Comparación datos / modelos / calibración de dos puntos (capacitivo)
function graf_comp_cap(win, tit, h, adc, r, adc_seco, adc_hum, lbl)
    scf(win); clf();
    xx = linspace(min(h), max(h), 200)';
    plot(h, adc, "bo");
    plot(xx, r.c1(1) + r.c1(2) * xx, "r-");
    plot(xx, r.c2(1) + r.c2(2) * xx + r.c2(3) * xx.^2, "g--");
    plot([min(h) max(h)], [adc_seco adc_hum], "m-.");
    xgrid();
    xtitle(tit, "Humedad del suelo (%) [escala de referencia]", "Lectura ADC del ESP32 (cuentas, 12 bits)");
    legend([lbl; "Modelo lineal"; "Modelo cuadrático"; "Recta de calibración de 2 puntos"], 1);
endfunction

// ---- Comparación referencia / indicado / ideal (DHT22)
function graf_comp_dht(win, tit, ref, ind, r, espec, xl, yl, lbl)
    scf(win); clf();
    xx = linspace(min(ref), max(ref), 200)';
    plot(xx, xx, "k--");
    plot(xx, xx + espec, "k:");
    plot(xx, xx - espec, "k:");
    plot(ref, ind, "bo");
    plot(xx, evalpol(r.csel, xx), "r-");
    xgrid();
    xtitle(tit, xl, yl);
    legend(["Referencia = respuesta ideal (y = x)"; "Ideal + banda típica (verificar)"; ..
            "Ideal - banda típica (verificar)"; lbl; "Modelo adoptado"], 2);
endfunction

// =====================================================================
// SECCIÓN 1. CONFIGURACIÓN GENERAL
// =====================================================================
USAR_DATOS_SIMULADOS = %t;   // %t: datos simulados | %f: datos reales (sección 2)

// ESP32 clásico: ADC de 12 bits, lecturas de 0 a 4095.
// La relación voltaje <-> ADC depende de la atenuación configurada
// (p. ej. analogSetPinAttenuation(pin, ADC_11db)), de la calibración del
// chip y de la no linealidad del ADC, sobre todo cerca de los extremos.
// VREF_NOM solo sirve para dar un orden de magnitud en mV; para voltajes
// reales conviene usar analogReadMilliVolts() en el firmware.
ADC_BITS = 12;
ADC_MAX  = 2^ADC_BITS - 1;   // 4095
VREF_NOM = 3.3;              // V, valor nominal (no es una medición)

// Valores típicos de hoja de datos del DHT22 (VERIFICAR con el fabricante)
ESPEC_T  = 0.5;              // °C
ESPEC_HR = 2.0;              // %HR (típico; puede llegar a ±5 %HR)

// Puntos de calibración del capacitivo (dejar [] para tomarlos de los datos:
// ADC en la humedad mínima = "seco" y en la máxima = "húmedo")
ADC_SECO_CAL = [];
ADC_HUM_CAL  = [];

// =====================================================================
// SECCIÓN 2. DATOS DE ENTRADA (MODIFICAR AQUÍ)
//   Variables diferenciadas:
//     hum_suelo                  -> humedad del SUELO (%)
//     adc_cap                    -> lectura ADC del capacitivo (cuentas)
//     T_aire_ref / T_aire_ind    -> temperatura del AIRE (°C)
//     HR_aire_ref / HR_aire_ind  -> humedad RELATIVA del AIRE (%HR)
// =====================================================================
if USAR_DATOS_SIMULADOS then
    ORIGEN = "DATOS SIMULADOS (HIPOTÉTICOS)";
    grand("setsd", 2026);                       // semilla fija: resultados reproducibles

    // ---- Capacitivo V2: modelo hipotético. El ADC disminuye al aumentar la
    //      humedad, con respuesta curva y ruido. Los valores extremos
    //      (2800 y 1300) son ilustrativos y NO representan una calibración real.
    hum_suelo = (0:10:100)';                    // % (escala de referencia hipotética)
    ADC_S_SIM = 2800;  ADC_H_SIM = 1300;  K_SIM = 1.2;
    f_resp    = (exp(-K_SIM * hum_suelo / 100) - exp(-K_SIM)) / (1 - exp(-K_SIM));
    adc_cap   = round(ADC_H_SIM + (ADC_S_SIM - ADC_H_SIM) * f_resp ..
                      + grand(size(hum_suelo, 1), 1, "nor", 0, 15));
    adc_cap(adc_cap < 0)       = 0;
    adc_cap(adc_cap > ADC_MAX) = ADC_MAX;

    // ---- DHT22 temperatura: error hipotético de ganancia, offset y ruido
    T_aire_ref = (-10:5:50)';                   // °C (termómetro de referencia)
    T_aire_ind = 1.004 * T_aire_ref + 0.15 + grand(size(T_aire_ref, 1), 1, "nor", 0, 0.15);
    T_aire_ind = round(T_aire_ind * 10) / 10;   // resolución digital de 0,1 °C

    // ---- DHT22 humedad relativa: desviación hipotética ligeramente curva y ruido
    HR_aire_ref = (0:10:100)';                  // %HR (higrómetro de referencia)
    delta_hr    = 0.8 + 0.005 * (HR_aire_ref - 50) - 0.0004 * (HR_aire_ref - 50).^2;
    HR_aire_ind = HR_aire_ref + delta_hr + grand(size(HR_aire_ref, 1), 1, "nor", 0, 0.4);
    HR_aire_ind(HR_aire_ind < 0)   = 0;
    HR_aire_ind(HR_aire_ind > 100) = 100;
    HR_aire_ind = round(HR_aire_ind * 10) / 10;
else
    ORIGEN = "DATOS EXPERIMENTALES";
    // Reemplace los corchetes por sus mediciones (vectores del mismo tamaño):
    hum_suelo   = [];   // % de humedad del suelo (referencia: pesada/secado, o escala relativa)
    adc_cap     = [];   // lectura ADC promedio del capacitivo en cada nivel
    T_aire_ref  = [];   // °C del termómetro de referencia
    T_aire_ind  = [];   // °C indicados por el DHT22
    HR_aire_ref = [];   // %HR del higrómetro de referencia
    HR_aire_ind = [];   // %HR indicada por el DHT22
end

hum_suelo = hum_suelo(:);     adc_cap     = adc_cap(:);
T_aire_ref = T_aire_ref(:);   T_aire_ind  = T_aire_ind(:);
HR_aire_ref = HR_aire_ref(:); HR_aire_ind = HR_aire_ind(:);

validar_par("Capacitivo V2 (humedad del suelo vs ADC)", hum_suelo, adc_cap);
validar_par("DHT22 temperatura", T_aire_ref, T_aire_ind);
validar_par("DHT22 humedad relativa", HR_aire_ref, HR_aire_ind);

// Puntos de calibración (seco / húmedo)
if isempty(ADC_SECO_CAL) then
    [vv, i0] = min(hum_suelo);  ADC_SECO_CAL = adc_cap(i0);
end
if isempty(ADC_HUM_CAL) then
    [vv, i1] = max(hum_suelo);  ADC_HUM_CAL = adc_cap(i1);
end

mprintf("\n=====================================================================\n");
mprintf(" CURVAS CARACTERÍSTICAS DHT22 Y CAPACITIVO V2  |  %s\n", ORIGEN);
mprintf(" ESP32: ADC de %d bits (0-%d) | LSB nominal = %.3f mV (Vref nominal %.1f V)\n", ..
        ADC_BITS, ADC_MAX, VREF_NOM / ADC_MAX * 1000, VREF_NOM);
if USAR_DATOS_SIMULADOS then
    mprintf(" AVISO: datos hipotéticos. No son mediciones ni calibraciones reales.\n");
end
mprintf("=====================================================================\n");

// =====================================================================
// SECCIÓN 3. SENSOR CAPACITIVO V2: HUMEDAD DEL SUELO vs ADC
// =====================================================================
rC = ajustar(hum_suelo, adc_cap);

mprintf("\n######## A. CAPACITIVO V2 - HUMEDAD DEL SUELO (%s) ########", ORIGEN);
tabla_cap(hum_suelo, adc_cap, rC.yh1, rC.yh2, rC.yhs);
mostrar_ajuste("Capacitivo V2: ADC = f(humedad del suelo)", rC, "H", "ADC");

// Errores del ajuste (modelo adoptado frente al dato)
[eC, eaC, epC] = calc_errores(rC.yhs, adc_cap, 1e-9);
resumen_errores("Errores del ajuste adoptado (modelo - dato)", eC, eaC, epC, "cuentas");

// Pendiente, sensibilidad y linealidad
pendC  = rC.c1(2);
FS_C   = max(adc_cap) - min(adc_cap);
nolinC = max(abs(adc_cap - rC.yh1)) / FS_C * 100;
mprintf("\nPendiente del modelo lineal : m = %.4f cuentas/%%\n", pendC);
mprintf("Sensibilidad media          : |S| = %.4f cuentas/%%  (orden de magnitud: %.3f mV/%% con Vref nominal)\n", ..
        abs(pendC), abs(pendC) * VREF_NOM / ADC_MAX * 1000);
if pendC < 0 then
    mprintf("Sentido de variación        : el ADC DISMINUYE al aumentar la humedad.\n");
else
    mprintf("Sentido de variación        : el ADC AUMENTA al aumentar la humedad.\n");
end
mprintf("No linealidad máxima        : %.2f %% de la excursión del ADC (%.0f cuentas)\n", nolinC, FS_C);
xs = min(hum_suelo) + [0.1 0.5 0.9] * (max(hum_suelo) - min(hum_suelo));
Sl = sens_local(rC.csel, xs);
mprintf("Sensibilidad local del modelo adoptado (cuentas/%%):\n");
for k = 1:3
    mprintf("   a H = %5.1f %% -> S = %9.4f\n", xs(k), Sl(k));
end
mprintf("Nota: si la sensibilidad local cambia mucho, la escala de dos puntos pierde exactitud.\n");

// Calibración de dos puntos -> escala RELATIVA de humedad
H_rel = calibrar_humedad(adc_cap, ADC_SECO_CAL, ADC_HUM_CAL);
mprintf("\n--- Calibración de dos puntos (ESCALA RELATIVA 0-100 %%, no contenido físico de agua) ---\n");
mprintf("ADC_seco = %.1f | ADC_húmedo = %.1f\n", ADC_SECO_CAL, ADC_HUM_CAL);
mprintf("H_rel(%%) = (ADC_seco - ADC) / (ADC_seco - ADC_húmedo) * 100  (limitada a 0-100)\n");
mprintf("\n%3s %10s %8s %12s %12s\n", "N", "H_ref(%)", "ADC", "H_rel(%)", "H_rel-H_ref");
for i = 1:size(hum_suelo, "*")
    mprintf("%3d %10.1f %8.0f %12.2f %+12.2f\n", i, hum_suelo(i), adc_cap(i), H_rel(i), H_rel(i) - hum_suelo(i));
end
mprintf("Diferencia máxima entre la escala de 2 puntos y la referencia: %.2f puntos porcentuales\n", ..
        max(abs(H_rel - hum_suelo)));
if USAR_DATOS_SIMULADOS then
    mprintf("NOTA: calibración obtenida con datos simulados; NO debe cargarse en el firmware.\n");
end

graf_curva(1, "Curva característica del capacitivo V2 (" + ORIGEN + ")", hum_suelo, adc_cap, rC, ..
           "Humedad del suelo (%)", "Lectura ADC del ESP32 (cuentas)", %f, "Datos del sensor");

// =====================================================================
// SECCIÓN 4. DHT22: TEMPERATURA DEL AIRE (referencia vs indicada)
//   El DHT22 entrega el dato ya digital: no hay conversión ADC externa.
// =====================================================================
rT = ajustar(T_aire_ref, T_aire_ind);

mprintf("\n\n######## B. DHT22 - TEMPERATURA DEL AIRE (%s) ########", ORIGEN);
tabla_dht(T_aire_ref, T_aire_ind, rT.yhs, "°C");
mostrar_ajuste("DHT22: T_indicada = f(T_referencia)", rT, "Tref", "Tind");

[eT, eaT, epT] = calc_errores(T_aire_ind, T_aire_ref, 1);
resumen_errores("Error del sensor en temperatura (indicado - referencia)", eT, eaT, epT, "°C");

pendT  = rT.c1(2);
nolinT = max(abs(T_aire_ind - rT.yh1)) / (max(T_aire_ind) - min(T_aire_ind)) * 100;
mprintf("\nPendiente (modelo lineal)   : m = %.5f °C/°C (ideal = 1)\n", pendT);
mprintf("Intercepto (offset)         : b = %+.4f °C (ideal = 0)\n", rT.c1(1));
mprintf("Sensibilidad                : S = %.5f °C indicados por °C de referencia (adimensional)\n", pendT);
mprintf("Error de ganancia           : %+.3f %% respecto a la respuesta ideal\n", (pendT - 1) * 100);
mprintf("No linealidad máxima        : %.3f %% de la excursión ensayada\n", nolinT);
mprintf("Puntos con |error| <= %.2f °C (valor típico de hoja de datos, verificar): %d de %d\n", ..
        ESPEC_T, length(find(eaT <= ESPEC_T)), size(eaT, "*"));
if abs(pendT) > 1e-9 then
    mprintf("Corrección lineal sugerida  : Tcorr = (Tind - (%.4f)) / %.5f\n", rT.c1(1), pendT);
end

graf_curva(2, "Curva característica del DHT22: temperatura (" + ORIGEN + ")", T_aire_ref, T_aire_ind, rT, ..
           "Temperatura de referencia (°C)", "Temperatura indicada por el DHT22 (°C)", %t, "Datos del DHT22");

// =====================================================================
// SECCIÓN 5. DHT22: HUMEDAD RELATIVA DEL AIRE (referencia vs indicada)
//   No confundir con la humedad del SUELO de la sección 3.
// =====================================================================
rH = ajustar(HR_aire_ref, HR_aire_ind);

mprintf("\n\n######## C. DHT22 - HUMEDAD RELATIVA DEL AIRE (%s) ########", ORIGEN);
tabla_dht(HR_aire_ref, HR_aire_ind, rH.yhs, "%HR");
mostrar_ajuste("DHT22: HR_indicada = f(HR_referencia)", rH, "HRref", "HRind");

[eH, eaH, epH] = calc_errores(HR_aire_ind, HR_aire_ref, 1);
resumen_errores("Error del sensor en humedad relativa (indicado - referencia)", eH, eaH, epH, "%HR");

pendH  = rH.c1(2);
nolinH = max(abs(HR_aire_ind - rH.yh1)) / (max(HR_aire_ind) - min(HR_aire_ind)) * 100;
mprintf("\nPendiente (modelo lineal)   : m = %.5f %%HR/%%HR (ideal = 1)\n", pendH);
mprintf("Intercepto (offset)         : b = %+.4f %%HR (ideal = 0)\n", rH.c1(1));
mprintf("Sensibilidad                : S = %.5f %%HR indicado por %%HR de referencia (adimensional)\n", pendH);
mprintf("Error de ganancia           : %+.3f %% respecto a la respuesta ideal\n", (pendH - 1) * 100);
mprintf("No linealidad máxima        : %.3f %% de la excursión ensayada\n", nolinH);
mprintf("Puntos con |error| <= %.2f %%HR (valor típico de hoja de datos, verificar): %d de %d\n", ..
        ESPEC_HR, length(find(eaH <= ESPEC_HR)), size(eaH, "*"));
if abs(pendH) > 1e-9 then
    mprintf("Corrección lineal sugerida  : HRcorr = (HRind - (%.4f)) / %.5f\n", rH.c1(1), pendH);
end

graf_curva(3, "Curva característica del DHT22: humedad relativa del aire (" + ORIGEN + ")", ..
           HR_aire_ref, HR_aire_ind, rH, "Humedad relativa de referencia (%HR)", ..
           "Humedad relativa indicada por el DHT22 (%HR)", %t, "Datos del DHT22");

// =====================================================================
// SECCIÓN 6. GRÁFICAS ADICIONALES (ventanas 4 a 7)
// =====================================================================
// 4) Capacitivo: datos, modelos y calibración de dos puntos
graf_comp_cap(4, "Capacitivo V2: datos vs modelos (" + ORIGEN + ")", hum_suelo, adc_cap, rC, ..
              ADC_SECO_CAL, ADC_HUM_CAL, "Datos del sensor");

// 5) DHT22 temperatura: referencia, indicada e ideal
graf_comp_dht(5, "DHT22 temperatura: referencia, indicada e ideal (" + ORIGEN + ")", T_aire_ref, ..
              T_aire_ind, rT, ESPEC_T, "Temperatura de referencia (°C)", ..
              "Temperatura (°C)", "Indicada por el DHT22");

// 6) DHT22 humedad relativa: referencia, indicada e ideal
graf_comp_dht(6, "DHT22 humedad relativa: referencia, indicada e ideal (" + ORIGEN + ")", HR_aire_ref, ..
              HR_aire_ind, rH, ESPEC_HR, "Humedad relativa de referencia (%HR)", ..
              "Humedad relativa (%HR)", "Indicada por el DHT22");

// 7) Errores y residuos de cada modelo
scf(7); clf();
subplot(3, 1, 1);
plot([min(hum_suelo) max(hum_suelo)], [0 0], "k-");
plot(hum_suelo, adc_cap - rC.yh1, "bo-");
plot(hum_suelo, adc_cap - rC.yh2, "gs--");
xgrid();
xtitle("Residuos de los modelos del capacitivo V2", "Humedad del suelo (%)", "Residuo (cuentas ADC)");
legend(["Cero"; "Residuo modelo lineal"; "Residuo modelo cuadrático"], 1);

subplot(3, 1, 2);
plot([min(T_aire_ref) max(T_aire_ref)], [0 0], "k-");
plot(T_aire_ref, T_aire_ind - T_aire_ref, "bo-");
plot(T_aire_ref, T_aire_ind - rT.yh1, "gs--");
plot([min(T_aire_ref) max(T_aire_ref)], [ESPEC_T ESPEC_T], "r:");
plot([min(T_aire_ref) max(T_aire_ref)], [-ESPEC_T -ESPEC_T], "r:");
xgrid();
xtitle("Errores del DHT22: temperatura", "Temperatura de referencia (°C)", "Error (°C)");
legend(["Cero"; "Error del sensor (ind - ref)"; "Residuo del ajuste lineal"; ..
        "+ banda típica (verificar)"; "- banda típica (verificar)"], 1);

subplot(3, 1, 3);
plot([min(HR_aire_ref) max(HR_aire_ref)], [0 0], "k-");
plot(HR_aire_ref, HR_aire_ind - HR_aire_ref, "bo-");
plot(HR_aire_ref, HR_aire_ind - rH.yh1, "gs--");
plot([min(HR_aire_ref) max(HR_aire_ref)], [ESPEC_HR ESPEC_HR], "r:");
plot([min(HR_aire_ref) max(HR_aire_ref)], [-ESPEC_HR -ESPEC_HR], "r:");
xgrid();
xtitle("Errores del DHT22: humedad relativa del aire", "Humedad relativa de referencia (%HR)", "Error (%HR)");
legend(["Cero"; "Error del sensor (ind - ref)"; "Residuo del ajuste lineal"; ..
        "+ banda típica (verificar)"; "- banda típica (verificar)"], 1);

// =====================================================================
// SECCIÓN 7. RESUMEN E INTERPRETACIÓN
// =====================================================================
mprintf("\n\n==================== RESUMEN DE RESULTADOS (%s) ====================\n", ORIGEN);
mprintf("%-34s %-11s %12s %10s %12s\n", "Variable", "Modelo", "Pendiente", "R2", "RMSE");
nm = ["Lineal", "Cuadrático"];
mprintf("%-34s %-11s %12.5f %10.5f %12.4f\n", "Suelo: ADC vs humedad (cuentas)", nm(rC.sel), rC.c1(2), rC.R2s, sqrt(rC.mses));
mprintf("%-34s %-11s %12.5f %10.5f %12.4f\n", "Aire: T indicada vs ref (°C)", nm(rT.sel), rT.c1(2), rT.R2s, sqrt(rT.mses));
mprintf("%-34s %-11s %12.5f %10.5f %12.4f\n", "Aire: HR indicada vs ref (%HR)", nm(rH.sel), rH.c1(2), rH.R2s, sqrt(rH.mses));
mprintf("(Pendiente = del modelo lineal. R2 y RMSE = del modelo adoptado, en las unidades de cada fila.)\n");

mprintf("\nINTERPRETACIÓN\n");
mprintf("1) Capacitivo V2: la curva relaciona humedad del suelo con cuentas ADC. Su forma,\n");
mprintf("   pendiente y rango dependen del módulo, la alimentación y el suelo; estos\n");
mprintf("   números describen el procedimiento de análisis, no una calibración real.\n");
mprintf("2) Escala de dos puntos: es una escala RELATIVA. Si la curva es no lineal, la\n");
mprintf("   escala relativa se aparta de la humedad de referencia (ver tabla de calibración).\n");
mprintf("3) DHT22: la pendiente cercana a 1 y el offset cercano a 0 indican una respuesta\n");
mprintf("   próxima a la ideal; el desvío se corrige con la ecuación sugerida.\n");
mprintf("4) La temperatura y la humedad relativa del AIRE son variables distintas de la\n");
mprintf("   humedad del SUELO y no deben mezclarse en un mismo análisis.\n");
mprintf("5) Esta curva de calibración (referencia vs indicado) NO es una gráfica de la\n");
mprintf("   variación de la temperatura o la humedad en función del tiempo.\n");
if USAR_DATOS_SIMULADOS then
    mprintf("6) AVISO: los resultados de esta ejecución provienen de datos simulados.\n");
    mprintf("   Repita el análisis con mediciones reales antes de usar los modelos.\n");
end
mprintf("=====================================================================\n");
