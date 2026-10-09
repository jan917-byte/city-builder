extends SceneTree
## Godot --path Godot --script res://outils/apercu_calendrier.gd
## Le compteur du temps et la saison de la barre du haut, à trois dates.

func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.moniteur_performances.hide()
	for date in [[0.0, "1_mars"], [4.4, "2_juillet"], [10.3, "3_janvier"]]:
		jeu.mois = date[0]
		jeu._rafraichir(true)
		for image in 4:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("calendrier_%s" % date[1])
	quit()
