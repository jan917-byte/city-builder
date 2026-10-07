extends SceneTree
## Godot --path Godot --script res://outils/apercu_toits.gd -- avant|apres
## Toits pentus du cœur ancien, six cadrages : aucun pan ne doit être vrillé.

func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.mois = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	var args := OS.get_cmdline_user_args()
	var suffixe: String = args[0] if args.size() > 0 else "avant"
	var couche := CanvasLayer.new()
	root.add_child(couche)
	var label := Label.new()
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("213d36"))
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color("f5f5ec")
	fond.content_margin_left = 14
	fond.content_margin_right = 14
	fond.content_margin_top = 8
	fond.content_margin_bottom = 8
	label.add_theme_stylebox_override("normal", fond)
	couche.add_child(label)
	await process_frame
	jeu._rafraichir(true)
	var vues := [
		["1", 15, 30.0, 38.0, 110.0],
		["2", 22, 120.0, 38.0, 110.0],
		["3", 62, 30.0, 38.0, 110.0],
		["4", 66, 210.0, 38.0, 110.0],
		["5", 30, 300.0, 38.0, 130.0],
		["6", 10, 30.0, 38.0, 130.0],
	]
	for vue in vues:
		jeu._viser_objet("i", int(vue[1]), float(vue[4]))
		jeu.pivot.caler(float(vue[2]), float(vue[3]))
		jeu._dernier_peint = -1.0
		jeu._rafraichir(true)
		label.text = "%s · îlot %d · %s" % [vue[0], vue[1], suffixe]
		for frame in 6:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("toits_%s_%s" % [vue[0], suffixe])
	quit()
