extends Node3D
## Chef d'orchestre de la partie : relie le joueur, le relais, les vagues,
## le HUD et la boutique, et gere les achats, la defaite et le redemarrage.

const TURRET_SCENE := preload("res://scenes/turret.tscn")
const BOULDER_SCENE := preload("res://assets/models/boulder/boulder_01_2k.gltf")
# AABB reel du maillage (source: Poly Haven boulder_01), utilise pour
# dimensionner/centrer la collision proportionnellement a l'echelle
# aleatoire appliquee a chaque rocher.
const BOULDER_SIZE := Vector3(1.272136, 1.00383, 1.830334)
const BOULDER_CENTER := Vector3(-0.112092, 0.428272, -0.033273)

const FORT_SCENE := preload("res://assets/models/fort/modular_fort_01_2k.gltf")
# Sous-ensemble du kit modulaire (Poly Haven) utilise comme fragments de
# ruine : murs droits/coins en deux epaisseurs, un pan casse net et une
# tour ronde, pour varier les silhouettes sans importer les 22 pieces.
const FORT_PIECE_NAMES := [
	"modular_fort_01_wall_thick_straight_01",
	"modular_fort_01_wall_thick_corner_01",
	"modular_fort_01_wall_thick_end_01",
	"modular_fort_01_wall_thin_straight_01",
	"modular_fort_01_wall_thin_corner_01",
	"modular_fort_01_tower_round",
]
# Echelle reduite : les pieces du kit sont a l'echelle d'un vrai fortin
# (jusqu'a 14 m de long, 13 m de haut), trop imposantes telles quelles.
const FORT_SCALE := 0.55

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
	# Angle bas (proche de l'horizon) pour une ambiance crepuscule/tempete
	# de sable plutot que plein jour neutre.
	$Sun.rotation_degrees = Vector3(-22.0, -52.0, 0.0)
	_scatter_rocks()
	_scatter_ruins()
	_bake_navigation()
	_decorate_relay_surroundings()
	_scatter_bushes()
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
		var has_turret := false
		for child in pad.get_children():
			if child.name != "PadDecor":
				has_turret = true
				break
		if not has_turret:
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

## Rayon de l'anneau de spawn des ennemis (doit rester synchronise avec
## SPAWN_RADIUS dans wave_manager.gd) et marge de securite pour qu'aucun
## rocher ni ruine n'empiete dessus.
const ENEMY_SPAWN_RADIUS := 48.0
const SPAWN_EXCLUSION_MARGIN := 6.0

## Seme des rochers autour de l'arene pour donner du relief et des abris.
## Utilise le vrai maillage scanne (Poly Haven, CC0) plutot qu'une boite,
## avec une echelle aleatoire par rocher pour varier les tailles.
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
		while absf(distance - ENEMY_SPAWN_RADIUS) < SPAWN_EXCLUSION_MARGIN:
			distance = rng.randf_range(16.0, 95.0)
		var scale_factor := rng.randf_range(0.5, 2.0)

		var pos_x := cos(angle) * distance
		var pos_z := sin(angle) * distance
		var ground_y: float = $NavigationRegion3D/Ground.get_height(pos_x, pos_z)

		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		# Le pivot du maillage est proche de sa base : le poser a hauteur du
		# sol suffit a l'ancrer naturellement (leger enfoncement realiste).
		body.position = Vector3(pos_x, ground_y, pos_z)
		body.rotation.y = rng.randf() * TAU
		rocks.add_child(body)

		var boulder := BOULDER_SCENE.instantiate()
		boulder.scale = Vector3.ONE * scale_factor
		body.add_child(boulder)

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = BOULDER_SIZE * scale_factor
		collision.position = BOULDER_CENTER * scale_factor
		collision.shape = shape
		body.add_child(collision)

## Ajoute des fragments de fortin en ruine (kit modulaire Poly Haven) :
## de vrais obstacles que les ennemis doivent contourner (inclus dans le
## maillage de navigation, voir _bake_navigation()). Le pack fourni n'a
## pas ses textures : couleurs pierre/mortier appliquees a la main.
func _scatter_ruins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260916

	var ruins := Node3D.new()
	ruins.name = "Ruins"
	$NavigationRegion3D.add_child(ruins)

	# Extrait les maillages voulus depuis le kit (une seule instance
	# temporaire) pour les reutiliser sur toutes les copies dispersees.
	var fort := FORT_SCENE.instantiate()
	var piece_meshes: Array[Mesh] = []
	for piece_name in FORT_PIECE_NAMES:
		var piece: MeshInstance3D = fort.get_node(piece_name)
		piece_meshes.append(piece.mesh)
	fort.free()

	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.58, 0.52, 0.44)
	wall_material.roughness = 1.0

	var trim_material := StandardMaterial3D.new()
	trim_material.albedo_color = Color(0.4, 0.35, 0.3)
	trim_material.roughness = 1.0

	for i in 10:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(26.0, 88.0)
		while absf(distance - ENEMY_SPAWN_RADIUS) < SPAWN_EXCLUSION_MARGIN:
			distance = rng.randf_range(26.0, 88.0)

		var pos_x := cos(angle) * distance
		var pos_z := sin(angle) * distance
		var ground_y: float = $NavigationRegion3D/Ground.get_height(pos_x, pos_z)

		var mesh: Mesh = piece_meshes[rng.randi_range(0, piece_meshes.size() - 1)]
		var mesh_aabb := mesh.get_aabb()

		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(pos_x, ground_y, pos_z)
		body.rotation.y = rng.randf() * TAU
		body.scale = Vector3.ONE * FORT_SCALE
		ruins.add_child(body)

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = mesh
		mesh_instance.set_surface_override_material(0, wall_material)
		mesh_instance.set_surface_override_material(1, trim_material)
		body.add_child(mesh_instance)

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh_aabb.size
		collision.position = mesh_aabb.position + mesh_aabb.size * 0.5
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

## Ajoute des buissons secs (vegetation morte) : des bouquets de branches
## fines, inclinees et tournees aleatoirement pour un aspect broussailleux.
## Purement decoratif, sans collision, en dehors du NavigationRegion3D (pas
## d'impact sur le maillage de navigation). Meme logique d'exclusion de
## l'anneau de spawn que les rochers/ruines.
func _scatter_bushes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260917

	var bushes := Node3D.new()
	bushes.name = "Bushes"
	add_child(bushes)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.36, 0.28)
	material.roughness = 1.0

	for i in 40:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(14.0, 90.0)
		while absf(distance - ENEMY_SPAWN_RADIUS) < SPAWN_EXCLUSION_MARGIN:
			distance = rng.randf_range(14.0, 90.0)

		var pos_x := cos(angle) * distance
		var pos_z := sin(angle) * distance
		var ground_y: float = $NavigationRegion3D/Ground.get_height(pos_x, pos_z)

		var bush := Node3D.new()
		bush.position = Vector3(pos_x, ground_y, pos_z)
		bush.rotation.y = rng.randf() * TAU
		bushes.add_child(bush)

		var branch_count := rng.randi_range(4, 6)
		for b in branch_count:
			var length := rng.randf_range(0.35, 0.75)
			var branch := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.05, length, 0.05)
			branch.mesh = box
			branch.material_override = material

			var lean := deg_to_rad(rng.randf_range(20.0, 55.0))
			var spin := rng.randf() * TAU
			branch.rotation = Vector3(lean, spin, 0.0)
			# La branche part du sol (pivot du buisson) et s'etend vers le
			# haut le long de son propre axe local, apres inclinaison.
			branch.position = branch.transform.basis.y * (length * 0.5)
			bush.add_child(branch)

## Ajoute des elements visuels simples autour du relais : une dalle au sol,
## un anneau de renfort sur le fut, et un socle visible sous chaque
## emplacement de tourelle (visible meme avant achat). Purement decoratif,
## sans collision, en dehors du NavigationRegion3D.
func _decorate_relay_surroundings() -> void:
	var decor := Node3D.new()
	decor.name = "RelayDecor"
	add_child(decor)

	var foundation_mesh := CylinderMesh.new()
	foundation_mesh.top_radius = 10.0
	foundation_mesh.bottom_radius = 10.0
	foundation_mesh.height = 0.25

	var foundation_material := StandardMaterial3D.new()
	foundation_material.albedo_color = Color(0.4, 0.35, 0.27)
	foundation_material.roughness = 0.9

	var foundation := MeshInstance3D.new()
	foundation.mesh = foundation_mesh
	foundation.material_override = foundation_material
	foundation.position = Vector3(0.0, 0.05, 0.0)
	decor.add_child(foundation)

	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 2.0
	collar_mesh.bottom_radius = 2.0
	collar_mesh.height = 0.4

	var collar_material := StandardMaterial3D.new()
	collar_material.albedo_color = Color(0.3, 0.32, 0.37)
	collar_material.metallic = 0.6
	collar_material.roughness = 0.4

	var collar := MeshInstance3D.new()
	collar.mesh = collar_mesh
	collar.material_override = collar_material
	collar.position = Vector3(0.0, 3.0, 0.0)
	decor.add_child(collar)

	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 1.3
	pad_mesh.bottom_radius = 1.3
	pad_mesh.height = 0.15

	var pad_material := StandardMaterial3D.new()
	pad_material.albedo_color = Color(0.34, 0.35, 0.39)
	pad_material.metallic = 0.4
	pad_material.roughness = 0.6

	for pad in turret_pads.get_children():
		var pad_disc := MeshInstance3D.new()
		pad_disc.name = "PadDecor"
		pad_disc.mesh = pad_mesh
		pad_disc.material_override = pad_material
		pad_disc.position = Vector3(0.0, 0.08, 0.0)
		pad.add_child(pad_disc)
