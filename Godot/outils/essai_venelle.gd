extends SceneTree
## --headless --script res://outils/essai_venelle.gd [-- --captures, sans --headless]
## 🚶 Les venelles se creusent seules dans l'herbe (122) : rien à aménager.
## `--captures` : planche numérotée mois 0 | 10 | 30 → QGIS/rendus/wehrau_venelles.png.
const Ville := preload("res://scripts/ville.gd")
const N_VENELLES := 6
const TUILE := Vector2i(520, 350)
const MOIS := [0.0, 10.0, 30.0]
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
	var a_zero := true
	var au_bout := true
	var monte := true
	var rythmes := {}
	for fid in fids:
		a_zero = a_zero and v.venelle_usure(fid, 0.0) == 0.0
		au_bout = au_bout and v.venelle_usure(fid, 30.0) == 1.0
		var avant := 0.0
		for m in range(0, 31):
			var u := v.venelle_usure(fid, float(m))
			monte = monte and u >= avant
			avant = u
		rythmes[snappedf(v.venelle_usure(fid, 10.0), 0.01)] = true
	verifier(a_zero, "Mois 0 : de l'herbe partout")
	verifier(au_bout, "Mois 30 : toutes creusées")
	verifier(monte, "L'usure ne recule jamais")
	verifier(rythmes.size() >= 4, "Au mois 10, %d rythmes différents sur %d" % [rythmes.size(), fids.size()])
	verifier(v.cout_commande_ke("i", fids[0], {"venelle": true}, 0.0) == 0.0, "Plus rien à payer pour une venelle")

	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	current_scene = jeu
	for i in 8:
		await process_frame
	verifier(jeu.venelles.size() == N_VENELLES, "%d traces dans la ville" % jeu.venelles.size())
	if "--captures" in OS.get_cmdline_user_args():
		await capturer(jeu, fids)
	else:
		var fid: int = fids[0]
		var src: Dictionary = jeu._venelles_sources[fid]
		jeu.mois = 0.0
		jeu._rafraichir(true)
		verifier(_nb_teinte(jeu, fid, src["terre"]) == 0, "Mois 0 : aucune terre visible")
		jeu.mois = 30.0
		jeu._rafraichir(true)
		verifier(_nb_teinte(jeu, fid, src["terre"]) > 0, "Mois 30 : la terre battue apparaît")
		verifier((jeu.venelles[fid] as MeshInstance3D).visible, "La trace reste visible")
	print("VENELLES : %s" % ("ok" if echecs == 0 else "%d échec(s)" % echecs))
	quit(echecs)


func _nb_teinte(jeu, fid: int, teinte: Color) -> int:
	var co: PackedColorArray = (jeu.venelles[fid] as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var n := 0
	for c in co:
		if jeu._ecart(c, teinte) < 0.01:
			n += 1
	return n


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
	var planche := Image.create(TUILE.x * 6, TUILE.y * 3, false, Image.FORMAT_RGB8)
	for k in fids.size():
		var fid: int = fids[k]
		var mi: MeshInstance3D = jeu.venelles[fid]
		var c := mi.get_aabb().get_center() + mi.global_position
		for e in MOIS.size():
			jeu.mois = MOIS[e]
			jeu.pivot.caler(30.0, 50.0)
			jeu.pivot.viser(Vector2(c.x, c.z), 40.0)
			jeu._rafraichir(true)
			label.text = "%d · îlot %d · mois %d" % [k + 1, fid, int(MOIS[e])]
			for i in 4:
				await process_frame
				await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(TUILE.x, TUILE.y, Image.INTERPOLATE_LANCZOS)
			var col := (k % 2) * 3 + e
			@warning_ignore("integer_division")
			planche.blit_rect(img, Rect2i(Vector2i.ZERO, TUILE), Vector2i(col * TUILE.x, (k / 2) * TUILE.y))
	var dossier := ProjectSettings.globalize_path(jeu.RENDUS)
	DirAccess.make_dir_recursive_absolute(dossier)
	var chemin := dossier + "wehrau_venelles.png"
	planche.save_png(chemin)
	print("planche → %s" % chemin)
