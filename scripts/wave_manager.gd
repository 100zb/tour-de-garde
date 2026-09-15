extends Node3D
class_name WaveManager
## Orchestre les vagues : entracte, composition de la vague, apparition
## echelonnee des ennemis, puis retour a l'entracte quand tout est mort.

signal wave_started(wave: int)
signal intermission_started(duration: float)

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

const FIRST_INTERMISSION := 18.0
const INTERMISSION := 22.0
const SPAWN_RADIUS := 48.0
const SPAWN_HEIGHT := 1.6

@export var spawn_interval: float = 0.45

## Lecture seule, affiche par le HUD.
var enemies_alive: int = 0
var enemies_pending: int = 0
var intermission_left: float = 0.0

var _queue: Array[int] = []
var _spawn_timer := 0.0
var _running := false

func _ready() -> void:
	start_intermission(FIRST_INTERMISSION)

func start_intermission(duration: float) -> void:
	intermission_left = duration
	Game.set_state(Game.State.INTERMISSION)
	intermission_started.emit(duration)

func _process(delta: float) -> void:
	if Game.state == Game.State.GAME_OVER:
		return

	if Game.state == Game.State.INTERMISSION:
		intermission_left -= delta
		if intermission_left <= 0.0:
			_begin_wave()
		return

	_process_spawning(delta)

## Permet au joueur de lancer la vague suivante en avance (touche Entree).
func skip_intermission() -> void:
	if Game.state == Game.State.INTERMISSION:
		intermission_left = 0.0

func _begin_wave() -> void:
	Game.wave += 1
	_queue = _build_composition(Game.wave)
	_queue.shuffle()
	enemies_pending = _queue.size()
	enemies_alive = 0
	_spawn_timer = 0.0
	_running = true
	Game.set_state(Game.State.WAVE)
	wave_started.emit(Game.wave)

## Compose la vague : des rodeurs, des traqueurs rapides a partir de la vague 3,
## et un colosse tous les 5 niveaux.
func _build_composition(wave: int) -> Array[int]:
	var composition: Array[int] = []
	var total := mini(5 + wave * 2, 42)

	var colosses := 0
	if wave >= 5:
		colosses = 1 + int(float(wave - 5) / 5.0)

	var traqueurs := 0
	if wave >= 3:
		traqueurs = int(float(total) * 0.3)

	var rodeurs := maxi(1, total - traqueurs - colosses * 3)

	for i in rodeurs:
		composition.append(Enemy.Kind.RODEUR)
	for i in traqueurs:
		composition.append(Enemy.Kind.TRAQUEUR)
	for i in colosses:
		composition.append(Enemy.Kind.COLOSSE)

	return composition

func _process_spawning(delta: float) -> void:
	if not _running:
		return

	if not _queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			_spawn(_queue.pop_back())

	if _queue.is_empty() and enemies_alive <= 0:
		_running = false
		start_intermission(INTERMISSION)

func _spawn(kind: int) -> void:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.configure(kind, Game.wave)
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)

	var angle := randf() * TAU
	enemy.global_position = Vector3(
		cos(angle) * SPAWN_RADIUS,
		SPAWN_HEIGHT,
		sin(angle) * SPAWN_RADIUS
	)

	enemies_pending -= 1
	enemies_alive += 1

func _on_enemy_died(_enemy: Enemy) -> void:
	enemies_alive = maxi(0, enemies_alive - 1)

## Nettoie le terrain (utilise a la mort du joueur).
func clear_field() -> void:
	_running = false
	_queue.clear()
	enemies_pending = 0
	enemies_alive = 0
	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()
