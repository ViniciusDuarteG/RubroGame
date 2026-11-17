extends Node
## Real-engine integration tests. Test setup may place actors; production RPCs remain unchanged.
var game: Node3D
var mode = ""
var wall_start = 0
var stage = 0
var stage_time = 0.0
var report: Dictionary = {}
var finished = false
var client_team = 1
var interact_left = 0.0
var report_tag = ""
var scenario = ""

func _ready() -> void:
	wall_start = Time.get_ticks_msec()
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--team="): client_team=int(arg.get_slice("=",1))
		if arg.begins_with("--tag="): report_tag=arg.get_slice("=",1)
		if arg.begins_with("--scenario="): scenario=arg.get_slice("=",1)
	if "--capture" in args:
		mode="capture"
		call_deferred("capture")
	elif "--test-rules" in args:
		mode="rules"
		call_deferred("rules")
	elif "--test-solo" in args:
		mode="solo"
		Engine.time_scale=8
		Engine.physics_ticks_per_second=240
		call_deferred("solo")
	elif "--test-host" in args:
		mode="host"
		game.host()
		game.select_team(0)
	else:
		mode="client"
		game.join("127.0.0.1")

func check(condition: bool, label: String) -> void:
	print("CHECK ",label," ","PASS" if condition else "FAIL")
	report[label]=condition

func finish() -> void:
	if finished: return
	finished=true
	var ok = true
	for value in report.values():
		if value is bool and not value: ok=false
	report["metrics"]=game.metrics.duplicate()
	report["tickets"]=game.tickets.duplicate()
	report["seconds"]=game.elapsed
	report["ok"]=ok
	var path = "res://docs/test-%s%s.json"%[mode,str(client_team) if mode=="client" else ""]
	if scenario!="": path="res://docs/test-lan-%s-%s.json"%[scenario,report_tag]
	var f = FileAccess.open(path,FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(report,"  "))
	print("TEST_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if ok else 1)

func solo() -> void:
	check(game.phase=="menu","starts_at_menu")
	# Exercise the actual menu button, leaving the human idle at base.
	for c in game.ui.panel.get_children():
		if c is Button and c.text.begins_with("JOGAR SOLO"):
			c.pressed.emit()
	check(game.phase=="match" and game.soldiers.size()==16,"solo_1_human_15_bots")
	var bots=0
	for a in game.soldiers.values():
		if a.bot: bots+=1
	check(bots==15,"bot_count")

func rules() -> void:
	game.start_solo()
	# Stop automatic simulation so rule scenarios are reproducible.
	game.set_physics_process(false)
	for a in game.soldiers.values(): a.position=game.world.BASES[a.team]+Vector3(0,.1,0)
	var a=game.soldiers[1]
	var b=game.soldiers[9]
	a.position=game.world.FLAG_POS[0]
	game.capture_tick(9)
	check(game.flags[0].owner==0,"capture_neutral")
	b.position=a.position+Vector3(1,0,0)
	game.flags[0].progress=.4
	game.capture_tick(1)
	check(game.flags[0].contested and is_equal_approx(game.flags[0].progress,.4),"contested_pauses")
	a.position=game.world.BASES[0]
	game.capture_tick(20)
	game.capture_tick(20)
	game.capture_tick(20)
	check(game.flags[0].owner==1,"enemy_neutralize_recapture")
	a.dead=true; a.respawn_left=0
	game.spawn_soldier(a,2,0)
	check(a.position.distance_to(game.world.BASES[0])<5 and a.role==2,"lost_spawn_falls_back")
	a.hp=30; a.role=1; a.ability_cooldown=0
	a.support()
	check(a.hp>30,"medic_heals")
	var jeep=game.vehicles[0]
	jeep.hp=100; a.role=2; a.ability_cooldown=0; a.position=jeep.position
	a.support()
	check(jeep.hp>100,"engineer_repairs")
	game._interact(1)
	check(a.vehicle_id==0 and jeep.seats[0]==a.id,"driver_entry")
	var passenger=game.soldiers[2]
	passenger.peer_id=22; passenger.bot=false; passenger.position=jeep.position+Vector3(2,0,0)
	game._interact(22)
	check(passenger.vehicle_id==0 and passenger.seat==1,"passenger_entry")
	game.exit_vehicle(passenger,true)
	passenger.peer_id=0; passenger.bot=true; passenger.position=game.world.BASES[0]
	game.exit_vehicle(a)
	check(a.vehicle_id<0 and jeep.seats[0]<0,"safe_exit")
	jeep.position=Vector3(-20,.1,0); a.position=jeep.position
	game._interact(1)
	var before=game.tickets[0]
	b.role=2; b.rocket_selected=true; b.cooldown=0
	b.position=Vector3(-10,.1,0); b.yaw=PI/2; b.pitch=-.04
	jeep.hp=350
	await get_tree().physics_frame
	await get_tree().physics_frame
	b.fire()
	check(jeep.hp<350 and b.rocket_ammo==2,"engineer_rocket_hits_vehicle")
	jeep.take_damage(500,1,9)
	check(jeep.hp==0 and a.dead and game.tickets[0]==before-1,"jeep_destroy_kills_occupant_once")
	jeep.server_tick(game.jeep_respawn_delay+1)
	check(jeep.hp==350 and jeep.position==jeep.home,"jeep_base_respawn")
	a.respawn_left=0; game.spawn_soldier(a,0,-1)
	a.position=Vector3(-15,.1,0)
	a.ammo=0; a.reserve=17; a.start_reload(); a.server_tick(3)
	check(a.ammo==17 and a.reserve==0,"reload_conserves_ammo")
	a.position=game.world.BASES[0]
	a.commands={"prone":true}
	a.server_tick(.033)
	check(a.prone and a.eye_height()<.7 and a.hit_shape.shape.height<1,"prone_stance")
	a.commands={"move":Vector2(0,-1),"sprint":true}
	a.last_input_time=game.elapsed
	a.server_tick(.1)
	check(a.stamina<100,"sprint_uses_stamina")
	a.commands={}; a.server_tick(.1)
	check(not a.prone and not a.crouch,"stance_restores")
	a.position=game.world.BASES[0]
	a.hp=100; a.take_damage(50,1,9)
	check(a.hp==100,"protected_base")
	game.flags[0].owner=0; game.flags[1].owner=0; game.flags[2].owner=1
	var tickets=game.tickets[1]
	game.capture_tick(game.bleed_interval)
	check(game.tickets[1]<tickets,"majority_bleeds")
	game.tickets[1]=0; game.check_victory()
	check(game.phase=="result" and game.winner==0,"result_screen")
	game.rematch()
	check(game.phase=="match" and game.tickets==[100,100],"rematch_resets")
	game.back_to_menu()
	check(game.phase=="menu" and game.soldiers.is_empty(),"return_menu")
	finish()

func input_for_local(original: Dictionary) -> Dictionary:
	if mode=="solo" or mode=="rules": return {}
	if mode=="client" and stage>=2:
		if stage_time<3: return {"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0}
		if stage_time<5: return {"move":Vector2.ZERO,"prone":true,"yaw":0.0,"pitch":0.0}
		if stage_time<6: return {"move":Vector2(0,-1),"sprint":true,"yaw":0.0,"pitch":0.0}
		return {"move":Vector2(0,-1) if game.soldiers[game.local_actor].vehicle_id>=0 else Vector2.ZERO,"yaw":0.0,"pitch":0.0}
	return original

func _process(dt: float) -> void:
	if finished: return
	stage_time+=dt
	interact_left-=dt
	if mode=="solo":
		if game.phase=="result":
			check(game.metrics.captures>=3,"bots_capture")
			check(game.metrics.recaptures>=1,"bots_recapture")
			check(game.metrics.deaths>0,"bots_combat")
			check(game.tickets.has(0),"idle_human_match_finishes")
			finish()
		elif game.elapsed>1200 or Time.get_ticks_msec()-wall_start>180000:
			check(false,"solo_timeout")
			for a in game.soldiers.values(): print("ACTOR ",a.id," ",a.position," objective ",a.objective," hp ",a.hp)
			finish()
	elif mode=="host": host_process()
	elif mode=="client": client_process()
	if mode in ["host","client"] and Time.get_ticks_msec()-wall_start>90000:
		check(false,"network_timeout")
		finish()

func host_process() -> void:
	if stage==0 and game.lobby.size()>=3 and game.can_start():
		game.start_match(); stage=1; stage_time=0
		check(game.soldiers.size()==16,"lan_16_slots")
		var humans=0
		for a in game.soldiers.values():
			if not a.bot: humans+=1
		check(humans==3,"host_plus_two_human_slots")
		for a in game.soldiers.values():
			if a.bot: a.dead=true; a.respawn_left=90
	elif stage==1 and stage_time>8:
		# Keep bots away while exercising remote-client capture.
		for a in game.soldiers.values():
			if a.bot: a.dead=true; a.respawn_left=90
		var remote=remote_actor(1)
		remote.position=game.world.FLAG_POS[0]
		game.flags[0]={"owner":-1,"progress":0.0,"capturing":-1,"contested":false}
		stage=2; stage_time=0
	elif stage==2 and stage_time>16:
		check(game.flags[0].owner==1,"remote_client_captures")
		var a=remote_actor(1)
		a.die(1); a.respawn_left=0
		stage=3; stage_time=0
	elif stage==3 and stage_time>4:
		var a=remote_actor(1)
		check(not a.dead,"remote_respawn_request")
		var jeep=game.vehicles[1]
		jeep.position=Vector3(25,.1,0)
		a.position=jeep.position+Vector3(2,0,0)
		stage=4; stage_time=0
	elif stage==4 and stage_time>4:
		var a=remote_actor(1)
		check(a.vehicle_id==1,"remote_jeep_entry")
		check(game.vehicles[1].position.distance_to(Vector3(25,.1,0))>2,"remote_driver_moves_jeep")
		game.vehicles[1].take_damage(500,0,1)
		stage=5; stage_time=0
	elif stage==5 and stage_time>4:
		check(game.vehicles[1].hp<=0,"authoritative_jeep_destroyed")
		stage=6; stage_time=0
	elif stage==6 and stage_time>3:
		game.tickets[1]=0; game.check_victory()
		stage=7; stage_time=0
	elif stage==7 and stage_time>3: finish()

func remote_actor(team: int):
	for a in game.soldiers.values():
		if not a.bot and a.peer_id!=1 and a.team==team: return a
	return null

func client_process() -> void:
	if stage==0 and game.phase=="lobby":
		game.select_team(client_team)
		stage=1
	elif stage==1 and game.phase=="match":
		check(game.local_actor>0,"ip_join_and_roster")
		check(game.soldiers[game.local_actor].team==client_team,"chosen_team")
		stage_time=0
		stage=2
	elif stage>=2 and game.phase=="match":
		var a=game.soldiers[game.local_actor]
		if a.prone: report["prone_synced"]=true
		if a.stamina<99: report["stamina_synced"]=true
		if a.dead and a.respawn_left<=0:
			game.respawn(2,-1)
		if interact_left<=0 and a.team==1 and a.vehicle_id<0 and not a.dead and game.vehicles[1].position.distance_to(a.position)<4.5:
			game.interact()
			interact_left=1
		if game.flags[0].owner==1: report["capture_synced"]=true
		if game.vehicles[1].hp<=0: report["jeep_destruction_synced"]=true
	elif game.phase=="result" and stage<100:
		stage=100
		check(report.get("capture_synced",false),"capture_replication")
		check(report.get("jeep_destruction_synced",false),"vehicle_replication")
		check(game.winner==0,"result_replication")
		check(report.get("prone_synced",false),"prone_replication")
		check(report.get("stamina_synced",false),"stamina_replication")
		await get_tree().create_timer(.5).timeout
		finish()

func capture() -> void:
	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/menu.png")
	game.start_solo()
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/gameplay.png")
	game.set_physics_process(false)
	game.set_process(false)
	game.ui.visible=false
	game.weapon.visible=false
	var model=game.soldiers[2]
	game.camera.position=model.position+Vector3(2.2,1.6,-2.8)
	game.camera.look_at(model.position+Vector3(0,1,0))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/equipment.png")
	game.set_physics_process(true)
	game.set_process(true)
	game.ui.visible=true
	game.soldiers[game.local_actor].die()
	await get_tree().create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/deployment.png")
	game.camera.position=Vector3(-5,90,65)
	game.camera.look_at(Vector3.ZERO)
	game.set_process(false)
	game.ui.visible=false
	game.weapon.visible=false
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/vale-seco.png")
	get_tree().quit()
