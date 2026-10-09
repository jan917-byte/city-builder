extends SceneTree
## Godot --path Godot --script res://outils/apercu_debris.gd
## 🪵 Les dégâts de la crue (2026-10-09) : rasé au bord de l'eau, debout au
## bord du sinistré, troncs et débris, puis l'îlot 63 et la rue 166 remis en état.

var jeu
var couche: CanvasLayer


func _initialize() -> void:
	call_deferred("capturer")


func etiquette(texte: String, ou: Vector3) -> void:
	var label := Label.new()
	label.text = texte
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("20352c"))
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color("f5f5ec")
	fond.content_margin_left = 10
	fond.content_margin_right = 10
	fond.content_margin_top = 5
	fond.content_margin_bottom = 5
	label.add_theme_stylebox_override("normal", fond)
	couche.add_child(label)
	label.position = jeu.pivot.camera.unproject_position(ou)


func photo(nom: String, cible: Vector2, taille: float, lacet: float,
		hauteur: float, reperes: Array) -> void:
	for e in couche.get_children():
		e.queue_free()
	jeu.pivot.viser(cible, taille)
	jeu.pivot.caler(lacet, hauteur)
	await process_frame
	for r in reperes:
		etiquette(r[0], r[1])
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
	couche = CanvasLayer.new()
	root.add_child(couche)

	var vue := [
		["1", Vector3(283, 1, -173)],
		["2", Vector3(291, 1, -217)],
		["3", Vector3(267, 1, -209)],
		["4", Vector3(337, 1, -150)]]
	await photo("debris_01_vue", Vector2(300, -190), 170.0, 0.0, 50.0, vue)
	await photo("debris_02_bord_eau", Vector2(283, -175), 70.0, 25.0, 42.0, [])
	await photo("debris_03_bord_sinistre", Vector2(290, -217), 70.0, 25.0, 42.0, [])
	await photo("debris_04_rue", Vector2(267, -209), 60.0, 25.0, 45.0, [])
	await photo("debris_05_pavillons", Vector2(330, -150), 90.0, 0.0, 45.0, [])

	# La remise en état, montrée sans passer par la partie : l'îlot 63 et la
	# rue 166 comme le peint `_peindre` une fois la réparation livrée.
	for c in [["i", 63], ["r", 166]]:
		for mi in [jeu.noeuds[c[0]].get(c[1]), jeu.reparations[c[0]].get(c[1])]:
			if mi != null:
				mi.set_instance_shader_parameter("boue_propre", 1.0)
		if jeu.reparations[c[0]].has(c[1]):
			jeu.reparations[c[0]][c[1]].visible = true
	await photo("debris_06_pavillons_repares", Vector2(330, -150), 90.0, 0.0, 45.0, [])
	await photo("debris_07_vue_repare", Vector2(300, -190), 170.0, 0.0, 50.0, [
		["5", Vector3(337, 1, -150)], ["6", Vector3(267, 1, -209)]])
	quit()
