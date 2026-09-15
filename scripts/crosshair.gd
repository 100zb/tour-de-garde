extends Control
class_name Crosshair
## Reticule dessine a la main : quatre traits qui s'ecartent quand on arrose,
## plus un marqueur en X quand un tir touche.

const COLOR := Color(1.0, 1.0, 1.0, 0.85)
const HIT_COLOR := Color(1.0, 0.35, 0.3)
const KILL_COLOR := Color(1.0, 0.85, 0.2)

var gap: float = 6.0
var length: float = 9.0
var thickness: float = 2.0

var _hit_timer := 0.0
var _hit_color := HIT_COLOR

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if _hit_timer > 0.0:
		_hit_timer = maxf(0.0, _hit_timer - delta)
		queue_redraw()

func flash_hit(was_kill: bool) -> void:
	_hit_timer = 0.25 if was_kill else 0.15
	_hit_color = KILL_COLOR if was_kill else HIT_COLOR
	queue_redraw()

func set_spread(value: float) -> void:
	var target := 6.0 + value * 260.0
	if not is_equal_approx(gap, target):
		gap = target
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5

	# Point central.
	draw_circle(center, 1.5, COLOR)

	# Les quatre branches.
	draw_line(center + Vector2(0, -gap), center + Vector2(0, -gap - length), COLOR, thickness)
	draw_line(center + Vector2(0, gap), center + Vector2(0, gap + length), COLOR, thickness)
	draw_line(center + Vector2(-gap, 0), center + Vector2(-gap - length, 0), COLOR, thickness)
	draw_line(center + Vector2(gap, 0), center + Vector2(gap + length, 0), COLOR, thickness)

	# Marqueur de touche : un X par-dessus, qui s'efface.
	if _hit_timer > 0.0:
		var alpha := clampf(_hit_timer * 5.0, 0.0, 1.0)
		var color := Color(_hit_color.r, _hit_color.g, _hit_color.b, alpha)
		var near := 4.0
		var far := 11.0
		for direction in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			draw_line(center + direction * near, center + direction * far, color, 2.0)
