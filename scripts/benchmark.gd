extends Node
var game: Node3D
var frames: Array[float] = []
var draws: Array[float] = []
var process_times: Array[float] = []
var physics_times: Array[float] = []
var started = 0
var label = "baseline"
var done = false
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bench-label="): label=arg.get_slice("=",1)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	call_deferred("begin")
func begin() -> void:
	var clicked=false
	for child in game.ui.panel.get_children():
		if child is Button and child.text.begins_with("JOGAR SOLO"):
			child.pressed.emit()
			clicked=true
			break
	if not clicked:
		push_error("Solo button not found")
		get_tree().quit(1)
		return
	started=Time.get_ticks_msec()
func _process(dt: float) -> void:
	if started==0 or done: return
	var elapsed=(Time.get_ticks_msec()-started)/1000.0
	if elapsed>5:
		frames.append(dt)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS))
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	if elapsed<35: return
	done=true
	var total=0.0
	var calls=0.0
	for f in frames: total+=f
	for d in draws: calls+=d
	frames.sort()
	var result={"label":label,"frames":frames.size(),"average_fps":frames.size()/total,"p99_frame_ms":frames[int(frames.size()*.99)]*1000,"average_draw_calls":calls/draws.size(),"canvas_size":str(game.get_viewport().get_visible_rect().size),"window_size":str(game.get_window().size),"render_scale":game.get_viewport().scaling_3d_scale,"quality":game.graphics.quality,"process_ms":process_times.reduce(func(a,b): return a+b,0.0)/process_times.size()*1000,"physics_ms":physics_times.reduce(func(a,b): return a+b,0.0)/physics_times.size()*1000,"static_memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576,"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"renderer":"Compatibility","warmup_s":5,"duration_s":elapsed}
	var output="user://diagnostics" if OS.has_feature("template") else "res://docs"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file=FileAccess.open(output+"/benchmark-"+label+".json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(result,"  "))
	print("BENCHMARK ",JSON.stringify(result))
	game.get_viewport().get_texture().get_image().save_png(output+"/benchmark-"+label+".png")
	get_tree().quit()
