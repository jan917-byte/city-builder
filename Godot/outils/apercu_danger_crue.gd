extends SceneTree
## Godot --path Godot --position 6000,6000 --script res://outils/apercu_danger_crue.gd -- --ouverture
## 🌊 La barre de danger sous la date à quatre âges de l'étude, puis le détail
## de la caisse et sa croix (auteur, 2026-10-09).

func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	root.size = Vector2i(1600, 900)
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.moniteur_performances.hide()
	await process_frame
	jeu._sur_mode(false)
	if jeu.recit != null:
		jeu.recit.terminer()
	var o = jeu.ouverture
	o.pont_termine = true
	o.suite = true
	o.etude_parue = true
	o.etude_mois = 3.0
	# Années depuis l'étude : calme, l'approche, dans la fenêtre, au bout.
	for ans in [[1.0, "1_an_1"], [5.5, "2_approche"], [6.5, "3_fenetre"], [7.8, "4_au_bout"]]:
		jeu.mois = 3.0 + 12.0 * ans[0]
		jeu._rafraichir(true)
		for image in 4:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("danger_crue_%s" % ans[1])
	jeu.interface.ouvrir_detail("caisse")
	for image in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	await jeu._capturer("danger_crue_5_caisse_croix")
	quit()
