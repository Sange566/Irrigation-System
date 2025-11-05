# AquaLink Irrigation System 🌾💧

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-Active%20Development-green.svg)](#)
[![Python](https://img.shields.io/badge/python-3.8%2B-brightgreen)](#)
[![ESP32](https://img.shields.io/badge/microcontroller-ESP32-orange)](#)

An intelligent IoT-based automated irrigation system designed to optimize water usage and improve crop growth conditions. AquaLink combines precision sensor technology, MQTT communication, and data-driven analytics to revolutionize agricultural water management for sustainable farming.

**Project for:** University of the Western Cape - Advanced Computing (IFS325)  
**Institution:** Faculty of Economic and Management Sciences  
**Client:** Agricultural Research Council (ARC)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Problem Statement](#problem-statement)
- [Key Features](#key-features)
- [System Architecture](#system-architecture)
- [Hardware Components](#hardware-components)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [API Documentation](#api-documentation)
- [Data Flow](#data-flow)
- [Contributing](#contributing)
- [Team](#team)
- [License](#license)

---

## 🎯 Overview

AquaLink is a comprehensive solution to inefficient water management in agricultural operations. By integrating soil moisture sensors, water flow meters, and intelligent control algorithms, the system delivers:

- **25-30% reduction** in water consumption
- **Automated irrigation** based on real-time soil conditions
- **Real-time monitoring** via intuitive web dashboard
- **Historical data analysis** for long-term optimization
- **Cost-effective and scalable** deployment

---

## 🚨 Problem Statement

Traditional irrigation practices in South African agriculture rely on manual scheduling rather than actual crop needs, resulting in:

- **Water waste** through over- and under-watering
- **Inconsistent crop yields** due to plant stress and root disease
- **Labour-intensive operations** requiring significant manual intervention
- **Lack of data visibility** preventing informed optimization decisions
- **Soil degradation** from excessive water or nutrient leaching

AquaLink addresses these challenges through precision, automation, and intelligence.

---

## ✨ Key Features

| Feature | Description |
|---------|-------------|
| **Real-Time Monitoring** | Live water flow rates, soil moisture levels, and pump status via responsive dashboard |
| **Automated Control** | Intelligent pump actuation based on soil moisture thresholds and sensor feedback |
| **Data Persistence** | Comprehensive logging of all irrigation events and sensor readings in Oracle Database |
| **Multi-Channel Communication** | MQTT protocol for reliable, low-latency sensor-to-broker communication |
| **Alert System** | Automated notifications for sensor faults, low water levels, and system anomalies |
| **Manual Override** | User-friendly controls for emergency irrigation or scheduled adjustments |
| **Scalable Architecture** | Modular design supports expansion to multiple greenhouse zones |
| **Energy Efficient** | Optimized firmware and hardware for sustainable long-term operation |

---

## 🏗️ System Architecture

![System Architecture](https://github.com/Moufire-7/ARC_Irrigation_System/blob/main/Media/System%20Architecture.png?raw=true)


**Data Flow Path:**
```
Sensors (ESP32) → MQTT → Raspberry Pi → Python Script → Oracle APEX → Database → Dashboard
```

---

## 🔧 Hardware Components

### Core Components

| Component | Model | Purpose |
|-----------|-------|---------|
| Microcontroller | ESP32 | Main data collection and control unit |
| Water Flow Sensor | YF-S401 | Measures volumetric water flow rate (L/min) |
| Soil Moisture Sensor | Capacitive | Detects soil water content (integration with Group 2) |
| Relay Module | 2-Channel 5V | Switches pump on/off based on control signals |
| Water Pump | Submersible/Centrifugal | Pumps water through irrigation system |
| Broker Server | Raspberry Pi | Hosts MQTT broker and orchestrates data flow |
| Power Supply | Stable PSU / UPS | Ensures consistent operation and data integrity |

### Sensor Specifications

- **Water Flow Sensor Range:** 0.3 - 6 L/min
- **Soil Moisture Range:** 0-1023 (analog); correlates to soil water potential
- **ESP32 Operating Voltage:** 3.3V (with 5V-tolerant inputs for sensor signals)
- **MQTT Latency:** <100ms typical

---

## 📦 Installation

### Prerequisites

- Python 3.8+
- Node.js (for frontend development, optional)
- Arduino IDE or PlatformIO (for ESP32 firmware compilation)
- MQTT broker (Mosquitto recommended)
- Oracle APEX instance with REST API enabled
- Git

### Clone the Repository

```bash
git clone https://github.com/UWC-Group6/AquaLink.git
cd AquaLink
```

### Backend Setup (Raspberry Pi)

```bash
# Update system packages
sudo apt-get update && sudo apt-get upgrade -y

# Install MQTT broker
sudo apt-get install mosquitto mosquitto-clients -y

# Install Python dependencies
pip install -r requirements.txt

# Start MQTT broker
sudo systemctl start mosquitto
sudo systemctl enable mosquitto
```

### ESP32 Firmware Setup

```bash
# Option 1: Using Arduino IDE
# 1. Open Arduino IDE
# 2. Install ESP32 board support: Preferences → Additional Boards Manager URLs
# 3. Board Manager → Search "ESP32" → Install latest version
# 4. Open firmware/aqualink_esp32.ino
# 5. Select Board: "ESP32 Dev Module"
# 6. Configure MQTT broker IP in config.h
# 7. Upload to device

# Option 2: Using PlatformIO CLI
pio run -e esp32 -t upload --upload-port /dev/ttyUSB0
```

### Frontend Setup (Oracle APEX)

```bash
# Import dashboard application
# 1. Navigate to your Oracle APEX environment
# 2. Import application from: /frontend/aqualink_dashboard_export.sql
# 3. Configure database connection parameters
# 4. Set REST API endpoints in Application Settings
# 5. Deploy and access at: https://<apex-url>/app/aqualink
```

---

## ⚙️ Configuration

### ESP32 Configuration (`firmware/config.h`)

```cpp
// MQTT Settings
#define MQTT_BROKER "<your_broker_credentials>"    // Raspberry Pi IP
#define MQTT_PORT 1883
#define MQTT_USER "your_username_here"
#define MQTT_PASS "<your_mqtt_password>"

// Sensor Calibration
#define SOIL_MOISTURE_THRESHOLD 400    // Trigger pump at this level
#define FLOW_SENSOR_CALIBRATION 4.5    // Pulses per liter

// Device Identity
#define DEVICE_ID "<your_device_id>"
#define GREENHOUSE_ID "ARC_GH_001"

// Timing
#define SENSOR_READ_INTERVAL 5000      // 5 seconds
#define DATA_PUBLISH_INTERVAL 10000    // 10 seconds
#define PUMP_COOLDOWN_PERIOD 300000    // 5 minutes between cycles
```

### Raspberry Pi MQTT Configuration (`/etc/mosquitto/mosquitto.conf`)

```conf
listener 1883
protocol mqtt
allow_anonymous false
password_file /etc/mosquitto/passwd

listener 9001
protocol websockets
```

### Python Data Aggregator (`config/aggregator_config.json`)

```json
{
  "mqtt": {
    "broker": "localhost",
    "port": 1883,
    "username": "your_username_here",
    "password": "your_secure_password",
    "topics": [
      "aqualink/+/flowrate",
      "aqualink/+/pumpstatus",
      "aqualink/+/soilmoisture"
    ]
  },
  "oracle": {
    "host": "<oracle_apex_instance>",
    "port": 443,
    "protocol": "https",
    "endpoints": {
      "data_insert": "/api/irrigation/readings",
      "event_log": "/api/irrigation/events"
    }
  },
  "data_sync_interval": 30000
}
```

---

## 🚀 Usage

### Starting the System

```bash
# 1. On Raspberry Pi, start MQTT broker
sudo systemctl start mosquitto

# 2. Run Python data aggregator
python3 backend/data_aggregator.py &

# 3. Upload firmware to ESP32 via Arduino IDE or CLI

# 4. Access dashboard
# Open browser → https://<apex-url>/app/aqualink
```

### MQTT Topics Reference

| Topic | Direction | Payload | Frequency |
|-------|-----------|---------|-----------|
| `aqualink/zone_1/flowrate` | ESP32 → Broker | `{"value": 2.34, "unit": "L/min", "timestamp": "2025-11-05T14:32:00Z"}` | 10s |
| `aqualink/zone_1/pumpstatus` | ESP32 → Broker | `{"status": "ON/OFF", "duration_ms": 300000}` | Event-driven |
| `aqualink/zone_1/soilmoisture` | ESP32 → Broker | `{"value": 450, "threshold": 400, "timestamp": "..."}` | 10s |
| `aqualink/zone_1/control/pump` | Broker → ESP32 | `{"action": "ON/OFF", "duration_ms": 60000}` | On-demand |
| `aqualink/zone_1/alerts` | ESP32 → Broker | `{"alert_type": "SENSOR_FAULT", "message": "..."}` | Event-driven |

### Manual Override Example

```bash
# Manually turn on pump for 2 minutes via MQTT CLI
mosquitto_pub -h localhost -u aqualink -P secure_password \
  -t "aqualink/zone_1/control/pump" \
  -m '{"action":"ON","duration_ms":120000}'
```

### Viewing Dashboard

1. Navigate to `https://<your-apex-url>/app/aqualink`
2. Login with ARC credentials
3. View real-time gauges showing:
   - Current water flow rate
   - Soil moisture levels
   - Pump operational status
   - System health alerts
4. Access analytics tab for historical trends over customizable date ranges

---

## 📡 API Documentation

### REST Endpoints (Oracle APEX)

#### Get Latest Sensor Readings
```
GET /api/irrigation/readings/latest
Query Parameters:
  - zone_id (optional): Filter by irrigation zone
  - limit (optional): Number of records to return (default: 100)

Response:
{
  "success": true,
  "data": [
    {
      "reading_id": "1001",
      "zone_id": "zone_1",
      "flow_rate": 2.34,
      "soil_moisture": 450,
      "pump_status": "ON",
      "timestamp": "2025-11-05T14:32:00Z"
    }
  ]
}
```

#### Get Historical Analytics
```
GET /api/irrigation/analytics
Query Parameters:
  - start_date: ISO 8601 format (required)
  - end_date: ISO 8601 format (required)
  - zone_id: Specific zone (optional)
  - granularity: "hourly", "daily", "weekly" (default: daily)

Response:
{
  "success": true,
  "summary": {
    "total_water_used": 1250.5,
    "irrigation_cycles": 48,
    "average_flow_rate": 2.15,
    "water_savings_vs_baseline": "27.3%"
  },
  "data": [...]
}
```

#### Trigger Manual Irrigation
```
POST /api/irrigation/control/pump
Body:
{
  "zone_id": "zone_1",
  "action": "ON",
  "duration_seconds": 120,
  "priority": "manual"
}

Response:
{
  "success": true,
  "control_id": "ctrl_5a3b",
  "message": "Pump activated for 2 minutes"
}
```

#### Get System Alerts
```
GET /api/irrigation/alerts
Query Parameters:
  - status: "ACTIVE", "RESOLVED", "ALL" (default: ACTIVE)
  - zone_id: (optional)

Response:
{
  "success": true,
  "alerts": [
    {
      "alert_id": "ALT_001",
      "type": "SENSOR_FAULT",
      "severity": "HIGH",
      "message": "Flow sensor unresponsive",
      "zone_id": "zone_1",
      "created_at": "2025-11-05T14:15:00Z",
      "status": "ACTIVE"
    }
  ]
}
```

---

## 🔄 Data Flow

### Typical Operating Cycle

1. **Sensor Reading (Every 5 seconds)**
   - ESP32 reads soil moisture and flow sensor values
   - Data validated and stored in local buffer

2. **Threshold Comparison**
   - Soil moisture compared against target threshold
   - Pump actuation decision made autonomously

3. **Data Publication (Every 10 seconds)**
   - Current readings published to MQTT broker
   - Raspberry Pi subscribes and receives data

4. **Data Aggregation (Every 30 seconds)**
   - Python script bundles readings into batch
   - Event logging triggers for significant changes

5. **Cloud Synchronization**
   - Batch POST request sent to Oracle APEX REST API
   - Data persisted in Oracle Database with timestamp

6. **Dashboard Update**
   - Frontend polls latest data endpoint
   - Graphs and gauges refresh in real-time (5-10s latency)

7. **Alert Trigger (On-demand)**
   - Anomalies detected → Alert logged to database
   - Notification sent to dashboard UI
   - Farmer receives alert for action

---

## 🤝 Contributing

We welcome contributions from developers, agricultural technologists, and researchers!

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/sensor-calibration`
3. **Commit** changes: `git commit -m 'Add adaptive threshold algorithm'`
4. **Push** to branch: `git push origin feature/sensor-calibration`
5. **Submit** a Pull Request with detailed description

### Code Standards

- **Python:** Follow PEP 8 guidelines; use black formatter
- **C/C++ (ESP32):** Use Arduino naming conventions; include inline comments
- **Documentation:** Update README and API docs for feature changes
- **Testing:** Include unit tests for backend modules; test on hardware before PR

### Issue Tracking

Please report bugs and suggest features via GitHub Issues with:
- Clear description and reproducibility steps
- Hardware/software configuration
- Screenshots or logs (if applicable)
- Expected vs. actual behavior

---

## 👥 Team

**AquaLink Development Team - Group 6**  
University of the Western Cape | Faculty of Economic and Management Sciences

| Name | Role | Contributions |
|------|------|---|
| **Likhaya Moko** | Documentation & QA Analyst | Project documentation, quality assurance testing, requirements validation |
| **Sharlet Netshiendeulu** | API Consultant & Technical Lead | REST API design, integration management, secondary documentation |
| **Liam Husselmann** | Database Consultant | Database schema design, data optimization, backend architecture |
| **Folu Opaleye** | Hardware Technician | Circuit design, sensor integration, hardware troubleshooting |
| **Sangesonke Njameni** | Hardware & Frontend Engineer | Hardware architecture, dashboard UI/UX, prototype validation |

**Project Manager:** Mohamed Awaale (ESP32 Firmware & Backend Development)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Agricultural Research Council (ARC)** - Project sponsor and greenhouse testing facility
- **University of the Western Cape** - Academic support and infrastructure
- **Group 2** (Soil Monitoring Team) - Soil moisture data integration
- **Group 5** (Data Management Platform) - API and database infrastructure

---

## 📞 Support & Contact

For technical support, questions, or collaboration inquiries:

- **Issues & Bug Reports:** GitHub Issues tab
- **Documentation:** Check `/docs` folder for detailed guides
- **Project Repository:** [GitHub - AquaLink](https:https://github.com/Moufire-7/ARC_Irrigation_System)

---

## 🗓️ Project Timeline

- **Week 1 (1-5 Oct):** Project initiation & team formation
- **Week 2 (6-12 Oct):** Requirements & system design
- **Week 3 (13-19 Oct):** Hardware setup & software development
- **Week 4 (20-26 Oct):** System integration & testing
- **Week 5 (27 Oct - 5 Nov):** Final optimization & delivery

**Submission Date:** 5 November 2025

---

**Last Updated:** November 2025  
**Status:** Active Development  
**Version:** 1.0.0 (Release Candidate)

---

*"Smart irrigation for sustainable agriculture" - AquaLink Mission*
