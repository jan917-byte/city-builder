extends SceneTree
## Godot --path Godot --script res://outils/apercu_lavoir.gd
## 🟫 Un îlot peu touché doit se lire sinistré (auteur, 2026-10-18) : le Lavoir (62),
## 19 % sinistré sans ruine, puis le Colombier (63) et les Forgerons (59) pour comparer.

var jeu


func _initialize() -> void:
	call_deferred("capturer")


func photo(nom: String, fid: int, taille: float) -> void:
	jeu._viser_objet("i", fid, taille)
	jeu.pivot.caler(25.0, 38.0)
	for frame in 10:
		await process_frame
		await RenderingServer.frame_post_draw
	await jeu._capturer(nom)


func capturer() -> void:
	root.size = Vector2i(1600, 1000)
	jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	if jeu.ouverture != null:
		jeu.ouverture.hide()
		jeu.ouverture._reperes.hide()
	if jeu.pastilles != null:
		jeu.pastilles.hide()
	if jeu.recit != null:
		jeu.recit.hide()
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
	jeu.mois = 1.0
	jeu._rafraichir(true)
	await photo("lavoir_1_lavoir", 62, 90.0)
	await photo("lavoir_2_colombier", 63, 90.0)
	await photo("lavoir_3_forgerons", 59, 90.0)
	quit(0)
