#pragma once

#include <Arduino.h>

// Estructura individual de cada medicion
struct SensorReading
{
    uint16_t raw_adc;
    float value;
    bool valid;
    bool has_adc;
};

// Variables monitoreadas en la huerta urbana
struct SensorData
{
    SensorReading temperatura;
    SensorReading humedad;
    SensorReading humedad_suelo;
};

/**
 * Inicializa el DHT22 y configura el ADC
 * para el sensor capacitivo HW-390.
 */
void sensors_init();

/**
 * Adquiere y valida las mediciones
 * de los sensores de la huerta urbana.
 */
SensorData sensors_read();
