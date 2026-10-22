extends "res://outils/essai_ouverture.gd"
## --script res://outils/apercu_chantiers.gd -- --ouverture --captures
## 🚧 La carte des chantiers en bas à droite, pleine : une étude et quatre îlots rebâtis.
## → QGIS/rendus/wehrau_ouverture_chantiers_carte.png (le recadrage) et _ecran.png


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_chantiers.wehrau"
	jeu._sauter_au_pont()
	jeu.ouverture.pont_termine = true
	var v = jeu.ville
	var t: float = jeu.mois
	v.crediter_essai_ke(v.ETUDE_KE)
	verifier(v.commander_etude(t), "L'étude de la crue est commandée")
	var sinistres := []
	for fid in v.ilots:
		if v.concours_utile(int(fid)) and not v.est_repare("i", int(fid)):
			sinistres.append(int(fid))
	sinistres.sort()
	for fid in sinistres.slice(0, 4):
		v.crediter_essai_ke(v.cout_reparation_ke("i", fid, false, "tradition"))
		jeu._sur_commande("i", fid, {"reparer": "tradition"})
		t += 0.15
		jeu.trafic.avancer(t)
		actualiser(t)
	var retours = jeu.interface.retours
	verifier(retours.chantiers.visible, "La carte des chantiers est ouverte")
	await capture("chantiers_ecran")
	if "--captures" in OS.get_cmdline_user_args():
		var r: Rect2 = retours.pile.get_global_rect().grow(12)
		var img: Image = root.get_texture().get_image().get_region(Rect2i(r))
		img.save_png("res://../QGIS/rendus/wehrau_ouverture_chantiers_carte.png")
		print("Carte des chantiers : %d × %d px" % [int(retours.chantiers.size.x), int(retours.chantiers.size.y)])
	print("Échecs : %d" % echecs)
	quit(1 if echecs else 0)
