extends SceneTree
## 🎞️ COURBE DE COULEURS ① ET FLOU DE MAQUETTE ②, à juger : même cadrage, chaque réglage
## seul puis ensemble. Images `QGIS/rendus/maquette_*.png`, planche par `planche_maquette.py`.
## Godot --path Godot --position 6000,6000 --script res://outils/apercu_maquette.gd [-- --saisons]
## `--saisons` : le cœur ancien aux quatre saisons de l'an 1 (graine 7, celle d'`apercu_saisons`).

const Saison := preload("res://scripts/saison.gd")

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
	root.get_texture().get_image().save_png(dossier + "maquette_%s.png" % nom)
	print("capture → maquette_%s.png" % nom)


func capturer() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	current_scene = jeu
	await images(40)
	jeu._sur_vitesse(0.0)
	jeu.pivot.set_process_unhandled_input(false)
	jeu.interface.hide()
	if jeu.ouverture != null:
		jeu.ouverture.process_mode = Node.PROCESS_MODE_DISABLED
	var g = jeu.graphismes
	var essais := [["0_avant", "non", "non"], ["1_couleurs", "douce", "non"],
		["2_flou", "non", "leger"], ["3_les_deux", "douce", "leger"]]
	if "--saisons" in OS.get_cmdline_user_args():
		var s := Saison.new(7)
		jeu.changer_saison(s)
		var e: Array = s.neige_hiver(1)
		var neige := (float(e[0]) + Saison.ARRIVEE_MOIS + float(e[1])) * 0.5
		jeu._repere("compact")
		for d in [["printemps", 1.35], ["ete", 4.5], ["automne", 7.75], ["hiver", neige]]:
			jeu.mois = d[1]
			jeu._dernier_peint = -1.0
			jeu._rafraichir(true)
			await images(150)
			for x in essais:
				g.choisir("couleurs", x[1])
				g.choisir("maquette", x[2])
				await photo("saison_%s_%s" % [d[0], x[0]])
		quit(0)
		return
	for vue in [["ville", "ville"], ["compact", "coeur"], ["faubourg", "faubourg"]]:
		jeu._repere(vue[0])
		await images(150)
		for x in essais:
			g.choisir("couleurs", x[1])
			g.choisir("maquette", x[2])
			await photo("%s_%s" % [vue[1], x[0]])
	quit(0)
