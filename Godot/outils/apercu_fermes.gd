extends SceneTree
## Les fermes des domaines : une vue de dessus numérotée, un chemin, puis les cinq formes de près.
func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
	var fermes: Array = jeu.donnees["paysage"]["fermes"]["reperes"]
	var couche := CanvasLayer.new()
	root.add_child(couche)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color("f5f5ec")
	fond.content_margin_left = 10
	fond.content_margin_right = 10
	fond.content_margin_top = 4
	fond.content_margin_bottom = 4
	var titre := Label.new()
	titre.position = Vector2(24, 24)
	titre.add_theme_font_size_override("font_size", 24)
	titre.add_theme_color_override("font_color", Color("213d36"))
	titre.add_theme_stylebox_override("normal", fond)
	couche.add_child(titre)
	var numeros: Array[Label] = []
	for f in fermes:
		var n := Label.new()
		n.text = str(f[3]).substr(1)
		n.add_theme_font_size_override("font_size", 22)
		n.add_theme_color_override("font_color", Color("213d36"))
		n.add_theme_stylebox_override("normal", fond)
		couche.add_child(n)
		numeros.append(n)
	# [nom, ferme visée (-1 : toute la campagne), lacet, hauteur, taille, titre, numéros ?]
	var vues := [["dessus", -1, 0.0, 90.0, 1150.0, "Les dix fermes, numérotées comme leur domaine", true],
			["chemins_nord", 6, 0.0, 90.0, 520.0, "Fermes 6 à 10 : chaque chemin rejoint la route la plus proche", true],
			["chemins_sud", 3, 0.0, 90.0, 520.0, "Fermes 1 à 5 : chaque chemin rejoint la route la plus proche", true],
			["6", 5, 35.0, 42.0, 150.0, "Ferme 6 : la cour, et son chemin jusqu'à la route", false]]
	# Une ferme de près pour chacune des cinq formes de `fermes.py`.
	for i in 5:
		vues.append([str(i + 1), i, 150.0, 34.0, 55.0, "Ferme %d" % (i + 1), false])
	for vue in vues:
		var k: int = vue[1]
		var cible := Vector2(-60, -60) if k < 0 else Vector2(fermes[k][0], fermes[k][2])
		jeu.pivot.viser(cible, vue[4])
		jeu.pivot.caler(vue[2], vue[3])
		titre.text = vue[5]
		for frame in 6:
			await process_frame
			await RenderingServer.frame_post_draw
		for i in numeros.size():
			var p := Vector3(fermes[i][0], fermes[i][1] + 14.0, fermes[i][2])
			numeros[i].visible = vue[6] and not jeu.pivot.camera.is_position_behind(p)
			numeros[i].position = jeu.pivot.camera.unproject_position(p) - Vector2(10, 40)
		await process_frame
		await RenderingServer.frame_post_draw
		await jeu._capturer("fermes_" + vue[0])
	print("Fermes : %d cadrages rendus." % vues.size())
	quit()
