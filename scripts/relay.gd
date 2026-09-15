extends StaticBody3D
class_name Relay
## Le relais : la structure que le joueur doit garder en vie.
## Si sa sante tombe a zero, la partie est perdue.

signal health_changed(current: int, maximum: int)
signal destroyed

@export var max_health: int = 600

@onready var core: MeshInstance3D = $Core
@onready var core_light: OmniLight3D = $CoreLight

var health: int
var _is_destroyed := false
var _pulse_time := 0.0

func _ready() -> void:
	add_to_group("relay")
	health = max_health
	call_deferred("_broadcast")

func _broadcast() -> void:
	health_changed.emit(health, max_health)

func _process(delta: float) -> void:
	if _is_destroyed:
		return
	# Le coeur pulse de plus en plus vite quand le relais est en danger.
	var urgency := 1.0 + (1.0 - health_ratio()) * 4.0
	_pulse_time += delta * urgency
	var pulse := 0.5 + 0.5 * sin(_pulse_time * 3.0)
	core_light.light_energy = 1.5 + pulse * 2.5
	core.scale = Vector3.ONE * (1.0 + pulse * 0.06)

func health_ratio() -> float:
	return float(health) / float(max_health)

func take_damage(amount: float) -> void:
	if _is_destroyed:
		return
	health = maxi(0, health - int(round(amount)))
	health_changed.emit(health, max_health)
	_flash()
	if health <= 0:
		_is_destroyed = true
		destroyed.emit()

func repair(amount: int) -> void:
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)

func _flash() -> void:
	core_light.light_color = Color(1.0, 0.3, 0.25)
	var tween := create_tween()
	tween.tween_property(core_light, "light_color", Color(0.4, 0.8, 1.0), 0.3)
