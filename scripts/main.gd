extends Node3D
## Chef d'orchestre de la partie : relie le joueur, le relais, les vagues,
## le HUD et la boutique, et gere les achats, la defaite et le redemarrage.

const TURRET_SCENE := preload("res://scenes/turret.tscn")

@onready var player: Player = $Player
@onready var relay: Relay = $NavigationRegion3D/Relay
@onready var waves: WaveManager = $WaveManager
@onready var hud: HUD = $HUD
@onready var shop: Shop = $ShopLayer/Shop
@onready var turret_pads: Node3D = $TurretPads

var _game_over := false

func _ready() -> void:
	Game.reset()
	hud.bind(player, relay, waves)
	shop.purchase_requested.connect(_on_purchase_requested)
	player.died.connect(_on_player_died)
	relay.destroyed.connect(_on_relay_destroyed)
	# Orientation du soleil reglee ici plutot que dans la scene : une matrice
	# ecrite a la main est illisible et facile a se tromper.
	$Sun.rotation_degrees = Vector3(-46.0, -52.0, 0.0)
	_scatter_rocks()
	_scatter_ruins()
	_bake_navigation()
	Game.announce("Defends le relais. Tab pour l'atelier.")

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("restart"):
		if _game_over:
			_restart()
		elif Game.state == Game.State.INTERMISSION:
			waves.skip_intermission()
		return

	if _game_over:
		if Input.is_action_just_pressed("pause"):
			get_tree().quit()
		return

	if Input.is_action_just_pressed("shop"):
		shop.toggle()
		return

	if Input.is_action_just_pressed("pause"):
		if shop.visible:
			shop.close()
		else:
			_toggle_mouse()

func _toggle_mouse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ---------------------------------------------------------------------- achats

func _on_purchase_requested(id: String) -> void:
	var price := shop.cost_of(id)

	# La tourelle est le seul achat qui peut echouer pour une autre raison
	# que le prix : il faut un socle libre.
	if id == "turret" and _free_pad() == null:
		Game.announce("Plus aucun socle libre")
		return

	if not Game.spend_scrap(price):
		return

	match id:
		"turret":
			_place_turret()
			Game.turrets_built += 1
			Game.announce("Tourelle deployee")
		"damage":
			Game.damage_multiplier += 0.2
			Game.announce("Degats : +%d%%" % int(round((Game.damage_multiplier - 1.0) * 100.0)))
		"repair":
			relay.repair(200)
			Game.announce("Relais repare")
		"magazine":
			Game.bonus_magazine += 10
			player.refill_ammo()
			Game.announce("Chargeur : %d balles" % player.magazine_size())
		"medkit":
			player.heal_full()
			Game.announce("Sante restauree")

	shop.register_purchase(id)

func _free_pad() -> Node3D:
	for pad in turret_pads.get_children():
		if pad.get_child_count() == 0:
			return pad
	return null

func _place_turret() -> void:
	var pad := _free_pad()
	if pad == null:
		return
	var turret := TURRET_SCENE.instantiate()
	pad.add_child(turret)

# ------------------------------------------------------------------------ fin

func _on_relay_destroyed() -> void:
	_end_game()

func _on_player_died() -> void:
	_end_game()

func _end_game() -> void:
	if _game_over:
		return
	_game_over = true
	Game.set_state(Game.State.GAME_OVER)
	shop.close()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	waves.clear_field()
	hud.show_game_over(Game.wave, Game.scrap)

func _restart() -> void:
	Game.reset()
	get_tree().reload_current_scene()

# --------------------------------------------------------------------- decor

## Seme des rochers autour de l'arene pour donner du relief et des abris.
## Graine fixe : le terrain est identique a chaque partie.
func _scatter_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260915

	var rocks := Node3D.new()
	rocks.name = "Rocks"
	$NavigationRegion3D.add_child(rocks)

	for i in 70:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(16.0, 95.0)
		var width := rng.randf_range(1.2, 4.5)
		var height := rng.randf_range(0.8, 3.6)
		var depth := rng.randf_range(1.2, 4.5)

		var pos_x := cos(angle) * distance
		var pos_z := sin(angle) * distance
		var ground_y: float = $NavigationRegion3D/Ground.get_height(pos_x, pos_z)

		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(pos_x, ground_y + height * 0.4, pos_z)
		body.rotation.y = rng.randf() * TAU
		rocks.add_child(body)

		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width, height, depth)
		mesh_instance.mesh = box

		var material := StandardMaterial3D.new()
		var shade := rng.randf_range(0.34, 0.52)
		material.albedo_color = Color(shade, shade * 0.86, shade * 0.68)
		material.roughness = 0.95
		mesh_instance.material_override = material
		body.add_child(mesh_instance)

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(width, height, depth)
		collision.shape = shape
		body.add_child(collision)

## Ajoute des pans de mur en ruine : de vrais obstacles que les ennemis
## doivent contourner (inclus dans le maillage de navigation, voir
## _bake_navigation()).
func _scatter_ruins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260916

	var ruins := Node3D.new()
	ruins.name = "Ruins"
	$NavigationRegion3D.add_child(ruins)

	for i in 10:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(26.0, 88.0)
		var width := rng.randf_range(5.0, 9.0)
		var height := rng.randf_range(2.2, 3.8)
		var thickness := rng.randf_range(0.8, 1.3)

		var pos_x := cos(angle) * distance
		var pos_z := sin(angle) * distance
		var ground_y: float = $NavigationRegion3D/Ground.get_height(pos_x, pos_z)

		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(pos_x, ground_y + height * 0.5, pos_z)
		body.rotation.y = rng.randf() * TAU
		ruins.add_child(body)

		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width, height, thickness)
		mesh_instance.mesh = box

		var material := StandardMaterial3D.new()
		var shade := rng.randf_range(0.55, 0.68)
		material.albedo_color = Color(shade, shade * 0.94, shade * 0.82)
		material.roughness = 1.0
		mesh_instance.material_override = material
		body.add_child(mesh_instance)

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(width, height, thickness)
		collision.shape = shape
		body.add_child(collision)

## Cree le maillage de navigation utilise par les ennemis pour se deplacer.
## A relancer (rebake) plus tard si des obstacles sont ajoutes sur le terrain.
func _bake_navigation() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.8
	nav_mesh.agent_height = 2.2
	# Doit correspondre a la cellule de la carte de navigation par defaut du
	# moteur (0.25/0.25) : un decalage fait echouer la synchronisation.
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	$NavigationRegion3D.navigation_mesh = nav_mesh
	$NavigationRegion3D.bake_navigation_mesh()
