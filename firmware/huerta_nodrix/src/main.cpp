
#include <Arduino.h>
#include "config.h"
#include "sensors.h"
#include "telemetry.h"

// Control del tiempo de publicacion
static unsigned long last_telemetry_time = 0;

// ============================================
// Inicializacion del sistema
// ============================================

void setup()
{

    Serial.begin(SERIAL_BAUD_RATE);

    while (!Serial && millis() < 2000)
    {
        // Espera breve para conexion serial
    }

    Serial.println();
    Serial.println(F("========================================"));
    Serial.println(F("     HUERTA URBANA INTELIGENTE"));
    Serial.println(F("       ESP32 - Telemetria IoT"));
    Serial.println(F("========================================"));

    // 1. Inicializar sensores
    sensors_init();

    Serial.println(F("[Hardware] Sensores inicializados."));
    Serial.println(F("[Hardware] DHT22: GPIO4"));
    Serial.println(F("[Hardware] HW-390: GPIO34"));
    Serial.println(F("[Hardware] ADC de 12 bits"));

    // 2. Inicializar WiFi y cliente Nodrix
    telemetry_init();

    Serial.printf(
        "[Sistema] Publicacion cada %lu segundos.\n\n",
        TELEMETRY_INTERVAL_MS / 1000UL);

    last_telemetry_time = millis();
}

// ============================================
// Funcion principal del sistema
// ============================================

void loop()
{

    // Mantener activa la comunicacion con Nodrix
    telemetry_run();

    unsigned long current_time = millis();

    // Adquisicion y publicacion periodica
    if (current_time - last_telemetry_time >= TELEMETRY_INTERVAL_MS)
    {

        last_telemetry_time = current_time;

        // Obtener las mediciones de los sensores
        SensorData data = sensors_read();

        Serial.println(F("----------------------------------------"));

        Serial.printf(
            "[Sistema] Tiempo: %lu ms\n",
            current_time);

        // Temperatura ambiental
        if (data.temperatura.valid)
        {
            Serial.printf(
                "Temperatura: %.1f °C\n",
                data.temperatura.value);
        }
        else
        {
            Serial.println(F("Temperatura: [INVALIDA]"));
        }

        // Humedad relativa ambiental
        if (data.humedad.valid)
        {
            Serial.printf(
                "Humedad ambiental: %.1f %% HR\n",
                data.humedad.value);
        }
        else
        {
            Serial.println(F("Humedad ambiental: [INVALIDA]"));
        }

        // Humedad del suelo
        if (data.humedad_suelo.valid)
        {
            Serial.printf(
                "Humedad del suelo: %u ADC\n",
                static_cast<unsigned int>(
                    data.humedad_suelo.raw_adc));
        }
        else
        {
            Serial.println(F("Humedad del suelo: [INVALIDA]"));
        }

        Serial.println(F("----------------------------------------"));

        // Enviar mediciones hacia Nodrix
        telemetry_publish(data);
    }
}
