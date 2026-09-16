extends Node3D
class_name Turret
## Tourelle automatique achetee dans la boutique. Vise l'ennemi le plus proche
## dans son rayon et tire toute seule.

const RANGE := 30.0
const FIRE_INTERVAL := 0.55
const DAMAGE := 20.0
## Rochers, murs en ruine et sol : ce que la ligne de tir ne doit pas traverser.
const OBSTACLE_MASK := 1

@onready var head: Node3D = $Head
@onready var barrel: Node3D = $Head/Barrel

var _cooldown := 0.0

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

	var target := _nearest_enemy()
	if target == null:
		# Balayage lent quand il n'y a rien a tirer.
		head.rotate_y(delta * 0.6)
		return

	_aim_at(target.global_position + Vector3.UP)

	if _cooldown <= 0.0:
		_cooldown = FIRE_INTERVAL
		_fire(target)

func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_distance := RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		var enemy := node as Enemy
		if enemy == null:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < best_distance and _has_line_of_sight(enemy):
			best_distance = distance
			best = enemy
	return best

## Vrai si rien (rocher, mur en ruine, terrain) ne coupe la ligne entre le
## canon et l'ennemi vise.
func _has_line_of_sight(enemy: Enemy) -> bool:
	var from := barrel.global_position
	var to := enemy.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = OBSTACLE_MASK
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _aim_at(point: Vector3) -> void:
	var flat := point
	flat.y = head.global_position.y
	if flat.distance_to(head.global_position) < 0.05:
		return
	head.look_at(flat, Vector3.UP)

func _fire(target: Enemy) -> void:
	Effects.tracer(
		get_tree().current_scene,
		barrel.global_position,
		target.global_position + Vector3.UP,
		Color(0.5, 0.9, 1.0)
	)
	Effects.impact(get_tree().current_scene, target.global_position + Vector3.UP, Color(0.5, 0.9, 1.0))
	target.take_damage(DAMAGE)
