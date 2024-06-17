# Eurom PAC serial protocol

Serial RS232 protocol used in Eurom PAC 12.2 Wifi & PAC 14.2 Wifi products between the Wi-Fi module (ESP based) and the MCU.

## Notation

All data streams are in Hexadecimal notation using LSB.

`Dir` means:

* `TX> 0x`: datastream transmited from the ESP to the MCU
* `RX> 0x`: datastream received from the MCU to the ESP

## Serial communication

Serial RS232 mode `9600` `8N1`:

* `bit/s`: 9600
* `data`: 8 bits
* `parity`: none
* `stop bits`: 1

### Description

* The ESP sends (TX) data (in this document is that is known `command`) to the MCU and it keeps receiving datastreams (from now known as `status (messages)`).
If no commands nor healthcheck/heartbeat were not sent in the last 120s, the ESP sends a healtcheck/heartbeat.
* The MCU sends (RX) status datastream after a valid command from the ESP is processed or every 3 seconds continuously.
* Unless changes in the status of the device are detected (eg remote or dashboard buttons not pressed by the user)
nor environment data from the sensors has changed (temperature or humidity), RX status datastreams are equal. 
Even when the device is sleeping for power on or on timer for power off.
* User pressing a button on the dashboard panel or in the remote, does not trigger a RX status datastream,
the ESP will be updated after 3 seconds in the regular update message.

### TX commands

Binary datagram 14 bytes fixed length (example data)

```
                           | b1 | b2 | b3|b4|b5|b6 |
Dir    | Gaitek            | ST | CO | Params      | X1 | X2 |
------ |-------------------|----|----|-------------|----|----|
TX> 0x | 47 41 49 14 45 4B   BD   FF   FF 00 00 00   FF   42
```

* `bN`: byte number `N` for checksum calculation.
* `Gaitek`: (6 bytes) header, always `GAITEK` in ascii (not used for checksums).
* `ST`: (1 byte) start byte, always `0xBD`.
* `CO`: (1 byte) command code.
* `Params`: (4 bytes) commands parameters (arguments), like set temperature.
* `X1`: (1 byte) Checksum8 XOR bytes [`b1`, `b3`, `b5`].
* `X2`: (1 byte) Checksum8 XOR bytes [`b2`, `b4`, `b6`].

Because all commands only have 1 byte as parameter, `X1` XOR checksum is always same as `CO` byte.

#### Commands code

```
| CO | P1 | P2 | P3 | P4 | Description                                                                                    |
| -- | -- | -- | -- | -- | ---------------------------------------------------------------------------------------------- |
  FF   FF   00   00   00 | Start (when device is plugged to electricity)
  FF   01   00   00   00 | Healthcheck (or heartbeat) (every 120s)
  00   P1   00   00   00 | Power management, where P1: 01 == power on; 00 == power off
  01   P1   00   00   00 | Swing management, where P1: 01 == swing on; 00 swing off
  06   P1   00   00   00 | Set working mode, where P1: 01 == cool (airco); 03 == dryer; 06 == fan
  07   P1   00   00   00 | Set air speed, where P1: 01 == high; 02 == medium; 03 == low
  08   P1   00   00   00 | Set target temperature in cool mode (airco), where P1 is the amount in C with range [16..31]
  09   P1   00   00   00 | Set target humidity in dry mode, where P1 is the amount in % with range [30..90]
  0A   P1   00   00   00 | Timer/Sleep management, where P1: 00 == timer/sleep off; NN == hour(s)
```

No commands have been found with more than one parameter.

### RX status

Binary datagram 24 bytes fixed length (example data)

```
                           | b1 | b2|b3|b4|b5|b6|b7|b8|b9|bA |
Dir    | Gaitek            | ST | Status                     | X1 | X2 | Ketiag            |
------ |-------------------|----|----------------------------|----|----|-------------------|
RX< 0x | 47 41 49 54 45 4B   BD   00 10 21 17 19 37 1E 00 00   26   8D   4B 45 54 49 41 47
```

* `bN`: byte number `N` for checksum calculation.
* `Gaitek`: (6 bytes) header, always `GAITEK` in ascii (not used for checksums).
* `ST`: (1 byte) start byte, always `0xBD`.
* `Status`: (9 bytes) current status data (see below).
* `X1`: (1 byte) Checksum8 XOR bytes [`b1`, `b3`, `b5`, `b7`, `b9`].
* `X2`: (1 byte) Checksum8 XOR bytes [`b2`, `b4`, `b6`, `b8`, `bA`].
* `Ketiag`: (6 bytes) signature, always `KETIAG` in ascii (not used for checksums).

For detecting and reporting changes in the environment data or device mode, is enough comparing the bytes `X1` and `X2` (XOR checksums) of the current datagram with the previously received.
Notice `X2` is also the XOR of the ST (`BD`), all status bytes and `X1`. (`X2=XOR([b1..bA], X1)`).

### Status data

`BD` + 9 bytes where:
                             
```

| byte 2   | byte 3   | byte 4   | byte 5   | byte 6   | byte 7   | byte 8   | byte 9   | byte 10  |
 
                          (4 bits) Mode: 0001 == cooling; 0011 == drying; 0110 == fan 
                              |
                              |                                             (8 bits) Sleep/Timer set in hours (1..24)
                              |                                                 |  (time to stop if currently powered on)
                              |                                                 |  (time to start if powered off )
                              |                                                 |
                             ----                                              ---------
  0000 0S0P  0001 0000  00VV MMMM  TTTT TTTT  TTTT TTTT  HHHH HHHH  HHHH HHHH  DDDD DDDD  0000 0000
        ^ ^               ^^       ---------  ---------  ---------  ---------
        | |               --         |         |           |         |
        | |               |          |         |           |     (8 bits) Target humidity in %
        | |               |          |         |           |  (30,40,45,50,55,60,65,70,75,80,85,90)
        | |               |          |         |           |
        | |               |          |         |       (8 bits) Current humidity in %
        | |               |          |         |
        | |               |          |      (8 bits) Target temperature in centigrade (16..31)
        | |               |          |
        | |               |      (8 bits) Current temperature in grades centigrade (integer)
        | |               |
        | |           (2 bits) Speed: 01 == high; 10 == medium; 11 == low
        | |
        | +-- (1 bit ) Power: 0 == off; 1 == on
        +---- (1 bit ) Swing: 0 == off; 1 == on
```

Notes:

* When the sleep or timer bits `DDDD DDDD` are set, they change in 1 hour interval (integer time is in hours). There is no option to represent less time than 1 hour.
* When that byte reaches 0, the device will stop (if sleep set) or start (if timer set).
* Target state for the sleep or timer settings is the opposite of current power mode.
* Settings can be updated (seep, swing ...) while the device is in timer mode (target is power on).


# Run sets example scenarios

Detailed behavior of the commands and the reported status.

* All commands where issued from the Mobile App which only allows one setting (command) at a time.
* Each run set starts with power on the device and finish powering it off (except for timer/sleep and healthcheck/heartbeat).
* Run sets are lineal. The settings on the previous run set remain enabled for the next one (device keeps the current configuration unless is disconnected from the electricity).

## Device plugged

When device is connected to the electricity, the ESP sends this command.

```
Dir    | Gaitek            | ST | Status                     | X1 | X2 | Ketiag            |
------ |-------------------|----|----------------------------|----|----|-------------------|
TX> 0x | 47 41 49 14 45 4B   BD   FF FF 00 00 00               FF   42
RX< 0x | 47 41 49 54 45 4B   BD   00 10 21 17 19 37 1E 00 00   26   8D   4B 45 54 49 41 47
```

## Healtcheck/heartbeat

Everyt 120s, the ESP sends a "healthcheck/heartbeat"  to the MCU

```
Dir    | Gaitek            | ST | Status                     | X1 | X2 | Ketiag            |
------ |-------------------|----|----------------------------|----|----|-------------------|
TX> 0x | 47 41 49 54 45 4B   BD   FF 01 00 00 00              FF    BC
RX< 0x | 47 41 49 54 45 4B   BD   00 10 21 17 19 34 1E 00 00  26    8E   4B 45 54 49 41 47
```

## Power on / set fan mode / power off

1. Power on
```
Dir    | Gaitek            | ST | Status                     | X1 | X2 | Ketiag            |
------ |-------------------|----|----------------------------|----|----|-------------------|
TX> 0x | 47 41 49 54 45 4B   BD   00 01 00 00 00               00   BC
RX< 0x | 47 41 49 54 45 4B   BD   00 10 21 17 19 34 1E 00 00   26   8E   4B 45 54 49 41 47
```

2. Set fan mode (from cool mode)
```
TX> 0x | 47 41 49 54 45 4B   BD   00 01 00 00 00               00   BC
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 19 35 1E 00 00   27   8F   4B 45 54 49 41 47
```

3. Power off
```
TX> 0x | 47 41 49 54 45 4B   BD   00 00 00 00 00               00   BD
RX< 0x | 47 41 49 54 45 4B   BD   00 10 26 17 19 35 1E 00 00   21   8F   4B 45 54 49 41 47
```

## Power on / set speed to low / set speed to high / power off

1. Power on
```
Dir    | Gaitek            | ST | Status                     | X1 | X2 | Ketiag            |
------ |-------------------|----|----------------------------|----|----|-------------------|
TX> 0x | 47 41 49 54 45 4B   BD   00 01 00 00 00               00   BC
RX< 0x | 47 41 49 54 45 4B   BD   01 10 26 17 19 35 1E 00 00   20   8F   4B 45 54 49 41 47
```

2. Set speed to low (from medium and fan mode)
```
TX> 0x | 47 41 49 54 45 4B   BD  07 03 00 00 00                07   BE
RX< 0x | 47 41 49 54 45 4B   BD  01 10 36 17 19 35 1E 00 00    30   8F   4B 45 54 49 41 47
```

3. Set speed to high (from low)
```
TX> 0x | 47 41 49 54 45 4B   BD  07 01 00 00 00                07   BC
RX< 0x | 47 41 49 54 45 4B   BD  01 10 36 17 19 35 1E 00 00    30   8F   4B 45 54 49 41 47
```

3. Power off
```
TX> 0x | 47 41 49 54 45 4B   BD   00 00 00 00 00               00   BD
RX< 0x | 47 41 49 54 45 4B   BD   00 10 16 17 19 35 1E 00 00   11   8F   4B 45 54 49 41 47
```

##  Power on / set speed to medium / set swing on / power off

1. Power on
```
Dir    | Gaitek            | ST | Status                     | X1 | X2 | Ketiag            |
------ |-------------------|----|----------------------------|----|----|-------------------|
TX> 0x | 47 41 49 54 45 4B   BD   00 01 00 00 00               00   BC
RX< 0x | 47 41 49 54 45 4B   BD   01 10 16 17 19 35 1E 00 00   10   8F   4B 45 54 49 41 47
```

2. Set speed to medium (from high)
```
TX> 0x | 47 41 49 54 45 4B   BD   07 02 00 00 00               07   BF
RX< 0x | 47 41 49 54 45 4B   BD   01 10 26 17 19 35 1E 00 00   20   8F   4B 45 54 49 41 47
```

3. Set swing on
```
TX> 0x | 47 41 49 54 45 4B   BD   01 01 00 00 00               01   BC
RX< 0x | 47 41 49 54 45 4B   BD   05 10 26 17 19 35 1E 00 00   24   8F   4B 45 54 49 41 47
```

4. Power off
```
TX> 0x | 47 41 49 54 45 4B   BD   00 00 00 00 00               00   BD
RX< 0x | 47 41 49 54 45 4B   BD   04 10 26 17 19 35 1E 00 00   25   8F   4B 45 54 49 41 47
```

## Set start timer 1 hour / set start timer 3 hours / wait / set start timer off

* Maximum timer value is 24 hours, so range is: 1 .. 24 (1 hour intervals).
* The timer only represents integer time in hours.
* Target state is the opposite of current power mode (with the current parameters).

1. Set start timer 1 hour (from powered off, mode fan, swing on, speed medium)
```
Dir    | Gaitek            | ST | Status                     | X1 | X2 | Ketiag            |
------ |-------------------|----|----------------------------|----|----|-------------------|
TX> 0x | 47 41 49 54 45 4B   BD   0A 01 00 00 00               0A   BC
RX< 0x | 47 41 49 54 45 4B   BD   04 10 26 17 19 35 1E 01 00   25   8E   4B 45 54 49 41 47
```

2. Change start timer 3 hours (from powered off, mode fan, swing on, speed medium)
```
TX> 0x | 47 41 49 54 45 4B   BD   0A 03 00 00 00               0A   BE
RX< 0x | 47 41 49 54 45 4B   BD   04 10 26 17 19 35 1E 03 00   25   8C   4B 45 54 49 41 47
```

3. ESP sent heartbit (every 120s)
```
TX> 0x | 47 41 49 54 45 4B   BD   FF 01 00 00 00               FF   BC
RX< 0x | 47 41 49 54 45 4B   BD   04 10 26 17 19 35 1E 03 00   25   8C   4B 45 54 49 41 47
```

4. Set timer off
```
TX> 0x | 47 41 49 54 45 4B   BD   0A 00 00 00 00               0A   BD
RX< 0x | 47 41 49 54 45 4B   BD   04 10 26 17 19 35 1E 00 00   25   8F   4B 45 54 49 41 47
```

## Power on / set swing off / set sleep in 2 hours (for stop) / power off

* Maximum timer value is 24 hours, so range is: 1 .. 24 (1 hour intervals).
* The timer only represents integer time in hours.
* Target state is the opposite of current power mode.

1. Power on (mode fan, speed medium, swing on)
```
Dir    | Gaitek            | ST | Status                     | X1 | X2 | Ketiag            |
------ |-------------------|----|----------------------------|----|----|-------------------|
TX> 0x | 47 41 49 54 45 4B   BD   00 01 00 00 00               00   BC
RX< 0x | 47 41 49 54 45 4B   BD   05 10 26 17 19 35 1E 00 00   24   8F   4B 45 54 49 41 47
```

2. Set swing off
```
TX> 0x | 47 41 49 54 45 4B   BD   01 00 00 00 00               01   BD
RX< 0x | 47 41 49 54 45 4B   BD   01 10 26 17 19 35 1E 00 00   20   8F   4B 45 54 49 41 47
```

3. Set sleep (stop timer) in 2 hours
```
TX> 0x | 47 41 49 54 45 4B   BD   0A 02 00 00 00               0A   BF
RX< 0x | 47 41 49 54 45 4B   BD   01 10 26 17 19 35 1E 02 00   20   8D   4B 45 54 49 41 47
```

4. Power off
```
TX> 0x | 47 41 49 54 45 4B   BD   00 00 00 00 00               00   BD
RX< 0x | 47 41 49 54 45 4B   BD   00 10 26 17 19 35 1E 00 00   21   8F   4B 45 54 49 41 47
```

## Power on / set dry mode / set target humidity to x / ... / power off

* Humidity target is set from: dry (30%), 40%, 45%, 50%, 55%, 60%, 65%, 70%, 75%, 80%, 85%, 90%

1. Power on (current mode fan, speed medium, swing off)
```
Dir    | Gaitek            | ST | Status                     | X1 | X2 | Ketiag            |
------ |-------------------|----|----------------------------|----|----|-------------------|
TX> 0x | 47 41 49 54 45 4B   BD   00 01 00 00 00               00   BC
RX< 0x | 47 41 49 54 45 4B   BD   01 10 26 17 19 35 1E 00 00   20   8F   4B 45 54 49 41 47
```

2. Set mode to dry (30%; min) (current humidity 53%)
```
TX> 0x | 47 41 49 54 45 4B   BD   06 03 00 00 00               06   BE
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 35 1E 00 00   25   8F   4B 45 54 49 41 47
```

3. Set target humidity 40%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 28 00 00 00               09   95
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 35 28 00 00   13   8F   4B 45 54 49 41 47
```

4. Set 45%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 2D 00 00 00               09   90
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 35 2D 00 00   16   8F   4B 45 54 49 41 47
```

5. Set 50%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 32 00 00 00               09   8F
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 35 32 00 00   09   8F   4B 45 54 49 41 47
```

6. Set 55%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 37 00 00 00               09   8A
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 35 37 00 00   0C   8F   4B 45 54 49 41 47
```

7. Set 60%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 3C 00 00 00               09   81
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 35 3C 00 00   07   8F   4B 45 54 49 41 47
```

8. Set 65%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 41 00 00 00               09   FC
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 35 41 00 00   7A   8F   4B 45 54 49 41 47
```

9. Set 70%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 46 00 00 00               09   FB
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 35 46 00 00   7D   8F   4B 45 54 49 41 47
```

10. Set 75% (change in current humidity to 52%)
```
TX> 0x | 47 41 49 54 45 4B   BD   09 4B 00 00 00               09   F6
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 4B 00 00   70   8E   4B 45 54 49 41 47
```

11. Set 80%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 50 00 00 00               09   ED
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 50 00 00   6B   8E   4B 45 54 49 41 47
```

12. Set 85%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 55 00 00 00               09   E8
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 55 00 00   6E   8E   4B 45 54 49 41 47
```

13. Set 90% (max)
```
TX> 0x | 47 41 49 54 45 4B   BD   09 5A 00 00 00               09   E7
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 5A 00 00   61   8E   4B 45 54 49 41 47
```

14. Set 85%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 55 00 00 00               09   E8
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 55 00 00   6E   8E   4B 45 54 49 41 47
```

15. Set 80%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 50 00 00 00               09   ED
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 50 00 00   6B   8E   4B 45 54 49 41 47
```

16. Set 75%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 4B 00 00 00               09   F6
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 4B 00 00   70   8E   4B 45 54 49 41 47
```

17. Set 70%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 46 00 00 00               09   FB
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 46 00 00   7D   8E   4B 45 54 49 41 47
```

18. Set 65%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 41 00 00 00               09   FC
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 41 00 00   7A   8E   4B 45 54 49 41 47
```

19. Set 60%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 3C 00 00 00               09   81
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 3C 00 00   07   8E   4B 45 54 49 41 47
```

20. Set 55%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 37 00 00 00               09   8A
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 37 00 00   0C   8E   4B 45 54 49 41 47
```

21. Set 50%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 32 00 00 00               09   8F
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 32 00 00   09   8E   4B 45 54 49 41 47
```

22. Set 45%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 2D 00 00 00               09   90
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 2D 00 00   16   8E   4B 45 54 49 41 47
```

23. Set 40%
```
TX> 0x | 47 41 49 54 45 4B   BD   09 28 00 00 00               09   95
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 28 00 00   13   8E   4B 45 54 49 41 47
```

24. Set mode to dry (30%; min)
```
TX> 0x | 47 41 49 54 45 4B   BD   09 1E 00 00 00               09   A3
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 34 1E 00 00   25   8E   4B 45 54 49 41 47
```

25. Power off
```
TX> 0x | 47 41 49 54 45 4B   BD   00 00 00 00 00               00   BD
RX< 0x | 47 41 49 54 45 4B   BD   00 10 23 17 19 34 1E 00 00   24   8E   4B 45 54 49 41 47
```

## Power on / set cool (airco) mode / set target temperature to x / ... / power off

* Temperature target is set from a range 16..31 grades centigrades

1. Power on (current mode dry, speed medium, swing off, current target temperature 25)
```
Dir    | Gaitek            | ST | Status                     | X1 | X2 | Ketiag            |
------ |-------------------|----|----------------------------|----|----|-------------------|
TX> 0x | 47 41 49 54 45 4B   BD   00 01 00 00 00               00   BC
RX< 0x | 47 41 49 54 45 4B   BD   01 10 23 17 19 35 1E 00 00   25   8F   4B 45 54 49 41 47
```

2. Set mode to cool (current environment temperature is 23)
```
TX> 0x | 47 41 49 54 45 4B   BD   06 01 00 00 00               06   BC
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 19 35 1E 00 00   27   8F   4B 45 54 49 41 47
```

3. Set target temperature 26
```
TX> 0x | 47 41 49 54 45 4B   BD   08 1A 00 00 00               08   A7
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 1A 35 1E 00 00   24   8F   4B 45 54 49 41 47
```

4. Set 27
```
TX> 0x | 47 41 49 54 45 4B   BD   08 1B 00 00 00               08   A6
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 1B 35 1E 00 00   25   8F   4B 45 54 49 41 47
```

5. Set 28
```
TX> 0x | 47 41 49 54 45 4B   BD   08 1C 00 00 00               08   A1
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 1C 35 1E 00 00   22   8F   4B 45 54 49 41 47
```

6. Set 29
```
TX> 0x | 47 41 49 54 45 4B   BD   08 1D 00 00 00               08   A0
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 1D 35 1E 00 00   23   8F   4B 45 54 49 41 47
```

7. Set 30
```
TX> 0x | 47 41 49 54 45 4B   BD   08 1E 00 00 00               08   A3
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 1E 35 1E 00 00   20   8F   4B 45 54 49 41 47
```

8. Set 31 (max)
```
TX> 0x | 47 41 49 54 45 4B   BD   08 1F 00 00 00               08   A2
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 1F 35 1E 00 00   21   8F   4B 45 54 49 41 47
```

9. Set 30
```
TX> 0x | 47 41 49 54 45 4B   BD   08 1E 00 00 00               08   A3
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 1E 35 1E 00 00   20   8F   4B 45 54 49 41 47
```

10. Set 29
```
TX> 0x | 47 41 49 54 45 4B   BD   08 1D 00 00 00               08   A0
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 1D 35 1E 00 00   23   8F   4B 45 54 49 41 47
```

11. Set 28
```
TX> 0x | 47 41 49 54 45 4B   BD   08 1C 00 00 00               08   A1
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 1C 35 1E 00 00   22   8F   4B 45 54 49 41 47
```

12. Set 27
```
TX> 0x | 47 41 49 54 45 4B   BD   08 1B 00 00 00               08   A6
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 1B 35 1E 00 00   25   8F   4B 45 54 49 41 47
```

13. Set 26
```
TX> 0x | 47 41 49 54 45 4B   BD   08 1A 00 00 00               08   A7
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 1A 35 1E 00 00   24   8F   4B 45 54 49 41 47
```

14. Set 25
```
TX> 0x | 47 41 49 54 45 4B   BD   08 19 00 00 00               08   A4
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 19 35 1E 00 00   27   8F   4B 45 54 49 41 47
```

15. Set 24
```
TX> 0x | 47 41 49 54 45 4B   BD   08 18 00 00 00               08   A5
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 18 35 1E 00 00   26   8F   4B 45 54 49 41 47
```

16. Set 23
```
TX> 0x | 47 41 49 54 45 4B   BD   08 17 00 00 00               08   AA
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 17 35 1E 00 00   29   8F   4B 45 54 49 41 47
```

17. Set 22
```
TX> 0x | 47 41 49 54 45 4B   BD   08 16 00 00 00               08   AB
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 16 35 1E 00 00   28   8F   4B 45 54 49 41 47
```

18. Set 21
```
TX> 0x | 47 41 49 54 45 4B   BD   08 15 00 00 00               08   A8
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 15 35 1E 00 00   2B   8F   4B 45 54 49 41 47
```

19. Set 20
```
TX> 0x | 47 41 49 54 45 4B   BD   08 14 00 00 00               08   A9
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 14 35 1E 00 00   2A   8F   4B 45 54 49 41 47
```

20. Set 19
```
TX> 0x | 47 41 49 54 45 4B   BD   08 13 00 00 00               08   AE
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 13 35 1E 00 00   2D   8F   4B 45 54 49 41 47
```

21. Set 18
```
TX> 0x | 47 41 49 54 45 4B   BD   08 12 00 00 00               08   AF
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 12 35 1E 00 00   2C   8F   4B 45 54 49 41 47
```

22. Set 17
```
TX> 0x | 47 41 49 54 45 4B   BD   08 11 00 00 00               08   AC
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 11 35 1E 00 00   2F   8F   4B 45 54 49 41 47
```

23. Set 16 (min)
```
TX> 0x | 47 41 49 54 45 4B   BD   08 10 00 00 00               08   AD
RX< 0x | 47 41 49 54 45 4B   BD   01 10 21 17 10 35 1E 00 00   2E   8F   4B 45 54 49 41 47
```

24. Power off
```
TX> 0x | 47 41 49 54 45 4B   BD   00 00 00 00 00               00   BD
RX< 0x | 47 41 49 54 45 4B   BD   00 10 21 17 10 35 1E 00 00   2F   8F   4B 45 54 49 41 47
```
