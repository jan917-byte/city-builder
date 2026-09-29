extends SceneTree
## En pause, l'horloge du trafic ne bouge plus : voitures, piétons et vélos figés.
## `-- --captures` ajoute deux images à une seconde d'écart, qui doivent être identiques.
var echecs := 0


func _initialize() -> void:
	call_deferred("executer")


func attendre(secondes: float) -> void:
	var fin := Time.get_ticks_msec() + int(secondes * 1000.0)
	while Time.get_ticks_msec() < fin:
		await process_frame


func executer() -> void:
	root.size = Vector2i(1600, 900)
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	current_scene = jeu
	await attendre(1.0)
	jeu._sur_vitesse(1.0)
	var t0: float = jeu.trafic._temps_trafic
	await attendre(0.5)
	if jeu.trafic._temps_trafic <= t0:
		echecs += 1
		push_error("En marche, l'horloge du trafic n'avance pas")
	jeu._sur_vitesse(0.0)
	await process_frame
	var t1: float = jeu.trafic._temps_trafic
	var a: Image = null
	if "--captures" in OS.get_cmdline_user_args():
		jeu._viser_route(55, 90.0)
		jeu.pivot.caler(35.0, 28.0)
		await attendre(0.3)
		a = root.get_texture().get_image()
	await attendre(1.0)
	if not is_equal_approx(jeu.trafic._temps_trafic, t1):
		echecs += 1
		push_error("En pause, l'horloge du trafic avance encore")
	if a != null:
		var b: Image = root.get_texture().get_image()
		a.save_png("user://pause_avant.png")
		b.save_png("user://pause_apres.png")
		var differents := 0
		for y in range(0, a.get_height(), 4):
			for x in range(0, a.get_width(), 4):
				if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
					differents += 1
		print("pixels qui ont bougé en pause : %d" % differents)
	print("PAUSE : %s" % ("ok" if echecs == 0 else "%d échec(s)" % echecs))
	quit(echecs)
