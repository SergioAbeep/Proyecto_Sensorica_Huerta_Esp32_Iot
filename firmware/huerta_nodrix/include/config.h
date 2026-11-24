#pragma once

#include <Arduino.h>

// ============================================
// Configuracion de Hardware y Sensores
// ============================================

// Sensor DHT22: temperatura y humedad ambiental
constexpr uint8_t PIN_DHT = 4;

// Sensor capacitivo HW-390: humedad del suelo
// GPIO34 pertenece al ADC1, compatible con WiFi
constexpr uint8_t PIN_SOIL = 34;

// Actuador opcional del proyecto original
constexpr uint8_t PIN_RELAY = 2;

// ============================================
// Temporizacion y Comunicacion
// ============================================

#ifndef TELEMETRY_INTERVAL_MS
constexpr unsigned long TELEMETRY_INTERVAL_MS = 5000;
#endif

constexpr unsigned long SERIAL_BAUD_RATE = 115200;

// ============================================
// Configuracion ADC de 12 bits
// ============================================

constexpr uint8_t ADC_RESOLUTION = 12;
constexpr uint16_t ADC_RAW_MAX = 4095;
constexpr float ADC_MAX_VAL = 4095.0f;

// ============================================
// Rangos fisicos del DHT22
// ============================================

// Temperatura ambiental en grados Celsius
constexpr float TEMP_MIN = -40.0f;
constexpr float TEMP_MAX = 80.0f;

// Humedad relativa ambiental en porcentaje
constexpr float HUM_MIN = 0.0f;
constexpr float HUM_MAX = 100.0f;

// ============================================
// Sensor capacitivo HW-390
// ============================================

// Rango teorico de lectura ADC
constexpr uint16_t SOIL_ADC_MIN = 0;
constexpr uint16_t SOIL_ADC_MAX = 4095;