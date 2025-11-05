#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <WiFiUdp.h>
#include <NTPClient.h>
#include <time.h>

// --- Pinout Configuration ---
#define RELAY_PIN   26
#define SENSOR_PIN  25

// --- WiFi & MQTT Configuration ---
const char* ssid = "Wifi";
const char* password = "password";
const char* mqtt_server = "10.124.122.189";
const int   mqtt_port = 1883;
const char* mqtt_data_topic = "arc/water-monitoring/group6/water-sensor";
const char* mqtt_command_topic = "grp6_irrigation_command";
#define MQTT_TOPIC_MOISTURE "irrigation/moisture-readings"
#define DEVICE_UID "GROUP6_ESP32_01"

// --- Time (NTP) Configuration ---
WiFiUDP ntpUDP;
const long utcOffsetInSeconds = 7200; // SAST is UTC+2
NTPClient timeClient(ntpUDP, "pool.ntp.org", utcOffsetInSeconds);

// --- Global Variables ---
volatile byte pulseCount;
float calibrationFactor = 16.005; // <-- FIXED SYNTAX
float flowRate;
unsigned long totalMilliLitres = 0;   // Tracks total volume, never resets
unsigned long cycleMilliLitres = 0;   // Tracks volume for the current cycle
bool pumpState = false;
String currentMoisture = "0 %"; // <-- ADDED: To store moisture reading

// Timers
unsigned long previousMillis = 0;
unsigned long minuteMillis = 0;
unsigned long pumpStartTime = 0;
const unsigned long FAILSAFE_DURATION = 3600000UL; // 1 hour
int interval = 5000; // 5 seconds

// Minute Average
float totalFlowRateForMinute = 0;
int readingCountForMinute = 0;

WiFiClient espClient;
PubSubClient client(espClient);

// --- START: NEW FAILSAFE & RECONNECT VARIABLES ---
unsigned long lastReconnectAttempt = 0;
const long reconnectInterval = 5000; // Try to reconnect every 5 seconds

// Failsafe: Turn pump off if MQTT is disconnected
unsigned long disconnectionTime = 0; // 0 = connected
const unsigned long MQTT_FAILSAFE_DURATION = 2000; // 2 seconds
// --- END: NEW FAILSAFE & RECONNECT VARIABLES ---


// --- Function to send the final OFF status ---
void sendPumpOffStatus() {
  char formattedTime[20];
  if (timeClient.getEpochTime() < 1609459200) { // Check if time is synced
    strcpy(formattedTime, "Syncing...");
  } else {
    time_t epochTime = timeClient.getEpochTime();
    struct tm* timeinfo = localtime(&epochTime);
    strftime(formattedTime, sizeof(formattedTime), "%Y-%m-%d %H:%M:%S", timeinfo);
  }

  StaticJsonDocument<300> doc;
  doc["device_uid"] = DEVICE_UID;
  doc["moisture"] = currentMoisture; // <-- ADDED
  doc["timestamp"] = formattedTime;
  doc["flow_rate"] = 0.00;
  doc["total_flow"] = float_with_three_decimals(totalMilliLitres / 1000.0);
  doc["pump_status"] = "OFF";
  char jsonBuffer[512];
  serializeJson(doc, jsonBuffer);
  client.publish(mqtt_data_topic, jsonBuffer);

  Serial.println("\n---------------------");
  Serial.println("PUMP TURNED OFF");
  Serial.print("Total Flow:       ");
  Serial.print(totalMilliLitres / 1000.0, 3);
  Serial.println(" L");
  Serial.println("Pump Status:      OFF");
  Serial.println("---------------------\n");
}

// --- Function to handle incoming MQTT commands ---
void callback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.print("MQTT Command received [");
  Serial.print(topic);
  Serial.print("]: ");
  Serial.println(message);

  if (String(topic) == mqtt_command_topic) {
    if (message == "ON" && !pumpState) {
      Serial.println("MQTT: Turning pump ON");
      digitalWrite(RELAY_PIN, LOW); // Turn relay ON
      pumpState = true;
      pumpStartTime = millis();
      cycleMilliLitres = 0; // Reset cycle volume on ON
    } else if (message == "OFF" && pumpState) {
      Serial.println("MQTT: Turning pump OFF");
      digitalWrite(RELAY_PIN, HIGH); // Turn relay OFF
      pumpState = false;
      sendPumpOffStatus(); // Send final status
    }
  }
  
  // --- UPDATED: Store moisture reading ---
  if (String(topic) == MQTT_TOPIC_MOISTURE) {
    currentMoisture = message; // Save the incoming moisture value
    Serial.print("Received new moisture reading: ");
    Serial.println(currentMoisture);
  }
}

// --- Function to handle Serial Monitor commands for testing ---
void checkSerialCommands() {
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    command.toUpperCase();

    Serial.print("Serial Monitor command received: ");
    Serial.println(command);

    if (command == "ON" && !pumpState) {
      Serial.println("Serial: Turning pump ON");
      digitalWrite(RELAY_PIN, LOW);
      pumpState = true;
      pumpStartTime = millis();
      cycleMilliLitres = 0;
    } else if (command == "OFF" && pumpState) {
      Serial.println("Serial: Turning pump OFF");
      digitalWrite(RELAY_PIN, HIGH);
      pumpState = false;
      
      if (client.connected()) {
        sendPumpOffStatus();
      } else {
         Serial.println("\n--- PUMP OFF (Serial) ---");
      }
    } else if (command == "ON" && pumpState) {
      Serial.println("Serial: Pump is already ON");
    } else if (command == "OFF" && !pumpState) {
      Serial.println("Serial: Pump is already OFF");
    }
  }
}

void IRAM_ATTR pulseCounter() {
  if (pumpState) {
    pulseCount++;
  }
}

void setup_wifi() {
    delay(10);
    Serial.println();
    Serial.print("Connecting to ");
    Serial.println(ssid);
    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\nWiFi connected");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
}

// --- NEW: NON-BLOCKING RECONNECT FUNCTION ---
void mqttReconnectAttempt() {
  Serial.print("Attempting MQTT connection...");
  
  if (client.connect("ESP32_001")) { 
    Serial.println("connected");
    
    client.subscribe(mqtt_command_topic);
    Serial.print("Subscribed to command topic: ");
    Serial.println(mqtt_command_topic);

    if (client.subscribe(MQTT_TOPIC_MOISTURE)) {
      Serial.print("Subscribed to moisture topic: ");
      Serial.println(MQTT_TOPIC_MOISTURE);
    } else {
      Serial.println("Failed to subscribe to moisture topic.");
    }
  } else {
    Serial.print("failed, rc=");
    Serial.print(client.state());
    Serial.println(" try again in 5 seconds");
  }
}


void setup() {
  Serial.begin(115200);
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(SENSOR_PIN, INPUT_PULLUP);
  digitalWrite(RELAY_PIN, HIGH); // Default to OFF
  setup_wifi();
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
  timeClient.begin();
  attachInterrupt(digitalPinToInterrupt(SENSOR_PIN), pulseCounter, FALLING);
  Serial.println("\nIrrigation System Monitor");
  Serial.println("Type ON or OFF into the Serial Monitor to test pump.");
  Serial.println("Pump is OFF. Waiting for command...\n");
}


// --- START: REWRITTEN MAIN LOOP ---
void loop() {
  // These functions MUST run every loop, regardless of connection state
  timeClient.update();
  checkSerialCommands();
  unsigned long currentMillis = millis();


  // --- Failsafe 1: 1-Hour Hard Limit ---
  if (pumpState && (currentMillis - pumpStartTime >= FAILSAFE_DURATION)) {
    Serial.println("\n*");
    Serial.println("!!! FAILSAFE TRIGGERED (1 Hour Limit) !!!");
    Serial.println("*");
    
    digitalWrite(RELAY_PIN, HIGH);
    pumpState = false;
    
    if (client.connected()) {
      sendPumpOffStatus();
    } else {
      Serial.println("--- PUMP FORCED OFF (1-Hour Failsafe, MQTT Disconnected) ---");
    }
  }


  // --- Handle MQTT Connection / Reconnection ---
  if (!client.connected()) {
    // --- STATE: DISCONNECTED ---

    // 1. Start 2-second failsafe timer
    if (disconnectionTime == 0) {
      disconnectionTime = currentMillis;
      Serial.println("MQTT Disconnected. Starting 2-second failsafe timer...");
    }

    // 2. Try to reconnect every 5 seconds (non-blocking)
    if (currentMillis - lastReconnectAttempt > reconnectInterval) {
      lastReconnectAttempt = currentMillis;
      mqttReconnectAttempt(); 
    }
    
    // 3. Check 2-second failsafe
    if (pumpState && (currentMillis - disconnectionTime > MQTT_FAILSAFE_DURATION)) {
      Serial.println("!!! MQTT FAILSAFE: Failed to reconnect in 2s. Turning pump OFF.");
      digitalWrite(RELAY_PIN, HIGH);
      pumpState = false;
      Serial.println("\n--- PUMP FORCED OFF (MQTT Failsafe) ---");
    }

  } else {
    // --- STATE: CONNECTED ---

    // 1. Reset failsafe timer
    if (disconnectionTime != 0) {
      Serial.println("MQTT Reconnected!");
      disconnectionTime = 0; 
    }

    // 2. Process MQTT messages
    client.loop(); 
    
    // 3. Run sensor reading/publishing logic (every 5 sec)
    if (currentMillis - previousMillis >= interval) {
      previousMillis = currentMillis;

      if (pumpState) {
        detachInterrupt(digitalPinToInterrupt(SENSOR_PIN));
        byte pulse1Sec = pulseCount;
        pulseCount = 0;
        attachInterrupt(digitalPinToInterrupt(SENSOR_PIN), pulseCounter, FALLING);

        // Calculate Flow Rate
        float avgPulsesPerSec = pulse1Sec / (interval / 1000.0);
        flowRate = avgPulsesPerSec / calibrationFactor;

        // Calculate Total Volume
        const float pulsesPerMilliLitre = (calibrationFactor * 60.0) / 1000.0;
        unsigned long mlThisInterval = pulse1Sec / pulsesPerMilliLitre;
              
        totalMilliLitres += mlThisInterval;
        cycleMilliLitres += mlThisInterval;

        // Add to minute average
        totalFlowRateForMinute += flowRate;
        readingCountForMinute++;

        // Get formatted time
        char formattedTime[20];
        if (timeClient.getEpochTime() < 1609459200) {
            strcpy(formattedTime, "Syncing...");
        } else {
            time_t epochTime = timeClient.getEpochTime();
            struct tm* timeinfo = localtime(&epochTime);
            strftime(formattedTime, sizeof(formattedTime), "%Y-%m-%d %H:%M:%S", timeinfo);
        }

        // Create JSON payload
        StaticJsonDocument<300> doc;
        doc["device_uid"] = DEVICE_UID;
        doc["moisture"] = currentMoisture; // <-- ADDED
        doc["timestamp"] = formattedTime;
        doc["flow_rate"] = float_with_two_decimals(flowRate);
        doc["total_flow"] = float_with_three_decimals(totalMilliLitres / 1000.0);
        doc["pump_status"] = "ON";

        // Publish to MQTT
        char jsonBuffer[512];
        serializeJson(doc, jsonBuffer);
        client.publish(mqtt_data_topic, jsonBuffer);

        // Print to Serial Monitor
        Serial.println("--- Sensor Update (5 sec) ---");
        Serial.print("Timestamp:        ");
        Serial.println(formattedTime);
        Serial.print("Flow Rate:        "); Serial.print(flowRate, 2); Serial.println(" L/min");
        Serial.print("Total Flow:       "); Serial.print(totalMilliLitres / 1000.0, 3); Serial.println(" L");
        Serial.print("Pump Status:      ON\n");
        Serial.println("---------------------");
      }
    }

    // 4. Run Minute Summary (every 60 sec)
    if (pumpState && (currentMillis - minuteMillis >= 60000)) {
      minuteMillis = currentMillis;
      if (readingCountForMinute > 0) {
        float averageFlowRate = totalFlowRateForMinute / readingCountForMinute;
        Serial.println("*");
        Serial.println("             MINUTE SUMMARY");
        Serial.print("Average Flow Rate: ");
        Serial.print(averageFlowRate, 2);
        Serial.println(" L/min");
        Serial.println("*\n");
        
        totalFlowRateForMinute = 0;
        readingCountForMinute = 0;
      }
    }
  } // End of if-else client.connected()
}
// --- END: REWRITTEN MAIN LOOP ---


// Helper functions for formatting floats
float float_with_two_decimals(float value) {
  return (int)(value * 100) / 100.0;
}
float float_with_three_decimals(float value) {
  return (int)(value * 1000) / 1000.0;
}