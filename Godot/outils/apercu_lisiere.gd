extends SceneTree
## La desserte 178 passée du quai de l'Ilse à la lisière du bois.
func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
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
	var centre: Array = jeu.donnees.meta.centre
	jeu.pivot.viser(Vector2(500840 - centre[0], centre[1] - 5600170), 260.0)
	jeu.pivot.caler(0.0, 60.0)
	var couche := CanvasLayer.new()
	root.add_child(couche)
	for repere in [["1 · Raccord à la rue du faubourg", 500845, 5600290],
			["2 · La route longe le bois", 500905, 5600200],
			["3 · Berge naturelle au bord de l'Ilse", 500760, 5600120],
			["4 · Fin au dernier champ", 500917, 5600055]]:
		var label := Label.new()
		label.text = repere[0]
		label.position = jeu.pivot.camera.unproject_position(Vector3(
			repere[1] - centre[0], 2, centre[1] - repere[2]))
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
	for frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	await jeu._capturer("lisiere_apres")
	quit()
