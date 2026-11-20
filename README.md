# Monitoreo de Huerta Urbana con ESP32

## Descripción del proyecto

Sistema académico de monitoreo de huerta urbana basado en un microcontrolador ESP32 y dos sensores: DHT22 para temperatura y humedad ambiental, y sensor capacitivo V2.0.0 HW-390 para humedad del suelo.

El proyecto incluye adquisición de datos y análisis matemático en Scilab. Se encuentra en desarrollo la integración cliente-servidor mediante MQTT y un dashboard.

## Componentes

- ESP32 Dev Module de 30 pines.
- DHT22 de tres pines.
- Sensor capacitivo de humedad del suelo V2.0.0 HW-390.
- Protoboard y cables.
- Computador con Arduino IDE y Scilab.

## Organización del repositorio

- `firmware/`: código de Arduino IDE.
- `scilab/`: análisis matemático de los sensores.
- `datos/`: mediciones experimentales.
- `docs/`: documentación técnica.
- `mqtt/`: comunicación cliente-servidor (pendiente).
- `dashboard/`: visualización de datos (pendiente).

## Instrucciones de uso del ESP32

1. Instalar Arduino IDE.
2. Instalar el paquete `esp32 by Espressif Systems`.
3. Instalar las bibliotecas `DHT sensor library` y `Adafruit Unified Sensor`.
4. Conectar el DHT22 a GPIO4 y el sensor capacitivo a GPIO34.
5. Alimentar ambos sensores desde 3V3 y GND del ESP32.
6. Abrir el archivo `.ino` de la carpeta `firmware/`.
7. Seleccionar la placa `ESP32 Dev Module`.
8. Seleccionar el puerto correspondiente.
9. Compilar y cargar el programa.
10. Abrir el Monitor Serie a 115200 baudios.

## Instrucciones de uso de Scilab

1. Instalar Scilab.
2. Abrir el archivo `.sce` de la carpeta `scilab/`.
3. Revisar las dependencias y rutas de datos que requiera el programa.
4. Ejecutar el script.
5. Consultar los resultados matemáticos y las gráficas generadas.

## Resultados iniciales

Las pruebas experimentales muestran que la lectura ADC del sensor capacitivo disminuye cuando aumenta la humedad del suelo.

La calibración cuantitativa todavía está pendiente.

## Estado del desarrollo

- [x] Montaje electrónico.
- [x] Lectura de sensores mediante ESP32.
- [x] Mediciones experimentales iniciales.
- [ ] Integración MQTT.
- [ ] Seguridad de comunicaciones.
- [ ] Dashboard.
- [ ] Validación completa del sistema IoT.

## Propósito

Proyecto académico orientado a la aplicación de conocimientos de sensórica, electrónica, programación, modelado matemático y comunicaciones IoT.
