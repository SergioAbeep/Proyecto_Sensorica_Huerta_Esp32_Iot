
#include "sensors.h"
#include "config.h"
#include <DHT.h>
#include <math.h>

// Configuracion del sensor DHT22
static DHT dht(PIN_DHT, DHT22);

// ============================================
// Lectura y validacion de sensores digitales
// ============================================

static SensorReading read_digital_sensor(
    float value,
    float min_val,
    float max_val
) {
    SensorReading reading{};

    // El DHT22 no utiliza el ADC del ESP32
    reading.raw_adc = 0;
    reading.has_adc = false;

    reading.valid = !isnan(value) &&
                    !isinf(value) &&
                    value >= min_val &&
                    value <= max_val;

    reading.value = reading.valid ? value : NAN;

    return reading;
}

// ============================================
// Lectura del sensor capacitivo HW-390
// ============================================

static SensorReading read_soil_sensor() {
    SensorReading reading{};

    reading.raw_adc = analogRead(PIN_SOIL);
    reading.has_adc = true;

    reading.valid =
        reading.raw_adc <= ADC_RAW_MAX;

    // Se conserva el valor ADC sin convertirlo
    // a porcentaje de humedad.
    reading.value = reading.valid
        ? static_cast<float>(reading.raw_adc)
        : NAN;

    return reading;
}

// ============================================
// Inicializacion de los sensores
// ============================================

void sensors_init() {

    // Inicializar DHT22
    dht.begin();

    // Configurar ADC del ESP32
    analogReadResolution(ADC_RESOLUTION);
    analogSetAttenuation(ADC_11db);

    // Entrada analogica del HW-390
    pinMode(PIN_SOIL, INPUT);
}

// ============================================
// Adquisicion de las variables de la huerta
// ============================================

SensorData sensors_read() {
    SensorData data{};

    // Lecturas del DHT22
    float temperatura = dht.readTemperature();
    float humedad = dht.readHumidity();

    // Validacion de temperatura
    data.temperatura = read_digital_sensor(
        temperatura,
        TEMP_MIN,
        TEMP_MAX
    );

    // Validacion de humedad ambiental
    data.humedad = read_digital_sensor(
        humedad,
        HUM_MIN,
        HUM_MAX
    );

    // Lectura de humedad del suelo
    data.humedad_suelo = read_soil_sensor();

    return data;
}
