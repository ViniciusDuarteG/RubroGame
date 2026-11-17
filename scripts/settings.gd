extends RefCounted
## Defaults favor the measured Celeron N4020 / UHD 600. Persisted locally, never networked.
const PATH = "user://graphics.cfg"
const NAMES = ["LEVE · 960 × 600", "EQUILIBRADO · 1280 × 800", "ALTO · 1440 × 900"]
var quality = 0
var limit = 60
func load_config() -> void:
	var c=ConfigFile.new()
	if c.load(PATH)==OK:
		quality=clampi(int(c.get_value("video","quality",0)),0,2)
		limit=int(c.get_value("video","fps",60))
func save_config() -> void:
	var c=ConfigFile.new()
	c.set_value("video","quality",quality)
	c.set_value("video","fps",limit)
	c.save(PATH)
func apply(game: Node3D) -> void:
	var sizes=[Vector2i(960,600),Vector2i(1280,800),Vector2i(1440,900)]
	game.get_window().content_scale_size=Vector2i(1440,900)
	game.get_window().size=sizes[quality]
	# Render 3D below the HUD resolution on low-end integrated graphics.
	game.get_viewport().scaling_3d_scale=.8 if quality==0 else 1.0
	game.get_viewport().msaa_3d=Viewport.MSAA_DISABLED if quality<2 else Viewport.MSAA_2X
	Engine.max_fps=limit
	if game.world!=null:
		game.world.sun.shadow_enabled=quality>=1
		game.world.baked_shadow.visible=quality==0
		game.world.sun.directional_shadow_max_distance=70 if quality==1 else 110
		game.world.sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
