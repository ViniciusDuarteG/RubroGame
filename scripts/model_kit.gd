extends RefCounted
## Chamfered tapered forms with shared UVs, consolidated by Batch at load time.
static func form(w: Node3D, parent: Node3D, pos: Vector3, size: Vector3, color: Color, taper := .85) -> MeshInstance3D:
	var v=PackedVector3Array(); var n=PackedVector3Array(); var uv=PackedVector2Array(); var ids=PackedInt32Array()
	var ring=[Vector2(-.32,-.5),Vector2(.32,-.5),Vector2(.5,-.32),Vector2(.5,.32),Vector2(.32,.5),Vector2(-.32,.5),Vector2(-.5,.32),Vector2(-.5,-.32)]
	for face in 8:
		var a: Vector2=ring[face]; var b: Vector2=ring[(face+1)%8]
		var normal=Vector3(b.y-a.y,0,a.x-b.x).normalized()
		var points=[Vector3(a.x*size.x,-size.y/2,a.y*size.z),Vector3(b.x*size.x,-size.y/2,b.y*size.z),Vector3(b.x*size.x*taper,size.y/2,b.y*size.z*taper),Vector3(a.x*size.x*taper,size.y/2,a.y*size.z*taper)]
		for j in [0,2,1,0,3,2]:
			ids.append(v.size()); v.append(points[j]); n.append(normal)
			uv.append(Vector2(float(face)/4 + (0.25 if j==1 or j==2 else 0.0),0 if j<2 else 1))
	for top in [false,true]:
		for face in 8:
			var y=size.y/2 if top else -size.y/2
			var scale_x=size.x*(taper if top else 1.0); var scale_z=size.z*(taper if top else 1.0)
			var a: Vector2=ring[face]; var b: Vector2=ring[(face+1)%8]
			var points=[Vector3(0,y,0),Vector3(a.x*scale_x,y,a.y*scale_z),Vector3(b.x*scale_x,y,b.y*scale_z)]
			for j in ([0,2,1] if top else [0,1,2]):
				ids.append(v.size()); v.append(points[j]); n.append(Vector3.UP if top else Vector3.DOWN); uv.append(Vector2(points[j].x,points[j].z))
	var arr=[]; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX]=v; arr[Mesh.ARRAY_NORMAL]=n; arr[Mesh.ARRAY_TEX_UV]=uv; arr[Mesh.ARRAY_INDEX]=ids
	var mesh=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
	var instance=MeshInstance3D.new(); instance.mesh=mesh; instance.material_override=w.material(color)
	parent.add_child(instance); instance.position=pos
	return instance
