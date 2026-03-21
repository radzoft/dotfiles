#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyserial"]
# ///

import time
import subprocess
import serial # Import the pyserial library for wired communication
import re
import glob

# --- Serial Port Configuration ---
# IMPORTANT: The script will now auto-detect available /dev/ttyUSB* devices before each connection attempt.
# You can still override this by setting a specific port if needed.
SERIAL_PORT = None  # Will be set dynamically
BAUD_RATE = 921600 # Must match the Serial.begin() baud rate in your Arduino sketch

# --- Microphone Status Monitoring Configuration ---
PACTL_CMD = ['pactl', 'get-source-mute', '@DEFAULT_SOURCE@']

# --- Global Variables for State Tracking ---
current_mic_muted = None
serial_connection = None # Renamed from bluetooth_socket to serial_connection

# --- Connection Retry Configuration ---
RETRY_DELAY_SECONDS = 5 # How long to wait before retrying connection

# --- RAM Monitoring Thresholds ---
RAM_WARN_THRESHOLD_GB = 7.0   # Send MEM:WARN when available RAM drops below this
RAM_CRIT_THRESHOLD_GB = 4.0   # Send MEM:CRIT when available RAM drops below this

def get_microphone_mute_status():
    """
    Retrieves the current mute status of the default microphone using pactl.
    Returns True if muted, False if unmuted, or None if status cannot be determined.
    """
    try:
        result = subprocess.run(PACTL_CMD, capture_output=True, text=True, check=True)
        output = result.stdout.strip()

        if "Mute: yes" in output:
            return True
        elif "Mute: no" in output:
            return False
        else:
            print(f"Warning: Unexpected pactl output: {output}")
            return None
    except FileNotFoundError:
        print("Error: 'pactl' command not found. Is PulseAudio installed and in your PATH?")
        print("Please ensure PulseAudio is running and 'pactl' is accessible.")
        return None
    except subprocess.CalledProcessError as e:
        print(f"Error running pactl command: {e}")
        print(f"Stdout: {e.stdout}")
        print(f"Stderr: {e.stderr}")
        return None
    except Exception as e:
        print(f"An unexpected error occurred while checking mic status: {e}")
        return None

def send_command_to_ttgo(command):
    """
    Sends a command string to the TTGO via the serial port.
    Appends a newline character as the Arduino sketch reads until newline.
    If the serial connection is not active, it attempts to reconnect.
    """
    global serial_connection
    
    # Ensure connection before sending
    if not serial_connection or not serial_connection.is_open:
        print("Serial connection not active. Attempting to connect...")
        if not connect_serial_blocking(): # Use the blocking connect
            print("Failed to establish serial connection. Command not sent.")
            return

    try:
        full_command = f"{command}\n"
        serial_connection.write(full_command.encode('utf-8')) # Encode string to bytes
        #print(f"Sent command: '{command}' via Serial")
        time.sleep(0.05) # Small delay to ensure command is sent
        
        # Read and print any response from the TTGO for debugging (optional)
        while serial_connection.in_waiting:
            response = serial_connection.readline().decode('utf-8').strip()
            if response:
                print(f"TTGO response (Serial): {response}")

    except serial.SerialException as e:
        print(f"Serial communication error during send: {e}")
        if serial_connection:
            try:
                serial_connection.close()
            except Exception as close_e:
                print(f"Error closing serial port after send error: {close_e}")
        serial_connection = None # Mark as disconnected, next send will trigger reconnect
    except Exception as e:
        print(f"An unexpected error occurred while sending command via Serial: {e}")

def find_available_ttyusb():
    """
    Returns the first available /dev/ttyUSB* device, or None if none found.
    If multiple devices are found, returns the first one (sorted).
    """
    devices = sorted(glob.glob('/dev/ttyUSB*'))
    if devices:
        print(f"Available ttyUSB devices: {devices}")
        return devices[0]
    else:
        print("No /dev/ttyUSB* devices found.")
        return None

def connect_serial_blocking():
    """
    Establishes or re-establishes the serial connection to the TTGO.
    This function blocks and retries until a connection is successful.
    Returns True on successful connection, False if script is interrupted.
    """
    global serial_connection
    global SERIAL_PORT
    if serial_connection and serial_connection.is_open:
        try:
            serial_connection.close()
        except Exception as e:
            print(f"Error closing existing serial connection: {e}")
        serial_connection = None

    while serial_connection is None or not serial_connection.is_open:
        SERIAL_PORT = find_available_ttyusb()
        if not SERIAL_PORT:
            print(f"No serial device found. Retrying in {RETRY_DELAY_SECONDS} seconds...")
            time.sleep(RETRY_DELAY_SECONDS)
            continue
        print(f"Attempting to connect to serial port {SERIAL_PORT}...")
        try:
            serial_connection = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
            print(f"Successfully connected to {SERIAL_PORT} at {BAUD_RATE} baud.")
            time.sleep(1) # Small delay after connecting, for Arduino to initialize
            return True # Connection successful
        except serial.SerialException as e:
            print(f"Failed to connect to serial port {SERIAL_PORT}: {e}. Retrying in {RETRY_DELAY_SECONDS} seconds...")
            serial_connection = None # Ensure serial_connection is None if connection failed
            time.sleep(RETRY_DELAY_SECONDS)
        except KeyboardInterrupt:
            print("\nConnection attempt interrupted by user.")
            return False # User interrupted
        except Exception as e:
            print(f"An unexpected error occurred during serial connection attempt: {e}. Retrying in {RETRY_DELAY_SECONDS} seconds...")
            serial_connection = None
            time.sleep(RETRY_DELAY_SECONDS)

import subprocess
import re
import sys

def get_sensors_temperatures():
    """
    Executes the 'sensors' command, parses its output, and returns
    a list of all valid temperature readings found, excluding thresholds and 0.0°C.

    Returns:
        list: A list of float values representing current temperatures.
              Returns an empty list if the 'sensors' command fails or no temperatures are found.
    """
    temperatures = []
    try:
        # Execute the 'sensors' command
        # universal_newlines=True is deprecated, use text=True for Python 3.7+
        # encoding='utf-8' is a good practice for cross-platform compatibility
        process = subprocess.run(['sensors'], capture_output=True, text=True, check=True, encoding='utf-8')
        output = process.stdout

        # Regular expression to find temperature values like "+XX.X°C"
        # This pattern captures the numerical part ([+-]?\d+\.?\d*)
        temp_pattern = re.compile(r'([+-]?\d+\.?\d*)°C')

        # Keywords that indicate a threshold reading (to be ignored)
        threshold_keywords = ["(low =", "(high =", "(crit =", "(crit low ="]

        for line in output.splitlines():
            # Check if the line contains any threshold keyword first
            is_threshold_line = any(keyword in line for keyword in threshold_keywords)

            if is_threshold_line:
                # print(f"Info: Skipping threshold line: {line.strip()}"), file=sys.stderr) # For debugging
                continue # Skip this line entirely if it's a threshold definition

            match = temp_pattern.search(line)
            if match:
                try:
                    # Extract the numerical part of the temperature
                    temp_str = match.group(1)
                    temp_value = float(temp_str)
                    # Exclude 0.0 degrees as requested
                    if temp_value != 0.0:
                        temperatures.append(temp_value)
                except ValueError:
                    pass

    except FileNotFoundError:
        print("Error: 'sensors' command not found. Please ensure lm-sensors is installed.", file=sys.stderr)
    except subprocess.CalledProcessError as e:
        print(f"Error executing 'sensors' command: {e}", file=sys.stderr)
        print(f"Stderr: {e.stderr}", file=sys.stderr)
    except Exception as e:
        print(f"An unexpected error occurred: {e}", file=sys.stderr)

    return temperatures

def get_max_avg_temperature():
    """
    Gets all current CPU temperature readings, then calculates and returns
    the maximum and average temperatures.

    Returns:
        tuple: A tuple (max_temp, avg_temp) as floats.
               Returns (0.0, 0.0) if no valid temperatures are found.
    """
    all_temps = get_sensors_temperatures()

    if not all_temps:
        print("No valid temperature readings found.", file=sys.stderr)
        return 0.0, 0.0 # Return default values if no temps

    max_temp = max(all_temps)
    avg_temp = sum(all_temps) / len(all_temps)

    return (max_temp, avg_temp)

def get_available_ram_gb():
    """
    Returns available RAM in GB by reading /proc/meminfo (MemAvailable).
    Returns None if the value cannot be determined.
    """
    try:
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                if line.startswith('MemAvailable:'):
                    kb = int(line.split()[1])
                    return kb / (1024 * 1024)  # Convert kB to GB
    except Exception as e:
        print(f"Error reading /proc/meminfo: {e}", file=sys.stderr)
    return None

# --- Main Logic ---
if __name__ == "__main__":
    # Initial connection attempt - now blocking until successful
    print("Starting initial serial connection...")
    if not connect_serial_blocking():
        exit("Exiting due to user interruption during connection.")

    print("Monitoring microphone status...")
    last_mic_muted = None

    skipped_count = 0
    mic_muted_start_time = None  # Track when mic was first muted
    last_temp_sent_time = 0   # Track last time temps were sent
    last_time_sent = None
    last_mem_level = None  # Track last sent memory level: None, 'OK', 'WARN', 'CRIT'

    try:
        while True:
            # Check if serial connection is still valid before checking mic and sending commands
            if not serial_connection or not serial_connection.is_open:
                print("Serial connection disconnected. Attempting to reconnect...")

                # Reset values
                last_mic_muted = None
                mic_muted_start_time = None
                last_temp_sent_time = 0
                last_time_sent = None
                last_mem_level = None
                skipped_count = 0

                if not connect_serial_blocking(): # Reconnect if disconnected
                    print("Failed to re-establish serial connection. Skipping command send.")
                    time.sleep(RETRY_DELAY_SECONDS) # Prevent rapid retries if connection keeps failing
                    continue # Skip current loop iteration, try again next time

            current_mic_muted = get_microphone_mute_status()
            now = time.time()
            commands = []
            if current_mic_muted is not None:
                if current_mic_muted:
                    commands.append('MIC:OFF')
                    mic_muted_start_time = now  # Start timer for temp sending
                else:
                    commands.append('MIC:ON')
                    mic_muted_start_time = None
                last_mic_muted = current_mic_muted
                
            # if last_time_sent is None or (now - last_time_sent) >= 10:
            #     current_time = time.localtime()
            #     commands.append(f"TIME:{current_time.tm_hour}:{current_time.tm_min:02d}")
                
            #     last_temp_sent_time = now

            if now - last_temp_sent_time >= 2:
                last_temp_sent_time = now
                max_temp, avg_temp = get_max_avg_temperature()
                commands.append(f"TEMP:{max_temp:.1f}:{avg_temp:.1f}")

            available_ram = get_available_ram_gb()
            if available_ram is not None:
                if available_ram < RAM_CRIT_THRESHOLD_GB:
                    mem_level = 'CRIT'
                elif available_ram < RAM_WARN_THRESHOLD_GB:
                    mem_level = 'WARN'
                else:
                    mem_level = 'OK'
                if mem_level != last_mem_level:
                    commands.append(f"MEM:{mem_level}")
                    last_mem_level = mem_level

            for command in commands:
                send_command_to_ttgo(command)
            time.sleep(0.1) # Check mic status every 0.2 seconds

    except KeyboardInterrupt:
        print("\nMonitoring stopped by user.")
    except Exception as e:
        print(f"An unexpected error occurred in the main loop: {e}")
    finally:
        if serial_connection:
            try:
                serial_connection.close()
            except Exception as e:
                print(f"Error closing serial port on exit: {e}")
            print("Serial port closed.")

