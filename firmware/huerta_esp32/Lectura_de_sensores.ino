
#include <Arduino.h>
#include <DHT.h>

// Proyecto: Monitoreo de huerta urbana
// ESP32 + DHT22 + Capacitivo V2

#define DHTPIN 4
#define DHTTYPE DHT22
#define SUELO_PIN 34

DHT dht(DHTPIN, DHTTYPE);

void setup() {
  Serial.begin(115200);
  dht.begin();

  analogReadResolution(12);

  Serial.println("MONITOREO DE HUERTA URBANA");
  Serial.println("Iniciando sensores...");
}

void loop() {
  // Lecturas del DHT22
  float temperatura = dht.readTemperature();
  float humedadAire = dht.readHumidity();

  // Lectura del sensor capacitivo V2
  int adcSuelo = analogRead(SUELO_PIN);

  Serial.println("-------------------------");

  if (isnan(temperatura) || isnan(humedadAire)) {
    Serial.println("Error al leer el DHT22");
  } else {
    Serial.print("Temperatura: ");
    Serial.print(temperatura);
    Serial.println(" °C");

    Serial.print("Humedad ambiental: ");
    Serial.print(humedadAire);
    Serial.println(" %");
  }

  Serial.print("Humedad suelo ADC: ");
  Serial.println(adcSuelo);

  delay(2000);
}




