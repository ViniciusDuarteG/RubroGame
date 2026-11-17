extends Node3D
## Fixed voice/tracer pools: no per-rifle-shot mesh, timer or audio-node allocation.
const SOUNDS = {"step":preload("res://assets/audio/step.wav"),"shot":preload("res://assets/audio/shot.wav"),"reload":preload("res://assets/audio/reload.wav"),"rocket":preload("res://assets/audio/rocket.wav"),"boom":preload("res://assets/audio/boom.wav"),"capture":preload("res://assets/audio/capture.wav")}
var voices: Array[AudioStreamPlayer3D] = []
var tracers: Array[MeshInstance3D] = []
var lives: Array[float] = []
var voice_cursor = 0
var tracer_cursor = 0
var bullet_mat: StandardMaterial3D
var rocket_mat: StandardMaterial3D
func _ready() -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 20:
		var audio=AudioStreamPlayer3D.new()
		audio.max_distance=65
		audio.unit_size=7
		add_child(audio)
		voices.append(audio)
	bullet_mat=StandardMaterial3D.new()
	bullet_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	bullet_mat.albedo_color=Color("e8cf95")
	rocket_mat=bullet_mat.duplicate()
	rocket_mat.albedo_color=Color("ed8b47")
	var mesh=BoxMesh.new()
	mesh.size=Vector3(.014,.014,1)
	for i in 24:
		var tracer=MeshInstance3D.new()
		tracer.mesh=mesh
		tracer.material_override=bullet_mat
		tracer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tracer.visible=false
		add_child(tracer)
		tracers.append(tracer)
		lives.append(0)
func sound(kind: String, point: Vector3, volume: float) -> void:
	if voices.is_empty() or not SOUNDS.has(kind): return
	var audio=voices[voice_cursor]
	voice_cursor=(voice_cursor+1)%voices.size()
	audio.stop()
	audio.stream=SOUNDS[kind]
	audio.position=point
	audio.volume_db=linear_to_db(maxf(.01,volume))-8
	audio.play()
func shot(origin: Vector3, end: Vector3, rocket: bool) -> void:
	if tracers.is_empty() or origin.distance_squared_to(end)<.01: return
	var tracer=tracers[tracer_cursor]
	tracer.position=(origin+end)/2
	tracer.scale=Vector3.ONE
	tracer.look_at(end)
	tracer.scale.z=origin.distance_to(end)
	tracer.material_override=rocket_mat if rocket else bullet_mat
	tracer.visible=true
	lives[tracer_cursor]=.065
	tracer_cursor=(tracer_cursor+1)%tracers.size()
func _process(dt: float) -> void:
	for i in tracers.size():
		if lives[i]<=0: continue
		lives[i]-=dt
		if lives[i]<=0: tracers[i].visible=false
