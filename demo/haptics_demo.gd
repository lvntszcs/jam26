extends Control
## Test bench for DualSense feedback. Run it and feel each effect.

const PALETTE: Array[Color] = [
	Color("#349189"), Color("#d3fe28"), Color("#c94b01"),
	Color("#9625fd"), Color("#a9ff00"), Color("#406635"),
]

const TRIGGER_MODES: Array[String] = ["ramp", "stuck", "jammed"]
const MAX_TRIGGER_LEVEL := 8

const DOT_INTERVAL := 0.5
const DOT_DAMAGE := 4.0
const MAX_HP := 100.0

var _engine_id := -1
var _light_index := 0
var _trigger_mode := 0
## 0 = triggers free (R2/L2 drive the motors instead), 1..8 = resistance strength.
var _trigger_level := 4
var _hp := MAX_HP
var _dot_timer := Timer.new()

@onready var _info: Label = $Info
@onready var _status: Label = $Status
@onready var _tilt: ColorRect = $Tilt


func _ready() -> void:
	_info.text = "\n".join([
		"Cross: tap        Circle: impact",
		"Square: explosion Triangle: heartbeat",
		"R1: toggle damage over time (tick every %.1fs)" % DOT_INTERVAL,
		"D-pad Up/Down: trigger resistance (0 = free, R2/L2 drive motors)",
		"L1: trigger feel (ramp / stuck / jammed)",
		"D-pad L/R: light bar color   Options: stop all",
		"Tilt the controller to move the square",
	])
	_engine_id = DualSense.rumble_loop(0.0, 0.0)
	DualSense.device_changed.connect(func(_d: int) -> void: _engine_id = DualSense.rumble_loop(0.0, 0.0))
	_dot_timer.wait_time = DOT_INTERVAL
	_dot_timer.timeout.connect(_on_dot_tick)
	add_child(_dot_timer)
	_apply_trigger()


func _on_dot_tick() -> void:
	_hp = maxf(_hp - DOT_DAMAGE, 0.0)
	# Ticks get stronger as health runs out.
	DualSense.damage_tick(lerpf(0.3, 1.0, 1.0 - _hp / MAX_HP))
	if _hp <= 0.0:
		_dot_timer.stop()
		DualSense.explosion()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton and event.pressed):
		return
	match event.button_index:
		JOY_BUTTON_A:
			DualSense.tap()
		JOY_BUTTON_B:
			DualSense.impact()
			DualSense.flash_light(Color("#c94b01"))
		JOY_BUTTON_X:
			DualSense.explosion()
			DualSense.flash_light(Color("#f1fdd9"), 0.8)
		JOY_BUTTON_Y:
			DualSense.heartbeat()
		JOY_BUTTON_RIGHT_SHOULDER:
			if _dot_timer.is_stopped():
				_hp = MAX_HP
				_dot_timer.start()
			else:
				_dot_timer.stop()
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN:
			var step := 1 if event.button_index == JOY_BUTTON_DPAD_UP else -1
			_trigger_level = clampi(_trigger_level + step, 0, MAX_TRIGGER_LEVEL)
			_apply_trigger()
			DualSense.tap()
		JOY_BUTTON_LEFT_SHOULDER:
			_trigger_mode = wrapi(_trigger_mode + 1, 0, TRIGGER_MODES.size())
			_apply_trigger()
			DualSense.tap()
		JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			var step := 1 if event.button_index == JOY_BUTTON_DPAD_RIGHT else -1
			_light_index = wrapi(_light_index + step, 0, PALETTE.size())
			DualSense.light_color = PALETTE[_light_index]
			DualSense.tap()
		JOY_BUTTON_START:
			DualSense.stop_all()
			_trigger_level = 0
			_apply_trigger()
			_engine_id = DualSense.rumble_loop(0.0, 0.0)


func _apply_trigger() -> void:
	var level := _trigger_level
	for trigger in [DualSense.Trigger.LEFT, DualSense.Trigger.RIGHT]:
		if level == 0:
			DualSense.trigger_off(trigger)
			continue
		match TRIGGER_MODES[_trigger_mode]:
			"ramp":
				# Light at the top, `level` at full press: heavier the deeper you go.
				DualSense.trigger_ramp(trigger, 0, maxi(1, level / 3), level)
			"stuck":
				DualSense.trigger_snap(trigger, 1, 10, level)
			"jammed":
				DualSense.trigger_vibrate(trigger, 2, level, 25)


func _process(_delta: float) -> void:
	var d := DualSense.device
	var r2 := Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) if d >= 0 else 0.0
	var l2 := Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) if d >= 0 else 0.0
	# Motor rumble would mask the trigger resistance, so only drive it with free triggers.
	if _trigger_level == 0:
		DualSense.set_voice(_engine_id, r2 * r2, l2 * 0.6)
	else:
		DualSense.set_voice(_engine_id, 0.0, 0.0)

	var g := DualSense.get_gravity()
	var center := size * 0.5 - _tilt.size * 0.5
	_tilt.position = center + Vector2(g.x, g.z) * size * 0.4

	if d < 0:
		_status.text = "No controller connected"
	else:
		_status.text = "%s (device %d)\nlight: %s  motion: %s  triggers: %s  %s %d/%d\nR2 %.2f  L2 %.2f  HP %d%s" % [
			Input.get_joy_name(d), d,
			"yes" if Input.has_joy_light(d) else "no",
			"yes" if DualSense.has_motion() else "no",
			"yes" if DualSense.has_triggers() else "no",
			TRIGGER_MODES[_trigger_mode] if _trigger_level > 0 else "free",
			_trigger_level, MAX_TRIGGER_LEVEL,
			r2, l2, _hp, "  (DoT)" if not _dot_timer.is_stopped() else "",
		]
