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

From the previous setup, it is trivial to transplant the original ESP (and keep it safe) and put a new ESP flashed with [Tasmota](https://tasmota.github.io/docs/)  or any other open firmware.

## Protocol Specs

The description of the serial protocol is in [protocol.md](protocol.md).

Thanks to [CemDK](https://github.com/CemDK) for helping me decoding the checksum algorithm used in the serial communication


## Tasmota configuration with ESP32 using a Berry Driver

Using [ESP32 S2 Mini](https://www.wemos.cc/en/latest/s2/s2_mini.html) and after [flash it with Tasmota](https://templates.blakadder.com/s2_mini.html)
```
esptool.py  write_flash 0x0 tasmota32s2.factory.bin
```

Load this template which defines the `gpio.TX` and `gpio.RX` pins for the Driver
```
{"NAME":"Eurom PAC 12.2 WiFi","GPIO":[32,0,0,0,0,3232,0,3200,0,0,0,0,0,0,0,576,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```

![ESP32s2 Template](esp32s2_template1.png "ESP32s2 Template")

* `GPIO#5` is for `Serial RX`
* `GPIO#7` is for `Serial TX`

Load the Driver [EuromPacWifi.be](./esp32/EuromPacWifi.be) and [autoexec](./esp32/autoexec.be) files from `/esp32` [folder](./esp32/)

![ESP32s2 FS](esp32s2_fs.png "ESP32s2 FS")


Automatically the Tasmota web will become:

![ESP32s2 FS](esp32s2_driver.png "ESP32s2 FS")


### Home Assistant

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














#9 Serial TX
#10 Serial RX
{"NAME":"Eurom PAC 12.2 WiFi","GPIO":[17,224,225,226,0,0,3200,3232,227,228,229,230,231,0],"FLAG":0,"BASE":18}

# Software serial
{"NAME":"Eurom PAC 12.2 WiFi","GPIO":[17,224,225,226,1792,1824,0,0,227,228,229,230,231,0],"FLAG":0,"BASE":18}
# Decouple Buttons from Relays
SetOption73 1
# only single press action on buttons
SetOption13 1

# lock the relays, only one relay can be on
backlog InterLock 1 2,3,4 5 6,7,8; InterLock 1

# Name buttons
backlog WebButton1 on; WebButton2 cool; WebButton3 dry; WebButton4 fan; WebButton5 swing; WebButton6 low; WebButton7 med; WebButton8 high

# set the software serial
backlog SBaudrate 9600; SSerialConfig 3; SerialDelimiter 254
mem1 47414954454BBD

rule1
    on Wifi#Connected do SSerialsend5 %mem1%FF01000000FFBC endon
    on Wifi#Disconnected do SSerialsend5 %mem1%FF00000000FFBD endon
    on Power1#State>0 do SSerialsend5 %mem1%000100000000BC endon
    on Power1#State<1 do SSerialsend5 %mem1%000000000000BD endon
    on Power5#State<1 do SSerialsend5 %mem1%010000000001BD endon
    on Power5#State>0 do SSerialsend5 %mem1%010100000001BC endon
    on Power6#State>0 do SSerialsend5 %mem1%070300000007BE endon
    on Power7#State>0 do SSerialsend5 %mem1%070200000007BF endon
    on Power8#State>0 do SSerialsend5 %mem1%070100000007BC endon
    on Power2#State>0 do SSerialsend5 %mem1%060100000006BC endon
    on Power3#State>0 do SSerialsend5 %mem1%060300000006BE endon
    on Power4#State>0 do SSerialsend5 %mem1%060600000006BB endon

# One shot
rule1 5

rule2
    on sserialreceived#data$<%mem1%0010 do power1 0 endon
    on sserialreceived#data$<%mem1%0410 do power1 0 endon
    on sserialreceived#data$<%mem1%0110 do backlog power1 1; power5 0 endon
    on sserialreceived#data$<%mem1%0510 do backlog power1 1; power5 1 endon
    on sserialreceived#data$<%mem1%011011 do backlog power2 1; power8 1 endon
    on sserialreceived#data$<%mem1%051011 do backlog power2 1; power8 1 endon
    on sserialreceived#data$<%mem1%011013 do backlog power3 1; power8 1 endon
    on sserialreceived#data$<%mem1%051013 do backlog power3 1; power8 1 endon
    on sserialreceived#data$<%mem1%011016 do backlog power4 1; power8 1 endon
    on sserialreceived#data$<%mem1%051016 do backlog power4 1; power8 1 endon

<!-- 
rule2
    on Power2#State==1 do SSerialsend5 %mem1%060100000006BC endon
    on sserialreceived#data$<%mem1%011011 do backlog power2 1; power8 1 endon
    on sserialreceived#data$<%mem1%051011 do backlog power2 1; power8 1 endon
    on Power3#State==1 do SSerialsend5 %mem1%060300000006BE endon
    on sserialreceived#data$<%mem1%011013 do backlog power3 1; power8 1 endon
    on sserialreceived#data$<%mem1%051013 do backlog power3 1; power8 1 endon
    on Power4#State==1 do SSerialsend5 %mem1%060600000006BB endon
    on sserialreceived#data$<%mem1%011016 do backlog power4 1; power8 1 endon
    on sserialreceived#data$<%mem1%051016 do backlog power4 1; power8 1 endon
 -->


rule3
    on sserialreceived#data$<%mem1%011021 do backlog power2 1; power7 1 endon
    on sserialreceived#data$<%mem1%051021 do backlog power2 1; power7 1 endon
    on sserialreceived#data$<%mem1%011031 do backlog power2 1; power6 1 endon
    on sserialreceived#data$<%mem1%051031 do backlog power2 1; power6 1 endon
    on sserialreceived#data$<%mem1%011023 do backlog power3 1; power7 1 endon
    on sserialreceived#data$<%mem1%051023 do backlog power3 1; power7 1 endon
    on sserialreceived#data$<%mem1%011033 do backlog power3 1; power6 1 endon
    on sserialreceived#data$<%mem1%051033 do backlog power3 1; power6 1 endon
    on sserialreceived#data$<%mem1%011026 do backlog power4 1; power7 1 endon
    on sserialreceived#data$<%mem1%051026 do backlog power4 1; power7 1 endon
    on sserialreceived#data$<%mem1%011036 do backlog power4 1; power6 1 endon
    on sserialreceived#data$<%mem1%051036 do backlog power4 1; power6 1 endon







---------------------------



rule3
    on sserialreceived#data$<%mem1%0010 do backlog power1 0; power5 0 endon
    on sserialreceived#data$<%mem1%0410 do backlog power1 0; power5 1 endon
    on sserialreceived#data$<%mem1%011011 do backlog power1 1; power2 1; power5 0; power8 1 endon
    on sserialreceived#data$<%mem1%051011 do backlog power1 1; power2 1; power5 1; power8 1 endon
    on sserialreceived#data$<%mem1%011021 do backlog power1 1; power2 1; power5 0; power7 1 endon
    on sserialreceived#data$<%mem1%051021 do backlog power1 1; power2 1; power5 1; power7 1 endon
    on sserialreceived#data$<%mem1%011031 do backlog power1 1; power2 1; power5 0; power6 1 endon
    on sserialreceived#data$<%mem1%051031 do backlog power1 1; power2 1; power5 1; power6 1 endon
    on sserialreceived#data$<%mem1%011013 do backlog power1 1; power3 1; power5 0; power8 1 endon
    on sserialreceived#data$<%mem1%051013 do backlog power1 1; power3 1; power5 1; power8 1 endon
    on sserialreceived#data$<%mem1%011023 do backlog power1 1; power3 1; power5 0; power7 1 endon
    on sserialreceived#data$<%mem1%051023 do backlog power1 1; power3 1; power5 1; power7 1 endon
    on sserialreceived#data$<%mem1%011033 do backlog power1 1; power3 1; power5 0; power6 1 endon
    on sserialreceived#data$<%mem1%051033 do backlog power1 1; power3 1; power5 1; power6 1 endon
    on sserialreceived#data$<%mem1%011016 do backlog power1 1; power4 1; power5 0; power8 1 endon
    on sserialreceived#data$<%mem1%051016 do backlog power1 1; power4 1; power5 1; power8 1 endon
    on sserialreceived#data$<%mem1%011026 do backlog power1 1; power4 1; power5 0; power7 1 endon
    on sserialreceived#data$<%mem1%051026 do backlog power1 1; power4 1; power5 1; power7 1 endon
    on sserialreceived#data$<%mem1%011036 do backlog power1 1; power4 1; power5 0; power6 1 endon
    on sserialreceived#data$<%mem1%051036 do backlog power1 1; power4 1; power5 1; power6 1 endon






    on Power3#State=1 do ss endon
    on Power4#State=1 do backlog IF (Var1==0) event#on=1; var1 3; ENDIF; ss dry; var3 1 endon

    on Var1#State<=0 do backlog var1 0; SSerialSend5 47414954454BBD060100000006BC endon
    on Var1#State>0 do backlog

    on Power4#State=1 do SSerialSend5 47414954454BBD060600000006BB endon
    on Power4#State=0 do SSerialSend5 47414954454BBD060600000006BB endon
    
    on Power2#State=1 do SSerialSend5 47414954454BBD060100000006BC endon
    on Power3#State=1 do SSerialSend5 47414954454BBD060300000006BE endon



ON POWER2#State=0 DO power4 OFF ENDON
ON POWER2#State=0 DO power3 OFF ENDON
ON POWER2#State=0 DO var1 3 ENDON
ON POWER2#State=0 DO var2 1 ENDON
ON POWER2#State=1 DO power4 ON ENDON
ON POWER2#State=1 DO power3 ON ENDON
ON POWER2#State=1 DO var1 2 ENDON
ON POWER2#State=1 DO var2 0 ENDON



rule2
    on serialreceived#data=55AA0008000C00020202020202010100010123 do power 1 endon 
    on serialreceived#data=55AA0008000C00020202020202010100010022 do power 0 endon


{"NAME":"Example","GPIO":[416,0,418,0,417,2720,0,0,2624,32,2656,224,0,0],"FLAG":0,"BASE":45,"CMND":"LedTable 1|ChannelRemap 36"}



rule1 
on system#init do baudrate 9600 endon 
on system#boot do backlog serialsend5 55AA000800010008; delay 5; serialsend5 55AA000200010406 endon

rule2  
on serialreceived#data=55AA0008000C00020202020202010100010123 do power 1 endon 
on serialreceived#data=55AA0008000C00020202020202010100010022 do power 0 endon
on serialreceived#data=55AA0008000C00010101010101030400010223 do publish2 stat/%topic%/BATTERY high endon 
on serialreceived#data=55AA0008000C00010101010101030400010122 do publish2 stat/%topic%/BATTERY medium endon 
on serialreceived#data=55AA0008000C00010101010101030400010021 do publish2 stat/%topic%/BATTERY low endon 


Backlog WebButton1 Diffuser; WebButton2 Light; FriendlyName1 Diffuser Fan; FriendlyName2 Diffuser Light 

Rule1 
  ON TuyaReceived#CmndData=0E04000102 DO publish2 stat/%topic%/BATT high ENDON 
  ON TuyaReceived#Data=0E04000101 DO publish2 stat/%topic%/BATT medium ENDON 
  ON TuyaReceived#Data=0E04000100 DO publish2 stat/%topic%/BATT low ENDON 
  ON TuyaReceived#CmndData=0104000100 DO publish stat/%topic%/SMOKE OFF ENDON 
  ON TuyaReceived#CmndData=0104000101 DO Publish stat/%topic%/SMOKE ON ENDON


  Rule2 
  ON Analog#A0div10<30 DO Power3 2 BREAK 
  ON Analog#A0div10<60 DO Power2 2 BREAK 
  ON Analog#A0div10<80 DO Power1 2 ENDON

  Backlog Rule2 ON button3#state=3 DO power4 2 ENDON; Rule2 1


  Added a rule to get it working properly:
```console
Rule1 
	on Power1#State=0 do LEDPower1 0 endon 
	on Power1#State=1 do LEDPower1 1 endon 
	on Power2#State=0 do LEDPower2 0 endon 
	on Power2#State=1 do LEDPower2 1 endon
```
This combines to:
```console
Rule1 on Power1#State=0 do LEDPower1 0 endon on Power1#State=1 do LEDPower1 1 endon on Power2#State=0 do LEDPower2 0 endon on Power2#State=1 do LEDPower2 1 endon
```

Added some commands too:
```console
InterLock 1,2,3 # lock the relays, only one relay can be on
InterLock    on # switch interlocking on
PowerOnState  0 # keep relay(s) OFF after power up
PowerRetain   0 # don't retain states
SetOption1    1 # restrict button-multipress to single, double and hold actions
LedPower 0	# disables power LED
SetOption31 1	# optional, prevents LED from flashing if WiFi or MQTT are disconnected
SetOption80 1	# enable ShutterMode
Pulsetime3 1 	# this button is used to stop the relays. It can be turned off immediatly
```

template9: '{"NAME":"ShutterSwitch","GPIO":[544,227,289,34,226,33,0,0,32,224,290,225,288,0],"FLAG":0,"BASE":18,"CMND":"Rule1 1"}'


Rule1
 on System#Boot do Backlog Baudrate 9600; SerialSend5 0 endon
 on Power1#State=1 do SerialSend5 A00101A2 endon
 on Power1#State=0 do SerialSend5 A00100A1 endon



```console
Rule1
 on System#Boot do Backlog Baudrate 9600; SerialSend5 0 endon
 on Power1#State=1 do SerialSend5 A00101A2 endon
 on Power1#State=0 do SerialSend5 A00100A1 endon
```

Enable the rule: `Rule1 1`
If that doesn't work for you, you may find that using Power1#Boot as the event to trigger the baud rate setting (instead of System#Boot) works, as it did for me. So the alternate rule is: 
```console
Rule1
on Power1#Boot do Backlog Baudrate 9600; SerialSend5 0 endon
on Power1#State=1 do SerialSend5 A00101A2 endon
on Power1#State=0 do SerialSend5 A00100A1 endon
```



```console
Rule1 ON Switch2#State DO backlog rule2 0; IF ((Switch2#State==%value%) AND (Power1#State==%value%)) Power3 2 ENDIF; Power3 2; rule2 1 ENDON
```
```console
Rule2 ON Power3#State DO backlog rule1 0; Power1 2; rule1 1 ENDON
```


Decouple Buttons from Relays
```
SetOption73 1
```

Single rule to handle fan speed logic
```console
Rule1
ON SYSTEM#Init DO Backlog var1 3; var2 1 ENDON
ON BUTTON1#State=10 DO power1 Toggle ENDON
ON BUTTON2#State=10 DO event p=%var2% ENDON
ON BUTTON3#State=10 DO event s=%var1% ENDON
ON EVENT#p>0 DO power4 ON ENDON
ON EVENT#p>0 DO power3 ON ENDON
ON EVENT#p>0 DO power2 ON ENDON
ON EVENT#p>0 DO var1 2 ENDON
ON EVENT#p>0 DO var2 0 ENDON
ON EVENT#p=0 DO power3 OFF ENDON
ON EVENT#p=0 DO power4 OFF ENDON
ON EVENT#p=0 DO power2 OFF ENDON
ON EVENT#p=0 DO var1 3 ENDON
ON EVENT#p=0 DO var2 1 ENDON
ON EVENT#s>0 DO var2 0 ENDON
ON EVENT#s=1 DO power3 OFF ENDON
ON EVENT#s=1 DO power4 OFF ENDON
ON EVENT#s=1 DO power2 ON ENDON
ON EVENT#s=1 DO var1 3 ENDON
ON EVENT#s=2 DO power3 OFF ENDON
ON EVENT#s=2 DO power4 ON ENDON
ON EVENT#s=2 DO power2 ON ENDON
ON EVENT#s=2 DO var1 1 ENDON
ON EVENT#s=3 DO power3 ON ENDON
ON EVENT#s=3 DO power4 ON ENDON
ON EVENT#s=3 DO power2 ON ENDON
ON EVENT#s=3 DO var1 2 ENDON
ON POWER2#State=0 DO power4 OFF ENDON
ON POWER2#State=0 DO power3 OFF ENDON
ON POWER2#State=0 DO var1 3 ENDON
ON POWER2#State=0 DO var2 1 ENDON
ON POWER2#State=1 DO power4 ON ENDON
ON POWER2#State=1 DO power3 ON ENDON
ON POWER2#State=1 DO var1 2 ENDON
ON POWER2#State=1 DO var2 0 ENDON
```

Enable rule with `Rule1 1`

Description:
`SetOption73` Decouples the buttons and relay
The VAR1 can be thought of as "NextSpeed" and VAR2 as "Next Power", if it makes it easier to read the code






You have to use another rule so that it will report speed to mqtt:
```console
Rule1 on TuyaReceived#Data=55AA00070005040400010014 do publish2 stat/%topic%/speed 4,0 endon on TuyaReceived#Data=55AA00070005040400010115 do publish2 stat/%topic%/speed 4,1 endon on TuyaReceived#Data=55AA00070005040400010216 do publish2 stat/%topic%/speed 4,2 endon
```


```console{% raw %}
Rule3 
on tuyareceived#dptype2id9 do publish stat/%topic%/pm10 %value% endon on tuyareceived#dptype2id7 do publish stat/%topic%/pm25 %value% endon on system#boot do devicename endon on devicename#data do var16 %value% endon

on var16#state do publish2 homeassistant/sensor/%macaddr%/pm10/config {"name":"%value% PM10","state_topic":"stat/%topic%/pm10","val_tpl":"{{ value }}","dev_cla":"pm10","unit_of_meas":"µg/m³","avty_t":"tele/%topic%/LWT","pl_avail":"Online","pl_not_avail":"Offline","unique_id":"%macaddr%_pm10","dev":{"cns":[["mac","%macaddr%"]]}} endon

on var16#state do publish2 homeassistant/sensor/%macaddr%/pm25/config {"name":"%value% PM2.5","state_topic":"stat/%topic%/pm25","val_tpl":"{{ value }}","dev_cla":"pm25","unit_of_meas":"µg/m³","avty_t":"tele/%topic%/LWT","pl_avail":"Online","pl_not_avail":"Offline","unique_id":"%macaddr%_pm25","dev":{"cns":[["mac","%macaddr%"]]}} endon{% endraw %}
```

#### All Together ####
First part:
```console
Backlog template {"NAME":"Anccy Shutter","GPIO":[157,0,53,19,23,18,0,0,17,21,54,22,52],"FLAG":0,"BASE":18}; module 0; Topic anccy; FriendlyName Anccy; DeviceName Anccy
```
Second part:
```console
Backlog SetOption80 1; InterLock 1,2; InterLock on; ShutterButton1 1 up 1; ShutterButton1 2 down 1; Pulsetime3 30; WebButton3 ■; PowerOnState 0; rule1 ON Power3#State=1 DO ShutterStop1 ENDON; rule1 on
```


#### All Together ####

First part:
```console
Backlog mem1 1; mem2 30; SetOption32 20; Pulsetime3 0; Interlock 1,2
```
Second part:
```console
rule1 ON Button3#State=2 DO Backlog ShutterStop1; Power3 toggle; RuleTimer1 2 ENDON ON Button3#State=3 DO event togglemem1=%mem1% ENDON ON Rules#Timer=1 DO var1 %var1% ENDON ON event#togglemem1=0 DO mem1 1 ENDON ON event#togglemem1=1 DO mem1 0 ENDON ON mem1#State DO Backlog var1 %mem1%; Sub1 %var2% ENDON ON var2#State DO Backlog var1 %mem1%; Sub1 %var2% ENDON ON var1#State<1 DO Backlog Power3 on; Rule2 off ENDON ON var1#State==1 DO Backlog Power3 off; Rule2 on ENDON ON var2#State DO event blink=%value% ENDON ON event#blink=1 DO Backlog delay %mem2%; Power3 toggle; event blink=%var2% ENDON ON System#Init DO var2 1 ENDON ON Time#Initialized DO var2 0 ENDON
```


Label web UI buttons:
```console
Backlog WebButton1 Fan; WebButton2 Light; FriendlyName1 Diffuser Fan; FriendlyName2 Diffuser Light
```
### What you get

- `Power1` Device diffuser status (on/off)
- `Power2` Device RGB light (on/off)
- `TuyaEnum1` Diffuser intensity (high/medium/low)
- `TuyaEnum2` Timer (2h/4h/off)
- `TuyaEnum3` RGB mode (solid/cycle)



```console
Backlog Rule1 on tuyareceived#dptype4id3 do publish stat/%topic%/speed %value% endon; Rule1 1
```






Flashing is straightforward:
- remove the TYJW2S-5V module that's similar to the one shown in the Klarstein template
- solder a 6-pin header on to the TXD0 through to 3.3V pins
- connect your FTDI with Rx to TXD0, Tx to RXDO, GND to GND, 3.3V to 3.3V, and hold the BOOT pin to GND while inserting the FTDI adapter. DO NOT USE 5V AS YOU WILL FRY THE CHIP!
- Use Tasmotizer to load the Tasmota firmware
- Don't reboot the module while attached to the FTDI - it may not successfully boot, and might corrupt the firmware. Instead, reattach it to the heater and reassemble the heater (for safety's sake, don't skimp and run the heater with the cover off).

Once you've booted and connected to the default 192.168.4.1 access point, set your MQTT server parameters and load the following rules in the console:

```console
RULE1
  ON System#Init do sserialsend5 
    f1f10210000000000000000000000000000400167E ENDON 
  ON WiFi#Connected do sserialsend5 
    f1f10210000000000000000000000000000300157e ENDON 
  ON Mqtt#Connected do sserialsend5 
    f1f10210000000000000000000000000000100137e ENDON 
  ON Mqtt#Disconnected do sserialsend5 
    f1f10210000000000000000000000000000300157e ENDON 
  ON Wifi#Disconnected do sserialsend5 
    f1f10210000000000000000000000000000100137e ENDON 
  ON sserialreceived#Data=F2F20600067E DO Wificonfig 2 ENDON
```

This rule enables intelligent use of the WiFi icon on the panel (it flashes slow on System Init, flashes fast when WiFi connected but no MQTT yet or when MQTT connection is lost, and goes solid on when MQTT connected. Also, when the Power button is held down for 3 seconds, it forces Tasmota to reboot into Access Point mode (as with the stock firmware).

```console
RULE2 
  ON Mqtt#Connected DO RuleTimer1 60 ENDON 
  ON Rules#Timer=1 DO backlog sserialsend5 f1f10100017e; ruletimer1 60 ENDON
```

This rule polls the MCU every 60s as a keep-alive which triggers the MCU to send the status hex string via a tele/<topic>/RESULT message as follows:

  `tele/tasmota_B7AE5F/RESULT = {""SSerialReceived"":""F2F202100202020019000100010015010000014A7E""}`

Deconstructing this status string is a challenge - you may want to take advantage of an MQTT helper app I wrote to transform it into discrete MQTT messages for POWER, CHILDLOCK, MODE, TEMP, TIMER and SETPOINT - see [https://github.com/gooman-uk/devola-mqtt](https://github.com/gooman-uk/devola-mqtt)

```console
RULE3 
  ON Power1#state=1 DO sserialsend5 
    F1F10210010002001900000000010001000001317E ENDON 
  ON Power1#state=0 DO sserialsend5 
    F1F10210020002001900000000010001000001327E ENDON
```
This rule uses the template's assignment of dummy GPIO 4 to a Relay to allow simple access to turning the heater on and off through a simple ""cmnd/tasmota/POWER"" message, and also allows toggling it on the Tasmota web page

If you're planning to build and unpack the hex strings yourself, here's the structure:

- Bytes 1-2 - Direction - F1F1 from ESP, F2F2 from MCU
- Bytes 2-3 - Padding as far as I can work out - always  02 10
- Byte 5 - Power - 02=OFF, 01=ON
- Byte 6 - Childlock - 02=OFF, 01=ON
- Bytes 7-10 - More padding - always 02 00 19 00
- Byte 11 - Mode - 01=off, 02=low, 03=high, 04=anti-frost
- Byte 12 - Setpoint temperature, converted to hex
- Bytes 13-14 - Timer - 0100 = off, 0001 = on, 0002 = 1 hr,  0003 = 2 hrs (etc)
- Byte 15 - Ambient temperature, converted to hex
- Bytes 16-19 - More padding - always 01 00 00 01
- Byte 20 - Additive checksum of bytes 2-19
- Byte 21 - Terminator - always 7E


For meaningful web buttons:

```console
WebButton1 up
WebButton2 stop
WebButton3 down
```"






Rule to control all 6 relays with multi-press and hold to turn all relays off.
```
Rule1
ON System#Boot DO Var1 0 ENDON
ON Switch1#State=3 DO Backlog0 Power1 0; Power2 0; Power3 0; Power4 0; Power5 0; Power6 0; Var1 0 ENDON
ON Switch1#State=2 DO ADD1 1 ENDON
ON Var1#State==1 DO RuleTimer1 1 ENDON
ON Rules#Timer=1 DO Backlog Var2 %Var1%; Var1 0 ENDON
ON Var2#State==1 DO Power1 TOGGLE ENDON
ON Var2#State==2 DO Power2 TOGGLE ENDON
ON Var2#State==3 DO Power3 TOGGLE ENDON
ON Var2#State==4 DO Power4 TOGGLE ENDON
ON Var2#State==5 DO Power5 TOGGLE ENDON
ON Var2#State==6 DO Power6 TOGGLE ENDON
```
Enable with `Rule1 1`.




```console
Backlog TempRes 0; TuyaEnumList 1,1; WebButton1 Mute; WebButton2 Run Test
```



```console
rule1 
on System#Boot do Baudrate 115200 endon
on SerialReceived#Data=41542B5253540D0A do SerialSend5 5749464920434f4e4e45435445440a5749464920474f542049500a41542b4349504d55583d310a41542b4349505345525645523d312c383038300a41542b43495053544f3d333630 endon
on Power1#State=1 do SerialSend5 A00101A2 endon
on Power1#State=0 do SerialSend5 A00100A1 endon
on Power2#State=1 do SerialSend5 A00201A3 endon
on Power2#State=0 do SerialSend5 A00200A2 endon
on Power3#State=1 do SerialSend5 A00301A4 endon
on Power3#State=0 do SerialSend5 A00300A3 endon
on Power4#State=1 do SerialSend5 A00401A5 endon
on Power4#State=0 do SerialSend5 A00400A4 endon
```





If you wish to integrate the device seamlessly in Home Assistant, type the following into the Tasmota console window (modify the names to your requirements):

```console
Rule2
  ON system#boot do publish2 homeassistant/binary_sensor/%macaddr%_fire/config {"name":"Fire Alarm","state_topic":"stat/%topic%/FIRE","device_class":"smoke","unique_id":"%macaddr%_fire","device":{"connections":[["mac","%macaddr%"]]}} ENDON
  ON system#boot do publish2 homeassistant/binary_sensor/%macaddr%_test/config {"name":"Fire Alarm Test","state_topic":"stat/%topic%/TEST","icon":"mdi:bell-alert","unique_id":"%macaddr%_test","device":{"connections":[["mac","%macaddr%"]]}} ENDON
  ON system#boot do publish2 homeassistant/binary_sensor/%macaddr%_mute/config {"name":"Fire Alarm Mute","state_topic":"stat/%topic%/MUTE","icon":"mdi:bell-sleep","unique_id":"%macaddr%_mute","device":{"connections":[["mac","%macaddr%"]]}} ENDON
  ON system#boot do publish2 homeassistant/binary_sensor/%macaddr%_battery/config {"name":"Fire Alarm Battery","state_topic":"stat/%topic%/BATTERY","device_class":"battery","unique_id":"%macaddr%_battery","device":{"connections":[["mac","%macaddr%"]]}} ENDON
```




Set names for pump control and watering autorun to have nice entity names in HA:

```console 
Backlog FriendlyName1 Water Pump; FriendlyName2 Autorun Watering
```



This rule is required to shut down Tasmota 5 minutes after a successful boot and reset the trap.

```console
rule1 on tuyareceived#data=55AA00050005650100010070 do backlog delay 300; serialsend5 55AA000500010005 endon
```








## Home Assistant configuration

Add these rules to console and your mouse trap will be autodiscovered on reboot or on devicename change

```console
rule2
on system#boot do devicename endon
on tuyareceived#data=55AA00050005650100010171 do publish2 stat/%topic%/trap ON endon
on tuyareceived#data=55AA00050005650100010070 do publish2 stat/%topic%/trap OFF endon
on tuyareceived#data=55AA00050005660400010074 do publish2 stat/%topic%/battery 100 endon 
on tuyareceived#data=55AA00050005660400010175 do publish2 stat/%topic%/battery 75 endon 
on tuyareceived#data=55AA00050005660400010276 do publish2 stat/%topic%/battery 50 endon 
on tuyareceived#data=55AA00050005660400010377 do publish2 stat/%topic%/battery 25 endon 
```

```console
{% raw %}rule3 
on devicename#data do publish2 homeassistant/binary_sensor/%macaddr%/trap/config {"name":"%value% Alert","state_topic":"stat/%topic%/trap","value":"{{ value }}","force_update":true,"icon":"mdi:rodent","unique_id":"%macaddr%_trap","dev":{"cns":[["mac","%macaddr%"]]}} endon
on devicename#data do publish2 homeassistant/sensor/%macaddr%/battery/config {"name":"%value% Battery","state_topic":"stat/%topic%/battery","value_template":"{{ value | int }}","device_class":"battery","entity_category":"diagnostic","unit_of_measurement":"%%%","unique_id":"%macaddr%_battery","dev":{"cns":[["mac","%macaddr%"]]}} endon{% endraw %}
```

Enable all the rules:

```console
rule0 1
```








Short press = All on incl. button LED   
Long press = All off incl. button LED 

```console
Backlog ButtonTopic 0; SetOption1 1; SetOption32 20
```

```console
Rule on button1#state=3 do backlog power1 0;power2 0;power4 0;power3 0;power5 0;power6 1 endon on button1#state=2 do backlog power1 1;power2 1;power4 1;power3 1;power5 1;power6 0 endon
Rule 1
```







```console
Rule1 ON IrReceived#Data=0x00F740BF do power off ENDON ON IrReceived#Data=0x00F7C03F do power on ENDON ON IrReceived#Data=0x00F700FF do dimmer + ENDON ON IrReceived#Data=0x00F7807F do dimmer - ENDON ON IrReceived#Data=0x00F720DF do color2 ff0000 ENDON ON IrReceived#Data=0x00F7A05F do color2 00ff00 ENDON ON IrReceived#Data=0x00F7609F do color2 0000ff ENDON

Rule2 ON IrReceived#Data=0x00F710EF do color2 ff5000 ENDON ON IrReceived#Data=0x00F7906F do color2 aeff00 ENDON  ON IrReceived#Data=0x00F750AF do color2 0077ff ENDON ON IrReceived#Data=0x00F730CF do color2 f2ba41 ENDON ON IrReceived#Data=0x00F7B04F do color2 41e3f2 ENDON ON IrReceived#Data=0x00F7708F do color2 a80355 ENDON ON IrReceived#Data=0x00F708F7 do color2 fcce62 ENDON ON IrReceived#Data=0x00F78877 do color2 25a9c4 ENDON ON IrReceived#Data=0x00F748B7 do color2 c4254a ENDON

Rule3 ON IrReceived#Data=0x00F728D7 do color2 fcfc05 ENDON ON IrReceived#Data=0x00F7A857 do color2 2d7c93 ENDON ON IrReceived#Data=0x00F76897 do color2 fc5582 ENDON ON IrReceived#Data=0x00F7E01F do color2 ffffff ENDON ON IrReceived#Data=0x00F7E817 do scheme 2 ENDON ON IrReceived#Data=0x00F7C837 do scheme 3 ENDON ON IrReceived#Data=0x00F7F00F do scheme 4 ENDON ON IrReceived#Data=0x00F7D02F do Power 3 ENDON
```






Button controls single relay only. To switch other relays use rules.

E.g. all other relays synchronized to relay 1:
```console
rule
    on Power1#boot do var1 %value% endon
    on Power1#state do var1 %value% endon
    on button1#state do event change=%var1% endon
    on event#change==0 do backlog POWER1 1; POWER2 1; POWER3 1; POWER4 1 endon on event#change==1 do backlog POWER1 0; POWER2 0; POWER3 0; POWER4 0 endon
```











{% highlight yaml %}
{% raw %}
Rule1 
	on TuyaReceived#Data=55AA03070005040400010017 DO Publish stat/%topic%/PRESET 80 endon 
	on TuyaReceived#Data=55AA03070005040400010118 DO Publish stat/%topic%/PRESET 85 endon 
	on TuyaReceived#Data=55AA03070005040400010219 DO Publish stat/%topic%/PRESET 90 endon
	on TuyaReceived#Data=55AA0307000504040001031A DO Publish stat/%topic%/PRESET 95 endon
	on TuyaReceived#Data=55AA0307000504040001041B DO Publish stat/%topic%/PRESET 100 endon
rule1 1

Rule2 
	on TuyaReceived#Data=55AA030700050F0400010022 DO Publish stat/%topic%/MODE Stand By endon 
	on TuyaReceived#Data=55AA030700050F0400010123 DO Publish stat/%topic%/MODE Heating endon 
	on TuyaReceived#Data=55AA030700050F0400010224 DO Publish stat/%topic%/MODE Sleep endon
	on TuyaReceived#Data=55AA030700050F0400010325 DO Publish stat/%topic%/MODE Keep Warm endon
rule2 1

rule3
	ON var1#state DO if (var1>79) scale2 %var1%,80,100,0,4; ENDIF ENDON
	on var2#state do tuyasend4 4,%var2% endon
rule3 1
{% endraw %}
{% endhighlight %}

The above rules will report the current temperature, preset and mode in easy to read MQTT payloads.

{% highlight yaml %}
{% raw %}
rule3
	ON Var1#State==80 DO var2 0 ENDON
	ON Var1#State==85 DO var2 1 ENDON
	ON Var1#State==90 DO var2 2 ENDON
	ON Var1#State==95 DO var2 3 ENDON
	ON Var1#State==100 DO var2 4 ENDON
	ON var2#state DO tuyasend4 4,%var2% ENDON"	
rule3 1
{% endraw %}
{% endhighlight %}

If you are using the standard tasmota binary without SUPPORT_IF_STATEMENT, then rule 3 can be substituted as above.