extends SceneTree
## Godot --path Godot --script res://outils/apercu_etages.gd -- [--avant] [--liste]
## Façades de près sur les deux rives : chaque étage doit être une rangée
## entière, et aucune rangée ne doit être tranchée par l'égout.

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
	if "--liste" in args:
		# Le pied des murs dit la rive : −1,5 m à gauche, +0,5 m à droite.
		for fid in jeu.noeuds["i"]:
			var mi: MeshInstance3D = jeu.noeuds["i"][fid]
			var ab := mi.get_aabb()
			print("îlot %d · pied %.2f · haut %.2f · centre (%.0f, %.0f)" % [
				fid, ab.position.y, ab.end.y, ab.get_center().x, ab.get_center().z])
		quit()
		return
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
	var suffixe := "avant" if "--avant" in args else "apres"
	await process_frame
	jeu._rafraichir(true)
	# [nom, légende, îlot, lacet, hauteur, taille]
	var vues := [
		["1_rive_gauche", "1 · Rive gauche · îlot 62", 62, 30.0, 14.0, 60.0],
		["2_rive_gauche", "2 · Rive gauche · îlot 66", 66, 210.0, 14.0, 60.0],
		["3_rive_droite", "3 · Rive droite · cœur ancien, îlot 15", 15, 120.0, 14.0, 60.0],
		["4_rive_droite", "4 · Rive droite · îlot compact 49", 49, 30.0, 14.0, 60.0],
		["5_distance", "5 · Vue moyenne · rive gauche et droite", 62, 30.0, 30.0, 220.0],
		["6_loin", "6 · De loin · cœur ancien", 22, 30.0, 32.0, 450.0],
		["7_plus_loin", "7 · Plus loin · cœur ancien", 22, 30.0, 32.0, 700.0],
	]
	for vue in vues:
		jeu._viser_objet("i", int(vue[2]), float(vue[5]))
		jeu.pivot.caler(float(vue[3]), float(vue[4]))
		jeu._dernier_peint = -1.0
		jeu._rafraichir(true)
		label.text = vue[1]
		for frame in 6:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("etages_%s_%s" % [vue[0], suffixe])
	quit()
