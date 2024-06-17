# Eurom PAC 12.2/14.2 Wifi

Open the device removing the screw from the back cover. The body consists in three parts: top panel with ventilator, front panel and back panel. Once removed the front panel, the ESP device and the IR receiver are visible.

![Eurom Front](eurom_front.jpg)

The ESP module is a TYWE1S on a board TYJW1 V2.1.5 commonly used in Tuya modules, but in this case is using a different firmware. This module is only used for sniffing. There is no attempt to change the firmware, so no backup is needed. Original cable and module are kept intact.

The box with the MCU is on the right. It can also be easily opened.

![Eurom Front](eurom_mcu1.jpg)

The serial cable from the ESP to the MCU is the top one red connector.

Focus now on connecting the [LHT00SU1 Logic Analyzer](https://sigrok.org/wiki/Noname_LHT00SU1)

![LHT00SU1 Logic Analyzer](eurom_logicanalyzer.jpg)

Using [Pulseview](https://sigrok.org/wiki/PulseView) to setup the UART filter on inputs `D0` and `D1` using 9600 bits/s, no parity, 1 stop bit.

![Example](pulseview/general_view.png)
![Example](pulseview/start1.png)

Although `TYJW1 V2.1.5` board has printed in the reverse the connector pins, it says Vcc 5V, which is not true, the board works with 3V.
The The serial connector on the MCU side has this configuration:

![Eurom MCU connection](eurom_mcu5.jpg)

Top panel and remote has exactly the same functions as the protocol spec
![Eurom Top](eurom_top.jpg)


Pulseview setup:
```
10M Samples @ 100kHz
UART 9600 8N1
```

XOR checksum8 decoded with: https://www.scadacore.com/tools/programming-calculators/online-checksum-calculator/
