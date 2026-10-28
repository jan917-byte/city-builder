extends SceneTree
## Godot --path Godot --script res://outils/apercu_toits_verts.gd
## Les toits plats les plus grands, verdis au maximum : de près, puis au zoom de jeu.

const Energie := preload("res://scripts/energie.gd")

func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
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
	var v = jeu.ville
	var plats := []
	for fid in v.ilots:
		var m2: float = Energie.toit_plat_equipable_m2(v, fid)
		if m2 > 0.0:
			plats.append([m2, fid])
	plats.sort()
	plats.reverse()
	var choisis := []
	for p in plats.slice(0, 3):
		var fid: int = p[1]
		v.ajouter_rampe("i", fid, "part_toit_vert", v.part_vert_max(fid, 0.0), 0.0, 0.0, 0.01)
		choisis.append(fid)
	jeu.mois = 6.0
	var n := 0
	for fid in choisis:
		for vue in [[30.0, 45.0, 45.0], [210.0, 50.0, 140.0]]:
			n += 1
			jeu._viser_objet("i", fid, float(vue[2]))
			jeu.pivot.caler(float(vue[0]), float(vue[1]))
			jeu._dernier_peint = -1.0
			jeu._rafraichir(true)
			label.text = "%d · îlot %d · toit vert, juin" % [n, fid]
			for frame in 6:
				await process_frame
				await RenderingServer.frame_post_draw
			await jeu._capturer("toits_verts_%d" % n)
	for fid in choisis:
		var noeuds: Array = jeu._toits_verts.get(fid, {}).get("noeuds", [])
		print("îlot %d : %s" % [fid, noeuds.map(func(x): return x.multimesh.instance_count if x is MultiMeshInstance3D else x.mesh.get_faces().size() / 6)])
	quit()
