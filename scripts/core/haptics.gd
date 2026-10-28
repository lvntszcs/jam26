extends Node
## Shared feedback for the last controller used. Keyboard input silences rumble.

signal device_changed
## Named gameplay feedback; emitted even when no controller is connected.
signal event_triggered(event_name: StringName)

const TICK_DAMAGE: StringName = &"tick_damage"
const DAMAGE_INTERVAL := 0.35

@export var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			stop()
@export_range(0.0, 1.0) var strength := 0.7

var device := -1
var _remaining := 0.0
var _priority := -1
var _damage_cooldown := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_select_device(event.device)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		_select_device(event.device)
	elif event is InputEventKey and event.pressed and not event.echo:
		_select_device(-1)
	elif event is InputEventMouseButton and event.pressed:
		_select_device(-1)


func _process(delta: float) -> void:
	_damage_cooldown = maxf(0.0, _damage_cooldown - delta)
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining == 0.0:
		_priority = -1
	if get_tree().paused and _remaining > 0.0:
		stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		stop()


func _exit_tree() -> void:
	stop()


func pulse(weak: float, strong: float, duration: float, priority := 0) -> void:
	if not enabled or strength <= 0.0 or duration <= 0.0 or device < 0:
		return
	if not Input.get_connected_joypads().has(device) or not get_window().has_focus():
		return
	if get_tree().paused or priority < _priority:
		return
	Input.start_joy_vibration(device, clampf(weak * strength, 0.0, 1.0),
		clampf(strong * strength, 0.0, 1.0), duration)
	_remaining = duration
	_priority = priority


func play_event(event_name: StringName) -> void:
	if event_name != TICK_DAMAGE or get_tree().paused:
		return
	if _damage_cooldown > 0.0:
		return
	_damage_cooldown = DAMAGE_INTERVAL
	event_triggered.emit(event_name)
	pulse(0.15, 0.45, 0.14, 2)


func stop() -> void:
	if device >= 0:
		Input.stop_joy_vibration(device)
	_remaining = 0.0
	_priority = -1
	_damage_cooldown = 0.0


func _select_device(next: int) -> void:
	if device == next:
		return
	stop()
	device = next
	device_changed.emit()


func _on_joy_connection_changed(id: int, connected: bool) -> void:
	if not connected and id == device:
		_select_device(-1)
