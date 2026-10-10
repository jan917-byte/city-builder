extends SceneTree
## 🌳 LES ARBRES, à juger d'un coup d'œil : la pépinière numérotée de toutes
## les essences (ville, rive, forêt), puis quatre cadrages de la ville.
## Godot --path Godot --script res://outils/apercu_arbres.gd -- [--avant]
## Les numéros de la pépinière sont ceux que l'auteur désigne sur l'image.

const C := preload("res://scripts/constructeur.gd")

var jeu
var couche: CanvasLayer
var fond: StyleBoxFlat
var titre: Label
var numeros: Array[Label] = []


func _initialize() -> void:
	call_deferred("capturer")


func capturer() -> void:
	root.size = Vector2i(1600, 1000)
	jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.mois = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	if jeu.ouverture != null:
		jeu.ouverture.hide()
		jeu.ouverture._reperes.hide()
	jeu.set_process(false)
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
	couche = CanvasLayer.new()
	root.add_child(couche)
	fond = StyleBoxFlat.new()
	fond.bg_color = Color("f5f5ec")
	fond.set_content_margin_all(8)
	fond.content_margin_left = 14
	fond.content_margin_right = 14
	titre = _etiquette(26)
	titre.position = Vector2(24, 24)
	var suffixe := "avant" if "--avant" in OS.get_cmdline_user_args() else "apres"
	# ❄️ `-- --mois=10.3` : les mêmes vues à ce mois, météo à graine fixe.
	jeu.changer_saison(jeu.Saison.new(7))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mois="):
			jeu.mois = float(a.split("=")[1])
			suffixe += "_mois%s" % a.split("=")[1]
	await process_frame

	# Les alignements tous en terre : sinon une rue sans plantation n'en montre aucun.
	for a in jeu._arbres_slots:
		a[6] = -1.0
	jeu._arbres_compte = -1
	jeu._dernier_peint = -1.0
	jeu._rafraichir(true)
	# Berge 6 rendue, comme la vue 14 de la passe graphique.
	jeu.ville._berge[6] = {"cible": jeu.ville.BERGE_RENATUREE, "depuis": 0,
		"debut": -2.0, "duree": 1.0}

	# [nom, légende, lacet, hauteur, taille, cible]
	var vues := [
		["02_pavillons", "Clos des Noyers · jardins, fruitiers, thuyas", 30.0, 40.0, 130.0,
			["i", 11]],
		["03_rue_plantee", "Rues plantées · alignements en terre", 30.0, 38.0, 170.0,
			["i", 22]],
		["04_berge", "Berge 6 rendue · saules, buissons, roseaux", 30.0, 38.0, 160.0,
			["b", 6]],
		["05_lisiere", "Lisière · haies et bois", 30.0, 36.0, 320.0,
			Vector2(-560.0, 120.0)],
		["06_vallee", "Vallée · la forêt de loin", 30.0, 32.0, 1100.0, Vector2.ZERO],
	]
	for vue in vues:
		var cible = vue[5]
		if cible is Array:
			jeu._viser_objet(cible[0], int(cible[1]), float(vue[4]))
		else:
			jeu.pivot.viser(cible, float(vue[4]))
		jeu.pivot.caler(float(vue[2]), float(vue[3]))
		jeu._dernier_peint = -1.0
		jeu._rafraichir(true)
		titre.text = vue[1]
		await _attendre()
		await jeu._capturer("arbres_%s_%s" % [vue[0], suffixe])

	await _pepiniere(suffixe)
	print("Arbres : cadrages rendus (%s)." % suffixe)
	quit()


## La ville cachée, les essences en rang sur une dalle : même soleil, mêmes
## teintes que la maquette. Rang du fond = âges et tirages d'une même essence.
func _pepiniere(suffixe: String) -> void:
	jeu.monde.visible = false
	var p := Node3D.new()
	jeu.add_child(p)
	var dalle := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(190.0, 2.0, 70.0)
	dalle.mesh = bm
	var md := StandardMaterial3D.new()
	md.albedo_color = Color("c9c4b4")
	md.roughness = 1.0
	dalle.material_override = md
	dalle.position = Vector3(0.0, -1.0, 0.0)
	p.add_child(dalle)

	var vert: Color = jeu.Donnees.teinte(jeu.donnees, "_feuillage").srgb_to_linear()
	var brun: Color = jeu.Donnees.teinte(jeu.donnees, "_tronc")
	var noms := []
	var x := -70.0
	var rangs := [C.FEUILLU, C.BOULEAU, C.FRUITIER, C.PEUPLIER, C.SAULE,
		C.CONIFERE, C.BUISSON, C.ROSEAU]
	for e in rangs:
		var liste := [[x, 0.0, 6.0, 1.0, 0.6, e]]
		# Le rang du fond : jeune, moyen, vieux, tournés différemment.
		for k in 3:
			liste.append([x - 4.0 + 4.0 * k, 0.0, -14.0 - 3.0 * (k % 2),
				[0.6, 0.85, 1.2][k], 1.3 + 2.1 * k, e])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = C.arbres(liste, e, _teinte(e, vert),
			jeu.ECORCE_BOULEAU if e == C.BOULEAU else brun)
		p.add_child(mmi)
		noms.append([Vector3(x, 0.0, 6.0), ["feuillu", "bouleau", "fruitier",
			"peuplier", "saule", "conifère", "buisson", "roseau"][rangs.find(e)]])
		x += 15.0
	# Les trois arbres du décor, tels que la forêt les plante.
	for k in 3:
		var foret: MultiMesh
		for n in jeu.paysage.get_children():
			if n.name.begins_with("Foret%d_" % k):
				foret = (n as MultiMeshInstance3D).multimesh
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = foret.mesh
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ONE
			* jeu.paysage.FORET_ECHELLE), Vector3(x, 0.0, 6.0)))
		mm.set_instance_color(0, foret.get_instance_color(0))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		p.add_child(mi)
		noms.append([Vector3(x, 0.0, 6.0), ["forêt feuillu", "forêt sapin",
			"forêt peuplier"][k]])
		x += 15.0

	jeu.pivot.viser(Vector2(10.0, -4.0), 155.0)
	jeu.pivot.caler(0.0, 24.0)
	titre.text = "Pépinière · devant : chaque essence · fond : trois âges"
	await _attendre()
	for k in noms.size():
		var l := _etiquette(20)
		l.text = "%d %s" % [k + 1, noms[k][1]]
		var s: Vector2 = jeu.pivot.camera.unproject_position(noms[k][0] + Vector3(0, 0, 7.0))
		l.position = s - Vector2(30.0, 0.0)
		numeros.append(l)
	await _attendre()
	await jeu._capturer("arbres_01_pepiniere_%s" % suffixe)


## Recopie de `_montrer_arbres` et `_montrer_rives`, à garder d'accord.
func _teinte(e: int, vert: Color) -> Color:
	if e == C.ROSEAU:
		return vert * 1.22
	if e == C.BUISSON:
		return vert * 0.74
	if jeu.VALEUR_ESSENCE.has(e):
		return vert * float(jeu.VALEUR_ESSENCE[e])
	if e == C.FEUILLU:
		return vert
	return Color(vert.r * 0.70, vert.g * 0.80, vert.b * 0.76)


func _attendre() -> void:
	for f in 6:
		await process_frame
		await RenderingServer.frame_post_draw


func _etiquette(taille: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", Color("213d36"))
	l.add_theme_stylebox_override("normal", fond)
	couche.add_child(l)
	return l
