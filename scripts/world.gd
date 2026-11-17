extends Node3D
## Original map: Vale Seco. Geometry and navigation are deterministic, shared offline/LAN.
const TEAM_COLORS = [Color("ef493c"), Color("57b8ce")]
const FLAG_POS = [Vector3(-31, 0, -23), Vector3(0, 0, 24), Vector3(31, 0, -23)]
const FLAG_NAMES = ["A · DEPÓSITO", "B · ESTAÇÃO", "C · ANTENA"]
const BASES = [Vector3(-61, 0, 0), Vector3(61, 0, 0)]
var obstacles: Array[Rect2] = []
var flags: Array[MeshInstance3D] = []
var flag_labels: Array[Label3D] = []
var nav: NavigationRegion3D
var mats: Dictionary = {}
var sun: DirectionalLight3D
var baked_shadow: MeshInstance3D
var static_shapes: Array = []
const Batch = preload("res://scripts/batch.gd")

func material(color: Color) -> StandardMaterial3D:
	var key = color.to_html(false)
	if mats.has(key): return mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.94
	m.shading_mode=BaseMaterial3D.SHADING_MODE_PER_VERTEX
	var texture_name = {"bbb08b":"ground","555f55":"concrete","766b51":"metal","a0926b":"fabric","424b49":"asphalt","59634e":"camo","465346":"metal","8d7c56":"fabric","4e584d":"concrete","777660":"concrete","737e73":"ground","64634f":"ground","939078":"ground","696e59":"concrete","53624f":"metal","434c3d":"fabric","515943":"fabric","465047":"camo","283131":"metal","37433d":"metal","414d44":"metal","7c4937":"metal","777661":"fabric"}.get(key,"")
	if not texture_name.is_empty():
		m.albedo_texture=load("res://assets/textures/%s-v2.png"%texture_name)
		# Colored diffuse scans carry the base color; vertex tint only varies the kit.
		var tint={"ground":Color("c0b7a2"),"concrete":Color("d5d6c9"),"metal":Color("9ca28c"),"fabric":Color("c2bba1"),"asphalt":Color("555f61"),"camo":Color("d4d4bf")}
		m.albedo_color=tint[texture_name]
		m.uv1_triplanar=true
		m.uv1_scale=Vector3.ONE*(.14 if texture_name=="ground" else (.16 if texture_name=="asphalt" else .4))
	mats[key] = m
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = pos
	if solid:
		var body = StaticBody3D.new()
		parent.add_child(body)
		body.position = pos
		var collision = CollisionShape3D.new()
		var b = BoxShape3D.new()
		b.size = size
		collision.shape = b
		body.add_child(collision)
	return mesh

func obstacle(pos: Vector3, size: Vector3, color: Color) -> void:
	box(self, pos, size, color, true)
	static_shapes.append({"p":pos,"s":size})
	obstacles.append(Rect2(Vector2(pos.x-size.x/2, pos.z-size.z/2), Vector2(size.x,size.z)).grow(1.0))

func label_at(text: String, pos: Vector3, color: Color, font_size := 64) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.015
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 4
	label.outline_modulate = Color("20292a")
	add_child(label)
	label.position = pos
	return label

func _ready() -> void:
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky=Sky.new()
	var sky_mat=ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("356a8c")
	sky_mat.sky_horizon_color=Color("c7c8ae")
	sky_mat.ground_horizon_color=Color("c7c8ae")
	sky_mat.ground_bottom_color=Color("656951")
	sky_mat.sky_curve=.18
	sky_mat.sun_angle_max=3
	sky.sky_material=sky_mat
	sky.radiance_size=Sky.RADIANCE_SIZE_128
	e.sky=sky
	e.background_color = Color("899d9b")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("a1b6bd")
	e.ambient_light_energy = 0.62
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.fog_enabled = true
	e.fog_light_color = Color("b5b6a1")
	e.fog_density = 0.0008
	e.fog_sky_affect = 0.12
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("f5f0de")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140
	add_child(sun)
	box(self,Vector3(0,-2,0),Vector3(420,1,350),Color("bbb08b"))
	box(self, Vector3(0,-0.6,0), Vector3(150,1,118), Color("64634f"), true)
	box(self, Vector3(0,-0.07,0), Vector3(140,0.08,10), Color("424b49"))
	for x in range(-65, 66, 10):
		box(self,Vector3(x,0,0),Vector3(4,.025,.18),Color("c9ba87"))
	for i in 3:
		var p: Vector3 = FLAG_POS[i]
		box(self,Vector3(p.x,-.04,p.z),Vector3(17,.06,17),Color("939078"))
		box(self,p+Vector3(0,.05,0),Vector3(2,.1,2),Color("484f49"))
		box(self,p+Vector3(0,3,0),Vector3(.13,6,.13),Color("b8baaa"))
		flags.append(box(self,p+Vector3(1.2,5.1,0),Vector3(2.4,1.4,.05),Color("e0ddc7")))
		flag_labels.append(label_at(FLAG_NAMES[i],p+Vector3(0,7,0),Color("efead1"),44))
		# Marker ring: individual dashes keep infantry paths clear.
		for k in 20:
			var a = k*TAU/20
			box(self,p+Vector3(cos(a)*8,.015,sin(a)*8),Vector3(.5,.025,.5),Color("d4bc86"))
	# Shipping yard, pumping station and relay compound.
	for item in [[-38, -39, 10, 5, 6],[-23,-38,8,4,5],[-44,-19,5,3,11],[-16,19,7,4,11],[16,29,7,4,12],[0,42,17,5,5],[41,-36,12,4,7],[21,-39,5,6,5],[44,-15,5,3,12],[-28,14,7,2,3],[28,14,7,2,3],[-12,-12,5,2,3],[12,-12,5,2,3]]:
		var pos = Vector3(item[0],item[3]/2.0,item[1])
		var size = Vector3(item[2],item[3],item[4])
		obstacle(pos,size,Color("555f55") if item[3]<4 else Color("766b51"))
		box(self,pos+Vector3(0,size.y/2+.07,0),Vector3(size.x+.3,.14,size.z+.3),Color("373f3e"))
		if size.y>=3:
			# Recessed doors, panes, lintels and faded unit stripes, all merged at load.
			for side in [-1,1]:
				for x in [-size.x*.28,size.x*.28]:
					box(self,pos+Vector3(x,.3,side*(size.z/2+.015)),Vector3(1.25,1.05,.045),Color("263e43"))
					box(self,pos+Vector3(x,.88,side*(size.z/2+.08)),Vector3(1.45,.12,.18),Color("a7a18c"))
				box(self,Vector3(pos.x-.6,1.05,pos.z+side*(size.z/2+.03)),Vector3(.95,2.1,.08),Color("3a4540"))
				box(self,pos+Vector3(0,-.65,side*(size.z/2+.045)),Vector3(size.x,.17,.05),Color("826150"))
	# Alternating low cover along flank routes.
	for side in [-1,1]:
		for x in [-48,-8,8,48]:
			obstacle(Vector3(x,.65,side*39),Vector3(4,1.3,2),Color("a0926b"))
	for team in 2:
		var p: Vector3 = BASES[team]
		box(self,p+Vector3(0,-.03,0),Vector3(23,.07,26),Color("696e59"))
		label_at("01 / BRASA" if team==0 else "02 / NÉVOA",p+Vector3(0,7,0),TEAM_COLORS[team],55)
		for k in 36:
			var angle = k*TAU/36
			box(self,p+Vector3(cos(angle)*13,.025,sin(angle)*13),Vector3(.5,.035,.5),TEAM_COLORS[team])
		for z in [-17,17]:
			obstacle(p+Vector3(0,1.5,z),Vector3(17,3,3),Color("4e584d"))
			box(self,p+Vector3(0,2,z-1.6),Vector3(14,.4,.1),TEAM_COLORS[team])
	# Boundaries are real collisions, not invisible escape routes.
	for z in [-58,58]: obstacle(Vector3(0,2,z),Vector3(150,4,2),Color("777660"))
	for x in [-74,74]: obstacle(Vector3(x,2,0),Vector3(2,4,116),Color("777660"))
	# Low-poly distant silhouettes, outside the playable enclosure.
	var rng = RandomNumberGenerator.new()
	rng.seed = 12005
	for i in 26:
		var mountain = MeshInstance3D.new()
		var cone = SphereMesh.new()
		cone.radius=1; cone.height=2; cone.radial_segments=10; cone.rings=5
		mountain.scale=Vector3(rng.randf_range(15,28),rng.randf_range(12,23),rng.randf_range(13,24))
		mountain.mesh = _crag(cone)
		mountain.material_override = material(Color("737e73"))
		add_child(mountain)
		mountain.position = Vector3(rng.randf_range(-130,130),-2,(-85 if i%2==0 else 85))
	# Relay mast with cross braces and three antenna elements.
	for x in [-.6,.6]:
		box(self,Vector3(35+x,6.5,-38),Vector3(.14,13,.14),Color("555e59"))
	for y in range(3,14,2):
		var brace=box(self,Vector3(35,y,-38),Vector3(1.4,.1,.1),Color("555e59"))
		brace.rotation.z=.55 if y%4==1 else -.55
	for x in [-1,0,1]: box(self,Vector3(35+x*1.5,12,-38),Vector3(.12,2.8,.12),Color("a8aba0"))
	preload("res://scripts/setdress.gd").populate(self)
	preload("res://scripts/architecture.gd").populate(self)
	Batch.merge(self,flags)
	_build_shadows()
	_build_navigation()

func _build_navigation() -> void:
	nav = NavigationRegion3D.new()
	var mesh = NavigationMesh.new()
	mesh.agent_radius = .5
	var verts = PackedVector3Array()
	var lookup: Dictionary = {}
	# Shared grid vertices form a continuous navigable surface with obstacle holes.
	for x in range(-70,70,2):
		for z in range(-54,54,2):
			var center = Vector2(x+1,z+1)
			var blocked = false
			for rect in obstacles:
				if rect.grow(1.2).has_point(center): blocked = true; break
			if blocked: continue
			var indices = PackedInt32Array()
			for p in [Vector2(x,z),Vector2(x+2,z),Vector2(x+2,z+2),Vector2(x,z+2)]:
				if not lookup.has(p):
					lookup[p] = verts.size()
					verts.append(Vector3(p.x,0,p.y))
				indices.append(lookup[p])
			mesh.add_polygon(indices)
	mesh.vertices = verts
	nav.navigation_mesh = mesh
	add_child(nav)

func update_flags(state: Array) -> void:
	for i in state.size():
		var owner: int = state[i].owner
		var color = Color("dbd8c1") if owner<0 else TEAM_COLORS[owner]
		flags[i].material_override = material(color)
		flag_labels[i].modulate = color

func _build_shadows() -> void:
	# Fixed projected contact shadows reproduce a baked-light look on the low preset.
	var verts=PackedVector3Array()
	for item in static_shapes:
		var p: Vector3=item.p
		var size: Vector3=item.s
		if size.x>35 or size.z>35: continue
		var points=PackedVector2Array()
		for xx in [-1,1]:
			for zz in [-1,1]:
				var v=Vector2(p.x+xx*size.x/2,p.z+zz*size.z/2)
				points.append(v)
				points.append(v+Vector2(1.1,.7)*size.y)
		var hull=Geometry2D.convex_hull(points)
		for i in range(1,hull.size()-2):
			for v in [hull[0],hull[i],hull[i+1]]: verts.append(Vector3(v.x,.005,v.y))
	var arrays=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=verts
	var mesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	baked_shadow=MeshInstance3D.new()
	baked_shadow.mesh=mesh
	var mat=StandardMaterial3D.new()
	mat.albedo_color=Color(.08,.1,.09,.3)
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	baked_shadow.material_override=mat
	baked_shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(baked_shadow)

func _crag(source: PrimitiveMesh) -> ArrayMesh:
	var a=source.surface_get_arrays(0)
	var original: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
	var ids: PackedInt32Array=a[Mesh.ARRAY_INDEX]
	for i in original.size():
		var v=original[i]
		v.x*=1+.17*sin(v.y*7+v.z*8)
		v.y*=1+.19*sin(v.x*6+v.z*5)
		original[i]=v
	var points=PackedVector3Array(); var normals=PackedVector3Array(); var uv=PackedVector2Array(); var indices=PackedInt32Array()
	for t in range(0,ids.size(),3):
		var v0=original[ids[t]]; var v1=original[ids[t+1]]; var v2=original[ids[t+2]]
		var normal=(v1-v0).cross(v2-v0).normalized()
		if normal.dot((v0+v1+v2)/3)<0: normal=-normal
		for v in [v0,v1,v2]:
			indices.append(points.size()); points.append(v); normals.append(normal); uv.append(Vector2(v.x,v.z))
	var arr=[]; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX]=points; arr[Mesh.ARRAY_NORMAL]=normals; arr[Mesh.ARRAY_TEX_UV]=uv; arr[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
	return mesh
