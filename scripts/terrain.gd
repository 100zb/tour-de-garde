extends StaticBody3D
## Sol du desert : un plan quadrille dont chaque sommet est souleve par du
## bruit pour former des dunes. Reste plat pres du relais et de l'anneau de
## spawn des ennemis, pour ne pas gener le jeu actuel.

const SIZE := 400.0
const RESOLUTION := 120
const AMPLITUDE := 5.0
const FLAT_RADIUS := 55.0
const HILLY_RADIUS := 140.0

@onready var mesh_instance: MeshInstance3D = $GroundMesh
@onready var collision: CollisionShape3D = $GroundCollision

var _noise: FastNoiseLite

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = 20260915
	_noise.frequency = 0.015

	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	plane.subdivide_width = RESOLUTION
	plane.subdivide_depth = RESOLUTION

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.get_mesh_arrays())

	var mdt := MeshDataTool.new()
	mdt.create_from_surface(array_mesh, 0)

	for i in mdt.get_vertex_count():
		var v := mdt.get_vertex(i)
		v.y = _height_at(v.x, v.z, _noise)
		mdt.set_vertex(i, v)

	array_mesh.clear_surfaces()
	mdt.commit_to_surface(array_mesh)

	# Le relief a change la forme du sol : il faut recalculer les normales
	# pour que la lumiere ne reste pas plaquee comme sur un plan plat.
	var surface_tool := SurfaceTool.new()
	surface_tool.create_from(array_mesh, 0)
	surface_tool.generate_normals()
	var final_mesh := surface_tool.commit()

	mesh_instance.mesh = final_mesh
	mesh_instance.material_override = _sand_material()
	collision.shape = final_mesh.create_trimesh_shape()

## Hauteur du sol a une position donnee. Reste a 0 jusqu'a FLAT_RADIUS
## (relais, socles, anneau de spawn a 48 m), puis monte en dunes jusqu'a
## HILLY_RADIUS.
func _height_at(x: float, z: float, noise: FastNoiseLite) -> float:
	var distance := Vector2(x, z).length()
	var slope := smoothstep(FLAT_RADIUS, HILLY_RADIUS, distance)
	return noise.get_noise_2d(x, z) * AMPLITUDE * slope

## Meme calcul que le maillage, expose pour que d'autres scripts (les
## rochers, les ruines) puissent poser leurs objets a la vraie hauteur du
## sol au lieu de supposer un terrain plat.
func get_height(x: float, z: float) -> float:
	return _height_at(x, z, _noise)

func _sand_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.58, 0.38)
	material.roughness = 0.95
	return material
