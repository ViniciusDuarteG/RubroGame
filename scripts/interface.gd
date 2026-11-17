extends CanvasLayer
## Original visual system: charcoal, parchment, signal red, monospaced field labels.
const RED = Color("ef493c")
const PAPER = Color("e3e1ce")
const MUTED = Color("9ba79c")
const DARK = Color("121b1e")
var game: Node3D
var root: Control
var deploy_buttons: Control
var panel: VBoxContainer
var ip: LineEdit
var selected_class = 0
var spawn_point = -1
var selected_team = 0
var screen_mode = ""
var info: Label
var spawn_button: Button
var draw_layer: Control
var font = ThemeDB.fallback_font
var hud_time = 0.0
var show_fps = true
var emblem = preload("res://assets/branding/icon.svg")

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	draw_layer = Control.new()
	draw_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(draw_layer)
	draw_layer.draw.connect(_draw)
	rebuild()

func style(color: Color, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left=18; s.content_margin_right=18
	s.content_margin_top=12; s.content_margin_bottom=12
	return s

func text(value: String, size := 18, color := PAPER) -> Label:
	var l = Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	panel.add_child(l)
	return l

func button(value: String, callback: Callable, primary := false) -> Button:
	var b = Button.new()
	b.text = value
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(405,48)
	b.add_theme_font_size_override("font_size",18)
	b.add_theme_color_override("font_color",PAPER)
	b.add_theme_stylebox_override("normal",style(RED.darkened(.15) if primary else Color("283330"),RED if primary else Color("485349")))
	b.add_theme_stylebox_override("hover",style(Color("5b5546"),PAPER))
	b.add_theme_stylebox_override("pressed",style(RED))
	b.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,PAPER))
	b.pressed.connect(callback)
	panel.add_child(b)
	return b

func gap(height := 12) -> void:
	var c = Control.new()
	c.custom_minimum_size.y = height
	panel.add_child(c)

func rebuild() -> void:
	if root==null: return
	if deploy_buttons!=null:
		root.remove_child(deploy_buttons)
		deploy_buttons.queue_free()
		deploy_buttons=null
	if panel!=null:
		root.remove_child(panel)
		panel.queue_free()
	panel = VBoxContainer.new()
	panel.position = Vector2(68,70)
	panel.size.x = 430
	panel.add_theme_constant_override("separation",9)
	root.add_child(panel)
	screen_mode = game.phase
	if game.phase=="match":
		var actor = game.soldiers.get(game.local_actor)
		if actor!=null and actor.dead:
			screen_mode = "spawn"
			spawn_menu(actor)
		elif game.paused_input:
			screen_mode = "pause"
			text("RUBRO",52,RED)
			text("OPERAÇÃO EM ANDAMENTO",18)
			gap()
			button("CONTINUAR",func(): game.paused_input=false; Input.mouse_mode=Input.MOUSE_MODE_CAPTURED; rebuild(),true)
			text("A partida continua enquanto o menu está aberto.",14,MUTED)
			button("GRÁFICOS: "+game.graphics.NAMES[game.graphics.quality],cycle_graphics)
			button("VOLTAR AO MENU",game.back_to_menu)
		else: panel.visible=false
	elif game.phase=="menu": menu()
	elif game.phase=="lobby": lobby()
	elif game.phase=="result": result()
	draw_layer.queue_redraw()

func menu() -> void:
	text("ESTÚDIO DE CAMPO   /   001",14,MUTED)
	text("RUBRO",84,RED)
	text("L I N H A   D E   R U P T U R A",18)
	gap(8)
	text("CONQUISTA  /  VALE SECO",24)
	text("16 combatentes. Três posições. Uma linha a romper.",15,MUTED)
	gap(10)
	var teams = OptionButton.new()
	teams.add_item("01  BRASA · vermelho")
	teams.add_item("02  NÉVOA · azul")
	teams.selected = selected_team
	teams.custom_minimum_size.y=42
	teams.item_selected.connect(func(i): selected_team=i)
	panel.add_child(teams)
	button("GRÁFICOS: "+game.graphics.NAMES[game.graphics.quality],cycle_graphics)
	var bleed = SpinBox.new()
	bleed.min_value=1; bleed.max_value=20; bleed.step=1; bleed.value=game.bleed_interval
	bleed.prefix="Intervalo de sangria: "; bleed.suffix=" s"
	bleed.value_changed.connect(func(v): game.bleed_interval=v)
	panel.add_child(bleed)
	button("JOGAR SOLO  →",func(): game.start_solo(selected_team),true)
	text("Offline · você + 15 bots · 100 tickets por time",14,MUTED)
	gap(12)
	button("HOSPEDAR LAN",game.host)
	var row = HBoxContainer.new()
	panel.add_child(row)
	ip = LineEdit.new()
	ip.placeholder_text = "IP do host · ex.: 192.168.1.10"
	ip.text = "127.0.0.1"
	ip.custom_minimum_size = Vector2(290,44)
	row.add_child(ip)
	var join = Button.new()
	join.text = "ENTRAR"
	join.custom_minimum_size = Vector2(109,44)
	join.pressed.connect(func(): game.join(ip.text))
	row.add_child(join)
	gap(4)
	text("WASD mover  /  mouse mirar e atirar  /  E jipe",14,MUTED)
	text("R recarga  /  Q suporte  /  Esc menu",14,MUTED)
	button("SAIR",func(): game.get_tree().quit())

func lobby() -> void:
	text("RUBRO / LAN",46,RED)
	text("ESCOLHA SUA UNIDADE",23)
	text("Até oito humanos por time; bots ocupam as vagas.",14,MUTED)
	button("01  BRASA",func(): game.select_team(0),true)
	button("02  NÉVOA",func(): game.select_team(1))
	gap()
	for p in game.lobby:
		var data: Dictionary = game.lobby[p]
		var team_name = "ESCOLHENDO" if data.team<0 else ("BRASA" if data.team==0 else "NÉVOA")
		text("%s%s  /  %s"%[data.name," · você" if p==game.my_peer() else "",team_name],16)
	gap()
	if game.authority():
		text("SANGRIA DE TICKETS / INTERVALO",14,MUTED)
		var bleed = SpinBox.new()
		bleed.min_value=1; bleed.max_value=20; bleed.step=1; bleed.value=game.bleed_interval
		bleed.suffix=" s"
		bleed.value_changed.connect(func(v): game.bleed_interval=v)
		panel.add_child(bleed)
		var start = button("INICIAR OPERAÇÃO  →",game.start_match,true)
		start.disabled = not game.can_start()
		text("Seu IP: "+local_addresses(),14,MUTED)
	else: text("Aguardando o host iniciar a operação…",16,MUTED)
	text("UDP 28745 · mesma rede local",14,MUTED)
	button("VOLTAR AO MENU",game.back_to_menu)

func local_addresses() -> String:
	var addresses = []
	for addr in IP.get_local_addresses():
		if "." in addr and not addr.begins_with("127."): addresses.append(addr)
	return ", ".join(addresses)

func spawn_menu(actor: Node3D) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	text("FORA DE COMBATE",37,RED)
	text("ESCOLHA CLASSE E INSERÇÃO",18)
	var class_group=ButtonGroup.new()
	for i in 3:
		var names=["01 / ASSALTO · RIFLE","02 / MÉDICO · CURA + RIFLE","03 / ENGENHEIRO · REPARO + AT"]
		var choice=button(names[i],func(): selected_class=i)
		choice.toggle_mode=true
		choice.button_group=class_group
		choice.set_pressed_no_signal(selected_class==i)
	var points = OptionButton.new()
	points.add_item("BASE PROTEGIDA",0)
	for i in game.flags.size():
		if game.spawn_allowed(i,actor.team): points.add_item(game.world.FLAG_NAMES[i],i+1)
	if spawn_point>=0 and not game.spawn_allowed(spawn_point,actor.team): spawn_point=-1
	for j in points.item_count:
		if points.get_item_id(j)==spawn_point+1: points.select(j)
	points.custom_minimum_size.y=44
	points.item_selected.connect(func(i): spawn_point=points.get_item_id(i)-1)
	panel.add_child(points)
	text("Se a posição for perdida, a inserção usa a base.",14,MUTED)
	info = text("",20)
	spawn_button = button("RENASCER  →",func(): game.respawn(selected_class,spawn_point),true)
	make_deploy_buttons(actor,points)
	button("ATUALIZAR PONTOS",rebuild)
	button("VOLTAR AO MENU",game.back_to_menu)

func result() -> void:
	text("OPERAÇÃO ENCERRADA",18,MUTED)
	text("BRASA" if game.winner==0 else "NÉVOA",70,game.world.TEAM_COLORS[game.winner])
	text("VITÓRIA POR ESGOTAMENTO",23)
	gap()
	text("TICKETS   %03d  /  %03d"%game.tickets,28)
	text("%d capturas · %d retomadas · %d baixas"%[game.metrics.captures,game.metrics.recaptures,game.metrics.deaths],16,MUTED)
	gap()
	if game.authority(): button("REVANCHE  →",game.rematch,true)
	else: text("O host pode iniciar a revanche.",16,MUTED)
	button("VOLTAR AO MENU",game.back_to_menu)

func refresh() -> void:
	if root==null: return
	if game.phase=="match":
		var actor = game.soldiers.get(game.local_actor)
		var desired = "spawn" if actor!=null and actor.dead else ("pause" if game.paused_input else "match")
		if screen_mode!=desired:
			rebuild()
			if desired=="match": Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		if desired=="spawn" and is_instance_valid(info):
			info.text = "INSERÇÃO EM %.1f s"%actor.respawn_left if actor.respawn_left>0 else "PRONTO PARA INSERÇÃO"
			spawn_button.disabled = actor.respawn_left>0
	hud_time+=get_process_delta_time()
	if hud_time>=.033:
		hud_time=0
		draw_layer.queue_redraw()

func rect(pos: Vector2, size: Vector2, color: Color) -> void:
	draw_layer.draw_rect(Rect2(pos,size),color)

func line(value: String, pos: Vector2, size := 18, color := PAPER) -> void:
	draw_layer.draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw() -> void:
	var size = root.size
	if size.x<10: size = Vector2(1440,900)
	var w = size.x
	var h = size.y
	if game.phase!="match" or screen_mode in ["spawn","pause"]:
		rect(Vector2.ZERO,Vector2(550,h),Color(.045,.07,.075,.96))
		rect(Vector2(550,0),Vector2(3,h),RED)
		for i in 14:
			draw_layer.draw_line(Vector2(570+i*70,0),Vector2(800+i*70,h),Color(1,1,1,.035),1)
		if game.phase!="match":
			line("VALE SECO",Vector2(w-330,h-100),38)
			line("22° S  /  056° O    •    SETOR 04",Vector2(w-330,h-70),15,MUTED)
		line("CONQUISTA  /  PROTÓTIPO 0.1",Vector2(68,h-26),13,MUTED)
	if game.phase=="menu": draw_layer.draw_texture_rect(emblem,Rect2(437,76,62,62),false)
	if game.phase=="match": draw_hud(w,h)
	if game.toast_time>0:
		var length = minf(w-40,maxf(450,font.get_string_size(game.toast,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+40))
		rect(Vector2((w-length)/2,h-100),Vector2(length,42),Color(.04,.06,.065,.9))
		line(game.toast,Vector2((w-length)/2+20,h-73),17)

func draw_hud(w: float, h: float) -> void:
	var actor=game.soldiers.get(game.local_actor)
	var ink=Color("c9d6b4")
	if show_fps: line("%d FPS  /  %s"%[Engine.get_frames_per_second(),["LEVE","MÉDIO","ALTO"][game.graphics.quality]],Vector2(24,h-15),12,MUTED)
	# Compact, translucent field telemetry; radar follows the classic upper-right layout.
	for team in 2:
		var p=Vector2(w-450,30+team*35)
		rect(p-Vector2(8,20),Vector2(172,31),Color(.045,.075,.06,.8))
		line("BRASA" if team==0 else "NÉVOA",p,15,game.world.TEAM_COLORS[team])
		line("%03d"%game.tickets[team],p+Vector2(105,0),21,game.world.TEAM_COLORS[team])
	for i in game.flags.size():
		var f: Dictionary=game.flags[i]
		var color=PAPER if f.owner<0 else game.world.TEAM_COLORS[f.owner]
		line(("! " if f.contested else "  ")+game.world.FLAG_NAMES[i],Vector2(w-456,120+i*25),13,color)
	if actor==null: return
	if screen_mode!="spawn": classic_radar(actor,Vector2(w-143,155))
	var feed_y=30
	for message in game.feed:
		line(message,Vector2(24,feed_y),13,ink)
		feed_y+=20
	if actor.dead:
		draw_deployment_map(actor,w,h)
		return
	if screen_mode!="match": return
	var center=Vector2(w/2,h/2)
	var gap=5+actor.aim_kick*120+minf(8,actor.velocity.length())
	var c=Color("c1d3a8")
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		draw_layer.draw_line(center+direction*gap,center+direction*(gap+8),c,1.5)
	for ally in game.soldiers.values():
		if ally.id==actor.id or ally.dead or ally.team!=actor.team or ally.position.distance_squared_to(actor.position)>2500: continue
		var head=ally.position+Vector3(0,2.2,0)
		if not game.camera.is_position_behind(head):
			var point=game.camera.unproject_position(head)
			draw_layer.draw_circle(point,2.3,game.world.TEAM_COLORS[ally.team])
	for i in game.flags.size():
		if actor.position.distance_squared_to(game.world.FLAG_POS[i])>64: continue
		var f: Dictionary=game.flags[i]
		var cp=center+Vector2(0,102)
		draw_layer.draw_arc(cp,27,0,TAU,36,Color(.1,.14,.1,.7),6)
		draw_layer.draw_arc(cp,27,-PI/2,-PI/2+maxf(.001,f.progress)*TAU,36,RED,4)
		line(["A","B","C"][i],cp+Vector2(-8,7),23,ink)
		var title="DISPUTADA" if f.contested else ("ALIADA" if f.owner==actor.team else "NEUTRALIZANDO" if f.owner>=0 else "CAPTURANDO")
		line(title,cp+Vector2(-70,52),14,ink)
		break
	# Health, magazine and stamina at the lower right, away from squad status.
	var pos=Vector2(w-332,h-136)
	rect(pos,Vector2(302,108),Color(.045,.075,.06,.8))
	line(actor.CLASSES[actor.role]+(" / DEITADO" if actor.prone else " / AGACHADO" if actor.crouch else ""),pos+Vector2(14,23),13,ink)
	line("+ %03d"%int(actor.hp),pos+Vector2(14,61),27,ink if actor.hp>30 else RED)
	line("%02d"%(actor.rocket_ammo if actor.rocket_selected else actor.ammo),pos+Vector2(166,60),34,PAPER)
	line("/ %03d"%(0 if actor.rocket_selected else actor.reserve),pos+Vector2(220,59),18,ink)
	line("RECARREGANDO" if actor.reload_left>0 else "ANTIVEÍCULO" if actor.rocket_selected else "RIFLE 5,56 / AUTO",pos+Vector2(14,82),12,ink)
	rect(pos+Vector2(14,94),Vector2(272,4),Color("303d2e"))
	rect(pos+Vector2(14,94),Vector2(272*actor.stamina/100,4),Color("a7b578"))
	# Read-only team roster, echoing the tactical infantry presentation of the period.
	var y=h-205
	line("EQUIPE / "+("BRASA" if actor.team==0 else "NÉVOA"),Vector2(24,y),14,ink)
	y+=22
	for ally in game.soldiers.values():
		if ally.team!=actor.team or ally.id==actor.id: continue
		line(("× " if ally.dead else "+ ")+"%s %02d"%["Soldado" if ally.bot else "Operador",ally.id],Vector2(24,y),13,MUTED if ally.dead else ink)
		y+=19
	var hint="Z deitar · Espaço saltar · Shift correr · E jipe · Esc menu"
	if actor.vehicle_id>=0:
		var jeep=game.vehicles[actor.vehicle_id]
		hint="%s / JIPE %d%% / %.0f km/h / E sair"%["MOTORISTA" if actor.seat==0 else "PASSAGEIRO",jeep.hp/350*100,absf(jeep.speed)*3.6]
	else:
		for jeep in game.vehicles.values():
			if jeep.hp>0 and jeep.team==actor.team and actor.position.distance_to(jeep.position)<4.5: hint="E ENTRAR / MOTORISTA OU PASSAGEIRO"
	line(hint,Vector2(w/2-210,h-28),12,ink)
	if actor.position.distance_to(game.world.BASES[actor.team])<13: line("BASE PROTEGIDA / REABASTECIMENTO",Vector2(w/2-155,30),12,ink)
	if Input.is_physical_key_pressed(KEY_TAB): draw_scoreboard(w,h)

func classic_radar(actor: Node3D, center: Vector2) -> void:
	var ink=Color("b7c8a4")
	draw_layer.draw_circle(center,110,Color(.045,.075,.06,.86))
	draw_layer.draw_arc(center,111,0,TAU,64,ink,1.5)
	draw_layer.draw_arc(center,105,0,TAU,64,Color(.4,.5,.3,.5),1)
	line("N",center+Vector2(-5,-115),13,ink)
	for k in 16:
		var angle=k*TAU/16
		var d=Vector2(cos(angle),sin(angle))
		draw_layer.draw_line(center+d*105,center+d*(99 if k%4==0 else 102),ink,1)
	draw_layer.draw_line(center-Vector2(102,0),center+Vector2(102,0),Color("5c6854"),8)
	var origin=center-Vector2(103.5,87)
	for i in game.flags.size():
		var p=map_point(game.world.FLAG_POS[i],origin)
		var owner: int=game.flags[i].owner
		draw_layer.draw_circle(p,5,PAPER if owner<0 else game.world.TEAM_COLORS[owner])
		line(["A","B","C"][i],p+Vector2(7,4),12,ink)
	for a in game.soldiers.values():
		if a.dead or a.team!=actor.team: continue
		var p=map_point(a.position,origin)
		if p.distance_to(center)<100: draw_layer.draw_circle(p,3,PAPER if a.id==actor.id else game.world.TEAM_COLORS[a.team])
	var p=map_point(actor.position,origin)
	if p.distance_to(center)<100: draw_layer.draw_line(p,p+Vector2(-sin(game.local_yaw),-cos(game.local_yaw))*12,PAPER,2)
	for jeep in game.vehicles.values():
		if jeep.hp>0: rect(map_point(jeep.position,origin)-Vector2(3,3),Vector2(6,6),game.world.TEAM_COLORS[jeep.team])

func draw_deployment_map(actor: Node3D, w: float, h: float) -> void:
	var pos=Vector2(590,210)
	var dimensions=Vector2(maxf(400,w-640),h-310)
	rect(pos-Vector2(16,40),dimensions+Vector2(32,70),Color(.045,.075,.06,.94))
	line("VALE SECO / INSERÇÃO TÁTICA",pos-Vector2(0,14),19,Color("b7c8a4"))
	for k in 9:
		var x=dimensions.x*k/8
		draw_layer.draw_line(pos+Vector2(x,0),pos+Vector2(x,dimensions.y),Color(.5,.6,.4,.15),1)
	for k in 7:
		var y=dimensions.y*k/6
		draw_layer.draw_line(pos+Vector2(0,y),pos+Vector2(dimensions.x,y),Color(.5,.6,.4,.15),1)
	rect(pos+Vector2(0,dimensions.y*.46),Vector2(dimensions.x,dimensions.y*.08),Color("495340"))
	for item in game.world.static_shapes:
		var p: Vector3=item.p
		var s: Vector3=item.s
		if s.x>30 or s.z>30: continue
		var point=pos+Vector2((p.x+74)/148,(p.z+58)/116)*dimensions
		rect(point-Vector2(s.x/148,s.z/116)*dimensions/2,Vector2(s.x/148,s.z/116)*dimensions,Color("616b51"))
	for ally in game.soldiers.values():
		if ally.dead or ally.team!=actor.team: continue
		var p=pos+Vector2((ally.position.x+74)/148,(ally.position.z+58)/116)*dimensions
		draw_layer.draw_circle(p,3,game.world.TEAM_COLORS[ally.team])
	for i in 3:
		var p=game.world.FLAG_POS[i]
		var point=pos+Vector2((p.x+74)/148,(p.z+58)/116)*dimensions
		var owner: int=game.flags[i].owner
		draw_layer.draw_circle(point,13,PAPER if owner<0 else game.world.TEAM_COLORS[owner])
		line(["A","B","C"][i],point+Vector2(-6,6),18,DARK)
	line("Selecione uma posição aliada no mapa ou use a base.",pos+Vector2(0,dimensions.y+25),14,MUTED)

func map_point(p: Vector3, origin: Vector2) -> Vector2:
	return origin+Vector2((p.x+74)/148*207,(p.z+58)/116*174)

func draw_scoreboard(w: float, _h: float) -> void:
	rect(Vector2(w/2-320,150),Vector2(640,550),Color(.035,.05,.055,.97))
	line("EFETIVO / BAIXAS / MORTES",Vector2(w/2-295,185),22,RED)
	var y = 220
	for a in game.soldiers.values():
		line("%02d  %s  %s"%[a.id,"BOT" if a.bot else "HUMANO","BRASA" if a.team==0 else "NÉVOA"],Vector2(w/2-295,y),17,game.world.TEAM_COLORS[a.team])
		line("%02d       %02d"%[a.kills,a.deaths],Vector2(w/2+150,y),17)
		y += 28

func cycle_graphics() -> void:
	game.graphics.quality=(game.graphics.quality+1)%3
	game.graphics.apply(game)
	game.graphics.save_config()
	rebuild()

func make_deploy_buttons(actor: Node3D, points: OptionButton) -> void:
	deploy_buttons=Control.new()
	deploy_buttons.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(deploy_buttons)
	var dimensions=Vector2(maxf(400,root.size.x-640),root.size.y-310)
	for index in [-1,0,1,2]:
		var location: Vector3=game.world.BASES[actor.team] if index<0 else game.world.FLAG_POS[index]
		var p=Vector2(590,210)+Vector2((location.x+74)/148,(location.z+58)/116)*dimensions
		var b=Button.new()
		b.text="BASE" if index<0 else ["A","B","C"][index]
		b.disabled=index>=0 and not game.spawn_allowed(index,actor.team)
		b.position=p-Vector2(31,17)
		b.size=Vector2(62,34)
		b.disabled=index>=0 and not game.spawn_allowed(index,actor.team)
		b.add_theme_stylebox_override("normal",style(Color("43523d"),game.world.TEAM_COLORS[actor.team]))
		b.pressed.connect(func():
			spawn_point=index
			for option in points.item_count:
				if points.get_item_id(option)==index+1: points.select(option))
		deploy_buttons.add_child(b)
