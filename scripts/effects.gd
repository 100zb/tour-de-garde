class_name Effects
extends RefCounted
## Petits effets visuels jetables (traceurs de balles, impacts, explosions).
## Tout est genere en code avec des primitives : aucun asset externe requis.

## Trait lumineux entre le canon et le point d'impact.
static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.04, length)
	mesh_instance.mesh = box
	mesh_instance.material_override = _glow_material(color)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)

	# Place le trait a mi-chemin et oriente son axe Z vers la cible.
	var middle := from.lerp(to, 0.5)
	var direction := (to - from).normalized()
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	mesh_instance.global_position = middle
	mesh_instance.look_at(to, up)

	_fade_and_free(mesh_instance, 0.07)

## Eclat blanc au point d'impact.
static func impact(parent: Node, position: Vector3, color: Color = Color(1.0, 0.85, 0.5)) -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	sphere.radial_segments = 6
	sphere.rings = 3
	mesh_instance.mesh = sphere
	mesh_instance.material_override = _glow_material(color)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	mesh_instance.global_position = position

	var tween := mesh_instance.create_tween()
	tween.tween_property(mesh_instance, "scale", Vector3(2.2, 2.2, 2.2), 0.12)
	_fade_and_free(mesh_instance, 0.12)

## Gerbe de debris a la mort d'un ennemi.
static func burst(parent: Node, position: Vector3, color: Color) -> void:
	for i in 10:
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.14, 0.14, 0.14)
		shard.mesh = box
		shard.material_override = _glow_material(color)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(shard)
		shard.global_position = position

		var scatter := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.2, 1.4),
			randf_range(-1.0, 1.0)
		).normalized() * randf_range(1.5, 3.5)

		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", position + scatter, 0.45)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.45)
		tween.chain().tween_callback(shard.queue_free)

static func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	return material

static func _fade_and_free(node: MeshInstance3D, duration: float) -> void:
	var material: StandardMaterial3D = node.material_override
	var tween := node.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.tween_callback(node.queue_free)
