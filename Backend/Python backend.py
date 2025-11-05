import threading
import time
import json
from datetime import datetime, timedelta, timezone
import pytz
import schedule
import paho.mqtt.client as mqtt
import requests
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import os
import asyncio
import queue  # For thread-safe communication
from typing import List, Dict, Any

# --- Load environment variables from .env file ---
from dotenv import load_dotenv

load_dotenv()
# ----------------------------------------------------

# --- Basic Configuration ---
SAST_TIMEZONE = pytz.timezone('Africa/Johannesburg')

# --- FastAPI App Setup ---
app = FastAPI(title="Irrigation Backend")

# --- CORS Configuration ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# --- APEX API CONFIGURATION (from .env) ---
APEX_BASE_URL = os.environ.get('APEX_BASE_URL')

if not APEX_BASE_URL:
    print("=" * 50)
    print("FATAL: APEX_BASE_URL not found in .env file.")
    print("=" * 50)
    # Use the actual URL as a fallback if needed for testing, but .env is preferred
    APEX_BASE_URL = "https://oracleapex.com/ords/irrigation_system/api"
else:
    print("APEX API URLs loaded successfully from .env file.")

# --- Build full API paths from .env ---
APEX_TELEMETRY_API = f"{APEX_BASE_URL}{os.environ.get('APEX_TELEMETRY_API_PATH', '/telemetry/')}"
APEX_DEVICES_API = f"{APEX_BASE_URL}{os.environ.get('APEX_DEVICES_API_PATH', '/devices/')}"
APEX_ALERTS_API = f"{APEX_BASE_URL}{os.environ.get('APEX_ALERTS_API_PATH', '/alerts/')}"
APEX_AUDIT_API = f"{APEX_BASE_URL}{os.environ.get('APEX_AUDIT_API_PATH', '/audit/')}"
APEX_SCHEDULE_API = f"{APEX_BASE_URL}{os.environ.get('APEX_SCHEDULE_API_PATH', '/schedule/')}"

# --- Global Headers for all API Requests ---
APEX_HEADERS = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'Irrigation-Backend-FastAPI/1.0'  # <-- ADDED
}

# --- MQTT Configuration ---
# MQTT Broker on WiFi network "Wifi" (password: "password")
# ESP32 device connects to same broker
MQTT_BROKER = "10.124.122.189"  # MQTT broker IP (from WiFi network)
MQTT_PORT = 1883
MQTT_PUMP_COMMAND_TOPIC = "grp6_irrigation_command"
MQTT_PUMP_DATA_TOPIC = "arc/water-monitoring/group6/water-sensor"
MQTT_MOISTURE_TOPIC = "irrigation/moisture-readings"
DEVICE_UID = "GROUP6_ESP32_01"  # Expected device UID from ESP32

# --- Automation Configuration ---
automation_enabled = False
MIN_MOISTURE_THRESHOLD = 25.0  # Pump turns ON when moisture drops below this
MAX_MOISTURE_THRESHOLD = 60.0  # Pump turns OFF when moisture rises above this
last_known_moisture = None
automation_pump_state = False  # Track if pump was turned on by automation

# --- Scheduling Configuration ---
scheduling_enabled = False
active_schedules = {}  # Dictionary to store schedule jobs: {job_id: {schedule_obj, day, time, duration}}
next_job_id = 1  # Counter for unique job IDs

# --- Action History Tracking ---
action_history = []  # List to store pump action history
MAX_HISTORY_SIZE = 100  # Keep last 100 actions

# --- Device Identification ---
DEVICE_UNIQUE_ID = DEVICE_UID  # Use MQTT configuration device UID
device_db_id = None  # This is the internal DB primary key, e.g., 1, 2, 3...

# --- Daily Usage Tracking (In-Memory) ---
daily_start_volume = None  # Volume at start of day
daily_current_volume = 0.0  # Current volume
daily_peak_flow = 0.0  # Peak flow rate today
last_reset_date = None  # Track when we last reset


# --- WebSocket Connection Manager ---
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        print(f"WebSocket connected: {websocket.client}")
        # Send current automation status on connect
        await websocket.send_json({"type": "automation_status", "enabled": automation_enabled})

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
            print(f"WebSocket disconnected: {websocket.client}")

    async def broadcast(self, message: Dict[str, Any]):
        disconnected_clients = []
        message_json = json.dumps(message)  # Serialize dict to JSON string once
        for connection in self.active_connections:
            try:
                await connection.send_text(message_json)
            except WebSocketDisconnect:
                disconnected_clients.append(connection)
            except Exception as e:
                print(f"Error sending message to {connection.client}: {e}")
                disconnected_clients.append(connection)  # Assume disconnected on error

        # Clean up disconnected clients after iterating
        for client in disconnected_clients:
            self.disconnect(client)


manager = ConnectionManager()
message_queue = queue.Queue()  # Thread-safe queue for MQTT -> WebSocket


# --- APEX Interaction Functions (Unchanged logic, just used by FastAPI now) ---

# --- *** CORRECTED FUNCTION 1 *** ---
def get_or_create_device_id_api(uid):
    """
    Finds device ID (primary key) from APEX by fetching all devices
    and filtering them here in Python to match the provided PL/SQL.
    The device is created by the telemetry API on its first post, not here.
    """
    global device_db_id
    if device_db_id:
        return device_db_id

    try:
        # The provided APEX GET API for /devices_api returns ALL devices
        # and does not support filtering via query parameters.
        # Therefore, we fetch all and filter client-side (here in Python).
        print(f"Fetching all devices from {APEX_DEVICES_API} to find '{uid}'...")
        response = requests.get(APEX_DEVICES_API, headers=APEX_HEADERS)
        response.raise_for_status()
        data = response.json()

        if data.get('items'):
            # Loop through the list of all devices
            for device in data.get('items', []):
                # Check if this device is the one we're looking for
                if device.get('device_uid') == uid:
                    device_db_id = device['id']
                    print(f"Found device '{uid}' via APEX with ID: {device_db_id}")
                    return device_db_id

        # If we get here, the loop finished and no device was found
        print(f"Device '{uid}' not found via APEX. It will be created on first data message.")
        device_db_id = None
        return None
    except requests.exceptions.RequestException as e:
        print(f"APEX API error in get_or_create_device_id_api: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"API Response Body: {e.response.text}")
        device_db_id = None
        return None
    except Exception as e:
        print(f"Error in get_or_create_device_id_api: {e}")
        device_db_id = None
        return None


# --- *** CORRECTED FUNCTION 2 *** ---
def log_to_audit_api(action, user="system"):
    """Sends a log entry to the APEX Audit API."""
    print(f"Logging Audit: {action}")

    # Map Python variables to the keys the PL/SQL API expects
    event_type = "USER_ACTION" if user == "api_user" else "SYSTEM_ACTION"

    payload = {
        "device_uid": DEVICE_UNIQUE_ID,  # API expects device_uid (optional)
        "event_type": event_type,  # API expects event_type (required)
        "description": action,  # API expects description (required)
        "source": user  # API expects source (optional)
    }
    try:
        response = requests.post(APEX_AUDIT_API, json=payload, headers=APEX_HEADERS)
        response.raise_for_status()
    except Exception as e:
        print(f"Failed to log audit: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Audit API Response Body: {e.response.text}")


# --- *** CORRECTED FUNCTION 3 *** ---
def create_alert_api(title, message, severity="INFO"):
    """Creates a new alert via the APEX API."""
    # This function no longer needs the global 'device_db_id'
    # The API finds the device using 'device_uid'

    print(f"Creating Alert: {title}")
    payload = {
        "device_uid": DEVICE_UNIQUE_ID,  # API expects device_uid
        "alert_type": title,  # API expects alert_type
        "message": message,  # API expects message
        "severity": severity,  # API expects severity
        "status": "new"  # API expects status
    }
    try:
        response = requests.post(APEX_ALERTS_API, json=payload, headers=APEX_HEADERS)
        response.raise_for_status()
    except Exception as e:
        print(f"Failed to create alert: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Alert API Response Body: {e.response.text}")


# --- MQTT Client Logic ---
mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)


def on_connect(client, userdata, flags, rc, properties=None):
    """Callback when MQTT client connects"""
    if rc == 0:
        print("\n" + "=" * 60)
        print("[MQTT] ✓ Successfully connected to MQTT broker")
        print(f"[MQTT] Broker: {MQTT_BROKER}:{MQTT_PORT}")
        print(f"[MQTT] Device UID: {DEVICE_UNIQUE_ID}")
        print("=" * 60)
        print(f"[MQTT] Subscribing to topics...")
        client.subscribe(MQTT_PUMP_DATA_TOPIC)
        print(f"[MQTT] ✓ Subscribed to: {MQTT_PUMP_DATA_TOPIC} (Pump Data)")
        client.subscribe(MQTT_MOISTURE_TOPIC)
        print(f"[MQTT] ✓ Subscribed to: {MQTT_MOISTURE_TOPIC} (Moisture Data)")
        print(f"[MQTT] Publishing commands to: {MQTT_PUMP_COMMAND_TOPIC}")
        print("=" * 60 + "\n")
        # Attempt to get device ID right after connecting
        get_or_create_device_id_api(DEVICE_UNIQUE_ID)
    else:
        print("\n" + "=" * 60)
        print("[MQTT] ✗ FAILED to connect to MQTT broker")
        print("=" * 60)
        print(f"Broker: {MQTT_BROKER}:{MQTT_PORT}")
        print(f"Error Code: {rc}")
        print("")
        print("Error code meanings:")
        print("  1 = Connection refused - incorrect protocol version")
        print("  2 = Connection refused - invalid client identifier")
        print("  3 = Connection refused - server unavailable")
        print("  4 = Connection refused - bad username or password")
        print("  5 = Connection refused - not authorized")
        print("")
        print("⚠️  TROUBLESHOOTING:")
        print(f"  1. Check if MQTT broker is running at {MQTT_BROKER}")
        print(f"  2. Test with: ping {MQTT_BROKER}")
        print("  3. Verify port 1883 is accessible")
        print("  4. Check firewall settings")
        print("=" * 60 + "\n")


def on_disconnect(client, userdata, disconnect_flags, reason_code, properties=None):
    """Callback when MQTT client disconnects"""
    print("\n" + "=" * 60)
    print("[MQTT] ⚠️  DISCONNECTED from broker")
    print("=" * 60)
    if reason_code != 0:
        print(f"Unexpected disconnect. Reason code: {reason_code}")
        print("The client will attempt to reconnect automatically...")
    print("=" * 60 + "\n")


def on_message(client, userdata, msg):
    """Processes MQTT messages, POSTs to APEX, and puts data in queue for WebSockets."""
    global last_known_moisture, daily_start_volume, daily_current_volume, daily_peak_flow, last_reset_date
    topic = msg.topic
    payload_str = msg.payload.decode()
    print(f"[MQTT] ✓ Received on '{topic}': {payload_str[:100]}...")

    # --- REMOVED device_db_id check ---
    # The telemetry API and alert API no longer need it.
    # They both use DEVICE_UNIQUE_ID.

    try:
        data = json.loads(payload_str)
        ts_str = data.get('timestamp')

        if not ts_str or 'Syncing' in ts_str:
            return

        # --- Put raw data into queue for WebSocket broadcast ---
        websocket_message = {"type": "live_data", "payload": data}
        message_queue.put(websocket_message)
        print(
            f"[MQTT→WS] Message queued for broadcast. Queue size: {message_queue.qsize()}, Active WS clients: {len(manager.active_connections)}")
        # --------------------------------------------------------

        telemetry_payload = None

        # This payload format was corrected in the previous step
        if topic == MQTT_PUMP_DATA_TOPIC:
            # Track daily usage in memory
            current_volume = data.get('total_volume')
            current_flow = data.get('flow_rate_Lmin', 0)

            if current_volume is not None:
                # Check if we need to reset for a new day
                today = datetime.now(SAST_TIMEZONE).date()
                if last_reset_date != today:
                    print(
                        f"New day detected! Resetting daily stats. Previous start: {daily_start_volume}, Current: {current_volume}")
                    daily_start_volume = current_volume
                    daily_peak_flow = 0.0
                    last_reset_date = today
                elif daily_start_volume is None:
                    # First time tracking
                    print(f"Initializing daily tracking. Starting volume: {current_volume}")
                    daily_start_volume = current_volume
                    last_reset_date = today

                daily_current_volume = current_volume

                # Track peak flow
                if current_flow and current_flow > daily_peak_flow:
                    daily_peak_flow = current_flow

                # Calculate and log daily usage
                daily_usage = max(0, daily_current_volume - daily_start_volume) if daily_start_volume else 0
                print(
                    f"Daily Tracking - Start: {daily_start_volume:.2f}L, Current: {daily_current_volume:.2f}L, Usage Today: {daily_usage:.2f}L, Peak Flow: {daily_peak_flow:.2f} L/min")

            telemetry_payload = {
                'device_uid': DEVICE_UNIQUE_ID,
                'timestamp': ts_str,
                'pump_state': data.get('pump_state'),
                'flow_rate_Lmin': data.get('flow_rate_Lmin'),
                'total_volume': data.get('total_volume')
            }
            print("Sending Pump data to APEX...")

        # This payload format was corrected in the previous step
        elif topic == MQTT_MOISTURE_TOPIC:
            current_moisture = data.get('moisture')
            if current_moisture is not None:
                last_known_moisture = float(current_moisture)
                print(f"Updated moisture level: {last_known_moisture}%")

                telemetry_payload = {
                    'device_uid': DEVICE_UNIQUE_ID,
                    'timestamp': ts_str,
                    'moisture': last_known_moisture
                }
                print("Sending Moisture data to APEX...")

                # Simple bidirectional automation control
                # Turn ON when moisture ≤ threshold, OFF when moisture > threshold
                if automation_enabled:
                    global automation_pump_state

                    # Turn ON if moisture drops below MIN threshold and pump is not already on by automation
                    if last_known_moisture <= MIN_MOISTURE_THRESHOLD and not automation_pump_state:
                        print(
                            f"[AUTOMATION] Moisture below minimum ({last_known_moisture}% ≤ {MIN_MOISTURE_THRESHOLD}%). Turning pump ON.")
                        publish_pump_on()
                        automation_pump_state = True

                        # Log the automation action
                        log_pump_action('ON', 'automation', {
                            'moisture': last_known_moisture,
                            'min_threshold': MIN_MOISTURE_THRESHOLD,
                            'max_threshold': MAX_MOISTURE_THRESHOLD,
                            'reason': 'moisture_below_minimum'
                        })

                        create_alert_api("Moisture Critical Low",
                                         f"Moisture at {last_known_moisture}% (≤ {MIN_MOISTURE_THRESHOLD}%), turning on pump.",
                                         severity="WARNING")

                    # Turn OFF if moisture rises above MAX threshold and pump was turned on by automation
                    elif last_known_moisture >= MAX_MOISTURE_THRESHOLD and automation_pump_state:
                        print(
                            f"[AUTOMATION] Moisture above maximum ({last_known_moisture}% ≥ {MAX_MOISTURE_THRESHOLD}%). Turning pump OFF.")
                        publish_pump_off()
                        automation_pump_state = False

                        # Log the automation action
                        log_pump_action('OFF', 'automation', {
                            'moisture': last_known_moisture,
                            'min_threshold': MIN_MOISTURE_THRESHOLD,
                            'max_threshold': MAX_MOISTURE_THRESHOLD,
                            'reason': 'moisture_above_maximum'
                        })

                        create_alert_api("Moisture Optimal",
                                         f"Moisture at {last_known_moisture}% (≥ {MAX_MOISTURE_THRESHOLD}%), turning off pump.",
                                         severity="INFO")

        if telemetry_payload:
            response = requests.post(APEX_TELEMETRY_API, json=telemetry_payload, headers=APEX_HEADERS)
            response.raise_for_status()
            print(f"Data saved to APEX (Status: {response.status_code}).")

    except json.JSONDecodeError:
        print(f"Error decoding JSON from topic '{topic}': {payload_str}")
    except requests.exceptions.RequestException as api_err:
        print(f"APEX API Error processing message from '{topic}': {api_err}")
        if api_err.response:
            print(f"Response Body: {api_err.response.text}")
    except Exception as e:
        print(f"General error processing message from '{topic}': {e}")


def setup_mqtt():
    """Connects MQTT client."""
    try:
        print("\n" + "=" * 60)
        print("🔌 MQTT CLIENT CONFIGURATION")
        print("=" * 60)
        print(f"Broker Address:    {MQTT_BROKER}:{MQTT_PORT}")
        print(f"Device UID:        {DEVICE_UNIQUE_ID}")
        print(f"Command Topic:     {MQTT_PUMP_COMMAND_TOPIC}")
        print(f"Pump Data Topic:   {MQTT_PUMP_DATA_TOPIC}")
        print(f"Moisture Topic:    {MQTT_MOISTURE_TOPIC}")
        print("=" * 60)
        print("Connecting to MQTT broker...")
        print("=" * 60 + "\n")
        
        # Set up callbacks
        mqtt_client.on_connect = on_connect
        mqtt_client.on_disconnect = on_disconnect
        mqtt_client.on_message = on_message
        
        # Attempt connection
        print(f"[MQTT] Attempting connection to {MQTT_BROKER}:{MQTT_PORT}...")
        mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        mqtt_client.loop_start()  # Runs in a background thread
        print("[MQTT] MQTT client loop started in background thread")
        print("[MQTT] Waiting for connection callback...")
        print("\n⏳ If 'Successfully connected' message doesn't appear:")
        print(f"   → MQTT broker at {MQTT_BROKER} is not accessible")
        print("   → Backend will continue running (MQTT optional)")
        print("   → Check troubleshooting section below\n")
    except Exception as e:
        print("\n" + "=" * 60)
        print("❌ MQTT CONNECTION EXCEPTION")
        print("=" * 60)
        print(f"Error: {e}")
        print(f"Error Type: {type(e).__name__}")
        print(f"Broker: {MQTT_BROKER}:{MQTT_PORT}")
        print("\n⚠️  TROUBLESHOOTING:")
        print(f"  1. Check if MQTT broker is running at {MQTT_BROKER}")
        print(f"  2. Test connectivity: ping {MQTT_BROKER}")
        print("  3. Verify port 1883 is not blocked by firewall")
        print("  4. Check if broker is on same network")
        print("")
        print("💡 TIP: You can still test with:")
        print("   • Run Mosquitto broker on this machine")
        print("   • Change MQTT_BROKER to 'localhost'")
        print("   • Use a public broker: test.mosquitto.org")
        print("=" * 60 + "\n")
        # This allows the app to continue starting even if MQTT fails,
        # but you'll get errors. Consider if you should exit() here.
        # For now, just print the error.
        pass


def stop_mqtt():
    """Disconnects MQTT client."""
    try:
        print("Stopping MQTT client loop...")
        mqtt_client.loop_stop()
        mqtt_client.disconnect()
        print("MQTT client disconnected.")
    except Exception as e:
        print(f"Error stopping MQTT client: {e}")


# --- MQTT Publishing Functions (Unchanged) ---
def publish_pump_on():
    print(f"[{datetime.now()}] MQTT: Publishing ON")
    mqtt_client.publish(MQTT_PUMP_COMMAND_TOPIC, "ON")

    # Broadcast pump state change to WebSocket clients immediately
    websocket_message = {
        "type": "pump_command",
        "command": "ON",
        "timestamp": datetime.now(SAST_TIMEZONE).isoformat()
    }
    message_queue.put(websocket_message)
    print(f"[WS] Pump ON command queued for broadcast to {len(manager.active_connections)} clients")


def publish_pump_off():
    print(f"[{datetime.now()}] MQTT: Publishing OFF")
    mqtt_client.publish(MQTT_PUMP_COMMAND_TOPIC, "OFF")

    # Broadcast pump state change to WebSocket clients immediately
    websocket_message = {
        "type": "pump_command",
        "command": "OFF",
        "timestamp": datetime.now(SAST_TIMEZONE).isoformat()
    }
    message_queue.put(websocket_message)
    print(f"[WS] Pump OFF command queued for broadcast to {len(manager.active_connections)} clients")


# --- Action History Helper Functions ---
def log_pump_action(action_type, trigger_source, details=None):
    """
    Log a pump action to history.

    Args:
        action_type: 'ON' or 'OFF'
        trigger_source: 'manual', 'automation', 'schedule'
        details: Optional dict with additional info (moisture level, threshold, schedule info, etc.)
    """
    global action_history

    action = {
        'timestamp': datetime.now(SAST_TIMEZONE).isoformat(),
        'action': action_type,
        'trigger': trigger_source,
        'details': details or {}
    }

    action_history.append(action)

    # Limit history size
    if len(action_history) > MAX_HISTORY_SIZE:
        action_history.pop(0)

    print(f"[ACTION HISTORY] Logged: {action_type} by {trigger_source}")

    # Also log to audit API for persistence
    description = f"Pump {action_type}"
    if trigger_source == 'automation':
        description += f" (Auto: Moisture {details.get('moisture', 'N/A')}% < {details.get('threshold', 'N/A')}%)"
    elif trigger_source == 'schedule':
        description += f" (Scheduled: {details.get('schedule_info', '')})"
    else:
        description += f" (Manual)"

    log_to_audit_api(description, user=trigger_source)


# --- Scheduling Functions ---
def scheduled_pump_on(duration_minutes, schedule_info=""):
    """
    Function to be called by scheduler.
    Turns pump ON and schedules it to turn OFF after duration.
    """
    global automation_pump_state

    if not scheduling_enabled:
        print("Scheduling is disabled, skipping scheduled pump ON")
        return

    print(f"[SCHEDULE] Turning pump ON for {duration_minutes} minutes")

    # Reset automation state since schedule takes over
    automation_pump_state = False

    publish_pump_on()

    # Log action to history
    log_pump_action('ON', 'schedule', {
        'duration': duration_minutes,
        'schedule_info': schedule_info
    })

    # Schedule the pump to turn off after duration using a delayed job
    # Calculate the exact time to turn off
    off_time = datetime.now(SAST_TIMEZONE) + timedelta(minutes=duration_minutes)
    off_time_str = off_time.strftime("%H:%M:%S")

    # Use schedule to turn off after the specified duration
    schedule.every().day.at(off_time_str).do(scheduled_pump_off).tag(f'auto_off_{datetime.now().timestamp()}')


def scheduled_pump_off():
    """Function to be called by scheduler to turn pump OFF."""
    print("[SCHEDULE] Turning pump OFF (scheduled)")
    publish_pump_off()

    # Log action to history
    log_pump_action('OFF', 'schedule', {
        'reason': 'duration_completed'
    })

    return schedule.CancelJob  # Remove this one-time job


def add_schedule_job(day, time_str, duration_minutes):
    """
    Adds a recurring schedule job.
    day: 'monday', 'tuesday', etc., or 'everyday'
    time_str: 'HH:MM' format (24-hour)
    duration_minutes: how long to run pump
    """
    global next_job_id, active_schedules

    job_id = next_job_id
    next_job_id += 1

    schedule_info = f"{day} at {time_str} for {duration_minutes}min"

    # Create the schedule based on day
    day_lower = day.lower()
    if day_lower == 'everyday':
        job = schedule.every().day.at(time_str).do(scheduled_pump_on, duration_minutes, schedule_info)
    elif day_lower == 'monday':
        job = schedule.every().monday.at(time_str).do(scheduled_pump_on, duration_minutes, schedule_info)
    elif day_lower == 'tuesday':
        job = schedule.every().tuesday.at(time_str).do(scheduled_pump_on, duration_minutes, schedule_info)
    elif day_lower == 'wednesday':
        job = schedule.every().wednesday.at(time_str).do(scheduled_pump_on, duration_minutes, schedule_info)
    elif day_lower == 'thursday':
        job = schedule.every().thursday.at(time_str).do(scheduled_pump_on, duration_minutes, schedule_info)
    elif day_lower == 'friday':
        job = schedule.every().friday.at(time_str).do(scheduled_pump_on, duration_minutes, schedule_info)
    elif day_lower == 'saturday':
        job = schedule.every().saturday.at(time_str).do(scheduled_pump_on, duration_minutes, schedule_info)
    elif day_lower == 'sunday':
        job = schedule.every().sunday.at(time_str).do(scheduled_pump_on, duration_minutes, schedule_info)
    else:
        raise ValueError(f"Invalid day: {day}")

    # Store the job info
    active_schedules[job_id] = {
        'job': job,
        'day': day_lower,
        'time': time_str,
        'duration': duration_minutes
    }

    print(f"Added schedule #{job_id}: {day} at {time_str} for {duration_minutes} min")
    return job_id


def remove_schedule_job(job_id):
    """Removes a schedule job by ID."""
    global active_schedules

    if job_id not in active_schedules:
        raise ValueError(f"Schedule #{job_id} not found")

    # Cancel the schedule job
    schedule.cancel_job(active_schedules[job_id]['job'])

    # Remove from our tracking
    job_info = active_schedules.pop(job_id)
    print(f"Removed schedule #{job_id}: {job_info['day']} at {job_info['time']}")
    return job_info


def get_all_schedules():
    """Returns list of all active schedules."""
    return [
        {
            'id': job_id,
            'day': info['day'],
            'time': info['time'],
            'duration': info['duration']
        }
        for job_id, info in active_schedules.items()
    ]


# --- Schedule Runner ---
def run_schedule():
    """Runs pending scheduled jobs."""
    while True:
        schedule.run_pending()
        time.sleep(1)


scheduler_thread = threading.Thread(target=run_schedule, daemon=True)


# --- FastAPI Path Operations (API Endpoints) ---

@app.get("/")
async def root(request: Request):
    """Root endpoint for health check and API documentation"""
    client_info = f"{request.client.host}:{request.client.port}" if request.client else "unknown"
    print(f"[HTTP] GET / from {client_info}")
    
    response = {
        "message": "AquaLink Irrigation Backend API",
        "status": "running",
        "version": "2.0.0",
        "mqtt_connected": mqtt_client.is_connected() if mqtt_client else False,
        "endpoints": {
            "control": {
                "turn_on": "POST /control/turn_on",
                "turn_off": "POST /control/turn_off",
                "automation_toggle": "POST /control/automation_toggle"
            },
            "api": {
                "automation_status": "GET /api/automation_status",
                "update_threshold": "POST /api/automation/threshold",
                "alerts": "GET /api/alerts?limit=20",
                "action_history": "GET /api/action_history?limit=50",
                "data": "GET /api/data?range=hour|day|week|month",
                "daily_stats": "GET /api/daily_stats"
            },
            "schedule": {
                "list": "GET /api/schedule/list",
                "add": "POST /api/schedule/add",
                "remove": "POST /api/schedule/remove",
                "toggle": "POST /api/schedule/toggle"
            },
            "websocket": "WS /ws"
        }
    }
    print(f"[HTTP] Responding to {client_info} with status 200")
    return response


@app.options("/{path:path}")
async def options_handler(path: str):
    """Handle CORS preflight requests from browsers like Chrome"""
    return {}


@app.post("/control/turn_on")
async def api_flutter_on():
    global automation_pump_state
    print("Received API command: ON.")

    # Reset automation state since manual control takes over
    automation_pump_state = False

    # Log the manual action
    log_pump_action('ON', 'manual', {
        'reason': 'user_request'
    })

    publish_pump_on()
    return {"status": "success", "command": "on"}


@app.post("/control/turn_off")
async def api_flutter_off():
    global automation_pump_state
    print("Received API command: OFF.")

    # Reset automation state since manual control takes over
    automation_pump_state = False

    # Log the manual action
    log_pump_action('OFF', 'manual', {
        'reason': 'user_request'
    })

    publish_pump_off()
    return {"status": "success", "command": "off"}


@app.post("/control/automation_toggle")
async def api_toggle_automation(request: Request):
    global automation_enabled
    try:
        data = await request.json()
        new_state = data.get('enable')
        if new_state is not None:
            automation_enabled = bool(new_state)
            # This now uses the corrected function
            log_to_audit_api(f"Automation set to {automation_enabled}", user="api_user")
            print(f"Automation state set to: {automation_enabled}")
            # Broadcast new status to connected clients
            await manager.broadcast({"type": "automation_status", "enabled": automation_enabled})
            return {"status": "success", "automation_enabled": automation_enabled}
        else:
            raise HTTPException(status_code=400, detail="Missing 'enable' field")
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON body")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "mqtt_connected": mqtt_client.is_connected(),
        "automation_enabled": automation_enabled,
        "device_id": device_db_id
    }


@app.get("/api/automation_status")
async def api_get_automation_status():
    return {
        "automation_enabled": automation_enabled,
        "min_moisture_threshold": MIN_MOISTURE_THRESHOLD,
        "max_moisture_threshold": MAX_MOISTURE_THRESHOLD,
        "moisture_threshold": MIN_MOISTURE_THRESHOLD,  # Backward compatibility
        "current_moisture": last_known_moisture,
        "automation_pump_state": automation_pump_state
    }


@app.post("/api/automation/threshold")
async def api_update_threshold(request: Request):
    """Update moisture thresholds for automation (supports both single and dual threshold modes)."""
    global MIN_MOISTURE_THRESHOLD, MAX_MOISTURE_THRESHOLD
    try:
        data = await request.json()
        
        # Support both old single threshold and new dual threshold
        min_threshold = data.get('min_threshold') or data.get('threshold')
        max_threshold = data.get('max_threshold')

        if min_threshold is None:
            raise HTTPException(status_code=400, detail="Missing 'min_threshold' or 'threshold' field")

        min_threshold = float(min_threshold)
        if min_threshold < 0 or min_threshold > 100:
            raise HTTPException(status_code=400, detail="Min threshold must be between 0 and 100")
        
        # If max_threshold provided, validate it
        if max_threshold is not None:
            max_threshold = float(max_threshold)
            if max_threshold < 0 or max_threshold > 100:
                raise HTTPException(status_code=400, detail="Max threshold must be between 0 and 100")
            if max_threshold <= min_threshold:
                raise HTTPException(status_code=400, detail="Max threshold must be greater than min threshold")
        else:
            # If only min provided, keep current max or use default
            max_threshold = MAX_MOISTURE_THRESHOLD

        old_min = MIN_MOISTURE_THRESHOLD
        old_max = MAX_MOISTURE_THRESHOLD
        MIN_MOISTURE_THRESHOLD = min_threshold
        MAX_MOISTURE_THRESHOLD = max_threshold

        log_to_audit_api(
            f"Moisture thresholds updated: MIN {old_min}% → {min_threshold}%, MAX {old_max}% → {max_threshold}%", 
            user="api_user"
        )
        print(f"[THRESHOLD] Moisture thresholds updated:")
        print(f"[THRESHOLD]   MIN: {old_min}% → {min_threshold}% (Pump turns ON)")
        print(f"[THRESHOLD]   MAX: {old_max}% → {max_threshold}% (Pump turns OFF)")

        return {
            "status": "success",
            "message": f"Thresholds updated: Pump ON ≤{min_threshold}%, OFF ≥{max_threshold}%",
            "min_threshold": MIN_MOISTURE_THRESHOLD,
            "max_threshold": MAX_MOISTURE_THRESHOLD,
            "threshold": MIN_MOISTURE_THRESHOLD  # Backward compatibility
        }
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid threshold value")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/action_history")
async def api_get_action_history(limit: int = 50):
    """
    Get pump action history.

    Query params:
        limit: Maximum number of actions to return (default 50, max 100)
    """
    try:
        # Limit the number of returned actions
        limit = min(limit, 100)

        # Return most recent actions first
        recent_actions = action_history[-limit:]
        recent_actions.reverse()  # Most recent first

        return {
            "status": "success",
            "count": len(recent_actions),
            "actions": recent_actions
        }
    except Exception as e:
        print(f"Error fetching action history: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/alerts")
async def api_get_alerts(limit: int = 20):
    """
    Generate alerts from action history and system state.

    Alert types:
    - Low moisture warnings (automation triggers)
    - Schedule completions
    - Manual interventions
    - System status updates
    """
    try:
        alerts = []

        # Get recent actions for alert generation
        recent_limit = min(limit * 2, 50)  # Get more actions to generate alerts from
        recent_actions = action_history[-recent_limit:] if action_history else []
        recent_actions.reverse()  # Most recent first

        for action in recent_actions:
            alert_type = "info"
            title = ""
            severity = "INFO"

            # Generate alert based on action type and trigger
            if action['trigger'] == 'automation':
                if action['action'] == 'ON':
                    alert_type = "warning"
                    severity = "WARNING"
                    moisture = action['details'].get('moisture', 'N/A')
                    threshold = action['details'].get('threshold', 'N/A')
                    title = f"Low moisture alert: {moisture}% (threshold: {threshold}%)"
                else:
                    alert_type = "success"
                    severity = "INFO"
                    moisture = action['details'].get('moisture', 'N/A')
                    title = f"Irrigation completed: Moisture now at {moisture}%"

            elif action['trigger'] == 'schedule':
                if action['action'] == 'ON':
                    alert_type = "info"
                    severity = "INFO"
                    schedule_info = action['details'].get('schedule_info', '')
                    title = f"Scheduled irrigation started: {schedule_info}"
                else:
                    alert_type = "success"
                    severity = "INFO"
                    title = "Scheduled irrigation completed successfully"

            elif action['trigger'] == 'manual':
                alert_type = "info"
                severity = "INFO"
                if action['action'] == 'ON':
                    title = "Pump manually activated"
                else:
                    title = "Pump manually deactivated"

            # Create alert object
            alerts.append({
                'id': len(alerts) + 1,
                'type': alert_type,
                'title': title,
                'message': f"Pump {action['action']} triggered by {action['trigger']}",
                'timestamp': action['timestamp'],
                'severity': severity,
                'isRead': False,
                'source': action['trigger']
            })

            # Limit alerts
            if len(alerts) >= limit:
                break

        # Add system status alerts
        if automation_enabled:
            alerts.insert(0, {
                'id': 0,
                'type': 'success',
                'title': 'Soil moisture automation active',
                'message': f'System will irrigate when moisture ≤ {MIN_MOISTURE_THRESHOLD}% and stop at ≥ {MAX_MOISTURE_THRESHOLD}%',
                'timestamp': datetime.now(SAST_TIMEZONE).isoformat(),
                'severity': 'INFO',
                'isRead': True,
                'source': 'system'
            })

        if scheduling_enabled and len(active_schedules) > 0:
            alerts.insert(0, {
                'id': -1,
                'type': 'info',
                'title': f'{len(active_schedules)} irrigation schedule(s) active',
                'message': 'Automated watering schedules are running',
                'timestamp': datetime.now(SAST_TIMEZONE).isoformat(),
                'severity': 'INFO',
                'isRead': True,
                'source': 'system'
            })

        return {
            "status": "success",
            "count": len(alerts),
            "alerts": alerts
        }
    except Exception as e:
        print(f"Error generating alerts: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/data")
async def api_get_data(range: str = 'hour'):  # Use query parameter
    """Fetches historical data for Flutter charts from the APEX API."""
    global device_db_id
    if not device_db_id:
        # Try to get it one last time if it's missing
        # This will now correctly find the ID.
        get_or_create_device_id_api(DEVICE_UNIQUE_ID)
        if not device_db_id:
            # This is the correct behavior: tell the app the device isn't ready.
            # This will resolve itself after the first telemetry message.
            raise HTTPException(status_code=503,
                                detail="Device ID not available yet. Try again after data is received.")

    # This endpoint likely needs the internal 'device_fk'
    api_params = {
        'device_fk': device_db_id,
        'range': range
    }

    try:
        # NOTE: This assumes your GET /telemetry API (which is different from POST)
        # still accepts 'device_fk'. If not, this also needs changing.
        # Based on your previous code, it's assumed this is correct.
        response = requests.get(APEX_TELEMETRY_API, params=api_params, headers=APEX_HEADERS)
        response.raise_for_status()
        data = response.json()

        flow_rate_data = []
        water_used_data = []
        total_volume_data = []
        items = data.get('items', [])

        for item in items:
            try:
                ts_str = item.get('timestamp') or item.get('TIMESTAMP')
                if not ts_str: continue
                # Assuming APEX GET returns this format. Adjust if needed.
                ts_dt = datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S")
                ts_dt_sast = SAST_TIMEZONE.localize(ts_dt)
                ts_ms = int(ts_dt_sast.timestamp() * 1000)

                if item.get('FLOW_RATE') is not None:
                    flow_rate_data.append([ts_ms, item['FLOW_RATE']])
                if item.get('WATER_USED_CYCLE') is not None:
                    water_used_data.append([ts_ms, item['WATER_USED_CYCLE']])
                if item.get('TOTAL_FLOW') is not None:
                    total_volume_data.append([ts_ms, item['TOTAL_FLOW']])

            except (ValueError, TypeError):
                print(f"Skipping bad timestamp from APEX: {ts_str}")
                continue

        return {
            'flow_rate': flow_rate_data,
            'water_used_cycle': water_used_data,
            'total_volume': total_volume_data
        }

    except requests.exceptions.RequestException as api_err:
        print(f"APEX API Error fetching historical data: {api_err}")
        error_detail = f"Database error: {api_err.response.text}" if api_err.response else str(api_err)
        raise HTTPException(status_code=500, detail=error_detail)
    except Exception as e:
        print(f"Error fetching/processing historical data: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve data")


@app.get("/api/daily_stats")
async def api_get_daily_stats():
    """
    Calculates daily water usage statistics.
    Uses in-memory tracking from MQTT data for real-time results.
    Falls back to APEX database if available.
    """
    global daily_start_volume, daily_current_volume, daily_peak_flow, device_db_id

    # PRIMARY METHOD: Use in-memory tracking from MQTT data
    # This gives real-time results without database delays
    if daily_start_volume is not None and daily_current_volume is not None:
        today_usage = max(0, daily_current_volume - daily_start_volume)

        print(f"[DAILY STATS] Using in-memory tracking:")
        print(f"  Start Volume: {daily_start_volume:.2f}L")
        print(f"  Current Volume: {daily_current_volume:.2f}L")
        print(f"  Today's Usage: {today_usage:.2f}L")
        print(f"  Peak Flow: {daily_peak_flow:.2f} L/min")

        # For yesterday's data, we'd need persistent storage
        # For now, return 0 (can be enhanced later with file storage)
        yesterday_usage = 0.0
        change_percent = 100.0 if today_usage > 0 else 0.0

        return {
            'today_usage': round(today_usage, 2),
            'yesterday_usage': round(yesterday_usage, 2),
            'change_percent': round(change_percent, 1),
            'peak_flow_rate': round(daily_peak_flow, 2),
            'data_points': 1,  # We're tracking in real-time
            'current_total': round(daily_current_volume, 2),
            'source': 'real-time'  # Indicate data source
        }

    # FALLBACK METHOD: Try to get data from APEX database
    # This is used if MQTT data isn't available yet
    print("[DAILY STATS] No in-memory data yet, attempting APEX database query...")

    if not device_db_id:
        get_or_create_device_id_api(DEVICE_UNIQUE_ID)
        if not device_db_id:
            # Return zeros if no data available at all
            print("[DAILY STATS] No device ID and no in-memory data. Returning zeros.")
            return {
                'today_usage': 0.0,
                'yesterday_usage': 0.0,
                'change_percent': 0.0,
                'peak_flow_rate': 0.0,
                'data_points': 0,
                'current_total': 0.0,
                'source': 'no-data',
                'message': 'Waiting for first data from ESP32...'
            }

    try:
        # Get today's data from APEX
        today_params = {'device_fk': device_db_id, 'range': 'day'}
        today_response = requests.get(APEX_TELEMETRY_API, params=today_params, headers=APEX_HEADERS)
        today_response.raise_for_status()
        today_data = today_response.json()

        # Calculate today's usage
        today_items = today_data.get('items', [])
        today_usage = 0.0
        today_start_total = None
        today_end_total = None
        peak_flow = 0.0

        print(f"[DAILY STATS] APEX returned {len(today_items)} items for today")

        if today_items:
            # Get first and last total volume readings
            for item in today_items:
                total = item.get('TOTAL_FLOW')
                flow = item.get('FLOW_RATE', 0)

                if total is not None:
                    if today_start_total is None:
                        today_start_total = total
                    today_end_total = total

                if flow and flow > peak_flow:
                    peak_flow = flow

            # Calculate usage as difference
            if today_start_total is not None and today_end_total is not None:
                today_usage = max(0, today_end_total - today_start_total)
                print(
                    f"[DAILY STATS] APEX calculation: {today_start_total:.2f}L -> {today_end_total:.2f}L = {today_usage:.2f}L usage")

        # Get yesterday's data for comparison
        yesterday_params = {'device_fk': device_db_id, 'range': 'yesterday'}
        yesterday_usage = 0.0
        try:
            yesterday_response = requests.get(APEX_TELEMETRY_API, params=yesterday_params, headers=APEX_HEADERS)
            yesterday_response.raise_for_status()
            yesterday_data = yesterday_response.json()
            yesterday_items = yesterday_data.get('items', [])

            yesterday_start = None
            yesterday_end = None

            if yesterday_items:
                for item in yesterday_items:
                    total = item.get('TOTAL_FLOW')
                    if total is not None:
                        if yesterday_start is None:
                            yesterday_start = total
                        yesterday_end = total

                if yesterday_start is not None and yesterday_end is not None:
                    yesterday_usage = max(0, yesterday_end - yesterday_start)
        except Exception as e:
            print(f"[DAILY STATS] Could not get yesterday's data: {e}")
            yesterday_usage = 0.0

        # Calculate percentage change
        if yesterday_usage > 0:
            change_percent = ((today_usage - yesterday_usage) / yesterday_usage) * 100
        else:
            change_percent = 0.0 if today_usage == 0 else 100.0

        return {
            'today_usage': round(today_usage, 2),
            'yesterday_usage': round(yesterday_usage, 2),
            'change_percent': round(change_percent, 1),
            'peak_flow_rate': round(peak_flow, 2),
            'data_points': len(today_items),
            'current_total': round(today_end_total, 2) if today_end_total else 0.0,
            'source': 'database'
        }

    except requests.exceptions.RequestException as api_err:
        print(f"[DAILY STATS] APEX API Error: {api_err}")
        # Return zeros if database query fails
        return {
            'today_usage': 0.0,
            'yesterday_usage': 0.0,
            'change_percent': 0.0,
            'peak_flow_rate': 0.0,
            'data_points': 0,
            'current_total': 0.0,
            'source': 'error',
            'message': 'Database query failed. Data will appear once ESP32 sends updates.'
        }
    except Exception as e:
        print(f"[DAILY STATS] Error: {e}")
        return {
            'today_usage': 0.0,
            'yesterday_usage': 0.0,
            'change_percent': 0.0,
            'peak_flow_rate': 0.0,
            'data_points': 0,
            'current_total': 0.0,
            'source': 'error',
            'message': str(e)
        }


# --- Schedule Management API Endpoints ---

@app.post("/api/schedule/add")
async def api_add_schedule(request: Request):
    """Add a new irrigation schedule."""
    try:
        data = await request.json()
        day = data.get('day')
        time_str = data.get('time')
        duration = data.get('duration')

        print(f"[SCHEDULE API] Received schedule request: day={day}, time={time_str}, duration={duration}")

        # Validation
        if not day:
            raise HTTPException(status_code=400, detail="Missing field: day")
        if not time_str:
            raise HTTPException(status_code=400, detail="Missing field: time")
        if not duration:
            raise HTTPException(status_code=400, detail="Missing field: duration")

        # Validate time format (HH:MM)
        try:
            datetime.strptime(time_str, "%H:%M")
        except ValueError as e:
            print(f"[SCHEDULE API] Invalid time format: {time_str}")
            raise HTTPException(status_code=400,
                                detail=f"Invalid time format '{time_str}'. Use HH:MM (24-hour), e.g., 08:00 or 14:30")

        # Validate day
        valid_days = ['everyday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
        if day.lower() not in valid_days:
            raise HTTPException(status_code=400, detail=f"Invalid day '{day}'. Must be one of: {', '.join(valid_days)}")

        # Validate duration
        try:
            duration_int = int(duration)
            if duration_int < 1 or duration_int > 120:
                raise HTTPException(status_code=400, detail="Duration must be between 1 and 120 minutes")
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail="Duration must be a number")

        # Check if scheduling is enabled
        if not scheduling_enabled:
            print("[SCHEDULE API] Warning: Scheduling is disabled. Schedule added but won't trigger until enabled.")

        # Add the schedule
        print(f"[SCHEDULE API] Adding schedule: {day} at {time_str} for {duration_int} minutes")
        job_id = add_schedule_job(day, time_str, duration_int)
        log_to_audit_api(f"Schedule added: {day} at {time_str} for {duration_int}min", user="api_user")

        print(f"[SCHEDULE API] ✓ Schedule added successfully with job_id={job_id}")

        return {
            "status": "success",
            "message": f"Schedule added successfully for {day} at {time_str}",
            "job_id": job_id,
            "schedule": {
                "id": job_id,
                "day": day,
                "time": time_str,
                "duration": duration_int
            }
        }
    except HTTPException:
        raise
    except ValueError as e:
        print(f"[SCHEDULE API] ValueError: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"[SCHEDULE API] Exception: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")


@app.get("/api/schedule/list")
async def api_list_schedules():
    """Get all active schedules."""
    try:
        schedules = get_all_schedules()
        return {
            "status": "success",
            "scheduling_enabled": scheduling_enabled,
            "jobs": schedules,
            "count": len(schedules)
        }
    except Exception as e:
        print(f"Error listing schedules: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/schedule/remove")
async def api_remove_schedule(request: Request):
    """Remove a schedule by job ID."""
    try:
        data = await request.json()
        job_id = data.get('job_id')

        if job_id is None:
            raise HTTPException(status_code=400, detail="Missing required field: job_id")

        job_info = remove_schedule_job(job_id)
        log_to_audit_api(f"Schedule removed: #{job_id}", user="api_user")

        return {
            "status": "success",
            "message": f"Schedule removed successfully",
            "removed_schedule": job_info
        }
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        print(f"Error removing schedule: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/schedule/toggle")
async def api_toggle_scheduling(request: Request):
    """Enable or disable scheduling system."""
    global scheduling_enabled
    try:
        data = await request.json()
        enable = data.get('enable')

        if enable is None:
            raise HTTPException(status_code=400, detail="Missing required field: enable")

        scheduling_enabled = bool(enable)
        log_to_audit_api(f"Scheduling {'enabled' if scheduling_enabled else 'disabled'}", user="api_user")

        return {
            "status": "success",
            "message": f"Scheduling {'enabled' if scheduling_enabled else 'disabled'}",
            "scheduling_enabled": scheduling_enabled
        }
    except Exception as e:
        print(f"Error toggling scheduling: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# --- FastAPI WebSocket Endpoint ---
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    client_info = f"{websocket.client.host}:{websocket.client.port}" if websocket.client else "unknown"
    print(f"[WEBSOCKET] New connection attempt from {client_info}")

    await manager.connect(websocket)
    print(f"[WEBSOCKET] Client {client_info} connected successfully. Total clients: {len(manager.active_connections)}")

    try:
        while True:
            # Keep connection alive, receive ping messages
            try:
                message = await websocket.receive_text()
                if message == "ping":
                    await websocket.send_text("pong")
            except:
                pass
    except WebSocketDisconnect:
        print(f"[WEBSOCKET] Client {client_info} disconnected")
        manager.disconnect(websocket)
    except Exception as e:
        print(f"[WEBSOCKET] Error with client {client_info}: {e}")
        manager.disconnect(websocket)

    print(f"[WEBSOCKET] Connection closed for {client_info}. Remaining clients: {len(manager.active_connections)}")


# --- Background Task for Broadcasting WebSocket Messages ---
async def websocket_broadcaster():
    """ Periodically checks the queue and broadcasts messages. """
    print("[WEBSOCKET] Broadcaster task started.")
    message_count = 0

    while True:
        try:
            # Check if queue has messages (non-blocking)
            if not message_queue.empty():
                try:
                    # Get message from queue (non-blocking)
                    message = message_queue.get_nowait()

                    if message:
                        message_count += 1
                        # Log every message for debugging
                        print(
                            f"[WEBSOCKET] Broadcasting message #{message_count} type={message.get('type')} to {len(manager.active_connections)} clients")

                        await manager.broadcast(message)
                        message_queue.task_done()

                except queue.Empty:
                    pass

            # Small sleep to prevent busy-waiting
            await asyncio.sleep(0.1)

        except Exception as e:
            print(f"[WEBSOCKET] Error in broadcaster: {e}")
            import traceback
            traceback.print_exc()
            await asyncio.sleep(1)


# --- FastAPI Startup and Shutdown Events ---
@app.on_event("startup")
async def startup_event():
    print("FastAPI app starting up...")
    # Try to get device ID at startup.
    # This will now correctly find the ID.
    get_or_create_device_id_api(DEVICE_UNIQUE_ID)

    # Start MQTT client
    # This is wrapped in a try/except so a failed MQTT connection
    # doesn't block the entire server from starting.
    try:
        setup_mqtt()
    except Exception as e:
        print(f"CRITICAL: Failed to setup MQTT on startup: {e}")

    # Start the scheduler thread
    if not scheduler_thread.is_alive():
        print("Starting scheduler thread...")
        scheduler_thread.start()

    # Start the WebSocket broadcaster task
    asyncio.create_task(websocket_broadcaster())

    # This message should now be reached.
    print("Startup complete.")
    print("")
    print("=" * 60)
    print("🌐 BACKEND ACCESS URLS")
    print("=" * 60)
    print(f"Localhost:      http://localhost:8000")
    print(f"                ws://localhost:8000/ws")
    print(f"All Interfaces: http://0.0.0.0:8000")
    print("=" * 60)
    print("📱 Flutter Web: Use http://localhost:8000")
    print("📱 Flutter Mobile (emulator): Use http://10.0.2.2:8000")
    print("📱 Flutter Mobile (device): Use your PC's IP address")
    print("=" * 60)
    print("")


@app.on_event("shutdown")
def shutdown_event():
    print("FastAPI app shutting down...")
    stop_mqtt()
    # No explicit stop needed for daemon thread (scheduler)
    print("Shutdown complete.")


# --- Main Execution ---
if __name__ == "__main__":
    print(f"Starting FastAPI server...")
    # Use Uvicorn to run the app
    # reload=True is useful for development, disable for production
    uvicorn.run("backend_fastapi5:app", host="0.0.0.0", port=8000, reload=True)
    # If your filename is different than 'main.py', change "main:app" accordingly.
    # e.g., if filename is 'backend_fastapi.py', use "backend_fastapi:app"