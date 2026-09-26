extends SceneTree
## Godot --path Godot --script res://outils/apercu_graphisme.gd -- [--avant] [--seule=nom]
## Mêmes cadrages avant et après la passe graphique ; les toits équipés sont
## posés dans l'état de départ, sans décision engagée ni argent dépensé.
var jeu
var label: Label
var fond: StyleBoxFlat
var couche: CanvasLayer

func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.mois = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
	couche = CanvasLayer.new()
	root.add_child(couche)
	fond = StyleBoxFlat.new()
	fond.bg_color = Color("f5f5ec")
	fond.content_margin_left = 14
	fond.content_margin_right = 14
	fond.content_margin_top = 8
	fond.content_margin_bottom = 8
	label = _etiquette(26)
	label.position = Vector2(24, 24)
	var suffixe := "avant" if "--avant" in OS.get_cmdline_user_args() else "apres"
	var seule := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seule="):
			seule = a.trim_prefix("--seule=")
	await process_frame
	jeu._rafraichir(true)
	# [nom, légende, lacet, hauteur, taille, cible, toits équipés {fid: part}]
	var vues := [
		["01_riviere_quai", "Ilse en ville · quais et ponts", 30.0, 38.0, 260.0,
			Vector2(230.0, -300.0), {}],
		["02_riviere_champs", "Ilse en campagne · berge naturelle", 30.0, 40.0, 300.0,
			Vector2(560.0, 420.0), {}],
		["03_toits_anciens", "Cœur ancien · toits en pente équipés à 60 %", 30.0, 38.0, 140.0,
			["i", 22], {22: 0.6, 17: 0.3, 18: 1.0}],
		["04_toits_plats", "Îlot compact et barre · toits plats équipés", 30.0, 45.0, 200.0,
			["i", 49], {49: 0.7, 32: 0.5}],
		["03b_toits_pres", "Panneaux sur toits en pente, de près", 30.0, 42.0, 55.0,
			["i", 22], {22: 0.6, 17: 0.3, 18: 1.0}],
		["04b_toit_plat_pres", "Panneaux sur toit plat, de près", 30.0, 48.0, 70.0,
			["i", 49], {49: 0.7, 32: 0.5}],
		["05_halles", "Ateliers des Sureaux · halles de la friche", 30.0, 36.0, 220.0,
			["i", 31], {}],
		["06_coeur_facades", "Cœur ancien · façades de près", 120.0, 24.0, 110.0,
			["i", 15], {}],
		["07_barre", "Résidence de l'Aval · barre de 1970", 210.0, 30.0, 160.0,
			["i", 32], {}],
		["08_pavillons", "Clos des Noyers · pavillons et jardins", 30.0, 40.0, 150.0,
			["i", 11], {}],
		["09_foret_lisiere", "Lisière · champs, haies et bois", 30.0, 38.0, 320.0,
			Vector2(-560.0, 120.0), {}],
		["10_vallee_ensemble", "Vallée · ville, forêt et montagnes", 30.0, 32.0, 1550.0,
			Vector2.ZERO, {}],
		["11_vallee_panorama", "Vallée · panorama rasant", 30.0, 22.0, 2400.0,
			Vector2.ZERO, {}],
		["12_montagne", "Montagnes · versant ouest de près", 30.0, 34.0, 800.0,
			Vector2(-1350.0, -250.0), {}],
		["14_berge_rendue", "Berge 6 rendue au fleuve · talus, roseaux, saules", 30.0, 38.0, 180.0,
			["b", 6], {}],
		["13_riviere_sortie", "Ilse · sortie amont de la carte", 30.0, 38.0, 700.0,
			Vector2(380.0, -1500.0), {}],
	]
	for vue in vues:
		if seule != "" and not str(vue[0]).contains(seule):
			continue
		var cible = vue[5]
		if cible is Array:
			jeu._viser_objet(cible[0], int(cible[1]), float(vue[4]))
		else:
			jeu.pivot.viser(cible, float(vue[4]))
		jeu.pivot.caler(float(vue[2]), float(vue[3]))
		if str(vue[0]).begins_with("14"):
			jeu.ville._berge[6] = {"cible": jeu.ville.BERGE_RENATUREE, "depuis": 0,
				"debut": -2.0, "duree": 1.0}
		for fid in (vue[6] as Dictionary):
			jeu.ville.objets("i")[fid]["part_toit_equipe"] = float(vue[6][fid])
		jeu._dernier_peint = -1.0
		jeu._rafraichir(true)
		label.text = vue[1]
		for frame in 6:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("graphisme_%s_%s" % [vue[0], suffixe])
	print("Graphisme : cadrages rendus (%s)." % suffixe)
	quit()

func _etiquette(taille: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", Color("213d36"))
	l.add_theme_stylebox_override("normal", fond)
	couche.add_child(l)
	return l
