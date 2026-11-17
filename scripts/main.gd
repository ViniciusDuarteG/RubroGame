extends Node3D
const MapScene = preload("res://scenes/vale_seco.tscn")
const Soldier = preload("res://scripts/soldier.gd")
const Jeep = preload("res://scripts/jeep.gd")
const Interface = preload("res://scripts/interface.gd")
const PORT = 28745
const CAPACITY = 16
var world: Node3D
var ui: CanvasLayer
var camera: Camera3D
var weapon: Node3D
var rifle_model: Node3D
var rifle_magazine: MeshInstance3D
var prone_requested = false
var feed: Array[String] = []
var launcher_model: Node3D
const Settings = preload("res://scripts/settings.gd")
const Batch = preload("res://scripts/batch.gd")
var graphics = Settings.new()
var effects: Node3D
var benchmarking = false
var phase = "menu"
var mode = "solo"
var lobby: Dictionary = {}
var soldiers: Dictionary = {}
var vehicles: Dictionary = {}
var tickets = [100,100]
var flags: Array = []
var winner = -1
var local_actor = -1
var local_yaw = 0.0
var local_pitch = 0.0
var elapsed = 0.0
var bleed_interval = 4.0
var capture_seconds = 9.0
var respawn_delay = 5.0
var jeep_respawn_delay = 18.0
var bleed_timer = 0.0
var snapshot_timer = 0.0
var lobby_timer = 0.0
var toast = ""
var toast_time = 0.0
var fire_feedback = 0.0
var paused_input = false
var metrics = {"captures":0,"recaptures":0,"deaths":0,"jeep_destroyed":0,"jeep_respawns":0,"contested":0,"spawns":0}
var flag_history = [[],[],[]]
var test_runner: Node
var connection_timer = 0.0
var joining = false
var event_serial = 0
var last_local_vehicle = -1
var last_vehicle_yaw = 0.0

func _ready() -> void:
	seed(42005)
	world = MapScene.instantiate()
	add_child(world)
	graphics.load_config()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="): graphics.quality=clampi(int(arg.get_slice("=",1)),0,2)
	graphics.apply(self)
	camera = Camera3D.new()
	camera.far = 300
	camera.fov = 79
	add_child(camera)
	camera.position = Vector3(-46,37,65)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	effects=preload("res://scripts/effects.gd").new()
	add_child(effects)
	_build_weapon()
	ui = Interface.new()
	ui.game = self
	add_child(ui)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): connection_error("Não foi possível conectar ao IP."))
	multiplayer.server_disconnected.connect(func(): connection_error("O host desconectou."))
	multiplayer.peer_disconnected.connect(_peer_left)
	var args = OS.get_cmdline_user_args()
	if "--benchmark" in args:
		benchmarking=true
		var bench=preload("res://scripts/benchmark.gd").new()
		bench.game=self
		add_child(bench)
	if "--test-solo" in args or "--test-host" in args or "--test-client" in args or "--test-rules" in args or "--capture" in args:
		test_runner = load("res://tests/integration.gd").new()
		test_runner.game = self
		add_child(test_runner)

func authority() -> bool:
	return mode=="solo" or multiplayer.is_server()

func my_peer() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

func _build_weapon() -> void:
	weapon = Node3D.new()
	camera.add_child(weapon)
	weapon.position = Vector3(.26,-.27,-.68)
	weapon.scale = Vector3.ONE*.75
	rifle_model=Node3D.new()
	launcher_model=Node3D.new()
	weapon.add_child(rifle_model)
	weapon.add_child(launcher_model)
	preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(0,0,.06),Vector3(.1,.14,.29),Color("283131"))
	preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(0,0,-.25),Vector3(.13,.13,.31),Color("37433d"))
	preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(0,0,.31),Vector3(.12,.16,.24),Color("37433d"))
	preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(0,.088,-.03),Vector3(.035,.035,.3),Color("1e2828"))
	preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(0,.13,.02),Vector3(.065,.04,.065),Color("1e2828"))
	preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(0,.055,-.55),Vector3(.025,.09,.025),Color("1e2828"))
	preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(0,0,-.5),Vector3(.04,.045,.31),Color("1e2828"))
	var magazine=preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(0,-.16,.02),Vector3(.07,.22,.12),Color("414d44"))
	magazine.rotation.x=.18
	rifle_magazine=magazine
	preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(0,-.12,.18),Vector3(.065,.17,.07),Color("303832"))
	preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(0,.02,.13),Vector3(.105,.025,.055),Color("b44839"))
	preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(-.035,-.12,-.25),Vector3(.13,.13,.15),Color("a18e70"))
	preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(.02,-.16,.18),Vector3(.13,.13,.15),Color("a18e70"))
	preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(-.1,-.23,-.1),Vector3(.15,.14,.32),Color("59634e"))
	preload("res://scripts/model_kit.gd").form(world,rifle_model,Vector3(.08,-.28,.37),Vector3(.15,.16,.35),Color("59634e"))
	var tube=MeshInstance3D.new()
	var mesh=CylinderMesh.new()
	mesh.top_radius=.115; mesh.bottom_radius=.115; mesh.height=.95; mesh.radial_segments=10
	tube.mesh=mesh; tube.material_override=world.material(Color("59634e"))
	launcher_model.add_child(tube)
	tube.rotation.x=PI/2
	world.box(launcher_model,Vector3(0,-.16,.15),Vector3(.07,.24,.09),Color("273530"))
	world.box(launcher_model,Vector3(-.1,.12,-.03),Vector3(.06,.12,.13),Color("273530"))
	world.box(launcher_model,Vector3(-.08,-.1,-.18),Vector3(.16,.14,.16),Color("a18e70"))
	for k in 7:
		world.box(rifle_model,Vector3(0,.074,-.39+k*.042),Vector3(.14,.018,.018),Color("586357"))
	for side in [-1,1]:
		world.box(rifle_model,Vector3(side*.073,0,-.27),Vector3(.012,.055,.22),Color("171e1d"))
		world.box(rifle_model,Vector3(side*.04,.14,.02),Vector3(.015,.045,.055),Color("303832"))
	world.box(rifle_model,Vector3(.058,.028,.07),Vector3(.018,.025,.09),Color("697065"))
	world.box(rifle_model,Vector3(.064,0,.04),Vector3(.025,.018,.02),Color("a4a58e"))
	Batch.merge(rifle_model,[rifle_magazine])
	Batch.merge(launcher_model)
	for model in [rifle_model,launcher_model]:
		for child in model.get_children():
			if child is MeshInstance3D: child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weapon.visible=false

func start_solo(team := 0) -> void:
	close_network()
	mode = "solo"
	lobby = {1:{"team":team,"name":"VOCÊ"}}
	start_match()

func host() -> void:
	close_network()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT,15)
	if error!=OK:
		connection_error("Porta %d indisponível (%d)."%[PORT,error])
		return
	multiplayer.multiplayer_peer = peer
	mode = "lan"
	lobby = {1:{"team":-1,"name":"HOST"}}
	phase = "lobby"
	ui.rebuild()

func join(ip: String) -> void:
	if ip.strip_edges().is_empty():
		connection_error("Informe o IP do host.")
		return
	close_network()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip.strip_edges(),PORT)
	if error!=OK:
		connection_error("Endereço inválido (%d)."%error)
		return
	multiplayer.multiplayer_peer = peer
	mode = "lan"
	joining = true
	connection_timer = 0
	toast = "Conectando a %s…"%ip
	toast_time = 12

func _connected() -> void:
	joining = false
	register.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func register() -> void:
	if not authority(): return
	var sender = multiplayer.get_remote_sender_id()
	if sender<=1: return
	if phase!="lobby" or lobby.size()>=16:
		rejected.rpc_id(sender,"A partida já começou ou está cheia.")
		return
	lobby[sender] = {"team":-1,"name":"RECRUTA %d"%(sender%1000)}
	broadcast_lobby()

@rpc("authority","call_remote","reliable")
func rejected(reason: String) -> void:
	connection_error(reason)

func select_team(team: int) -> void:
	if mode=="solo": return
	if authority(): _set_team(my_peer(),team)
	else: request_team.rpc_id(1,team)

@rpc("any_peer","call_remote","reliable")
func request_team(team: int) -> void:
	if authority(): _set_team(multiplayer.get_remote_sender_id(),team)

func _set_team(peer: int, team: int) -> void:
	if phase!="lobby" or not lobby.has(peer) or team<0 or team>1: return
	var count = 0
	for p in lobby:
		if p!=peer and lobby[p].team==team: count += 1
	if count>=8: return
	lobby[peer].team = team
	broadcast_lobby()

func broadcast_lobby() -> void:
	if mode=="lan": lobby_state.rpc(lobby)
	ui.rebuild()

@rpc("authority","call_remote","reliable")
func lobby_state(state: Dictionary) -> void:
	lobby = state
	phase = "lobby"
	ui.rebuild()

func can_start() -> bool:
	if lobby.is_empty(): return false
	for p in lobby:
		if lobby[p].team<0: return false
	return true

func start_match() -> void:
	if not authority() or not can_start(): return
	_clear_match()
	phase = "match"
	winner = -1
	elapsed = 0
	bleed_timer = 0
	tickets = [100,100]
	metrics = {"captures":0,"recaptures":0,"deaths":0,"jeep_destroyed":0,"jeep_respawns":0,"contested":0,"spawns":0}
	flag_history = [[],[],[]]
	flags = []
	for i in 3: flags.append({"owner":-1,"progress":0.0,"capturing":-1,"contested":false})
	var roster: Array = []
	var next_id = 1
	for team in 2:
		var humans: Array = []
		for p in lobby:
			if lobby[p].team==team: humans.append(p)
		for slot in 8:
			var peer: int = humans[slot] if slot<humans.size() else 0
			roster.append({"id":next_id,"team":team,"peer":peer,"role":slot%3})
			next_id += 1
	_create_roster(roster)
	if mode=="lan": begin_match.rpc(roster)
	ui.rebuild()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _clear_match() -> void:
	for actor in soldiers.values():
		remove_child(actor)
		actor.queue_free()
	for jeep in vehicles.values():
		remove_child(jeep)
		jeep.queue_free()
	soldiers.clear()
	vehicles.clear()
	local_actor = -1
	last_local_vehicle = -1
	prone_requested=false
	feed.clear()
	paused_input = false

func _create_roster(roster: Array) -> void:
	for data in roster:
		var actor = Soldier.new()
		actor.game = self
		actor.id = data.id
		actor.team = data.team
		actor.peer_id = data.peer
		actor.bot = data.peer==0
		actor.role = data.role
		actor.name = "Soldier%d"%actor.id
		add_child(actor)
		soldiers[actor.id] = actor
		if data.peer==my_peer(): local_actor = actor.id
		if authority(): spawn_soldier(actor,data.role,-1)
	for team in 2:
		var jeep = Jeep.new()
		jeep.game = self
		jeep.id = team
		jeep.team = team
		jeep.name = "Jeep%d"%team
		add_child(jeep)
		jeep.home = world.BASES[team]+Vector3(0,.1,7)
		jeep.position = jeep.home
		jeep.rotation.y = -PI/2 if team==0 else PI/2
		vehicles[team] = jeep
	local_yaw = -PI/2 if local_actor>0 and soldiers[local_actor].team==0 else PI/2
	local_pitch = 0

@rpc("authority","call_remote","reliable")
func begin_match(roster: Array) -> void:
	_clear_match()
	flags = []
	for i in 3: flags.append({"owner":-1,"progress":0.0,"capturing":-1,"contested":false})
	_create_roster(roster)
	phase = "match"
	winner = -1
	ui.rebuild()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func spawn_allowed(index: int, team: int) -> bool:
	if index<0 or index>=flags.size(): return false
	var f: Dictionary=flags[index]
	if f.owner!=team or f.contested: return false
	if f.progress>0 and f.capturing>=0 and f.capturing!=team: return false
	for soldier in soldiers.values():
		if not soldier.dead and soldier.team!=team and soldier.position.distance_squared_to(world.FLAG_POS[index])<=64: return false
	return true

func best_spawn(team: int) -> int:
	var best = -1
	var distance = INF
	for i in flags.size():
		if not spawn_allowed(i,team): continue
		var d = world.FLAG_POS[i].distance_to(world.BASES[1-team])
		if d<distance: distance=d; best=i
	return best

func spawn_soldier(actor: Node3D, role: int, spawn_index: int) -> void:
	if not authority() or phase!="match" or role<0 or role>2: return
	if actor.dead and actor.respawn_left>0: return
	var point: Vector3 = world.BASES[actor.team]
	if spawn_allowed(spawn_index,actor.team):
		point = world.FLAG_POS[spawn_index]
	# Safe offsets entirely inside the clear area of each spawn zone.
	var angle = actor.id*2.39996
	actor.position = point+Vector3(cos(angle)*3,.2,sin(angle)*3)
	actor.velocity = Vector3.ZERO
	actor.hp = 100
	actor.stamina=100
	actor.sprint_locked=false
	actor.prone=false
	actor.crouch=false
	actor.aim_kick=0
	actor.ammo = 30
	actor.reserve = 150
	actor.rocket_ammo = 3
	actor.rocket_selected=false
	actor.dead = false
	actor.role = role
	actor.reload_left = 0
	actor.cooldown = .5
	actor.vehicle_id = -1
	actor.seat = -1
	actor.objective = -1
	actor.rally=false
	actor.yaw = -PI/2 if actor.team==0 else PI/2
	actor.hit_shape.disabled = false
	metrics.spawns += 1

func respawn(role: int, point: int) -> void:
	if authority(): _respawn(my_peer(),role,point)
	else: request_respawn.rpc_id(1,role,point)

@rpc("any_peer","call_remote","reliable")
func request_respawn(role: int, point: int) -> void:
	if authority(): _respawn(multiplayer.get_remote_sender_id(),role,point)

func _respawn(peer: int, role: int, point: int) -> void:
	var actor = actor_for_peer(peer)
	if actor!=null and actor.dead: spawn_soldier(actor,role,point)

func actor_for_peer(peer: int):
	for actor in soldiers.values():
		if actor.peer_id==peer: return actor
	return null

func choose_objective(actor: Node3D) -> int:
	var best = -1
	var best_score = INF
	for i in flags.size():
		var destination: Vector3 = world.FLAG_POS[i]
		var owner: int = flags[i].owner
		var assigned = 0
		for other in soldiers.values():
			if other!=actor and other.team==actor.team and other.objective==i and not other.dead: assigned+=1
		var defender = actor.id%4==0
		var score = actor.position.distance_to(destination)+assigned*17
		if owner==actor.team: score += 30 if defender else 80
		if flags[i].contested and owner==actor.team: score -= 48
		# Four raiders form a push while the rest hold/contest other positions.
		var squad_slot=(actor.id-1)%8
		if owner==1-actor.team and squad_slot<4: score-=38
		if owner==actor.team and squad_slot>=6: score-=42
		if score<best_score: best_score=score; best=i
	if best>=0 and best!=actor.objective:
		var route = NavigationServer3D.map_get_path(world.nav.get_navigation_map(),actor.position,world.FLAG_POS[best],true)
		if route.is_empty(): return -1
		actor.rally=flags[best].owner==1-actor.team and actor.position.distance_to(world.FLAG_POS[best])>32
		if actor.rally:
			actor.rally_point=world.FLAG_POS[best]+Vector3(-20 if actor.team==0 else 20,0,-17 if world.FLAG_POS[best].z<0 else 17)
			actor.rally_point=NavigationServer3D.map_get_closest_point(world.nav.get_navigation_map(),actor.rally_point)
			actor.agent.target_position=actor.rally_point
		else: actor.agent.target_position = world.FLAG_POS[best]+Vector3(sin(actor.id*1.7)*3,0,cos(actor.id*1.7)*3)
	return best

func capture_tick(dt: float) -> void:
	for i in flags.size():
		var counts = [0,0]
		for actor in soldiers.values():
			if not actor.dead and actor.position.distance_to(world.FLAG_POS[i])<=8:
				counts[actor.team] += 1
		var f: Dictionary = flags[i]
		var contested = counts[0]>0 and counts[1]>0
		if contested and not f.contested: metrics.contested+=1
		f.contested = contested
		if contested: continue
		var team = 0 if counts[0]>0 else (1 if counts[1]>0 else -1)
		if team<0: continue
		if f.owner==team:
			f.progress = move_toward(f.progress,0,dt/capture_seconds)
			if f.progress==0: f.capturing=-1
			continue
		if f.capturing!=team:
			f.progress = move_toward(f.progress,0,dt/capture_seconds)
			if f.progress>0: continue
			f.capturing = team
		f.progress += dt/capture_seconds*minf(2,1+(counts[team]-1)*.25)
		if f.progress>=1:
			# Enemy ownership must be neutralized before the second capture stage.
			if f.owner>=0:
				f.owner = -1
			else:
				f.owner = team
				metrics.captures += 1
				if not flag_history[i].is_empty() and flag_history[i].back()!=team: metrics.recaptures+=1
				flag_history[i].append(team)
				notice("%s capturada por %s"%[world.FLAG_NAMES[i],"BRASA" if team==0 else "NÉVOA"])
				for actor in soldiers.values(): actor.think_left = 0
			f.progress = 0
			f.capturing = -1
	bleed_timer += dt
	if bleed_timer>=bleed_interval:
		bleed_timer = fmod(bleed_timer,bleed_interval)
		var owned = [0,0]
		for f in flags:
			if f.owner>=0: owned[f.owner]+=1
		for team in 2:
			if owned[team]>=2: tickets[1-team] = maxi(0,tickets[1-team]-(2 if owned[team]==3 else 1))
		check_victory()

func protect_bases(body: Node3D) -> void:
	var enemy: Vector3 = world.BASES[1-body.team]
	var delta_pos = body.position-enemy
	delta_pos.y = 0
	if delta_pos.length()<13:
		if delta_pos.length()<.01: delta_pos = Vector3.RIGHT
		var protected_pos = enemy+delta_pos.normalized()*13.2
		body.position.x = protected_pos.x
		body.position.z = protected_pos.z
	body.position.x = clampf(body.position.x,-72,72)
	body.position.z = clampf(body.position.z,-56,56)

func check_victory() -> void:
	if phase!="match": return
	if tickets[0]<=0 or tickets[1]<=0:
		winner = 1 if tickets[0]<=0 else 0
		phase = "result"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.rebuild()
		if mode=="lan": match_result.rpc(winner,tickets,metrics)

@rpc("authority","call_remote","reliable")
func match_result(team: int, final_tickets: Array, final_metrics: Dictionary) -> void:
	metrics = final_metrics
	winner = team
	tickets = final_tickets
	phase = "result"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.rebuild()

func rematch() -> void:
	if authority(): start_match()

func interact() -> void:
	if authority(): _interact(my_peer())
	else: request_interact.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func request_interact() -> void:
	if authority(): _interact(multiplayer.get_remote_sender_id())

func _interact(peer: int) -> void:
	if phase!="match": return
	var actor = actor_for_peer(peer)
	if actor==null or actor.dead: return
	if actor.vehicle_id>=0:
		exit_vehicle(actor)
		return
	for jeep in vehicles.values():
		if jeep.hp<=0 or jeep.team!=actor.team or actor.position.distance_to(jeep.position)>4.5: continue
		for seat in 2:
			if jeep.seats[seat]<0:
				jeep.seats[seat] = actor.id
				actor.vehicle_id = jeep.id
				actor.seat = seat
				actor.velocity = Vector3.ZERO
				actor.hit_shape.disabled = true
				return

func exit_vehicle(actor: Node3D, forced := false) -> void:
	if actor.vehicle_id<0: return
	var jeep = vehicles[actor.vehicle_id]
	var candidate: Vector3 = jeep.position
	var found = false
	for offset in [Vector3(-2.6,.2,0),Vector3(2.6,.2,0),Vector3(0,.2,3.2)]:
		candidate = jeep.position+jeep.global_basis*offset
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = actor.hit_shape.shape
		query.transform = Transform3D(Basis(),candidate+Vector3(0,.9,0))
		query.collision_mask = 1|2|4
		query.exclude = [actor.get_rid(),jeep.get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(query).is_empty(): found=true; break
	if not found and not forced: return
	jeep.seats[actor.seat] = -1
	actor.position = candidate
	actor.vehicle_id = -1
	actor.seat = -1
	actor.hit_shape.disabled = actor.dead

func explode(point: Vector3, team: int, attacker: int) -> void:
	for actor in soldiers.values():
		if actor.dead or actor.vehicle_id>=0: continue
		var distance = actor.position.distance_to(point)
		if distance<5:
			var q = PhysicsRayQueryParameters3D.create(point+Vector3(0,.15,0),actor.position+Vector3(0,1,0),1)
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty(): actor.take_damage(110*(1-distance/6),team,attacker)
	for jeep in vehicles.values():
		if jeep.position.distance_to(point)<5: jeep.take_damage(190,team,attacker)

func shot_event(actor_id: int, origin: Vector3, end: Vector3, rocket: bool) -> void:
	show_shot(actor_id,origin,end,rocket)
	if mode=="lan": shot_fx.rpc(actor_id,origin,end,rocket)

@rpc("authority","call_remote","unreliable",2)
func shot_fx(actor_id: int, origin: Vector3, end: Vector3, rocket: bool) -> void:
	show_shot(actor_id,origin,end,rocket)

func show_shot(actor_id: int, origin: Vector3, end: Vector3, rocket: bool) -> void:
	if DisplayServer.get_name()=="headless": return
	sound_at("rocket" if rocket else "shot",origin,1.0)
	if actor_id==local_actor: fire_feedback = .12
	effects.shot(origin,end,rocket)
	if rocket:
		sound_at("boom",end,1.0)
		var flash = world.box(self,end,Vector3(1.6,1.6,1.6),Color("ee8545"))
		var tween = create_tween()
		tween.tween_property(flash,"scale",Vector3(.05,.05,.05),.3)
		tween.tween_callback(flash.queue_free)

func sound_at(kind: String, point: Vector3, volume: float) -> void:
	if DisplayServer.get_name()=="headless": return
	if camera.position.distance_to(point)>75: return
	effects.sound(kind,point,volume)

func notice(message: String) -> void:
	announce(message)
	if mode=="lan" and authority(): announce.rpc(message)

@rpc("authority","call_remote","reliable")
func announce(message: String) -> void:
	toast=message
	toast_time=3
	feed.push_front(message)
	if feed.size()>5: feed.pop_back()

func _unhandled_input(event: InputEvent) -> void:
	if benchmarking: return
	if phase!="match": return
	var actor = soldiers.get(local_actor)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		paused_input = not paused_input
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused_input else Input.MOUSE_MODE_CAPTURED
		ui.rebuild()
	if actor==null or actor.dead or paused_input: return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		local_yaw -= event.relative.x*.0022
		local_pitch = clampf(local_pitch-event.relative.y*.0022,-1.35,1.35)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_E: interact()
		if event.physical_keycode==KEY_Z: prone_requested=not prone_requested
		if event.physical_keycode==KEY_2: set_weapon(true)
		if event.physical_keycode==KEY_1: set_weapon(false)

func set_weapon(rocket: bool) -> void:
	if authority(): _weapon(my_peer(),rocket)
	else: request_weapon.rpc_id(1,rocket)

@rpc("any_peer","call_remote","reliable")
func request_weapon(rocket: bool) -> void:
	if authority(): _weapon(multiplayer.get_remote_sender_id(),rocket)

func _weapon(peer: int, rocket: bool) -> void:
	var actor = actor_for_peer(peer)
	if actor!=null and actor.role==2: actor.rocket_selected=rocket

func collect_input() -> Dictionary:
	if benchmarking: return {}
	if paused_input or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: return {}
	return {"move":Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))),"yaw":local_yaw,"pitch":local_pitch,"fire":Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),"sprint":Input.is_physical_key_pressed(KEY_SHIFT),"crouch":Input.is_physical_key_pressed(KEY_CTRL),"reload":Input.is_physical_key_pressed(KEY_R),"ability":Input.is_physical_key_pressed(KEY_Q),"brake":Input.is_physical_key_pressed(KEY_SPACE),"jump":Input.is_physical_key_pressed(KEY_SPACE),"prone":prone_requested}

@rpc("any_peer","call_remote","unreliable_ordered",1)
func send_input(command: Dictionary) -> void:
	if not authority() or phase!="match": return
	var actor = actor_for_peer(multiplayer.get_remote_sender_id())
	if actor==null or actor.dead: return
	# Network clients send intent only. No position, damage or ownership is accepted.
	if typeof(command.get("move",Vector2.ZERO))!=TYPE_VECTOR2: return
	var move: Vector2 = command.get("move",Vector2.ZERO)
	var y = float(command.get("yaw",actor.yaw))
	var p = float(command.get("pitch",actor.pitch))
	if not move.is_finite() or not is_finite(y) or not is_finite(p): return
	actor.commands = {"move":move.limit_length(1),"yaw":wrapf(y,-PI,PI),"pitch":clampf(p,-1.35,1.35)}
	for key in ["fire","sprint","crouch","reload","ability","brake","jump","prone"]: actor.commands[key]=bool(command.get(key,false))
	actor.last_input_time = elapsed

func _physics_process(dt: float) -> void:
	if joining:
		connection_timer += dt
		if connection_timer>10: connection_error("Tempo de conexão esgotado. Confira IP e porta UDP 28745.")
	if phase!="match": return
	if local_actor>0 and soldiers.has(local_actor) and not soldiers[local_actor].dead:
		var command = collect_input()
		if test_runner!=null: command = test_runner.input_for_local(command)
		if authority():
			soldiers[local_actor].commands = command
			soldiers[local_actor].last_input_time = elapsed
		else: send_input.rpc_id(1,command)
	if authority():
		elapsed += dt
		for actor in soldiers.values(): actor.server_tick(dt)
		for jeep in vehicles.values(): jeep.server_tick(dt)
		capture_tick(dt)
		if phase!="match": return
		snapshot_timer += dt
		if snapshot_timer>=.05 and mode=="lan":
			snapshot_timer -= .05
			sync_state.rpc(var_to_bytes(make_snapshot()).compress(FileAccess.COMPRESSION_GZIP))

func make_snapshot() -> Dictionary:
	var actors: Array = []
	for actor in soldiers.values():
		actors.append([actor.id,actor.position,actor.yaw,actor.pitch,actor.hp,actor.ammo,actor.reserve,actor.rocket_ammo,actor.dead,actor.respawn_left,actor.reload_left,actor.vehicle_id,actor.seat,actor.role,actor.rocket_selected,actor.kills,actor.deaths,actor.bot,actor.stamina,actor.crouch,actor.prone,actor.aim_kick])
	var jeeps: Array = []
	for jeep in vehicles.values(): jeeps.append([jeep.id,jeep.position,jeep.rotation.y,jeep.hp,jeep.seats,jeep.speed,jeep.respawn_left])
	return {"actors":actors,"jeeps":jeeps,"flags":flags,"tickets":tickets,"elapsed":elapsed,"metrics":metrics}

@rpc("authority","call_remote","unreliable_ordered",0)
func sync_state(packet: PackedByteArray) -> void:
	if phase!="match": return
	var state: Dictionary = bytes_to_var(packet.decompress_dynamic(65536,FileAccess.COMPRESSION_GZIP))
	tickets = state.tickets
	flags = state.flags
	elapsed = state.elapsed
	metrics = state.metrics
	for data in state.actors:
		if not soldiers.has(data[0]): continue
		var a = soldiers[data[0]]
		if a.position.distance_to(data[1])>8: a.position=data[1]
		a.remote_pos=data[1]; a.remote_yaw=data[2]; a.pitch=data[3]; a.hp=data[4]
		a.ammo=data[5]; a.reserve=data[6]; a.rocket_ammo=data[7]; a.dead=data[8]
		a.respawn_left=data[9]; a.reload_left=data[10]; a.vehicle_id=data[11]; a.seat=data[12]
		a.role=data[13]; a.rocket_selected=data[14]; a.kills=data[15]; a.deaths=data[16]; a.bot=data[17]
		a.stamina=data[18]; a.crouch=data[19]; a.prone=data[20]; a.aim_kick=data[21]
	for data in state.jeeps:
		var j = vehicles[data[0]]
		if j.position.distance_to(data[1])>8: j.position=data[1]
		j.remote_pos=data[1]; j.remote_yaw=data[2]; j.hp=data[3]; j.seats=data[4]; j.speed=data[5]; j.respawn_left=data[6]

func _process(dt: float) -> void:
	toast_time = maxf(0,toast_time-dt)
	fire_feedback = maxf(0,fire_feedback-dt)
	for actor in soldiers.values(): actor.presentation(dt,actor.id==local_actor)
	for jeep in vehicles.values():
		if not authority():
			jeep.position = jeep.position.lerp(jeep.remote_pos,minf(1,dt*18))
			jeep.rotation.y = lerp_angle(jeep.rotation.y,jeep.remote_yaw,minf(1,dt*18))
		jeep.model.visible = jeep.hp>0
		jeep.presentation(dt)
	if flags.size()==3: world.update_flags(flags)
	var actor = soldiers.get(local_actor)
	if actor!=null and actor.dead: prone_requested=false
	if actor!=null and actor.vehicle_id!=last_local_vehicle:
		if actor.vehicle_id>=0 and actor.seat==0: local_yaw=0
		elif last_local_vehicle>=0: local_yaw+=last_vehicle_yaw
		last_local_vehicle=actor.vehicle_id
	if actor!=null and actor.vehicle_id>=0: last_vehicle_yaw=vehicles[actor.vehicle_id].rotation.y
	if actor!=null:
		rifle_model.visible=not actor.rocket_selected
		launcher_model.visible=actor.rocket_selected
	weapon.visible = phase=="match" and actor!=null and not actor.dead and actor.vehicle_id<0 and not paused_input
	if phase=="match" and actor!=null and not actor.dead:
		var point: Vector3 = actor.position+Vector3(0,actor.eye_height(),0)
		if actor.vehicle_id>=0:
			var j = vehicles[actor.vehicle_id]
			point = j.position+j.global_basis*Vector3(-.48 if actor.seat==0 else .48,1.8,.35)
		camera.position = camera.position.lerp(point,minf(1,dt*25)) if camera.position.distance_to(point)<5 else point
		camera.rotation = Vector3(local_pitch+actor.aim_kick,local_yaw,0)
		if actor.vehicle_id>=0 and actor.seat==0: camera.rotation.y += vehicles[actor.vehicle_id].rotation.y
		var aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		camera.fov = lerpf(camera.fov,57.0 if aiming else 79.0,minf(1,dt*12))
		var sway = sin(elapsed*12)*.008 if actor.velocity.length()>1 else 0.0
		var reload_phase=clampf(1-actor.reload_left/2.15,0,1) if actor.reload_left>0 else 0.0
		var reload_motion=sin(reload_phase*PI)
		weapon.position = Vector3(.025 if aiming else .26,-.27+sway-reload_motion*.25,-.68+fire_feedback*.3)
		weapon.rotation=Vector3(-reload_motion*.4,0,-reload_motion*.32)
		rifle_magazine.position.y=-.16-reload_motion*.23
	elif phase in ["menu","lobby","result"]:
		camera.position = Vector3(-46,37,65)
		camera.look_at(Vector3.ZERO)
	ui.refresh()

func _peer_left(peer: int) -> void:
	if not authority(): return
	lobby.erase(peer)
	if phase=="lobby": broadcast_lobby()
	else:
		var actor = actor_for_peer(peer)
		if actor!=null:
			if actor.vehicle_id>=0: exit_vehicle(actor,true)
			actor.peer_id = 0
			actor.bot = true
			actor.commands = {}

func close_network() -> void:
	joining = false
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func back_to_menu() -> void:
	close_network()
	_clear_match()
	phase = "menu"
	mode = "solo"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.rebuild()

func connection_error(message: String) -> void:
	back_to_menu()
	notice(message)
	toast_time = 9
