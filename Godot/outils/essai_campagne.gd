extends SceneTree
## Contrôle rendu des parcelles, du clic et des transitions entre fiches.
func _initialize() -> void:
	call_deferred("verifier")

func verifier() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	var rural: Dictionary = jeu.donnees.paysage.campagne
	assert(rural.objets.size() > 50)
	assert(rural.sorties.size() >= 3)
	assert(jeu.noeuds.a.size() == rural.objets.size())
	jeu.pivot.viser(Vector2.ZERO, 2900.0)
	jeu.pivot.caler(0.0, 90.0)
	for k in 5:
		await process_frame
	await physics_frame
	var fermes := 0
	var ferme_id := -1
	for f in rural.objets:
		var o: Dictionary = rural.objets[f]
		var p := Vector3(o.point[0], o.point[1], o.point[2])
		var clic: Array = jeu.selection.sonder(jeu.pivot.camera.unproject_position(p))
		if clic != ["a", int(f)]:
			push_error("Parcelle %s : clic %s" % [f, clic])
			quit(1)
			return
		if o.ferme:
			fermes += 1
			ferme_id = int(f)
	assert(fermes >= 3)
	var couche := CanvasLayer.new()
	root.add_child(couche)
	var label := Label.new()
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_color", Color("213d36"))
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color("f5f5ec")
	fond.content_margin_left = 14
	fond.content_margin_right = 14
	fond.content_margin_top = 8
	fond.content_margin_bottom = 8
	label.add_theme_stylebox_override("normal", fond)
	couche.add_child(label)
	for vue in [["ensemble", 30.0, 42.0, 1650.0, "1 · Champs et fermes autour de Wehrau"],
		["dessus", 0.0, 90.0, 2450.0, "2 · Parcelles, routes et méandres"],
		["montagnes", 210.0, 30.0, 2500.0, "3 · Les routes continuent dans la vallée"]]:
		jeu.pivot.viser(Vector2.ZERO, vue[3])
		jeu.pivot.caler(vue[1], vue[2])
		label.text = vue[4]
		for k in 5:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("campagne_" + vue[0])
	jeu.interface.show()
	jeu.interface.montrer("i", 32)
	var ferme: Dictionary = rural.objets[str(ferme_id)]
	jeu.pivot.viser(Vector2(ferme.point[0], ferme.point[2]), 440.0)
	jeu.pivot.caler(30.0, 52.0)
	jeu.selection.sel_couche = "a"
	jeu.selection.sel_fid = ferme_id
	jeu.interface.montrer("a", ferme_id)
	label.text = "4 · Un îlot agricole sélectionné"
	for k in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	assert(jeu.interface._agricole_texte.visible)
	assert(not jeu.interface._solaire_bloc.visible)
	assert(jeu._apercu_couche == "a")
	await jeu._capturer("campagne_ferme")
	jeu.interface.montrer("r", 55)
	assert(not jeu.interface._agricole_texte.visible)
	jeu.interface.montrer("a", ferme_id)
	assert(jeu._partie_valide(jeu._partie()))
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/partie-campagne.wehrau"
	jeu._sur_sauvegarde()
	jeu.selection.sel_couche = "r"
	jeu.selection.sel_fid = 55
	jeu._sur_reprise()
	assert(jeu.selection.sel_couche == "a" and jeu.selection.sel_fid == ferme_id)
	assert(jeu.interface._fiche_couche == "a")
	jeu._sur_theme("energie")
	for k in 4:
		await process_frame
	jeu._sur_theme("")
	print("Campagne : %d clics vérifiés, %d fermes, %d sorties, fiches et miniature validées." % [rural.objets.size(), fermes, rural.sorties.size()])
	quit()
