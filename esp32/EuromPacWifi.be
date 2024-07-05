# Eurom Pac Wifi tasmota driver
# template: {"NAME":"Eurom PAC 12.2 WiFi","GPIO":[32,0,0,0,0,3232,0,3200,0,0,0,0,0,0,0,576,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}

import webserver
import string

class Log
  static PREFIX = "BERRY"
  static SEP = ": "
  var msg

  def init(prefix, sep)
    self.msg = !prefix ? self.PREFIX : prefix
    self.msg += !sep ? self.SEP : sep
  end

  def Info(msg)
    log(self.msg + msg, 2)
  end

  def Error(msg)
    log(self.msg + msg, 1)
  end

  def Debug(msg)
    log(self.msg + msg, 3)
  end
end


class EuromPacWifi : Driver
  static DEVICE = "EuromPACWifi"
  static HEARTBEAT_SEC = 120
  static PREFIX = bytes('47414954454B')
  static HEADER = bytes('BD')
  static MSG_SUFFIX = bytes('4B4554494147')
  static MSG_LEN = 24
  static CMD_LEN = 14
  static MODE_COOL = "cool"
  static MODE_FAN = "fan"
  static MODE_DRY = "dehum"
  static FAN_HIGH = "high"
  static FAN_MEDIUM = "medium"
  static FAN_LOW = "low"
  static UNDEFINED = "undef"
  static PRECISION = 1.0
  static TEMPERATURE_UNIT = "C"
  static HUMIDITY_UNIT = "pct"
  static TARGET_RANGE_TEMP = [16, 31]
  static TARGET_RANGE_HUM = [30, 90]
  static HEARTBEAT_PUBLISH_SEC = 300

  # create serial port object
  var _uart
  var _heartbeat_timer
  var _heartbeat_publish_timer
  var _previous_checksum
  var _log
  var _prefix_len
  var _msg_suffix_len
  var power
  # Connected with mqtt/remote
  var connected
  var mode
  var speed
  var swing
  var current_temperature
  var target_temperature
  var current_humidity
  var target_humidity
  var timer_hours

  # intialize the serial port, TX and RX defined in the template as SerTX and SerRX
  def init(tx, rx)
    self._log = Log(self.DEVICE)
    self._prefix_len = size(self.PREFIX)
    self._msg_suffix_len = size(self.MSG_SUFFIX)
    self._previous_checksum = bytes("0000")
    tx = !tx ? gpio.pin(gpio.TXD) : tx
    rx = !rx ? gpio.pin(gpio.RXD) : rx
    self._uart = serial(rx, tx, 9600, serial.SERIAL_8N1)
    self._log.Info(f"UART initialized GPIO tx={tx} rx={rx}")
    self._heartbeat_timer = self.HEARTBEAT_SEC
    self._heartbeat_publish_timer = self.HEARTBEAT_PUBLISH_SEC
    self.mode = self.UNDEFINED
    self.speed = self.UNDEFINED
    self.connected = false
    self.power = false
    self.swing = false
    self.timer_hours = 0
    tasmota.add_driver(self)
  end

  def deinit()
    self.remove_tasmota_commands()
    tasmota.remove_driver(self)
  end

  # heartbeat
  def every_second()
    if self._heartbeat_timer <= 0
      self.heartbeat()
      self._heartbeat_timer = self.HEARTBEAT_SEC
    else
      self._heartbeat_timer -= 1
    end
    if self._heartbeat_publish_timer <= 0
        tasmota.publish_result("{" + self.state_report() + "}", "RESULT")
        self._heartbeat_publish_timer = self.HEARTBEAT_PUBLISH_SEC
    else
        self._heartbeat_publish_timer -= 1
    end
  end

  # read serial port
  def every_50ms()
    var changes = self.receive()
    if changes != nil && changes.size() > 0
        self._log.Debug(f"Data has changed")
        tasmota.publish_result("{" + self.state_report(changes) + "}", "RESULT")
        self._heartbeat_publish_timer = self.HEARTBEAT_PUBLISH_SEC
    end
  end

  def decode_msg(datagram)
    var data = datagram[0..9]
    var current_chks = datagram[10..11]
    var expected_chks = self.checksum(data)
    var mode_codes = {
        0x01 : self.MODE_COOL,
        0x03 : self.MODE_DRY,
        0x06 : self.MODE_FAN
    }
    var speed_codes = {
        0x10 : self.FAN_HIGH,
        0x20 : self.FAN_MEDIUM,
        0x30 : self.FAN_LOW
    }
    var changes = []
    if data[0] == self.HEADER[0]
      if current_chks == expected_chks
        var power = bool(data[1] & (1 << 0))
        changes += (self.power != power) ? ["power"] : []
        self.power = power
        var swing = bool(data[1] & (1 << 2))
        changes += (self.swing != swing) ? ["swing"] : []
        self.swing = swing
        var speed = speed_codes.find(data[3] & 0xF0, self.UNDEFINED)
        changes += (self.speed != speed) ? ["fan"] : []
        self.speed = speed
        var mode = mode_codes.find(data[3] & 0x0F, self.UNDEFINED)
        changes += (self.mode != mode) ? ["mode"] : []
        self.mode = mode
        changes += (self.current_temperature != data[4]) ? ["current_temperature"] : []
        self.current_temperature = data[4]
        changes += (self.target_temperature != data[5]) ? ["target_temperature"] : []
        self.target_temperature = data[5]
        changes += (self.current_humidity != data[6]) ? ["current_humidity"] : []
        self.current_humidity = data[6]
        changes += (self.target_humidity != data[7]) ? ["target_humidity"] : []
        self.target_humidity = data[7]
        changes += (self.timer_hours != data[8]) ? ["timer"] : []
        self.timer_hours = data[8]
        self._previous_checksum = current_chks
        return changes
      else
        self._log.Error(f"Data CheckSum8 XOR Error: {current_chks} != checksum({data}) == {expected_chks}")
      end
    else
      self._log.Error(f"Data Header Error: {data[0]} != {self.HEADER}")
    end
    return changes
  end

  def receive()
    var s = self._uart.available()
    if s == self.MSG_LEN
      # read bytes from serial as bytes
      var msg = self._uart.read()
      if size(msg) == self.MSG_LEN
        var gaitek = msg[0..(self._prefix_len-1)]
        var datagram = msg[(self._prefix_len)..(self.MSG_LEN-self._msg_suffix_len-1)]
        var ketiag = msg[(self.MSG_LEN-self._msg_suffix_len)..(self.MSG_LEN-1)]
        if gaitek == self.PREFIX && ketiag == self.MSG_SUFFIX
          self._log.Debug(f"UART RX={str(msg)}")
          return self.decode_msg(datagram)
        end
      end
      self._log.Error(f"UART error decoding frame RX={str(msg)} size={size(msg)}")
    elif s > 24
      var msg = self._uart.read()
      self._log.Error(f"UART error: frame RX={str(msg)} size={size(msg)} too big")
      self._uart.flush()
    end
    return []
  end

  def send(data)
    var command = self.HEADER + data
    var datagram = self.PREFIX + command + self.checksum(command)
    self._log.Debug(f"UART TX={str(datagram)}")
    var amount = self._uart.write(datagram)
    self._uart.flush()
    return amount
  end

  def checksum(data)
    var xor_odd = 0
    var xor_eve = 0
    var result = bytes("0000")
    for i: 0..size(data)-1
      if i % 2 == 0
        xor_eve ^= data.get(i, 1)
      else
        xor_odd ^= data.get(i, 1)
      end
    end
    result.set(0, xor_odd, 1)
    result.set(1, xor_eve, 1)
    return result
  end

  def heartbeat()
    var cmd = bytes("FF00000000")
    cmd.set(1, (tasmota.wifi("ip") != nil) ? 0x01 : 0x00)
    return self.send(cmd)
  end

  def set_power(value)
    var cmd = bytes("0000000000")
    var a = (value != nil) ? int(bool(value)) : int(!self.power)
    cmd.set(1, a)
    self._log.Debug(f"Set power to {a}")
    return self.send(cmd)
  end

  def set_swing(value)
    var cmd = bytes("0100000000")
    var a = (value != nil) ? int(bool(value)) : int(!self.swing)
    cmd.set(1, a)
    self._log.Debug(f"Set swing to {a}")
    return self.send(cmd)
  end

  def set_speed(value)
    var cmd = bytes("0700000000") 
    var speed_codes = {
        self.FAN_HIGH: 0x01,
        self.FAN_MEDIUM: 0x02,
        self.FAN_LOW: 0x03
    }
    if self.speed == value
      self._log.Debug(f"Fan speed is already set to {value}")
      return 0
    end
    try
      cmd.set(1, speed_codes[value])
      self._log.Debug(f"Set fan speed to {value}")
      return self.send(cmd)
    except .. as e,m
      self._log.Error(f"Error: fan speed not set, {str(e)}: {m}")
    end
    return -1
  end

  def set_mode(value)
    var cmd = bytes("0600000000") 
    var mode_codes = {
        self.MODE_COOL: 0x01,
        self.MODE_DRY: 0x03,
        self.MODE_FAN: 0x06
    }
    if self.mode == value
      self._log.Debug(f"Mode is already set to {value}")
      return 0
    end
    try
      cmd.set(1, mode_codes[value])
      self._log.Debug(f"Set mode to {value}")
      return self.send(cmd)
    except .. as e,m
      self._log.Error(f"Error: mode not set, {str(e)}: {m}")
    end
    return -1
  end

  def set_temperature(value)
    if value == nil || value < 16 || value > 31
        self._log.Error(f"Error: temperature not set, value {value} out of range: [16..31]")
        return -1
    end
    if value == self.target_temperature
        self._log.Info(f"Target temperature is already set to value {value}")
        return 0
    end  
    var cmd = bytes("0800000000")
    cmd.set(1, value)
    self._log.Debug(f"Set target temperature to {value}")
    return self.send(cmd)
  end

  def inc_temperature()
    var temp = self.target_temperature
    if temp >= 30
        temp = 31
    else
        temp += 1
    end
    return self.set_temperature(temp)
  end

  def dec_temperature()
    var temp = self.target_temperature
    if temp <= 17
        temp = 16
    else
        temp -= 1
    end
    return self.set_temperature(temp)
  end

  def set_humidity(value)
    if value == nil || value < 30 || value > 90
        self._log.Error(f"Error: humidity not set, value {value} out of range: [30..90]")
        return -1
    end
    if value == self.target_humidity
        self._log.Info(f"Target humidity is already set to value {value}")
        return 0
    end
    var cmd = bytes("0900000000")
    cmd.set(1, value)
    self._log.Debug(f"Set target humidity to {value}")
    return self.send(cmd)
  end

  def inc_humidity()
    var humidity = self.target_humidity
    if humidity < 40
        humidity = 40
    elif humidity >= 85
        humidity = 90
    else
        humidity += 5
    end
    return self.set_humidity(humidity)
  end

  def dec_humidity()
    var humidity = self.target_humidity
    if humidity <= 40
        humidity = 30
    else
        humidity -= 5
    end
    return self.set_humidity(humidity)
  end

  def set_timer(value)
    if value == nil || value < 0 || value > 24
        self._log.Error(f"Error: timer not set, value {value} out of range: [0..24]")
        return -1
    end
    var cmd = bytes("0A00000000")
    cmd.set(1, value)
    self._log.Debug(f"Set timer to {value}")
    return self.send(cmd)
  end

  def state_report(changeslist)
    var msg = ""
    var power = "off"
    var precision = 1.0
    var temperature_unit = "C"
    var fan_mode = self.speed
    var target_temperature_high = 31
    var target_temperature_low = 16
    var swing_mode = self.swing ? "on" : "off"
    var hvac_mode = "off"
    var hvac_action = "off"
    var timer_mode = "off"
    var power_mode = "off"
    # action mode: "off, heating, cooling, drying, idle, fan
    if self.power
        power = "on"
        hvac_action = "idle"
        power_mode = self.mode
        if self.mode == self.MODE_FAN
            hvac_action = "fan"
            hvac_mode = "fan_only"
            power_mode = "fan"
        else
            if self.mode == self.MODE_DRY
                hvac_mode = "dry"
                if self.current_humidity >= self.target_humidity
                    hvac_action = "drying"
                end
            else
                hvac_mode = "cool"
                if self.current_temperature >= self.target_temperature
                    hvac_action = "cooling"
                end
            end
        end
    elif self.timer_hours != 0
        hvac_action = "idle"
        timer_mode = self.power ? "timer" : "sleep"
        power_mode = "timer"
    end
    # time
    var time = tasmota.rtc()
    var time_utc = tasmota.time_str(time['utc'])
    var time_restart = tasmota.time_str(time['restart'])
    # data
    msg  = f'"time_utc":"{time_utc}", "time_restart":"{time_restart}", ' 
    msg += f'"pwr":{int(self.power)}, "power":"{power}", "mode":"{self.mode}", "fan":"{self.speed}", "swing":{int(self.swing)}, '
    msg += f'"target_temperature":{self.target_temperature}, "target_humidity":{self.target_humidity}, '
    msg += f'"current_temperature":{self.current_temperature}, "current_humidity":{self.current_humidity}, '
    msg += f'"power_mode":"{power_mode}", "hvac_action":"{hvac_action}", "hvac_mode":"{hvac_mode}", "fan_mode":"{fan_mode}", '
    msg += f'"swing_mode":"{swing_mode}", "timer_mode":"{timer_mode}", "timer_unit":"H", "timer":{self.timer_hours}, '
    msg += f'"temperature_unit":"{self.TEMPERATURE_UNIT}", "precision":{self.PRECISION}, "humidity_unit":"{self.HUMIDITY_UNIT}", '
    msg += f'"target_temperature_low":{self.TARGET_RANGE_TEMP[0]}, "target_temperature_high":{self.TARGET_RANGE_TEMP[1]}, '
    msg += f'"target_humidity_low":{self.TARGET_RANGE_HUM[0]}, "target_humidity_high":{self.TARGET_RANGE_HUM[1]}'
    msg += (changeslist == nil) ? f'' : f', "changes":{string.tr(changeslist.tostring(), "\'", \'"\')}'
    return msg
  end

  def json_append()
    var msg = ", " + self.state_report()
    tasmota.response_append(msg)
  end

  def add_tasmota_commands()
    tasmota.add_cmd('power', /cmd, idx, payload, payload_json -> self.tasmota_power_cmd_handler(cmd, idx, payload, payload_json))
    tasmota.add_cmd('swing', /cmd, idx, payload, payload_json -> self.tasmota_swing_cmd_handler(cmd, idx, payload, payload_json))
    tasmota.add_cmd('mode', /cmd, idx, payload, payload_json -> self.tasmota_mode_cmd_handler(cmd, idx, payload, payload_json))
    tasmota.add_cmd('fan', /cmd, idx, payload, payload_json -> self.tasmota_speed_cmd_handler(cmd, idx, payload, payload_json))
    tasmota.add_cmd('humidity', /cmd, idx, payload, payload_json -> self.tasmota_sethum_cmd_handler(cmd, idx, payload, payload_json))
    tasmota.add_cmd('temperature', /cmd, idx, payload, payload_json -> self.tasmota_settemp_cmd_handler(cmd, idx, payload, payload_json))
    tasmota.add_cmd('timer', /cmd, idx, payload, payload_json -> self.tasmota_timer_cmd_handler(cmd, idx, payload, payload_json))
  end

  def remove_tasmota_commands()
    tasmota.remove_cmd('power')
    tasmota.remove_cmd('swing')
    tasmota.remove_cmd('fan')
    tasmota.remove_cmd('mode')
    tasmota.remove_cmd('humidity')
    tasmota.remove_cmd('temperature')
    tasmota.remove_cmd('timer')
end

  def tasmota_power_cmd_handler(cmd, idx, payload, payload_json)
    var ret = 0
    var js = isinstance(payload_json, map)
    var action = string.tolower((!js) ? payload : payload_json.find(cmd) != nil ? payload_json.find(cmd) : "")
    if action == "on" || action == "true" || action == "1"
        ret = self.set_power(true)
    elif action == "off" || action == "false" || action == "0"
        ret = self.set_power(false)
    elif action == "toggle"
        ret = self.set_power()
    elif action != ""
        tasmota.resp_cmnd_error()
        return
    end
    if ret < 0
        tasmota.resp_cmnd_failed()
    else
        if ret != 0
            tasmota.resp_cmnd_done()
        else
            js ? tasmota.resp_cmnd(format('{"power":%d}', int(self.power))) : tasmota.resp_cmnd_str(str(int(self.power)))
        end
    end
  end

  def tasmota_swing_cmd_handler(cmd, idx, payload, payload_json)
    var ret = 0
    var js = isinstance(payload_json, map)
    var action = string.tolower((!js) ? payload : payload_json.find(cmd) != nil ? payload_json.find(cmd) : "")
    if action == "on" || action == "true" || action == "1"
        ret = self.set_swing(true)
    elif action == "off" || action == "false" || action == "0"
        ret = self.set_swing(false)
    elif action == "toggle"
        ret = self.set_swing()
    elif action != ""
        tasmota.resp_cmnd_error()
        return
    end
    if ret < 0
        tasmota.resp_cmnd_failed()
    else
        if ret != 0
            tasmota.resp_cmnd_done()
        else
            js ? tasmota.resp_cmnd(format('{"swing":%d}', int(self.swing))) : tasmota.resp_cmnd_str(str(int(self.swing)))
        end
    end
  end

  def tasmota_mode_cmd_handler(cmd, idx, payload, payload_json)
    var ret = 0
    var js = isinstance(payload_json, map)
    var action = string.tolower((!js) ? payload : payload_json.find(cmd) != nil ? payload_json.find(cmd) : "")
    # homeassitant mqtt climate compatibility
    action = (action == "fan_only") ? self.MODE_FAN : action
    action = (action == "dry") ? self.MODE_DRY : action
    if action == "on"
        ret = self.set_power(true)
    elif action == "off"
        ret = self.set_power(false)
    elif action == ""
        ret = 0
    else
        ret = self.set_mode(action)
        if ret >= 0
            if !self.power
                tasmota.delay(50)
                ret = self.set_power(true)
            end
        end
    end
    if ret < 0
        tasmota.resp_cmnd_failed()
    else
        if ret != 0
            tasmota.resp_cmnd_done()
        else
            var mode = self.power ? self.mode : "off"
            js ? tasmota.resp_cmnd(format('{"mode":"%s"}', mode)) : tasmota.resp_cmnd_str(mode)
        end
    end
  end

  def tasmota_speed_cmd_handler(cmd, idx, payload, payload_json)
    var js = isinstance(payload_json, map)
    var action = string.tolower((!js) ? payload : payload_json.find(cmd) != nil ? payload_json.find(cmd) : "")
    var ret = (action != "") ? self.set_speed(action) : 0
    if ret < 0
        tasmota.resp_cmnd_failed()
    else
        if ret != 0
            tasmota.resp_cmnd_done()
        else
            js ? tasmota.resp_cmnd(format('{"fan":"%s"}', self.speed)) : tasmota.resp_cmnd_str(self.speed)
        end
    end
  end

  def tasmota_sethum_cmd_handler(cmd, idx, payload, payload_json)
    var js = isinstance(payload_json, map)
    var action = (!js) ? payload : payload_json.find(cmd) != nil ? payload_json.find(cmd) : ""
    var ret = (action != "") ? self.set_humidity(int(action)) : 0
    if ret < 0
        tasmota.resp_cmnd_failed()
    else
        if ret != 0
            tasmota.resp_cmnd_done()
        else
            js ? tasmota.resp_cmnd(format('{"target_humidity":%d}', self.target_humidity)) : tasmota.resp_cmnd_str(str(self.target_humidity))
        end
    end
  end

  def tasmota_settemp_cmd_handler(cmd, idx, payload, payload_json)
    var js = isinstance(payload_json, map)
    var action = (!js) ? payload : payload_json.find(cmd) != nil ? payload_json.find(cmd) : ""
    var ret = (action != "") ? self.set_temperature(int(action)) : 0
    if ret < 0
        tasmota.resp_cmnd_failed()
    else
        if ret != 0
            tasmota.resp_cmnd_done()
        else
            js ? tasmota.resp_cmnd(format('{"target_temperature":%d}', self.target_temperature)) : tasmota.resp_cmnd_str(str(self.target_temperature))
        end
    end
  end

  def tasmota_timer_cmd_handler(cmd, idx, payload, payload_json)
    var js = isinstance(payload_json, map)
    var action = string.tolower((!js) ? payload : payload_json.find(cmd) != nil ? payload_json.find(cmd) : "")
    var ret = 0
    if action == "0" || action == "off" || action == "false"
        ret = self.set_timer(0)
    else
        var value = int(action)
        ret = (value != 0) ? self.set_timer(value) : 0
    end
    if ret < 0
        tasmota.resp_cmnd_failed()
    else
        if ret != 0
            tasmota.resp_cmnd_done()
        else
            js ? tasmota.resp_cmnd(format('{"timer":%d}', self.timer_hours)) : tasmota.resp_cmnd_str(str(self.timer_hours))
        end
    end
  end

  def web_add_main_button()
    var selected = / a b -> a == b ? "selected":""
    var hours = / h -> h == 0 ? "disabled" : str(h) + " hour(s)"
    var html = '<p></p>'
    html += '<p></p>'
    html += '<table style="width:100%"><tbody><tr>'
    html += '  <td style="width:50%;padding: 0 4px 0 4px;">'
    html += '    <label for="sel_mode"><small>Operating Mode:</small></label>'
    html += '    <select id="sel_mode" name="sel_mode">'
    html +=f'      <option value="cool" { selected(self.mode,self.MODE_COOL) }>Cool</option>'
    html +=f'      <option value="dehum" { selected(self.mode,self.MODE_DRY) }>Dehum</option>'
    html +=f'      <option value="fan" { selected(self.mode,self.MODE_FAN) }>Fan</option>'
    html += '    </select>'
    html += '  </td>'
    html += '  <td style="width:50%;padding: 0 4px 0 4px;">'
    html += '    <label for="sel_speed"><small>Fan Speed:</label>'
    html += '    <select id="sel_speed" name="sel_speed">'
    html +=f'      <option value="high" { selected(self.speed,self.FAN_HIGH) }>High</option>'
    html +=f'      <option value="medium" { selected(self.speed,self.FAN_MEDIUM) }>Medium</option>'
    html +=f'      <option value="low" { selected(self.speed,self.FAN_LOW) }>Low</option>'
    html += '    </select>'
    html += '  </td>'
    html += '</tr></tbody></table>'
    html += '<p></p>'
    html += '<table style="width:100%"><tbody><tr>'
    html += '  <td style="width:33.33%"><button id="bn_up" name="bn_up" onclick="la(\'&m_sv_up=1\');">  +  </button></td>'
    html += '  <td style="width:33.33%"><button id="bn_down" name="bn_down" onclick="la(\'&m_sv_down=1\');">  -  </button></td>'
    html += '  <td style="width:33.33%"><button id="bn_swing" name="bn_swing" onclick="la(\'&m_sv_swing=1\');">swing</button></td>'
    html += '</tr></tbody></table>'
    html += '<p></p>'
    html += '<table style="width:100%"><tbody><tr>'
    html += '  <td style="width:33.33%"><button id="bn_on" name="bn_on" onclick="la(\'&m_sv_on=1\');"> power </button></td>'
    html += '  <td style="width:33.33%"><p style="text-align:right;">Timer: </p></td>'
    html += '  <td style="width:33.33%">'
    html += '    <select id="sel_timer" name="sel_timer">'
    for h: 0..24
      html +=f'    <option value="{h}_h" { selected(self.timer_hours,h) }>{ hours(h) }</option>'
    end
    html += '    </select>'
    html += '  </td>'
    html += '</tr></tbody></table>'
    html += '<script>'
    html += 'document.getElementById("sel_speed").addEventListener ("change",function(){la("&m_sv_sel_speed="+this.value);});'
    html += 'document.getElementById("sel_mode").addEventListener ("change",function(){la("&m_sv_sel_mode="+this.value);});'
    html += 'document.getElementById("sel_timer").addEventListener ("change",function(){la("&m_sv_sel_timer="+this.value);});'
    html += '</script>'
    html += '<p></p>'
    html += '<p></p>'
    webserver.content_send(html)
    html = nil
    tasmota.gc()
  end

  def web_sensor()
    var oper_mode =  self.timer_hours == 0 ? self.power ? "ON" : "OFF" : "TIMER"
    var swing = self.swing ? "ON" : "OFF"
    var sensor_data = format(
      "{s}Power Mode{m}%s{e}"..
      "{s}Operation Mode{m}%s{e}"..
      "{s}Fan Speed{m}%s{e}"..
      "{s}Swing enabled{m}%s{e}"..
      "{s}Target temperature{m}%s °C{e}"..
      "{s}Target humidity{m}%s %%{e}"..
      "{s}Current temperature{m}%s °C{e}"..
      "{s}Current humidity{m}%s %%{e}",
      oper_mode, string.toupper(self.mode), string.toupper(self.speed), swing,
      self.target_temperature, self.target_humidity, self.current_temperature, self.current_humidity
    )
    tasmota.web_send_decimal(sensor_data)
    if self.timer_hours != 0
        var timer_target = self.power ? "SLEEP" : "START"
        var timer_mode = self.timer_hours == 0 ? "disabled" : str(self.timer_hours) + " h"
        tasmota.web_send_decimal(format("{s}Timer to %s{m}%s{e}", timer_target, timer_mode))
    end
    if webserver.has_arg("m_sv_sel_timer")
      var value = int(string.split(webserver.arg("m_sv_sel_timer"), "_", 1)[0])
      self.set_timer(value)
    end
    if webserver.has_arg("m_sv_sel_mode")
      var value = webserver.arg("m_sv_sel_mode")
      self.set_mode(value)
    end
    if webserver.has_arg("m_sv_sel_speed")
      var value = webserver.arg("m_sv_sel_speed")
      self.set_speed(value)
    end
    if webserver.has_arg("m_sv_on")
      self.set_power()
    end
    if webserver.has_arg("m_sv_swing")
      self.set_swing()
    end
    if webserver.has_arg("m_sv_up")
      if self.mode == self.MODE_COOL
        self.inc_temperature()
      elif self.mode == self.MODE_DRY
        self.inc_humidity()
      else
        self._log.Error(f"Error increasing, incorrect mode. Switch mode first")
      end
    end
    if webserver.has_arg("m_sv_down")
      if self.mode == self.MODE_COOL
        self.dec_temperature()
      elif self.mode == self.MODE_DRY
        self.dec_humidity()
      else
        self._log.Error(f"Error decreasing, incorrect mode. Switch mode first")
      end
    end
  end
end

# Start driver
eurom=EuromPacWifi()

# add commands form mqtt and console
eurom.add_tasmota_commands()

# remove
#eurom.remove_tasmota_commands()
#eurom.deinit()