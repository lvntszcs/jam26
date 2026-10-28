class_name Hud
extends CanvasLayer
## In-game overlay: level title, air meter, interaction prompt, hint and messages.
## Styling lives in res://art/ui_theme.tres.

## Air bar fill color when air runs low.
@export var low_air_color := Palette.RUST
@export_range(0.0, 1.0) var low_air_ratio := 0.3

var _fill_style: StyleBoxFlat
var _normal_fill_color: Color

@onready var title_label: Label = %Title
@onready var air_bar: ProgressBar = %AirBar
@onready var prompt_label: Label = %Prompt
@onready var hint_label: Label = %Hint
@onready var message_panel: PanelContainer = %MessagePanel
@onready var message_title: Label = %MessageTitle
@onready var message_body: Label = %MessageBody


func _ready() -> void:
	var fill := air_bar.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		_fill_style = fill.duplicate()
		_normal_fill_color = _fill_style.bg_color
		air_bar.add_theme_stylebox_override("fill", _fill_style)
	message_panel.hide()


func show_level(title: String, hint: String) -> void:
	title_label.text = title
	hint_label.text = hint
	set_prompt("")
	message_panel.hide()


func set_air(air: float, max_air: float) -> void:
	air_bar.max_value = max_air
	air_bar.value = air
	if _fill_style:
		_fill_style.bg_color = low_air_color if air / max_air < low_air_ratio else _normal_fill_color


func set_prompt(text: String) -> void:
	prompt_label.text = "[E] %s" % text if text != "" else ""


func show_message(title: String, body: String) -> void:
	message_title.text = title
	message_body.text = body
	set_prompt("")
	message_panel.show()
