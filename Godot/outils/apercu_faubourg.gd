extends SceneTree
## Trois vues reproductibles : la coupe du faubourg, le camp et son module.
var jeu

func _initialize() -> void:
	call_deferred("capturer")

func photo(nom: String, texte: String) -> void:
	var couche := CanvasLayer.new()
	root.add_child(couche)
	var label := Label.new()
	label.text = texte
	label.position = Vector2(32, 24)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("20352c"))
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color("f5f5ec")
	fond.content_margin_left = 16
	fond.content_margin_right = 16
	fond.content_margin_top = 10
	fond.content_margin_bottom = 10
	label.add_theme_stylebox_override("normal", fond)
	couche.add_child(label)
	for frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	await jeu._capturer(nom)
	couche.queue_free()

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
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
	var centre: Array = jeu.donnees.meta.centre
	jeu.pivot.viser(Vector2(500820 - centre[0], centre[1] - 5600180), 300.0)
	jeu.pivot.caler(0.0, 65.0)
	await photo("faubourg_01_rive", "1 · Ilse → berge naturelle → trois champs → route → bois")
	jeu.ville.livraison_immediate = true
	jeu.ville.abriter(1082, 0.0)
	jeu._rafraichir(true)
	jeu.interface.hide()
	if jeu.ouverture != null:
		jeu.ouverture.hide()
	jeu.pivot.viser(Vector2(500858 - centre[0], centre[1] - 5600100), 120.0)
	jeu.pivot.caler(-25.0, 48.0)
	await photo("faubourg_02_camp", "2 · Containers entre la berge et la route")
	var q: Array = jeu.camp._places[1082][30]
	jeu.pivot.viser(Vector2(q[0], q[2]), 22.0)
	jeu.pivot.caler(rad_to_deg(-float(q[3])) + 160.0, 32.0)
	jeu.pivot.taille = 22.0
	jeu.pivot._appliquer()
	await photo("faubourg_03_module", "3 · Ossature, tôle nervurée, fenêtres et entrée abritée")
	quit()
