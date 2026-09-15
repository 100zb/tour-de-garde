extends CharacterBody3D
class_name Enemy
## Ennemi qui marche vers le relais et l'attaque. S'il croise le joueur de pres,
## il s'en prend a lui d'abord.

signal died(enemy: Enemy)

enum Kind { RODEUR, TRAQUEUR, COLOSSE }

const ATTACK_INTERVAL := 1.0
const RELAY_ATTACK_RANGE := 4.0
const PLAYER_ATTACK_RANGE := 2.4
const PLAYER_AGGRO_RANGE := 7.0
const SEPARATION_RANGE := 1.8
const ACCELERATION := 8.0

@onready var mesh: MeshInstance3D = $Mesh

var kind: Kind = Kind.RODEUR
var max_health: float = 40.0
var health: float = 40.0
var speed: float = 3.2
var damage: float = 8.0
var scrap_value: int = 12

var _attack_cooldown := 0.0
var _relay: Node3D
var _player: Node3D
var _material: StandardMaterial3D
var _base_color := Color(0.75, 0.22, 0.2)
var _is_dying := false

func _ready() -> void:
	add_to_group("enemies")
	_relay = get_tree().get_first_node_in_group("relay")
	_player = get_tree().get_first_node_in_group("player")
	_material = StandardMaterial3D.new()
	_material.albedo_color = _base_color
	_material.roughness = 0.7
	mesh.material_override = _material

## Regle les stats selon le type et le numero de vague. Appele par le spawner
## AVANT que le noeud entre dans l'arbre.
func configure(enemy_kind: Kind, wave: int) -> void:
	kind = enemy_kind
	var wave_scale := 1.0 + float(wave - 1) * 0.16

	match kind:
		Kind.RODEUR:
			max_health = 42.0 * wave_scale
			speed = 3.4
			damage = 8.0
			scrap_value = 12
			_base_color = Color(0.75, 0.22, 0.2)
			scale = Vector3.ONE
		Kind.TRAQUEUR:
			max_health = 26.0 * wave_scale
			speed = 6.2
			damage = 6.0
			scrap_value = 16
			_base_color = Color(0.9, 0.55, 0.15)
			scale = Vector3(0.8, 0.9, 0.8)
		Kind.COLOSSE:
			max_health = 190.0 * wave_scale
			speed = 2.1
			damage = 26.0
			scrap_value = 45
			_base_color = Color(0.45, 0.15, 0.45)
			scale = Vector3(1.6, 1.7, 1.6)

	health = max_health

func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	var target := _pick_target()
	if target == null:
		return

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	var attack_range := PLAYER_ATTACK_RANGE if target == _player else RELAY_ATTACK_RANGE

	if distance <= attack_range:
		velocity.x = move_toward(velocity.x, 0.0, ACCELERATION * speed * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCELERATION * speed * delta)
		_try_attack(target)
	else:
		var desired := to_target.normalized() * speed + _separation()
		velocity.x = move_toward(velocity.x, desired.x, ACCELERATION * speed * delta)
		velocity.z = move_toward(velocity.z, desired.z, ACCELERATION * speed * delta)
		_face(to_target)

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 18.0) * delta
	else:
		velocity.y = 0.0

	move_and_slide()

func _pick_target() -> Node3D:
	var player_alive: bool = is_instance_valid(_player) and not _player.is_dead
	if player_alive and global_position.distance_to(_player.global_position) <= PLAYER_AGGRO_RANGE:
		return _player
	if is_instance_valid(_relay):
		return _relay
	return _player if player_alive else null

## Petite force qui ecarte les ennemis entre eux pour eviter qu'ils
## s'empilent en une seule colonne.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		var offset: Vector3 = global_position - other.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.01 and distance < SEPARATION_RANGE:
			push += offset.normalized() * (SEPARATION_RANGE - distance)
	return push * 1.6

func _face(direction: Vector3) -> void:
	if direction.length_squared() < 0.01:
		return
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 0.2)

func _try_attack(target: Node3D) -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = ATTACK_INTERVAL
	if target.has_method("take_damage"):
		target.take_damage(damage)
	_lunge()

## Petit coup de zoom du mesh pour rendre l'attaque lisible.
func _lunge() -> void:
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.25, 0.8, 1.25), 0.08)
	tween.tween_property(mesh, "scale", Vector3.ONE, 0.16)

## Renvoie true si ce tir a tue l'ennemi (sert au marqueur de touche du HUD).
func take_damage(amount: float) -> bool:
	if _is_dying:
		return false
	health -= amount
	if health <= 0.0:
		_die()
		return true
	_flash()
	return false

func _flash() -> void:
	_material.albedo_color = Color(1.0, 0.95, 0.9)
	var tween := create_tween()
	tween.tween_property(_material, "albedo_color", _base_color, 0.12)

func _die() -> void:
	_is_dying = true
	remove_from_group("enemies")
	Game.add_scrap(scrap_value)
	Effects.burst(get_tree().current_scene, global_position + Vector3.UP, _base_color)
	died.emit(self)
	queue_free()
