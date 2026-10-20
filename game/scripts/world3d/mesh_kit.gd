extends RefCounted
## Small helpers for building a stylised 3D town out of primitives, batched into MultiMeshes so hundreds of buildings, trees and
## props cost a handful of draw calls. Flat, saturated, soft-lit: the look we're aiming for (a game like Peak), not final art.


## One mesh, one material, many instances (each with its own transform and colour).
class Batch extends RefCounted:
	var mesh: Mesh
	var material: Material
	var xforms: Array = []
	var colors: Array = []
	var shadows := true
	var srgb := true          # colours are given in sRGB (as typed) and converted for the renderer

	func _init(m: Mesh, mat: Material, cast_shadows: bool = true) -> void:
		mesh = m
		material = mat
		shadows = cast_shadows

	func add(xf: Transform3D, color: Color = Color.WHITE) -> void:
		xforms.append(xf)
		colors.append(color.srgb_to_linear() if srgb else color)

	func build(parent: Node3D, node_name: String = "") -> MultiMeshInstance3D:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
			mm.set_instance_color(i, colors[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if node_name != "":
			mi.name = node_name
		parent.add_child(mi)
		return mi


static func matte(color: Color = Color.WHITE, use_instance_color: bool = true, rough: float = 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.vertex_color_use_as_albedo = use_instance_color
	m.roughness = rough
	m.metallic = 0.0
	m.metallic_specular = 0.15
	return m


static func xf(center: Vector3, size: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), center)


static func xf_rot(center: Vector3, size: Vector3, euler: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(euler) * Basis.from_scale(size), center)


static func box_mesh() -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	return b


static func prism_mesh() -> PrismMesh:
	var p := PrismMesh.new()
	p.size = Vector3.ONE
	p.left_to_right = 0.5
	return p


static func cylinder_mesh(sides: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.5
	c.bottom_radius = 0.5
	c.height = 1.0
	c.radial_segments = sides
	c.rings = 1
	return c


static func cone_mesh(sides: int = 9) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.5
	c.height = 1.0
	c.radial_segments = sides
	c.rings = 1
	return c


static func sphere_mesh(seg: int = 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = seg
	s.rings = maxi(4, seg / 2)
	return s


static func hexcol(h: String, jitter: float = 0.0, seed_v: int = 0) -> Color:
	var c := Color(h)
	if jitter > 0.0:
		var r := RandomNumberGenerator.new()
		r.seed = seed_v
		c = c.lightened(r.randf_range(-jitter, jitter)) if r.randf() > 0.5 else c.darkened(r.randf_range(0.0, jitter))
	return c
