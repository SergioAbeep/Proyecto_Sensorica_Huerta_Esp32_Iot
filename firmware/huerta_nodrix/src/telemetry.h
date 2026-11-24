
#pragma once

#include "sensors.h"

/**
 * Inicializa la conexion WiFi y el cliente Nodrix.
 */
void telemetry_init();

/**
 * Gestiona los eventos de comunicacion de Nodrix.
 */
void telemetry_run();

/**
 * Publica las variables de la huerta urbana:
 * - Temperatura ambiental (°C).
 * - Humedad ambiental (% HR).
 * - Humedad del suelo (ADC).
 */
bool telemetry_publish(const SensorData& data);

/**
 * Comprueba el estado de la conexion.
 */
bool telemetry_is_connected();
