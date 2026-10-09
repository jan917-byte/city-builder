extends SceneTree
## Godot --path Godot --script res://outils/apercu_dangers.gd
## 🌊 La carte des dangers au mètre (2026-10-09) : les Dégâts, la prochaine
## crue, puis un plan rapproché du bord de l'eau.

var jeu


func _initialize() -> void:
	call_deferred("capturer")


func photo(nom: String, cible: Vector2, taille: float, lacet: float, hauteur: float) -> void:
	jeu.pivot.viser(cible, taille)
	jeu.pivot.caler(lacet, hauteur)
	jeu._dernier_peint = -1.0
	jeu._rafraichir(true)
	for frame in 8:
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
	for n in [jeu.ouverture, jeu.pastilles, jeu.recit]:
		if n != null:
			n.hide()
	if jeu.ouverture != null:
		jeu.ouverture._reperes.hide()
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu._sur_theme("dangers")
	jeu._sur_vue_crue("degats")
	await photo("dangers_01_degats", Vector2(250, -150), 700.0, 0.0, 70.0)
	await photo("dangers_03_degats_pres", Vector2(290, -200), 200.0, 25.0, 45.0)
	jeu._sur_vue_crue("prochaine")
	await photo("dangers_02_prochaine", Vector2(250, -150), 700.0, 0.0, 70.0)
	await photo("dangers_04_prochaine_pres", Vector2(290, -200), 200.0, 25.0, 45.0)
	quit()
