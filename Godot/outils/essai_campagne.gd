extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_campagne.gd [-- --captures]
## Quatre champs voisins : ① maraîchage · ② verger · ③ prairie · ④ céréales.
const Ville := preload("res://scripts/ville.gd")
var _reperes: Array[Label] = []
var _champs: Array[int] = []


## Sans guide d'ouverture : le temps seul.
func actualiser(mois: float) -> void:
	jeu.mois = mois
	jeu.trafic.avancer(mois)
	jeu._rafraichir(true)


## Le centre du contour, pas de sa boîte : un champ biais la déporterait.
func centre(fid: int) -> Vector3:
	var poly: Array = jeu.donnees["emprises"].get(str(fid), [])
	if poly.is_empty():
		return (jeu.noeuds["i"][fid] as MeshInstance3D).mesh.get_aabb().get_center()
	var c := Vector3.ZERO
	for p in poly:
		c += Vector3(float(p[0]), float(p[1]), float(p[2]))
	return c / poly.size()


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu._sur_mode(false)
	var v: Ville = jeu.ville
	var ui = jeu.interface

	# Le plus grand champ, puis ses trois voisins les plus proches.
	var tous: Array = []
	for fid in v.ilots:
		if v.est_champ(int(fid)) and jeu.noeuds["i"].has(int(fid)):
			tous.append(int(fid))
	tous.sort_custom(func(a, b): return v.base("i", a, "surface_m2") > v.base("i", b, "surface_m2"))
	var c0 := centre(tous[0])
	var voisins: Array = tous.slice(1)
	voisins.sort_custom(func(a, b): return centre(a).distance_to(c0) < centre(b).distance_to(c0))
	_champs = [tous[0], voisins[0], voisins[1], voisins[2]]
	print("champs : %s" % [_champs])

	var depart := v.nourriture_depart()
	verifier(is_equal_approx(v.nourriture_personnes(0.0), depart), "Au départ, les champs nourrissent %d personnes" % int(depart))
	verifier(is_equal_approx(v.achat_nourriture_cumule_ke(12.0), 0.0), "Sans décision, les achats ne coûtent rien de plus à la caisse")

	await cadrer()
	await capture_campagne("cultures_0_avant")

	# ① Le maraîchage par la fiche, comme un joueur.
	var f := _champs[0]
	var ha := v.base("i", f, "surface_m2") / 10000.0
	ui.reprendre_fiche("i", f)
	ui.ouvrir_onglet("campagne")
	await process_frame
	var b0: Button = ui._culture_boutons[Ville.CEREALES]
	verifier(ui._culture_bloc.visible and not b0.visible, "La culture en place n'a plus de bouton : la tuile Culture la dit")
	var bm: Button = ui._culture_boutons[1]
	verifier(bm.text == "Maraîchage", "Le bouton Maraîchage ne porte que son nom : " + bm.text)
	await cliquer(bm)
	verifier(int(ui._pose.get("culture", -1)) == 1, "Maraîchage posé sur la fiche")
	ui._maj_fiche()
	var effets := ""
	for e in ui._recap_effets.get_children():
		effets += (e.get_child(1) as Label).text + " | "
	verifier("k€/mois d'achats" in effets, "Le récapitulatif annonce l'économie d'achats : " + effets)
	await capture("campagne_fiche_maraichage")
	var caisse := v.caisse_ke(0.0)
	await cliquer(ui._recap_bouton)
	verifier(absf(caisse - v.caisse_ke(0.0) - v.cout_culture_ke(f, 1)) < 0.01, "La caisse paie %d k€" % int(v.cout_culture_ke(f, 1)))
	verifier(v.culture_en_cours(f, 0.5) and v.champ_rendement(f, 0.5) == 0.0, "Pendant le chantier, le champ ne nourrit personne")
	verifier(is_equal_approx(v.champ_rendement(f, 12.0), ha * 120.0), "Après un an, il nourrit %d personnes" % int(ha * 120.0))

	# ② ③ Le verger et la prairie, par le noyau.
	verifier(v.cultiver(_champs[1], 2, 0.0), "Verger engagé")
	verifier(v.cultiver(_champs[2], 3, 0.0), "Prairie engagée")
	verifier(not v.cultiver(_champs[1], 1, 1.0), "Un chantier en cours ne se recommence pas")
	verifier(v.champ_rendement(_champs[1], 59.0) == 0.0 and v.champ_rendement(_champs[1], 60.5) > 0.0,
		"Le verger ne rend rien avant cinq ans")
	verifier(v.baisse_crue_champs_m(7.0) > 0.0 and v.baisse_crue_champs_m(1.0) == 0.0,
		"La prairie livrée abaisse la crue : %.1f cm" % (v.baisse_crue_champs_m(7.0) * 100.0))

	# La caisse reste une fonction du temps : sauvegarder puis reprendre ne change rien.
	var avant := v.caisse_ke(80.0)
	var partie := v.exporter_partie()
	verifier(v.valider_partie(partie), "La partie avec cultures se valide")
	v.importer_partie(partie)
	verifier(is_equal_approx(v.caisse_ke(80.0), avant), "Reprise : même caisse au mois 80")
	verifier(v.achat_nourriture_cumule_ke(120.0) < 0.0, "Dix ans plus tard, les cultures ont fait économiser %d k€" % int(-v.achat_nourriture_cumule_ke(120.0)))

	actualiser(1.0)
	await capture_campagne("cultures_1_chantier")
	actualiser(13.0)
	await capture_campagne("cultures_2_un_an")
	actualiser(61.0)
	await capture_campagne("cultures_3_cinq_ans")
	var c1 := (centre(_champs[0]) + centre(_champs[1])) * 0.5
	jeu.pivot.viser(Vector2(c1.x, c1.z), 160.0)
	await capture_campagne("cultures_4_de_pres")
	ui.reprendre_fiche("i", _champs[1])
	ui.ouvrir_onglet("campagne")
	await capture("campagne_fiche_verger")

	# Un camp sur un champ cultivé : le bloc des cultures disparaît.
	var abri := -1
	for fid in _champs:
		if v.camp_possible(fid) and abri < 0:
			abri = fid
	# Personne n'est relogé dans ce scénario : l'aide d'urgence a vidé la caisse.
	v.crediter_essai_ke(1500.0)
	verifier(abri >= 0 and v.abriter(abri, 61.0), "Un camp se pose sur le champ %d" % abri)
	ui.reprendre_fiche("i", abri)
	await process_frame
	verifier(not ui._bloc_dispo.get(ui._culture_bloc, true), "Sous un camp, plus de culture à choisir")
	verifier(v.champ_rendement(abri, 61.5) == 0.0, "Sous un camp, le champ ne nourrit plus")

	print("%d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


## Sans guide d'ouverture : la capture de l'écran entier, fiche comprise.
func capture(nom: String) -> void:
	if not "--captures" in OS.get_cmdline_user_args():
		return
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var chemin := "res://../QGIS/rendus/wehrau_%s.png" % nom
	verifier(root.get_texture().get_image().save_png(chemin) == OK, "Capture " + nom)


func cadrer() -> void:
	var boite := AABB(centre(_champs[0]), Vector3.ZERO)
	for f in _champs:
		boite = boite.expand(centre(f))
	var c := boite.get_center()
	jeu.pivot.viser(Vector2(c.x, c.z), maxf(boite.size.x, boite.size.z) * 1.6 + 120.0)
	jeu.pivot.caler(20.0, 55.0)
	var couche := CanvasLayer.new()
	root.add_child(couche)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color("f5f5ec")
	fond.set_content_margin_all(6)
	for k in _champs.size():
		var n := Label.new()
		n.text = ["① maraîchage", "② verger", "③ prairie", "④ céréales"][k]
		n.add_theme_font_size_override("font_size", 20)
		n.add_theme_color_override("font_color", Color("213d36"))
		n.add_theme_stylebox_override("normal", fond)
		couche.add_child(n)
		_reperes.append(n)
	await process_frame


func capture_campagne(nom: String) -> void:
	jeu.interface.reprendre_fiche("i", -1)
	jeu.interface.hide()
	for k in _champs.size():
		_reperes[k].visible = true
		_reperes[k].position = jeu.pivot.camera.unproject_position(centre(_champs[k]))
	if "--captures" in OS.get_cmdline_user_args():
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var chemin := "res://../QGIS/rendus/wehrau_%s.png" % nom
		verifier(root.get_texture().get_image().save_png(chemin) == OK, "Capture " + nom)
	for r in _reperes:
		r.visible = false
	jeu.interface.show()
