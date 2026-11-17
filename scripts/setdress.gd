extends RefCounted
## Original environmental kit. Everything is baked into the map's shared render meshes.
static func cylinder(w: Node3D, p: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var instance=MeshInstance3D.new()
	var mesh=CylinderMesh.new()
	mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=height; mesh.radial_segments=10
	instance.mesh=mesh; instance.material_override=w.material(color)
	w.add_child(instance); instance.position=p
	return instance

static func populate(w: Node3D) -> void:
	# Sandbag courses over the existing flank barricades.
	var bag_mesh=SphereMesh.new()
	bag_mesh.radius=1; bag_mesh.height=2; bag_mesh.radial_segments=8; bag_mesh.rings=4
	for side in [-1,1]:
		for x in [-48,-8,8,48]:
			for row in 3:
				for k in 5:
					for z in [-1.02,1.02]:
						var bag=MeshInstance3D.new()
						bag.mesh=bag_mesh; bag.material_override=w.material(Color("a0926b"))
						w.add_child(bag)
						bag.position=Vector3(x+(k-2)*.79+(row%2)*.13,.25+row*.41,side*39+z)
						bag.scale=Vector3(.48,.245,.3)
	# Weathered concrete roadblocks, warning stripes and maintenance crates.
	for side in [1]:
		for x in [-28,28]:
			for k in 7:
				var stripe=w.box(w,Vector3(x+(k-3)*.85,1,side*14+(-1.52 if side<0 else 1.52)),Vector3(.3,1.1,.035),Color("b6aa7c") if k%2==0 else Color("8f4939"))
				stripe.rotation.z=.22
	for team in 2:
		var base: Vector3=w.BASES[team]
		for i in 4:
			var p=base+Vector3((-6 if team==0 else 6),.55,-7+i*1.2)
			w.obstacle(p,Vector3(1.2,1.1,1),Color("8d7c56"))
			for z in [-.43,.43]: w.box(w,p+Vector3(0,0,z),Vector3(1.22,.14,.1),Color("4c5847"))
		for k in 3:
			var p=base+Vector3(7 if team==0 else -7,.7,-8+k*1.3)
			cylinder(w,p,.43,1.4,Color("7c4937"))
			for y in [-.45,.45]: cylinder(w,p+Vector3(0,y,0),.45,.07,Color("343f3a"))
	# Utility poles and overhead crossarms beside the central road.
	for x in [-47,-19,19,47]:
		w.box(w,Vector3(x,3.25,7.8),Vector3(.15,6.5,.15),Color("777661"))
		w.box(w,Vector3(x+1.2,6.3,7.8),Vector3(2.6,.12,.12),Color("414f4c"))
		w.box(w,Vector3(x+2.2,6.15,7.8),Vector3(.65,.18,.35),Color("394945"))
		w.box(w,Vector3(x+2.2,6.05,7.8),Vector3(.45,.03,.25),Color("d1cba5"))
	for side in [-1,1]:
		w.box(w,Vector3(side*33,6.38,7.8),Vector3(28,.025,.025),Color("323f3a"))
	# Rooftop water tank, vents and a relay dish.
	cylinder(w,Vector3(5,6.1,42),1.5,2,Color("6b827b"))
	cylinder(w,Vector3(5,7.15,42),1.65,.12,Color("374c48"))
	for x in [-1,1]:
		for z in [-1,1]: w.box(w,Vector3(5+x,4.8,42+z),Vector3(.1,1,.1),Color("374c48"))
	for p in [Vector3(-38,5.5,-39),Vector3(41,4.4,-36),Vector3(-16,4.4,19)]:
		w.box(w,p,Vector3(1.2,.8,1),Color("64736a"))
		for k in 4: w.box(w,p+Vector3(0,-.2+k*.14,-.51),Vector3(.95,.045,.035),Color("273b37"))
	var dish=cylinder(w,Vector3(37,5.5,-36),1.4,.15,Color("b0b5a4"))
	dish.rotation_degrees=Vector3(55,0,-20)
	w.box(w,Vector3(37,4.7,-36),Vector3(.15,1.5,.15),Color("4a5e55"))
	# Dusty palms: opaque low-poly fronds, no alpha overdraw or shadow lights.
	for p in [Vector3(-65,0,-36),Vector3(64,0,35),Vector3(-63,0,37),Vector3(65,0,-35),Vector3(-24,0,50),Vector3(26,0,50),Vector3(-3,0,-49),Vector3(50,0,-49)]:
		p.y=3.5
		w.obstacle(p,Vector3(.45,7,.45),Color("7d7256"))
		for j in 7:
			var a=j*TAU/7
			var root=p+Vector3(0,3.3,0)
			var forward=Vector3(cos(a),0,sin(a))
			var right=Vector3(-sin(a),0,cos(a))
			var tip=root+forward*3.3-Vector3(0,1.1,0)
			var mid=root+forward*1.7+Vector3(0,.25,0)
			var points=PackedVector3Array([root,mid-right*.47,tip,root,tip,mid+right*.47])
			var normals=PackedVector3Array()
			for i in 6: normals.append(Vector3.UP)
			var arr=[]; arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX]=points; arr[Mesh.ARRAY_NORMAL]=normals
			var uv=PackedVector2Array(); var indices=PackedInt32Array()
			for i in 6: uv.append(Vector2.ZERO); indices.append(i)
			arr[Mesh.ARRAY_TEX_UV]=uv; arr[Mesh.ARRAY_INDEX]=indices
			var mesh=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
			var leaf=MeshInstance3D.new(); leaf.mesh=mesh
			var mat=w.material(Color("586a46")).duplicate(); mat.cull_mode=BaseMaterial3D.CULL_DISABLED
			leaf.material_override=mat; w.add_child(leaf)
