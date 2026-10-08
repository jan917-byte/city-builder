extends SceneTree
## --headless --script res://outils/essai_venelle.gd [-- --captures, sans --headless]
## 🚶 Les venelles naissent en trace dans l'herbe ; « Aménager » la change en pavé.
## `--captures` : planche numérotée avant | après → QGIS/rendus/wehrau_venelles.png.
const Ville := preload("res://scripts/ville.gd")
const N_VENELLES := 6
const TUILE := Vector2i(560, 380)
var echecs := 0


func verifier(ok: bool, quoi: String) -> void:
	print("%s · %s" % ["OK" if ok else "ÉCHEC", quoi])
	if not ok:
		echecs += 1


func _initialize() -> void:
	call_deferred("executer")


func executer() -> void:
	var v := Ville.new()
	v.charger(JSON.parse_string(FileAccess.get_file_as_string("res://data/wehrau.json")))
	var fids := []
	for fid in v.ilots:
		if v.venelle_possible(fid):
			fids.append(fid)
	fids.sort()
	verifier(fids.size() == N_VENELLES, "%d îlots portent une venelle : %s" % [fids.size(), fids])
	var fid: int = fids[0]
	var cout := v.cout_venelle_ke(fid)
	verifier(cout > 0.0 and is_equal_approx(v.cout_commande_ke("i", fid, {"venelle": true}, 0.0), cout),
		"Îlot %d : %.0f m², %.1f k€" % [fid, v.base("i", fid, "venelle_m2"), cout])
	var r := v.commander("i", fid, {"venelle": true}, 0.0)
	verifier(r["ok"] and "venelle" in r["faits"], "Commande engagée")
	verifier(v.venelle_en_cours(fid, 1.0) and not v.venelle_amenagee(fid, 1.0)
		and v.etat_chantier("i", fid, 1.0) == Ville.CHANTIER_EN_COURS, "En chantier au mois 1")
	verifier(v.venelle_amenagee(fid, Ville.VENELLE_MOIS), "Livrée au mois %.0f" % Ville.VENELLE_MOIS)
	verifier(v.cout_venelle_ke(fid) == 0.0 and not v.amenager_venelle(fid, 4.0), "On n'aménage pas deux fois")
	var etat := v.exporter_partie()
	verifier(v.valider_partie(etat), "La partie sauvée se relit")
	v.reinitialiser()
	verifier(not v.venelle_amenagee(fid, 10.0), "Recommencer rend la trace")
	v.importer_partie(etat)
	verifier(v.venelle_amenagee(fid, 10.0), "Reprendre rend le pavé")

	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	current_scene = jeu
	for i in 8:
		await process_frame
	verifier(jeu.venelles.size() == N_VENELLES, "%d traces dans la ville" % jeu.venelles.size())
	jeu.ville.livraison_immediate = true
	jeu.ville.crediter_essai_ke(1000.0)
	if "--captures" in OS.get_cmdline_user_args():
		await capturer(jeu, fids)
	else:
		jeu.ville.commander("i", fid, {"venelle": true}, jeu.mois)
		jeu._rafraichir(true)
		verifier(not (jeu.venelles[fid] as MeshInstance3D).visible, "Aménagée : la trace disparaît")
	print("VENELLES : %s" % ("ok" if echecs == 0 else "%d échec(s)" % echecs))
	quit(echecs)


func capturer(jeu, fids: Array) -> void:
	root.size = Vector2i(1600, 1000)
	jeu.vitesse = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	var couche := CanvasLayer.new()
	root.add_child(couche)
	var label := Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color("213d36"))
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color("f5f5ec")
	fond.set_content_margin_all(10)
	label.add_theme_stylebox_override("normal", fond)
	couche.add_child(label)
	var planche := Image.create(TUILE.x * 4, TUILE.y * 3, false, Image.FORMAT_RGB8)
	for k in fids.size():
		var fid: int = fids[k]
		var mi: MeshInstance3D = jeu.venelles[fid]
		var c := mi.get_aabb().get_center() + mi.global_position
		for apres in [false, true]:
			if apres:
				jeu.ville.commander("i", fid, {"venelle": true}, jeu.mois)
			jeu.pivot.caler(30.0, 50.0)
			jeu.pivot.viser(Vector2(c.x, c.z), 40.0)
			jeu._rafraichir(true)
			label.text = "%d · îlot %d · %s" % [k + 1, fid, "aménagée" if apres else "trace"]
			for i in 4:
				await process_frame
				await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(TUILE.x, TUILE.y, Image.INTERPOLATE_LANCZOS)
			var col := (k % 2) * 2 + (1 if apres else 0)
			@warning_ignore("integer_division")
			planche.blit_rect(img, Rect2i(Vector2i.ZERO, TUILE), Vector2i(col * TUILE.x, (k / 2) * TUILE.y))
		verifier(not mi.visible, "%d · îlot %d : la trace disparaît une fois aménagée" % [k + 1, fid])
	var dossier := ProjectSettings.globalize_path(jeu.RENDUS)
	DirAccess.make_dir_recursive_absolute(dossier)
	var chemin := dossier + "wehrau_venelles.png"
	planche.save_png(chemin)
	print("planche → %s" % chemin)
