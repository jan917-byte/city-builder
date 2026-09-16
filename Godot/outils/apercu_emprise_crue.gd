extends SceneTree
## Vue de contrôle des trois corrections demandées le 2026-09-16.
func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	root.size = Vector2i(1500, 1500)
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	if jeu.ouverture != null:
		jeu.ouverture.hide()
		jeu.ouverture._reperes.hide()
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
	var couche := CanvasLayer.new()
	root.add_child(couche)
	var reperes: Array[Label] = []
	for titre in ["1 · Sud : rivière libre", "2 · Limite du dépôt", "3 · Nord et ouest épargnés"]:
		var label := Label.new()
		label.text = titre
		label.add_theme_font_size_override("font_size", 21)
		label.add_theme_color_override("font_color", Color("20352c"))
		var fond := StyleBoxFlat.new()
		fond.bg_color = Color("f5f5ec")
		fond.content_margin_left = 10
		fond.content_margin_right = 10
		fond.content_margin_top = 6
		fond.content_margin_bottom = 6
		label.add_theme_stylebox_override("normal", fond)
		couche.add_child(label)
		reperes.append(label)
	var centre: Array = jeu.donnees.meta.centre
	var positions := [Vector2(500800, 5600120), Vector2(500745, 5600580), Vector2(500360, 5600900)]
	jeu.pivot.viser(Vector2(500470 - centre[0], centre[1] - 5600530), 660.0)
	jeu.pivot.caler(0.0, 90.0)
	for k in positions.size():
		reperes[k].position = jeu.pivot.camera.unproject_position(Vector3(
			positions[k].x - centre[0], 2, centre[1] - positions[k].y))
	for frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	await jeu._capturer("emprise_crue_apres")
	quit()
