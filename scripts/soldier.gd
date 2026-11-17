extends CharacterBody3D
## All movement, weapons and support abilities execute only on the match authority.
const CLASSES = ["ASSALTO", "MÉDICO", "ENGENHEIRO"]
var game: Node3D
var id = 0
var team = 0
var peer_id = 0
var bot = true
var role = 0
var hp = 100.0
var ammo = 30
var reserve = 150
var rocket_ammo = 3
var dead = false
var respawn_left = 0.0
var reload_left = 0.0
var cooldown = 0.0
var ability_cooldown = 0.0
var vehicle_id = -1
var seat = -1
var yaw = 0.0
var pitch = 0.0
var crouch = false
var prone = false
var stamina = 100.0
var sprint_locked = false
var aim_kick = 0.0
var jump_held = false
var commands: Dictionary = {}
var last_input_time = 0.0
var agent: NavigationAgent3D
var visual: Node3D
var hit_shape: CollisionShape3D
var class_marker: Node3D
var objective = -1
var think_left = 0.0
var target_id = -1
var reaction = 0.0
var footstep = 0.0
var muzzle_left = 0.0
var remote_pos = Vector3.ZERO
var remote_yaw = 0.0
var kills = 0
var deaths = 0
var rocket_selected = false
var rng = RandomNumberGenerator.new()
var sensor_left = 0.0
var walked = 0.0
var rally = false
var rally_point = Vector3.ZERO
var skin_materials: Array[ShaderMaterial] = []
var last_walk = -1.0
const Kit = preload("res://scripts/model_kit.gd")
const Batch = preload("res://scripts/batch.gd")

func _ready() -> void:
	rng.seed = id*713+77
	collision_layer = 2
	collision_mask = (1|4) if bot else (1|2|4)
	var capsule = CapsuleShape3D.new()
	capsule.radius = .36
	capsule.height = 1.8
	hit_shape = CollisionShape3D.new()
	hit_shape.shape = capsule
	hit_shape.position.y = .9
	add_child(hit_shape)
	visual = Node3D.new()
	add_child(visual)
	var w = game.world
	var color = w.TEAM_COLORS[team].darkened(.27)
	Kit.form(w,visual,Vector3(0,1.12,0),Vector3(.57,.62,.34),Color("59634e"))
	Kit.form(w,visual,Vector3(0,1.13,-.21),Vector3(.48,.44,.1),Color("434c3d"))
	Kit.form(w,visual,Vector3(0,1.18,.25),Vector3(.42,.46,.23),Color("515943"))
	w.box(visual,Vector3(0,1.35,-.27),Vector3(.35,.07,.035),color)
	w.box(visual,Vector3(0,1.46,0),Vector3(.14,.14,.15),Color("b3a180"))
	var head=MeshInstance3D.new()
	var sphere=SphereMesh.new()
	sphere.radius=.195; sphere.height=.37; sphere.radial_segments=8; sphere.rings=4
	head.mesh=sphere; head.material_override=w.material(Color("b3a180"))
	visual.add_child(head); head.position=Vector3(0,1.68,0)
	var helmet=MeshInstance3D.new()
	var cylinder=CylinderMesh.new()
	cylinder.top_radius=.18; cylinder.bottom_radius=.24; cylinder.height=.17; cylinder.radial_segments=8
	helmet.mesh=cylinder; helmet.material_override=w.material(Color("465047"))
	visual.add_child(helmet); helmet.position=Vector3(0,1.85,0)
	w.box(visual,Vector3(0,1.7,-.18),Vector3(.22,.055,.07),Color("263435"))
	for side in [-1,1]:
		Kit.form(w,visual,Vector3(side*.17,.69,0),Vector3(.25,.38,.29),Color("59634e"),1.08)
		Kit.form(w,visual,Vector3(side*.17,.33,-.015),Vector3(.21,.36,.24),Color("59634e"),1.13)
		Kit.form(w,visual,Vector3(side*.17,.51,-.14),Vector3(.18,.18,.08),Color("434c3d"))
		w.box(visual,Vector3(side*.17,.13,-.08),Vector3(.25,.2,.4),Color("303932"))
		var arm=Kit.form(w,visual,Vector3(side*.38,1.27,-.08),Vector3(.2,.4,.21),Color("59634e"))
		arm.rotation.x=-.45
		var forearm=Kit.form(w,visual,Vector3(side*.28,1.12,-.28),Vector3(.17,.36,.18),Color("59634e"))
		forearm.rotation.x=1.25
		w.box(visual,Vector3(side*.18,1.18,-.42),Vector3(.13,.14,.17),Color("b3a180"))
	Kit.form(w,visual,Vector3(.16,1.22,-.47),Vector3(.11,.12,.46),Color("37433d"))
	w.box(visual,Vector3(.16,1.22,-.79),Vector3(.035,.04,.25),Color("252e2e"))
	w.box(visual,Vector3(.16,1.09,-.46),Vector3(.07,.2,.12),Color("414d44"))
	for x in [-.15,0,.15]:
		Kit.form(w,visual,Vector3(x,1.08,-.28),Vector3(.12,.22,.09),Color("515943"))
	var body_mesh=Batch.merge(visual,[],105,true)
	for surface in body_mesh.mesh.get_surface_count():
		var mat=ShaderMaterial.new()
		mat.shader=preload("res://assets/shaders/soldier.gdshader")
		mat.set_shader_parameter("phase",id*1.7)
		mat.set_shader_parameter("cloth_texture",preload("res://assets/textures/military-atlas.png"))
		body_mesh.mesh.surface_set_material(surface,mat)
		skin_materials.append(mat)
	class_marker = Node3D.new()
	visual.add_child(class_marker)
	w.box(class_marker,Vector3(0,1.14,-.267),Vector3(.22,.065,.02),Color("e0e1ce"))
	w.box(class_marker,Vector3(0,1.14,-.28),Vector3(.065,.22,.02),Color("e0e1ce"))
	Batch.merge(class_marker)
	sensor_left=id*.017
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = .65
	agent.target_desired_distance = 1.2
	agent.radius = .45
	add_child(agent)

func server_tick(dt: float) -> void:
	cooldown = maxf(0,cooldown-dt)
	aim_kick=move_toward(aim_kick,0,dt*.12)
	ability_cooldown = maxf(0,ability_cooldown-dt)
	if dead:
		respawn_left = maxf(0,respawn_left-dt)
		if bot and respawn_left<=0: game.spawn_soldier(self,role,game.best_spawn(team))
		return
	if reload_left>0:
		reload_left -= dt
		if reload_left<=0:
			var amount = mini(30-ammo,reserve)
			ammo += amount
			reserve -= amount
	if bot: bot_tick(dt)
	elif game.elapsed-last_input_time>0.6: commands = {}
	if vehicle_id>=0:
		if not bot:
			yaw=commands.get("yaw",yaw)
			pitch=commands.get("pitch",pitch)
			if seat==1:
				if commands.get("reload",false): start_reload()
				if commands.get("fire",false): fire()
		return
	var move: Vector2 = commands.get("move",Vector2.ZERO)
	if move.length()>1: move = move.normalized()
	if not bot:
		yaw = commands.get("yaw",yaw)
		pitch = commands.get("pitch",pitch)
	prone=commands.get("prone",false)
	crouch=commands.get("crouch",false) and not prone
	var capsule_height=.75 if prone else (1.2 if crouch else 1.8)
	if hit_shape.shape.height!=capsule_height:
		hit_shape.shape.height=capsule_height
		hit_shape.position.y=capsule_height/2
	if stamina<=2: sprint_locked=true
	if stamina>=25: sprint_locked=false
	var running=not sprint_locked and commands.get("sprint",false) and move.length()>.2 and not commands.get("fire",false) and not crouch and not prone and stamina>2
	stamina=clampf(stamina+(-23 if running else 14)*dt,0,100)
	var speed=1.7 if prone else (3.0 if crouch else (8.0 if running else 5.3))
	var wish = Basis(Vector3.UP,yaw)*Vector3(move.x,0,move.y)
	velocity.x = wish.x*speed
	velocity.z = wish.z*speed
	if not is_on_floor(): velocity.y -= 22*dt
	else:
		velocity.y=-.5
		if commands.get("jump",false) and not jump_held and not prone and stamina>=12:
			velocity.y=6.0
			stamina-=12
	jump_held=commands.get("jump",false)
	if bot:
		for ally in game.soldiers.values():
			if ally==self or ally.dead or ally.team!=team: continue
			var away=position-ally.position
			away.y=0
			var length=away.length()
			if length>.05 and length<.95:
				velocity+=away/length*(.95-length)*3
	move_and_slide()
	game.protect_bases(self)
	rotation.y = yaw

	if move.length()>.1:
		footstep -= dt
		if footstep<=0:
			footstep = .3 if speed>6 else .46
			game.sound_at("step",position,.55)
	if commands.get("reload",false): start_reload()
	if commands.get("ability",false): support()
	if commands.get("fire",false): fire()
	# Bases replenish ammunition, without infinite magazines in the field.
	if position.distance_to(game.world.BASES[team])<12:
		if bot and agent.target_position.distance_to(game.world.BASES[team])<5:
			objective=-1
			think_left=0
			rally=false
		reserve = 150
		rocket_ammo = 3

func start_reload() -> void:
	if reload_left<=0 and ammo<30 and reserve>0:
		reload_left = 2.15
		game.sound_at("reload",position,.7)

func fire() -> void:
	if cooldown>0 or reload_left>0 or dead: return
	var rocket = role==2 and rocket_selected
	if rocket and rocket_ammo<=0: return
	if not rocket and ammo<=0:
		start_reload()
		return
	cooldown = 1.25 if rocket else .145
	if rocket: rocket_ammo -= 1
	else: ammo -= 1
	var origin = position+Vector3(0,eye_height(),0)
	var direction = -Basis.from_euler(Vector3(pitch+aim_kick,yaw,0)).z
	var spread = (.0025 if prone else (.004 if crouch else .007)) if not bot else rng.randf_range(.015,.045)
	if not bot: aim_kick=minf(.075,aim_kick+(.04 if rocket else .012))
	direction = (direction+Vector3(rng.randf_range(-spread,spread),rng.randf_range(-spread,spread),rng.randf_range(-spread,spread))).normalized()
	var excluded: Array[RID] = [get_rid()]
	if vehicle_id>=0: excluded.append(game.vehicles[vehicle_id].get_rid())
	var query = PhysicsRayQueryParameters3D.create(origin,origin+direction*180,1|2|4,excluded)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	var end = origin+direction*120
	if not hit.is_empty():
		end = hit.position
		if rocket:
			game.explode(end,team,id)
		elif hit.collider.has_method("take_damage"):
			hit.collider.take_damage(24.0,team,id)
	game.shot_event(id,origin,end,rocket)
	if bot and ammo==0: start_reload()

func take_damage(amount: float, from_team: int, attacker: int) -> void:
	if not game.authority() or dead or from_team==team or game.phase!="match": return
	if position.distance_to(game.world.BASES[team])<13: return
	hp = maxf(0,hp-amount)
	if hp<=0: die(attacker)

func die(attacker := -1) -> void:
	if dead: return
	dead = true
	hp = 0
	deaths += 1
	respawn_left = game.respawn_delay
	commands = {}
	if vehicle_id>=0: game.exit_vehicle(self,true)
	game.tickets[team] = maxi(0,game.tickets[team]-1)
	game.metrics.deaths += 1
	if game.soldiers.has(attacker): game.soldiers[attacker].kills += 1
	game.notice("%s %02d fora de combate" % ["Operador" if not bot else "Soldado",id])
	game.check_victory()

func support() -> void:
	if ability_cooldown>0: return
	ability_cooldown = .45
	if role==1:
		for other in game.soldiers.values():
			if other.team==team and not other.dead and position.distance_to(other.position)<5:
				other.hp = minf(100,other.hp+12)
	elif role==2:
		for jeep in game.vehicles.values():
			if jeep.team==team and jeep.hp>0 and position.distance_to(jeep.position)<5:
				jeep.hp = minf(350,jeep.hp+22)

func eye_height() -> float:
	return 1.8 if vehicle_id>=0 else (.6 if prone else (1.12 if crouch else 1.65))

func bot_tick(dt: float) -> void:
	think_left -= dt
	if think_left<=0:
		think_left = rng.randf_range(.55,1.05)
		objective = game.choose_objective(self)
	sensor_left-=dt
	var target=game.soldiers.get(target_id)
	var nearest=1000.0
	if sensor_left<=0:
		sensor_left=.24
		target=null
		for other in game.soldiers.values():
			if other.dead or other.team==team or other.vehicle_id>=0: continue
			var distance_squared=position.distance_squared_to(other.position)
			if distance_squared<44*44 and distance_squared<nearest*nearest and can_see(other):
				target=other
				nearest=sqrt(distance_squared)
	if target!=null:
		if target.dead: target=null
		else: nearest=position.distance_to(target.position)
	var next_target = -1 if target==null else target.id
	if next_target!=target_id:
		target_id = next_target
		reaction = rng.randf_range(.35,.85)
	reaction -= dt
	if rally and position.distance_to(rally_point)<3:
		rally=false
		agent.target_position=game.world.FLAG_POS[objective]+Vector3(sin(id*1.7)*3,0,cos(id*1.7)*3)
	var movement = Vector3.ZERO
	if not agent.is_navigation_finished():
		var next = agent.get_next_path_position()
		movement = (next-position)
		movement.y = 0
		movement = movement.normalized()*minf(1,movement.length()/maxf(.01,5.3*dt))
	if target!=null:
		var delta_pos = target.position+Vector3(0,1.3,0)-(position+Vector3(0,eye_height(),0))
		yaw = atan2(-delta_pos.x,-delta_pos.z)
		pitch = atan2(delta_pos.y,Vector2(delta_pos.x,delta_pos.z).length())
		if nearest<6: movement *= .6
	else:
		if movement.length()>.1: yaw = atan2(-movement.x,-movement.z)
		pitch = 0
	var local_move = Basis(Vector3.UP,-yaw)*movement
	commands = {"move":Vector2(local_move.x,local_move.z),"fire":target!=null and reaction<=0,"ability":true}
	if ammo==0: start_reload()
	if reserve==0 and ammo==0:
		agent.target_position = game.world.BASES[team]

func can_see(other: Node3D) -> bool:
	var q = PhysicsRayQueryParameters3D.create(position+Vector3(0,eye_height(),0),other.position+Vector3(0,1.25,0),1|2|4,[get_rid()])
	var hit = get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider==other

func presentation(dt: float, local: bool) -> void:
	if not game.authority():
		var before=position
		position = position.lerp(remote_pos,minf(1,dt*18))
		if not dead and vehicle_id<0:
			walked+=before.distance_to(position)
			if walked>2.3:
				walked=0
				game.sound_at("step",position,.55)
		yaw = lerp_angle(yaw,remote_yaw,minf(1,dt*18))
		rotation.y = yaw
	var walk=clampf(velocity.length()/5.3,0,1) if not dead else 0.0
	if not game.authority(): walk=1.0 if position.distance_to(remote_pos)>.04 else 0.0
	if absf(last_walk-walk)>.08:
		last_walk=walk
		for mat in skin_materials: mat.set_shader_parameter("walk_amount",walk)
	visual.scale.y=.7 if crouch else 1.0
	visual.rotation.x=-PI/2 if prone else 0
	visual.position.y=.3 if prone else 0
	class_marker.visible = role==1
	visual.visible = not dead and vehicle_id<0 and not local
	if hit_shape.disabled!=(dead or vehicle_id>=0): hit_shape.disabled = dead or vehicle_id>=0
