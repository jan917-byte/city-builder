extends SceneTree
## Godot --path Godot --resolution 1920x1080 --script res://outils/vitrine.gd -- [--seule=nom]
## Vues à publier : ni interface ni légende. Les toits équipés et la berge 6
## rendue sont posés à la main, sans décision engagée.

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
	var seule := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seule="):
			seule = a.trim_prefix("--seule=")
	await process_frame
	jeu._rafraichir(true)
	# [nom, lacet, hauteur, taille, cible, toits équipés {fid: part}, berge 6 rendue]
	var vues := [
		["01_ville", 30.0, 34.0, 700.0, Vector2(120.0, -80.0), {}, false],
		["02_vallee", 30.0, 26.0, 1700.0, Vector2.ZERO, {}, false],
		["03_quais", 30.0, 38.0, 260.0, Vector2(230.0, -300.0), {}, false],
		["04_coeur_ancien", 120.0, 26.0, 120.0, ["i", 15], {}, false],
		["05_toits_solaires", 30.0, 40.0, 150.0, ["i", 22], {22: 0.6, 17: 0.3, 18: 1.0}, false],
		["07_barre", 210.0, 30.0, 170.0, ["i", 32], {}, false],
		["08_pavillons", 30.0, 40.0, 160.0, ["i", 11], {}, false],
		["09_boulevard", 30.0, 40.0, 120.0, ["r", 8], {}, false],
	]
	for vue in vues:
		if seule != "" and not str(vue[0]).contains(seule):
			continue
		var cible = vue[4]
		if cible is Array:
			jeu._viser_objet(cible[0], int(cible[1]), float(vue[3]))
		else:
			jeu.pivot.viser(cible, float(vue[3]))
		jeu.pivot.caler(float(vue[1]), float(vue[2]))
		jeu.ville._berge.erase(6)
		if vue[6]:
			jeu.ville._berge[6] = {"cible": jeu.ville.BERGE_RENATUREE, "depuis": 0,
				"debut": -2.0, "duree": 1.0}
		for fid in [22, 17, 18]:
			jeu.ville.objets("i")[fid]["part_toit_equipe"] = float(
				(vue[5] as Dictionary).get(fid, 0.0))
		jeu._dernier_peint = -1.0
		jeu._rafraichir(true)
		for frame in 8:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("vitrine_%s" % vue[0])
	print("Vitrine : vues rendues.")
	quit()
