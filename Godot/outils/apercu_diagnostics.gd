extends SceneTree
## Godot --path Godot --script res://outils/apercu_diagnostics.gd [-- --avant]
## 🗺️ Les pages du diagnostic, panneau ouvert, au même cadrage : une capture
## par tuile du rail. `--avant` préfixe les noms, pour un avant/après.

var jeu


func _initialize() -> void:
	call_deferred("capturer")


func capturer() -> void:
	root.size = Vector2i(1600, 1000)
	jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	# Sans `--ouverture`, ni guide ni récit : le rail est ouvert en entier.
	jeu._sur_vitesse(0.0)
	# Une campagne qui a bougé, sinon la page Agriculture n'a qu'une teinte.
	var v = jeu.ville
	var champs := []
	for fid in v.ilots:
		if v.est_champ(int(fid)):
			champs.append(int(fid))
	champs.sort()
	v.abriter(champs[0], 0.0)
	for k in range(1, mini(champs.size(), 7)):
		v.cultiver(champs[k], 1 + k % 3, 0.0)
	jeu.mois = 60.0
	var prefixe := "avant_" if "--avant" in OS.get_cmdline_user_args() else ""
	jeu.pivot.viser(Vector2(250, -150), 900.0)
	jeu.pivot.caler(0.0, 70.0)
	for t in jeu.THEMES:
		var id := str(t["id"])
		jeu.interface._sur_rail(id)
		jeu._dernier_peint = -1.0
		jeu._rafraichir(true)
		for frame in 8:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("diagnostic_%s%s" % [prefixe, id])
	# Le relief hors de la ville, de loin : le fond du diagnostic.
	jeu.interface._sur_rail("energie")
	jeu.pivot.viser(Vector2(250, -150), 2600.0)
	jeu.pivot.caler(20.0, 45.0)
	for frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	await jeu._capturer("diagnostic_%slarge" % prefixe)
	quit()
