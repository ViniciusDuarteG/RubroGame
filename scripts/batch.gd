extends RefCounted
## Collapse original primitive meshes into a few vertex-colored surfaces at load time.
## Static colliders stay separate. Flags, articulated parts and class markers are excluded.
static func merge(parent: Node3D, excluded: Array = [], max_distance := 0.0, actor_atlas := false) -> MeshInstance3D:
	var groups: Dictionary = {}
	var sources: Array = []
	for child in parent.get_children():
		if not child is MeshInstance3D or excluded.has(child) or child.mesh==null: continue
		var mat: StandardMaterial3D = child.material_override
		if mat==null: continue
		var tex = mat.albedo_texture
		var key = (tex.resource_path if tex!=null else "flat")+str(mat.cull_mode)
		if actor_atlas: key="actor"
		if not groups.has(key): groups[key]={"v":PackedVector3Array(),"n":PackedVector3Array(),"uv":PackedVector2Array(),"c":PackedColorArray(),"i":PackedInt32Array(),"mat":mat}
		var g: Dictionary = groups[key]
		for surface in child.mesh.get_surface_count():
			var arr = child.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var offset: int = g.v.size()
			for j in points.size():
				var point: Vector3=child.transform*points[j]
				var normal: Vector3=(child.basis.inverse().transposed()*normals[j]).normalized()
				g.v.append(point)
				g.n.append(normal)
				# Bake dominant-axis UVs once, avoiding three texture fetches per fragment.
				if tex!=null and mat.uv1_triplanar:
					var axis=normal.abs()
					var mapped=Vector2(point.x,point.z) if axis.y>=axis.x and axis.y>=axis.z else (Vector2(point.z,point.y) if axis.x>=axis.z else Vector2(point.x,point.y))
					g.uv.append(mapped*mat.uv1_scale.x)
				else: g.uv.append(uv[j])
				var color: Color=mat.albedo_color
				if actor_atlas:
					var tile=0
					if tex!=null:
						var names=["ground","concrete","metal","fabric","asphalt","camo"]
						tile=names.find(tex.resource_path.get_file().trim_suffix("-v2.png"))+1
					color.a=float(tile)/7.0
				g.c.append(color)
			for j in indices: g.i.append(j+offset)
		sources.append(child)
	if sources.is_empty(): return null
	var mesh = ArrayMesh.new()
	for g in groups.values():
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX]=g.v; arr[Mesh.ARRAY_NORMAL]=g.n
		arr[Mesh.ARRAY_TEX_UV]=g.uv; arr[Mesh.ARRAY_COLOR]=g.c; arr[Mesh.ARRAY_INDEX]=g.i
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
		var mat: StandardMaterial3D = g.mat.duplicate()
		mat.uv1_triplanar=false
		mat.uv1_scale=Vector3.ONE
		mat.albedo_color=Color.WHITE
		mat.vertex_color_use_as_albedo=true
		mat.vertex_color_is_srgb=true
		mesh.surface_set_material(mesh.get_surface_count()-1,mat)
	var merged=MeshInstance3D.new()
	merged.mesh=mesh
	merged.name="MergedGeometry"
	if max_distance>0: merged.visibility_range_end=max_distance
	parent.add_child(merged)
	for child in sources:
		parent.remove_child(child)
		child.queue_free()
	return merged
