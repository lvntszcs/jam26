extends Node
## Gamepad feedback for the DualSense (works with any rumble pad): layered rumble
## on both motors, light bar and motion sensors.
##
## Motors: "low" = left/strong motor (heavy body rumble),
##         "high" = right/weak motor (sharp, buzzy detail).
## Every effect is a voice; voices are summed per motor every frame, so a
## continuous engine rumble and a one-shot hit can play at the same time.

signal device_changed(device: int)

enum Envelope { CONSTANT, DECAY, PULSE }
enum Trigger { LEFT, RIGHT }

## Global strength multiplier (accessibility / options menu). 0 = rumble off.
var intensity := 1.0
## Joypad that last sent input; all feedback goes here.
var device := -1
## Light bar color applied to the active pad.
var light_color := Color("#349189"):
	set(value):
		light_color = value
		_apply_light()

const _REFRESH := 0.1  # resend rumble this often, motor command lasts 2x longer
const _AXIS_WAKE := 0.5  # axis movement that switches the active pad

var _voices := {}  # id -> _Voice
var _next_id := 1
var _sent := Vector2(-1.0, -1.0)
var _since_send := 0.0
var _light_tween: Tween


class _Voice:
	var low: float
	var high: float
	var duration: float  # <= 0 means loop until stop()
	var envelope: Envelope
	var pulse_hz: float
	var delay: float
	var elapsed := 0.0

	func gain() -> float:
		match envelope:
			Envelope.DECAY:
				var t := clampf(elapsed / duration, 0.0, 1.0)
				return (1.0 - t) * (1.0 - t)
			Envelope.PULSE:
				return 1.0 if fmod(elapsed * pulse_hz, 1.0) < 0.5 else 0.0
		return 1.0

	func finished() -> bool:
		return duration > 0.0 and elapsed >= duration


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		_set_device(pads[0])


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > _AXIS_WAKE):
		if event.device != device:
			_set_device(event.device)


func _process(delta: float) -> void:
	var low := 0.0
	var high := 0.0
	for id in _voices.keys():
		var v: _Voice = _voices[id]
		if v.delay > 0.0:
			v.delay -= delta
			continue
		v.elapsed += delta
		if v.finished():
			_voices.erase(id)
			continue
		var g := v.gain()
		low += v.low * g
		high += v.high * g
	_send(clampf(low * intensity, 0.0, 1.0), clampf(high * intensity, 0.0, 1.0), delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		stop_all()
		triggers_off()


# --- Rumble primitives -------------------------------------------------------

## One-shot rumble. Returns a voice id.
func rumble(low: float, high: float, duration: float, envelope := Envelope.DECAY, delay := 0.0) -> int:
	return _add(low, high, maxf(duration, 0.01), envelope, 0.0, delay)


## Continuous rumble until stop(id). Change it every frame with set_voice().
func rumble_loop(low: float, high: float) -> int:
	return _add(low, high, 0.0, Envelope.CONSTANT, 0.0, 0.0)


## On/off buzzing at `hz`. duration <= 0 loops until stop(id).
func pulse(low: float, high: float, hz: float, duration := 0.0) -> int:
	return _add(low, high, duration, Envelope.PULSE, hz, 0.0)


func set_voice(id: int, low: float, high: float) -> void:
	if _voices.has(id):
		_voices[id].low = low
		_voices[id].high = high


func stop(id: int) -> void:
	_voices.erase(id)


func stop_all() -> void:
	_voices.clear()
	_send(0.0, 0.0, _REFRESH)


# --- Presets -----------------------------------------------------------------

## Tiny click: UI, footstep, pickup.
func tap() -> void:
	rumble(0.0, 0.5, 0.05, Envelope.CONSTANT)


## Hit taken or dealt. strength 0..1.
func impact(strength := 1.0) -> void:
	rumble(0.8 * strength, 0.4 * strength, 0.12 + 0.18 * strength)


## One tick of damage over time (poison, burn, bleed). Call it on every tick.
## Short, sharp double-motor sting so repeated ticks stay distinct instead of
## blurring into one rumble. strength 0..1, e.g. damage / max_hp scaled up.
func damage_tick(strength := 0.5) -> void:
	var s := clampf(strength, 0.0, 1.0)
	rumble(0.25 + 0.55 * s, 0.35 + 0.45 * s, 0.09)
	flash_light(Color("#c94b01"), 0.25)


## Big boom: sharp crack, then a long heavy tail.
func explosion() -> void:
	rumble(0.0, 1.0, 0.08, Envelope.CONSTANT)
	rumble(1.0, 0.3, 0.9, Envelope.DECAY, 0.04)


## Lub-dub heartbeat for `beats` beats (low health, tension).
func heartbeat(bpm := 70.0, beats := 4) -> void:
	var period := 60.0 / bpm
	for i in beats:
		rumble(0.7, 0.0, 0.12, Envelope.DECAY, i * period)
		rumble(0.45, 0.0, 0.1, Envelope.DECAY, i * period + 0.18)


# --- Adaptive triggers -------------------------------------------------------
# Implemented in C# (DualSenseTriggers.cs, raw HID). Positions are trigger travel
# zones 0 (released) .. 9 (fully pressed), strengths 1 (light) .. 8 (max).
# Calls do nothing when no DualSense is reachable.

func has_triggers() -> bool:
	var t := _triggers()
	return t != null and t.HasController()


## Trigger moves freely again.
func trigger_off(trigger: Trigger) -> void:
	var t := _triggers()
	if t:
		t.Off(trigger)


func triggers_off() -> void:
	var t := _triggers()
	if t:
		t.OffAll()


## Constant resistance from `start` on: pushing something heavy.
func trigger_resistance(trigger: Trigger, start := 0, strength := 6) -> void:
	var t := _triggers()
	if t:
		t.Resistance(trigger, start, strength)


## Resistance that grows with the press: a spring or a load getting heavier.
func trigger_ramp(trigger: Trigger, start := 0, from_strength := 1, to_strength := 8) -> void:
	var t := _triggers()
	if t:
		t.Ramp(trigger, start, from_strength, to_strength)


## Free travel, then it gets stuck at `start` and snaps through at `end`.
## start 2..7, end start+1..8.
func trigger_snap(trigger: Trigger, start := 3, end := 6, strength := 8) -> void:
	var t := _triggers()
	if t:
		t.Snap(trigger, start, end, strength)


## Trigger buzzes from `start` on: grinding, jammed, stalling.
func trigger_vibrate(trigger: Trigger, start := 0, amplitude := 6, hz := 30) -> void:
	var t := _triggers()
	if t:
		t.Vibrate(trigger, start, amplitude, hz)


func _triggers() -> Node:
	return get_node_or_null(^"/root/DualSenseTriggers")


# --- Light bar ---------------------------------------------------------------

## Flash the light bar to `color`, then fade back to light_color.
func flash_light(color: Color, duration := 0.3) -> void:
	if _light_tween:
		_light_tween.kill()
	var base := light_color
	_light_tween = create_tween()
	_light_tween.tween_method(_set_raw_light, color, base, duration)


# --- Motion sensors ----------------------------------------------------------

func has_motion() -> bool:
	return device >= 0 and Input.has_joy_motion_sensors(device)


func set_motion_enabled(enabled: bool) -> void:
	if has_motion():
		Input.set_joy_motion_sensors_enabled(device, enabled)


## Angular velocity in rad/s.
func get_gyro() -> Vector3:
	return Input.get_joy_gyroscope(device) if device >= 0 else Vector3.ZERO


## Gravity direction relative to the controller.
func get_gravity() -> Vector3:
	return Input.get_joy_gravity(device) if device >= 0 else Vector3.ZERO


# --- Internals ---------------------------------------------------------------

func _add(low: float, high: float, duration: float, envelope: Envelope, hz: float, delay: float) -> int:
	var v := _Voice.new()
	v.low = low
	v.high = high
	v.duration = duration
	v.envelope = envelope
	v.pulse_hz = hz
	v.delay = delay
	var id := _next_id
	_next_id += 1
	_voices[id] = v
	return id


func _send(low: float, high: float, delta: float) -> void:
	if device < 0:
		return
	_since_send += delta
	var target := Vector2(low, high)
	if target.is_equal_approx(_sent) and (_since_send < _REFRESH or target == Vector2.ZERO):
		return
	_since_send = 0.0
	_sent = target
	if target == Vector2.ZERO:
		Input.stop_joy_vibration(device)
	else:
		Input.start_joy_vibration(device, high, low, _REFRESH * 2.0)


func _set_device(new_device: int) -> void:
	if device >= 0:
		Input.stop_joy_vibration(device)
	device = new_device
	_sent = Vector2(-1.0, -1.0)
	_apply_light()
	set_motion_enabled(true)
	device_changed.emit(device)


func _apply_light() -> void:
	_set_raw_light(light_color)


func _set_raw_light(color: Color) -> void:
	if device >= 0 and Input.has_joy_light(device):
		Input.set_joy_light(device, color)


func _on_joy_connection_changed(joy: int, connected: bool) -> void:
	if connected and device < 0:
		_set_device(joy)
	elif not connected and joy == device:
		device = -1
		var pads := Input.get_connected_joypads()
		if not pads.is_empty():
			_set_device(pads[0])
