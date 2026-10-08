extends SceneTree
## Godot --path Godot --script res://outils/apercu_campus.gd
## Le campus en trois îlots (université 36, bibliothèque 77, institut 78), deux cadrages.

func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.mois = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	jeu.horloge_trafic.stop()
	jeu.trafic.set_process(false)
	var centre := Vector3.ZERO
	for fid in [36, 77, 78]:
		centre += (jeu.noeuds["i"][fid] as MeshInstance3D).get_aabb().get_center() / 3.0
	for vue in [[30.0, 35.0, 150.0, "a"], [210.0, 35.0, 150.0, "b"]]:
		jeu.pivot.viser(Vector2(centre.x, centre.z), vue[2])
		jeu.pivot.position.y = 7.0
		jeu.pivot.caler(vue[0], vue[1])
		for image in 4:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("campus_%s" % vue[3])
	quit()
