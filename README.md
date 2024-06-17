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

## Protocol Specs

The description of the serial protocol is in [protocol.md](protocol.md).

Thanks to [CemDK](https://github.com/CemDK) for helping me decoding the checksum algorithm used in the serial communication

## Tasmota configuration

From the previous setup, it is trivial to transplant the original ESP (and keep it safe) and put a new ESP flashed with [Tasmota](https://tasmota.github.io/docs/)  or any other open firmware.
I used one [Adafruit HUZZAH ESP 8266 module](https://templates.blakadder.com/adafruit_HUZZAH.html) I have around 
for testing with [Serial commands](https://tasmota.github.io/docs/Commands/#rf-bridge) on the console

RX and TX are the serial control and bootloading pins, and they are being used for flashing the device

* The TX pin is the output from the HUZZAH  module and is 3.3V logic.
* The RX pin is the input into the HUZZAH module and is 5V compliant (there is a level shifter on this pin)

To control the Airco, I am using software serial on the these GPIO pins used for serial transmit:

 * `GPIO#4` is for `SerBr TX`
 * `GPIO#5` is for `SerBr RX`

![Tasmota Serial config](tasmota-serialbridge.png)

The MCU connector

![Eurom MCU connection](eurom_mcu5.jpg)

The ESP HUZZAH module connections:

![ESP](esp.jpg)


Based on these settings, this is the template used for experiments:

```
{"NAME":"Eurom PAC","GPIO":[32,0,320,0,1792,1824,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":18}
```

![Tasmota Template](tasmota-settings.png)

### About serial modes and Tasmota

Hardware Serial Bridge uses GPIO1 (Tx) and GPIO3 (Rx) or GPIO15 (Tx) and GPIO13 (Rx) pins of your device. Software Serial Bridge can use any other GPIO to be configured as components Serial Tx and Serial Rx (or SerBr Tx and SerBr Rx). 

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
#

```

![Tasmota Web Console](tasmota-usage.png)
