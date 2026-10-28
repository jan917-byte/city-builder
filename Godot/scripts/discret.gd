extends Node
## 🫥 Lancé par `outils/discret.sh` (DESIRE_PATH_DISCRET=1) : fenêtre hors écran, transparente à la
## souris. ⚠️ Hors écran, macOS la dit occultée et Godot cesse de dessiner : on force le rendu.


func _ready() -> void:
	if OS.get_environment("DESIRE_PATH_DISCRET") != "1" or DisplayServer.get_name() == "headless":
		queue_free()
		return
	process_mode = PROCESS_MODE_ALWAYS
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, true)
	DisplayServer.window_set_position(Vector2i(-20000, -20000))
	# Le lanceur crée une fenêtre de 1 px (pas d'éclair à l'écran) : on remet la taille du projet.
	DisplayServer.window_set_size(Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")))


func _process(_delta: float) -> void:
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)
