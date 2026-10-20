extends SceneTree
## ⚙️ LES RÉGLAGES GRAPHIQUES, à juger : le panneau ouvert, puis le cœur ancien à chaque
## réglage, même cadrage. Images dans `QGIS/rendus/graphismes_*.png`.
## Godot --path Godot --position 6000,6000 --script res://outils/apercu_graphismes.gd -- --ouverture --auteur

var jeu


func _initialize() -> void:
	call_deferred("capturer")


func images(n: int) -> void:
	for i in n:
		await process_frame
		await RenderingServer.frame_post_draw


func photo(nom: String) -> void:
	await images(8)
	var dossier := ProjectSettings.globalize_path("res://../QGIS/rendus/")
	DirAccess.make_dir_recursive_absolute(dossier)
	root.get_texture().get_image().save_png(dossier + "graphismes_%s.png" % nom)
	print("capture → graphismes_%s.png" % nom)


func capturer() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	current_scene = jeu
	await images(40)
	jeu._sur_vitesse(0.0)
	jeu.pivot.set_process_unhandled_input(false)
	var g = jeu.graphismes
	jeu._repere("ville")
	g.basculer()
	await photo("0_panneau")
	g.basculer()
	jeu.interface.hide()
	if jeu.ouverture != null:
		jeu.ouverture.process_mode = Node.PROCESS_MODE_DISABLED
	for vue in [["compact", "coeur"], ["ville", "ville"]]:
		jeu._repere(vue[0])
		for r in [["ombres", "fines"], ["ombres", "moyennes"], ["ombres", "legeres"], ["ombres", "aucune"]]:
			g.choisir(r[0], r[1])
			await photo("%s_ombres_%s" % [vue[1], r[1]])
		g.choisir("ombres", "fines")
		g.choisir("bois", false)
		await photo("%s_bois_non" % vue[1])
		g.choisir("bois", true)
		g.choisir("recoins", false)
		await photo("%s_recoins_non" % vue[1])
		g.choisir("recoins", true)
		g.choisir("rebonds", true)
		await photo("%s_rebonds_oui" % vue[1])
		g.choisir("rebonds", false)
		for k in ["ciel", "brume"]:
			g.choisir(k, true)
			await photo("%s_%s_oui" % [vue[1], k])
			g.choisir(k, false)
		g.choisir("ciel", true)
		g.choisir("brume", true)
		g.choisir("rebonds", true)
		await photo("%s_lumiere_tout" % vue[1])
		for k in ["ciel", "brume", "rebonds"]:
			g.choisir(k, false)
		g.choisir("echelle", "70")
		await photo("%s_resolution_70" % vue[1])
		g.choisir("echelle", "100")
	quit(0)
