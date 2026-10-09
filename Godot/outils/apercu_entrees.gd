extends SceneTree
## Godot --path Godot --script res://outils/apercu_entrees.gd
## 🚪 Les entrées en retrait (2026-10-09) : allée de la porte au trottoir,
## seuil, auvent, porte vitrée de la barre.

func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.mois = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
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
	# [nom, légende, îlot, lacet, hauteur, taille]
	var vues := [
		["1_pavillons", "1 · Pavillons · îlot 26", 26, 300.0, 35.0, 45.0],
		["2_maisons", "2 · Maisons de ville · îlot 40", 40, 300.0, 35.0, 45.0],
		["3_collectifs", "3 · Collectifs de 1995 · îlot 30", 30, 30.0, 35.0, 70.0],
		["4_barre", "4 · Barre de 1970 · îlot 32", 32, 210.0, 30.0, 70.0],
	]
	for vue in vues:
		await _vue(jeu, label, vue)
	quit()

func _vue(jeu, label: Label, vue: Array) -> void:
	jeu._viser_objet("i", int(vue[2]), float(vue[5]))
	jeu.pivot.caler(float(vue[3]), float(vue[4]))
	jeu.trafic.regler_detail(jeu.pivot.taille)
	jeu._dernier_peint = -1.0
	jeu._rafraichir(true)
	label.text = vue[1]
	for frame in 6:
		await process_frame
		await RenderingServer.frame_post_draw
	await jeu._capturer("entrees_%s" % vue[0])
