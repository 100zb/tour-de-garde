extends CharacterBody3D
class_name Player
## Controleur FPS : deplacement, visee souris, tir hitscan, rechargement, vie.

signal health_changed(current: int, maximum: int)
signal ammo_changed(in_magazine: int, magazine_size: int)
signal shot_landed(was_kill: bool)
signal died

const WALK_SPEED := 6.0
const SPRINT_SPEED := 9.5
const GROUND_ACCELERATION := 14.0
const AIR_ACCELERATION := 3.0
const JUMP_VELOCITY := 6.4
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := deg_to_rad(89.0)

const BASE_DAMAGE := 24.0
const FIRE_INTERVAL := 0.11
const RELOAD_DURATION := 1.5
const BASE_MAGAZINE := 30
const SHOT_RANGE := 140.0
## Monde (1) + ennemis (4) + relais/tourelles (8).
const SHOT_COLLISION_MASK := 1 | 4 | 8

const REGEN_DELAY := 6.0
const REGEN_PER_SECOND := 14.0

@export var max_health: int = 100

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var muzzle: Node3D = $Head/Camera3D/Weapon/Muzzle

var health: int
var magazine: int
var is_reloading := false
var is_dead := false

var _fire_cooldown := 0.0
var _reload_timer := 0.0
var _time_since_damage := 0.0
var _regen_carry := 0.0

# Recul : decalage applique a la camera puis resorbe progressivement.
var _recoil_pitch := 0.0
var _recoil_yaw := 0.0
var _spread := 0.0

func _ready() -> void:
	health = max_health
	magazine = magazine_size()
	_capture_mouse()
	# Emis apres un frame pour laisser le HUD se connecter d'abord.
	call_deferred("_broadcast_stats")

func _broadcast_stats() -> void:
	health_changed.emit(health, max_health)
	ammo_changed.emit(magazine, magazine_size())

func magazine_size() -> int:
	return BASE_MAGAZINE + Game.bonus_magazine

func _capture_mouse() -> void:
	# En mode headless (tests automatises) il n'y a pas de souris a capturer.
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	move_and_slide()

	_handle_weapon(delta)
	_recover_recoil(delta)
	_handle_regeneration(delta)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 18.0) * delta

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _handle_movement(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()

	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var target := direction * speed

	velocity.x = move_toward(velocity.x, target.x, acceleration * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * speed * delta)

func _handle_weapon(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_spread = maxf(0.0, _spread - delta * 4.0)

	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			is_reloading = false
			magazine = magazine_size()
			ammo_changed.emit(magazine, magazine_size())
		return

	if Input.is_action_just_pressed("reload"):
		_start_reload()
		return

	# Le tir est bloque quand la souris est libre (boutique ouverte, pause).
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		return

	if Input.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
		if magazine <= 0:
			_start_reload()
		else:
			_fire()

func _start_reload() -> void:
	if is_reloading or magazine == magazine_size():
		return
	is_reloading = true
	_reload_timer = RELOAD_DURATION

func _fire() -> void:
	magazine -= 1
	_fire_cooldown = FIRE_INTERVAL
	ammo_changed.emit(magazine, magazine_size())

	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z
	# La dispersion s'ouvre quand on arrose, et se resorbe quand on lache.
	direction = direction.rotated(camera.global_transform.basis.y, randf_range(-_spread, _spread))
	direction = direction.rotated(camera.global_transform.basis.x, randf_range(-_spread, _spread))
	_spread = minf(_spread + 0.006, 0.05)

	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * SHOT_RANGE)
	query.collision_mask = SHOT_COLLISION_MASK
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var impact_point: Vector3 = hit.position if hit else origin + direction * SHOT_RANGE
	Effects.tracer(get_tree().current_scene, muzzle.global_position, impact_point, Color(1.0, 0.9, 0.55))

	_apply_recoil()

	if not hit:
		return

	var target: Object = hit.collider
	if target is Enemy:
		var was_kill: bool = target.take_damage(BASE_DAMAGE * Game.damage_multiplier)
		shot_landed.emit(was_kill)
		Effects.impact(get_tree().current_scene, impact_point, Color(1.0, 0.4, 0.35))
	else:
		Effects.impact(get_tree().current_scene, impact_point)

func _apply_recoil() -> void:
	_recoil_pitch += randf_range(0.010, 0.018)
	_recoil_yaw += randf_range(-0.006, 0.006)
	head.rotation.x = clampf(head.rotation.x + _recoil_pitch * 0.5, -PITCH_LIMIT, PITCH_LIMIT)
	rotate_y(_recoil_yaw * 0.5)

func _recover_recoil(delta: float) -> void:
	var recovery := 6.0 * delta
	if _recoil_pitch > 0.0:
		var applied := minf(_recoil_pitch, recovery)
		head.rotation.x = clampf(head.rotation.x - applied * 0.5, -PITCH_LIMIT, PITCH_LIMIT)
		_recoil_pitch -= applied
	_recoil_yaw = move_toward(_recoil_yaw, 0.0, recovery)

func _handle_regeneration(delta: float) -> void:
	_time_since_damage += delta
	if health >= max_health or _time_since_damage < REGEN_DELAY:
		return
	_regen_carry += REGEN_PER_SECOND * delta
	var whole := int(_regen_carry)
	if whole <= 0:
		return
	_regen_carry -= whole
	health = mini(max_health, health + whole)
	health_changed.emit(health, max_health)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	_time_since_damage = 0.0
	_regen_carry = 0.0
	health = maxi(0, health - int(round(amount)))
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()

func heal_full() -> void:
	health = max_health
	health_changed.emit(health, max_health)

func refill_ammo() -> void:
	is_reloading = false
	magazine = magazine_size()
	ammo_changed.emit(magazine, magazine_size())

func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	died.emit()

## Dispersion actuelle du tir (0 = precis). Utilise par le reticule.
func current_spread() -> float:
	return _spread
