extends SceneTree
## Capture un carrefour réel pendant huit secondes, à pas de temps fixe.
## Godot --path Godot --script res://outils/apercu_trafic.gd

func _initialize() -> void:
	call_deferred("filmer")

func filmer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.mois = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	jeu.horloge_trafic.stop()
	var t = jeu.trafic
	t.set_process(false)
	var cible := Vector2.ZERO
	for e in t._arc_L.size():
		if t._arc_fid[e] != 55:
			continue
		var u: int = t._arc_tete[e]
		var ouvertes := 0
		for i in range(t._sortie_deb[u], t._sortie_deb[u + 1]):
			if not t._indispo_courant.has(t._arc_fid[t._sortie_arc[i]]):
				ouvertes += 1
		if ouvertes >= 3:
			var p: Vector3 = t._arc_t[e].origin + t._arc_t[e].basis.z * t._arc_longueur_droite[e]
			cible = Vector2(p.x, p.z)
			break
	jeu.pivot.viser(cible, 55.0)
	jeu.pivot.caler(0.0, 65.0)
	t._maj_roulantes(0.0, true)
	var bandeau := CanvasLayer.new()
	root.add_child(bandeau)
	var legende := Label.new()
	legende.text = "1 · Carrefour de la rue 55 — virages et raccords"
	legende.position = Vector2(24, 18)
	legende.add_theme_font_size_override("font_size", 26)
	legende.add_theme_color_override("font_shadow_color", Color.BLACK)
	legende.add_theme_constant_override("shadow_offset_x", 2)
	legende.add_theme_constant_override("shadow_offset_y", 2)
	bandeau.add_child(legende)
	var dossier := ProjectSettings.globalize_path("res://../QGIS/rendus/trafic-mouvement/")
	DirAccess.make_dir_recursive_absolute(dossier)
	for k in 80:
		t._process(0.1)
		if k % 3 == 0:
			t._maj_roulantes(0.0, false)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.resize(960, 540, Image.INTERPOLATE_LANCZOS)
		var err := img.save_png(dossier + "%03d.png" % k)
		if err != OK:
			push_error("Capture du trafic impossible")
			quit(1)
			return
	print("Aperçu trafic : 80 images dans " + dossier)
	quit()
