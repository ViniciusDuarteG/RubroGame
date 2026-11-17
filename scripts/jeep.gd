extends CharacterBody3D
## Kinematic arcade jeep, two host-authoritative seats, shared collision and health.
var game: Node3D
var id = 0
var team = 0
var hp = 350.0
var seats = [-1,-1]
var speed = 0.0
var respawn_left = 0.0
var home = Vector3.ZERO
var remote_pos = Vector3.ZERO
var remote_yaw = 0.0
var model: Node3D
var wheels: Array[MeshInstance3D] = []
const Batch = preload("res://scripts/batch.gd")
var engine: AudioStreamPlayer3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1|2|4
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.1,1.4,3.7)
	collision.shape = shape
	collision.position.y = .85
	add_child(collision)
	model = Node3D.new()
	add_child(model)
	var w = game.world
	w.box(model,Vector3(0,.85,0),Vector3(2, .6,3.5),Color("465346"))
	w.box(model,Vector3(0,1.32,-1),Vector3(1.9,.4,1.4),Color("53624f"))
	w.box(model,Vector3(0,1.6,.1),Vector3(1.7,.15,.12),w.TEAM_COLORS[team])
	for side in [-1,1]:
		w.box(model,Vector3(side*.92,1.65,.9),Vector3(.1,1.2,.12),Color("303a33"))
		w.box(model,Vector3(side*.92,1.65,-.35),Vector3(.1,1.2,.12),Color("303a33"))
		w.box(model,Vector3(side*.65,1.2,.6),Vector3(.6,.5,.65),Color("242e2d"))
		w.box(model,Vector3(side*.72,1.1,-1.78),Vector3(.35,.22,.06),Color("efdf9d"))
		for z in [-1.1,1.15]:
			var wheel = MeshInstance3D.new()
			var mesh = CylinderMesh.new()
			mesh.top_radius = .48
			mesh.bottom_radius = .48
			mesh.height = .3
			mesh.radial_segments = 10
			wheel.mesh = mesh
			wheel.material_override = w.material(Color("222929"))
			model.add_child(wheel)
			wheel.position = Vector3(side*1.05,.48,z)
			wheel.rotation.z = PI/2
			wheels.append(wheel)
	# Original scout-car fittings, still merged into the existing body surfaces.
	for side in [-1,1]:
		w.box(model,Vector3(side*1.02,.77,-1),Vector3(.18,.13,1.4),Color("53624f"))
		w.box(model,Vector3(side*.98,1.28,.68),Vector3(.08,.48,1.45),Color("465346"))
		w.box(model,Vector3(side*.47,1.43,.86),Vector3(.56,.65,.16),Color("434c3d"))
		w.box(model,Vector3(side*.92,2.2,.25),Vector3(.11,.1,1.45),Color("465346"))
		w.box(model,Vector3(side*1.12,1.6,-.42),Vector3(.22,.18,.1),Color("303a33"))
		w.box(model,Vector3(side*.75,.9,1.78),Vector3(.22,.16,.06),Color("b44839"))
	w.box(model,Vector3(0,2.2,.9),Vector3(1.9,.1,.12),Color("465346"))
	w.box(model,Vector3(0,.72,-1.86),Vector3(2.2,.17,.13),Color("303a33"))
	w.box(model,Vector3(0,.72,1.86),Vector3(2.2,.17,.13),Color("303a33"))
	for k in 7: w.box(model,Vector3(-.46+k*.15,1.05,-1.72),Vector3(.06,.22,.14),Color("242e2d"))
	for k in 5: w.box(model,Vector3(-.3+k*.15,1.54,-.45),Vector3(.08,.08,.04),Color("d1c6a2"))
	Batch.merge(model,wheels)
	engine = AudioStreamPlayer3D.new()
	engine.stream = load("res://assets/audio/engine.wav")
	engine.max_distance = 65
	engine.volume_db = -15
	add_child(engine)
	engine.finished.connect(func():
		if hp>0 and seats[0]>=0: engine.play())

func server_tick(dt: float) -> void:
	if hp<=0:
		respawn_left -= dt
		if respawn_left<=0:
			hp = 350
			position = home
			rotation.y = -PI/2 if team==0 else PI/2
			speed = 0
			game.metrics.jeep_respawns += 1
		return
	var control: Dictionary = {}
	if seats[0]>=0 and game.soldiers.has(seats[0]): control = game.soldiers[seats[0]].commands
	var move: Vector2 = control.get("move",Vector2.ZERO)
	var desired = -move.y*19
	speed = move_toward(speed,desired,(12 if move.length()>.1 else 8)*dt)
	if control.get("brake",false): speed = move_toward(speed,0,35*dt)
	rotation.y -= move.x*dt*1.35*clampf(speed/8,-1,1)
	var forward = -global_basis.z
	velocity.x = forward.x*speed
	velocity.z = forward.z*speed
	if not is_on_floor(): velocity.y -= 24*dt
	else: velocity.y = -.5
	move_and_slide()
	if get_slide_collision_count()>0 and absf(speed)>9:
		for i in get_slide_collision_count():
			var impact = get_slide_collision(i)
			if absf(impact.get_normal().y)<.5:
				hp -= absf(speed)*.08
				speed *= .82
	game.protect_bases(self)
	for index in 2:
		if seats[index]>=0:
			var soldier = game.soldiers[seats[index]]
			soldier.position = position+global_basis*Vector3(-.48 if index==0 else .48,0,.35)
	if hp<=0: destroy()

func take_damage(amount: float, from_team: int, _attacker: int) -> void:
	if not game.authority() or hp<=0 or from_team==team: return
	if position.distance_to(game.world.BASES[team])<13: return
	hp = maxf(0,hp-amount)
	if hp<=0: destroy()

func destroy() -> void:
	hp = 0
	respawn_left = game.jeep_respawn_delay
	speed = 0
	game.metrics.jeep_destroyed += 1
	for soldier_id in seats.duplicate():
		if soldier_id>=0: game.soldiers[soldier_id].die()
	seats = [-1,-1]
	game.sound_at("boom",position,1)
	game.notice("Jipe destruído • reposição na base em %ds" % int(game.jeep_respawn_delay))

func presentation(dt: float) -> void:
	if not game.authority():
		position = position.lerp(remote_pos,minf(1,dt*15))
		rotation.y = lerp_angle(rotation.y,remote_yaw,minf(1,dt*15))
	model.visible = hp>0
	if hp>0 and seats[0]>=0:
		if not engine.playing: engine.play()
		engine.pitch_scale = .8+absf(speed)*.055
	else: engine.stop()
	for wheel in wheels: wheel.rotation.x += speed*dt*1.5
