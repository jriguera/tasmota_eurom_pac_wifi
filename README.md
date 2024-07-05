# Eurom PAC Wifi Airco Serial Protocol

These are the results of reverse engineering the serial RS232 protocol used in Eurom PAC 12.2 Wifi & PAC 14.2 Wifi products between the Wi-Fi module which takes care of network and software features and the MCU which controls the hardware based on commands received from the Wi-Fi module or built-in controls (buttons, switches, remotes and similar) and reports the status back to the Wi-Fi module. 

## About EUROM PAC Wifi

Note those are discontinued products by [Eurom](https://eurom.nl/). They have been superseded by new products with similar functionalities.
But, the manuals of the Eurom PAC Wifi, are still available: https://eurom.nl/wp-content/themes/eurom/images/downloads/438543_380439380446PAC12.214.2WifiNL-EN-DE-FRversie1.pdf

The current products have the same front panel as the previous ones and they can be managed with the same application. The [list of mobile air conditioning products using WIFI](https://eurom.nl/en/product-category/climate-control/mobile-airconditioners/?filter_bediening=eurom-smart-app-en&query_type_bediening=or) with (Eurom Smart App)[https://eurom.nl/smart-home/eurom-smart-app/]. 

Most likely other Eurom mobile air conditioning units can be compatible with this protocol -even if they use a different ESP for WIFI- but it was not tested. If somebody wants to try, please report it back here, thanks!

## Note

Use this information at your own risk. We don't take any responsibility nor liability for using this information.

## Setup

The hardware and setup used to reverse engineering the protocol is described in [setup.md](setup.md)

The MCU connector:

![Eurom MCU connection](eurom_mcu5.jpg)

From the previous setup, it is trivial to transplant the original ESP (and keep it safe) and put a new ESP flashed with [Tasmota](https://tasmota.github.io/docs/)  or any other open firmware.

## Protocol Specs

The description of the serial protocol is in [protocol.md](protocol.md).

Thanks to [CemDK](https://github.com/CemDK) for helping me decoding the checksum algorithm used in the serial communication


## Tasmota configuration with ESP32 using a Berry Driver

### 1. Using [ESP32 S2 Mini](https://www.wemos.cc/en/latest/s2/s2_mini.html) and after [flash it with Tasmota](https://templates.blakadder.com/s2_mini.html)
```
esptool.py  write_flash 0x0 tasmota32s2.factory.bin
```

### 2. Load this template which defines the `gpio.TX` and `gpio.RX` pins for the Driver
```
{"NAME":"Eurom PAC 12.2 WiFi","GPIO":[32,0,0,0,0,3232,0,3200,0,0,0,0,0,0,0,576,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```

![ESP32s2 Template](esp32s2_template1.png "ESP32s2 Template")

* `GPIO#5` is for `Serial RX`
* `GPIO#7` is for `Serial TX`

### 3. Load the Driver [EuromPacWifi.be](./esp32/EuromPacWifi.be) and [autoexec](./esp32/autoexec.be) files from `/esp32` [folder](./esp32/)

![ESP32s2 FS](esp32s2_fs.png "ESP32s2 FS")

Automatically the Tasmota web will become:

![ESP32s2 FS](esp32s2_driver.png "ESP32s2 FS")


### 4. Home Assistant

Setup the MQTT settings in Tasmota and put this in the HA configuration file:
```
mqtt:
  - climate:
      name: "EuromAirco"
      unique_id: tasmota_eurom_pac_wifi
      max_temp: 31.0
      min_temp: 16.0
      min_humidity: 30
      max_humidity: 90
      precision: 1.0
      optimistic: false
      temperature_unit: C
      modes:
        - "off"
        - "cool"
        - "dry"
        - "fan_only"
      swing_modes:
        - "on"
        - "off"
      fan_modes:
        - "high"
        - "medium"
        - "low"
      power_command_topic: "cmnd/MobileAirco/power"
      availability_topic: tele/MobileAirco/LWT
      payload_available: Online
      payload_not_available: Offline
      action_topic: "tele/MobileAirco/RESULT"
      action_template: "{{value_json['hvac_action']}}"
      mode_command_topic: "cmnd/MobileAirco/mode"
      mode_state_topic: "tele/MobileAirco/RESULT"
      mode_state_template: "{{value_json['hvac_mode']}}"
      target_humidity_command_topic: "cmnd/MobileAirco/humidity"
      target_humidity_state_topic: "tele/MobileAirco/RESULT"
      target_humidity_state_template: "{{value_json['target_humidity']}}"
      temperature_command_topic: "cmnd/MobileAirco/temperature"
      temperature_state_topic: "tele/MobileAirco/RESULT"
      temperature_state_template: "{{value_json['target_temperature']}}"
      fan_mode_command_topic:  "cmnd/MobileAirco/fan"
      fan_mode_state_topic: "tele/MobileAirco/RESULT"
      fan_mode_state_template: "{{value_json['fan_mode']}}"
      swing_mode_command_topic:  "cmnd/MobileAirco/swing"
      swing_mode_state_topic: "tele/MobileAirco/RESULT"
      swing_mode_state_template: "{{value_json['swing_mode']}}"
      json_attributes_topic: "tele/MobileAirco/RESULT"
      json_attributes_template: "{{ value_json | tojson }}"
      current_temperature_topic: "tele/MobileAirco/RESULT"
      current_temperature_template: "{{value_json['current_temperature']}}"
      current_humidity_topic: "tele/MobileAirco/RESULT"
      current_humidity_template: "{{value_json['current_humidity']}}"
```

![EuronHA1](eurom_ha1.png)
![EuronHA2](eurom_ha2.png)
![EuronHA3](eurom_ha3.png)


Debugging MQTT
```
mosquitto_sub -u ha -P password  -v -h localhost -p 1883 -t '#'
mosquitto_pub  -h localhost -p 1883 -u ha -P password -t 'cmnd/MobileAirco/mode' -m "cool"
```


## Tasmota configuration with ESP 8266 using Serial bridge

Using [Adafruit HUZZAH ESP 8266 module](https://templates.blakadder.com/adafruit_HUZZAH.html) to enable Serial Bridge [Serial commands](https://tasmota.github.io/docs/Commands/#rf-bridge) on the console.

RX and TX are the serial control and bootloading pins, and they are being used for flashing the device

* The TX pin is the output from the HUZZAH module and is 3.3V logic.
* The RX pin is the input into the HUZZAH module and is 5V compliant (there is a level shifter on this pin)

To control the Airco, I am using software serial on the these GPIO pins used for serial transmit:

 * `GPIO#4` is for `SerBr TX`
 * `GPIO#5` is for `SerBr RX`

![Tasmota Serial config](tasmota-serialbridge.png)

The ESP HUZZAH module connections:

![ESP](esp.jpg)


Based on these settings, this is the template used for experiments:

```
{"NAME":"Eurom PAC","GPIO":[32,0,320,0,1792,1824,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":18}
```

![Tasmota Template](tasmota-settings.png)

### About serial modes and Tasmota

Hardware Serial Bridge uses GPIO1 (Tx) and GPIO3 (Rx) or GPIO15 (Tx) and GPIO13 (Rx) pins of your device. Software Serial Bridge can use any other GPIO to be configured as components Serial Tx and Serial Rx (or `SerBr Tx` and `SerBr Rx`). 

In the console:
```
# Using Software serial. 
# set the baudrate and 8N1
Backlog SBaudrate 9600; SSerialConfig 3
# Disable hardware serial
SerialLog 0
# Disable serial delimiter to see the hex message
SerialDelimiter 254
# Check status
Status

# power on
SSerialSend5 47414954454BBD000100000000BC

# power off
SSerialSend5 47414954454BBD000000000000BD

# Enable Wifi led
SSerialSend5 47414954454BBDFF01000000FFBC
```

![Tasmota Web Console](tasmota-usage.png)

