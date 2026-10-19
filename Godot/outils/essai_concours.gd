extends "res://outils/essai_rebatir.gd"
## --script res://outils/essai_concours.gd -- --ouverture [--captures]
## 🏛️ Le concours facultatif (104 revue, 2026-10-19) : les quatre projets sans lui ;
## lancé, un mois et 120 k€ pour toute la zone, puis les projets neufs coûtent moins.

const LAVOIR := 62     # aucune maison détruite : ni projets ni concours (auteur, 2026-10-06)
const COLOMBIER := 63  # 4,3 m d'eau
const FOUR := 69       # 5,6 m : les pilotis n'y sauvent rien


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_concours.wehrau"
	jeu._sur_mode(false)
	jeu.recit.terminer()
	jeu._sur_vitesse(0.0)
	# Le chapitre de l'étude, après la première année (2026-10-18).
	jeu.ouverture.premiere_annee = false
	var v = jeu.ville
	var ui = jeu.interface
	var m: int = jeu.ouverture.MAISONS
	var t0 := 3.0
	var rabais: float = v.CONCOURS_LAUREAT_PRIX

	# --- La table : chaque îlot sinistré, chaque façon, sans puis avec le concours.
	var sinistres := []
	for fid in v.ilots:
		if v.base("i", fid, "logements_sinistres") > 0.0:
			sinistres.append(int(fid))
	sinistres.sort()
	print("îlot  nom                        façon      sans k€  lauréat k€")
	for fid in sinistres:
		_apres_etude(t0, true)
		for f in v.RECONSTRUCTIONS_ORDRE:
			if not v.facon_permise(fid, f, t0):
				print("%4d  %-26s %-9s  non offert" % [fid, ui.lieux.nom("i", fid).left(26), f])
				continue
			print("%4d  %-26s %-9s  %7.0f  %10.0f" % [fid, ui.lieux.nom("i", fid).left(26), f,
				v.cout_reparation_ke("i", fid, false, f), v.cout_reparation_ke("i", fid, false, f, t0)])

	# --- Le noyau : sans concours, les quatre façons ; le Lavoir, comme avant ou pilotis.
	_apres_etude(t0)
	v.crediter_essai_ke(5000.0)
	var plein: float = v.cout_reparation_ke("i", m, false, "moderne", t0)
	verifier(is_equal_approx(plein, v.base("i", m, "cout_reparation_ke") * 1.3),
		"Sans concours, le moderne coûte son prix plein : %.0f k€" % plein)
	verifier(v.commander("i", m, {"reparer": "moderne"}, t0)["ok"] and v.facon_reparation(m) == "moderne",
		"Sans concours, le moderne s'engage")
	verifier(not v.facon_permise(LAVOIR, "moderne", t0) and not v.facon_permise(LAVOIR, "parc", t0)
		and v.facon_permise(LAVOIR, "tradition", t0), "Au Lavoir, ni moderne ni parc")
	verifier(not v.lancer_concours(LAVOIR, t0), "Le Lavoir, maisons debout, ne lance pas de concours")

	# --- La fiche, l'étude parue : reconstruire tout de suite, les projets, ou le concours.
	_apres_etude(t0)
	var caisse0: float = v.caisse_ke(t0)
	jeu._sur_choix("i", m)
	jeu._rafraichir(true)
	verifier(ui._fiche_fid == m and ui._rebatir_boutons["tradition"].visible
		and ui._projets_bouton.visible and ui._concours_bouton.visible
		and "20 %" in ui._concours_bouton.text and not ui._rebatir_boutons["parc"].visible,
		"La fiche offre reconstruire, les quatre projets et le concours : %s" % ui._concours_bouton.text)
	jeu.examiner("i", m)
	await capture("concours_01_fiche")
	await cliquer(ui._projets_bouton)
	verifier(ui._projets_panneau.visible and ui._projets_titre.text.begins_with("Projets")
		and not "concours" in _lignes(ui, "moderne"),
		"Sans concours, les projets s'ouvrent au prix plein : %s" % _lignes(ui, "moderne"))
	await capture("concours_02_projets_sans")
	ui.fermer_projets()
	await cliquer(ui._concours_bouton)
	verifier(ui._pose.get("concours", false) == true, "« Lancer un concours » se pose")
	jeu._rafraichir(true)
	var texte := _effets(ui)
	verifier(texte.begins_with("120") and "mois" in texte, "La fiche annonce son prix et son mois : %s" % texte)
	await cliquer(ui._recap_bouton)
	actualiser(t0)
	verifier(v.concours_lance() and absf(caisse0 - v.caisse_ke(t0) - v.CONCOURS_KE) < 0.5,
		"Mettre en place lance le concours et le paie")
	verifier(ui._concours_bouton.visible and ui._concours_bouton.disabled
		and ui._concours_bouton.text == "Concours en cours" and ui._rebatir_boutons["tradition"].visible,
		"Pendant le mois, la fiche dit qu'on attend, et reconstruire reste offert")
	await capture("concours_03_en_cours")

	# --- Un mois plus tard : rendu pour toute la zone, les projets neufs à −20 %.
	actualiser(t0 + 1.05)
	verifier(v.concours_rendu(jeu.mois) and ui._projets_bouton.visible and not ui._concours_bouton.visible,
		"Rendu, le bouton du concours s'efface")
	verifier("20 %" in str(ui.retours.journal[-1]), "Le bandeau dit le rabais : %s" % ui.retours.journal[-1])
	verifier(is_equal_approx(v.cout_reparation_ke("i", m, false, "moderne", jeu.mois), plein * rabais)
		and is_equal_approx(v.cout_reparation_ke("i", m, false, "tradition", jeu.mois),
			v.base("i", m, "cout_reparation_ke")),
		"Lauréat : le moderne à −20 %, « comme avant » inchangé")
	await cliquer(ui._projets_bouton)
	verifier(ui._projets_panneau.visible and "Forgerons" in ui._projets_titre.text
		and ui._projets_titre.text.begins_with("Lauréats")
		and "concours" in _lignes(ui, "moderne") and not "concours" in _lignes(ui, "tradition"),
		"L'écran des lauréats : %s" % _lignes(ui, "moderne"))
	await capture("concours_04_forgerons")

	# --- Les mêmes projets, d'autres chiffres : l'eau ne monte pas pareil.
	var lignes := {}
	for fid in [FOUR, COLOMBIER]:
		jeu.examiner("i", fid)
		jeu._rafraichir(true)
		verifier(not ui._projets_panneau.visible, "Changer d'îlot referme l'écran")
		await cliquer(ui._projets_bouton)
		jeu._rafraichir(false)
		verifier(jeu.selection.sel_fid == fid and jeu._contour_fid == fid
			and jeu.cam_masque.global_transform == jeu.pivot.camera.global_transform,
			"Le trait entoure l'îlot %d, avec la caméra recadrée" % fid)
		verifier(jeu.apercus_projets.values().all(func(a) -> bool:
			return a.render_target_update_mode != SubViewport.UPDATE_DISABLED),
			"Les quatre cartes montrent leur miniature")
		lignes[fid] = {}
		for f in v.RECONSTRUCTIONS_ORDRE:
			lignes[fid][f] = _lignes(ui, f)
		await capture("concours_%02d_%s" % [5 if fid == FOUR else 6, "four" if fid == FOUR else "colombier"])
	verifier(lignes[FOUR]["pilotis"].contains("26 perdus") and lignes[FOUR]["tradition"].contains("26 perdus"),
		"Au Four, les pilotis ne sauvent rien : %s" % lignes[FOUR]["pilotis"])
	verifier(lignes[COLOMBIER]["pilotis"] != lignes[FOUR]["pilotis"],
		"Le Colombier n'a pas les chiffres du Four : %s" % lignes[COLOMBIER]["pilotis"])
	verifier(lignes[COLOMBIER]["parc"].contains("Personne ne rentre"), "Le parc ne rend personne")

	# --- Choisir un projet le pose, l'écran se retire, la fiche engage au prix lauréat.
	await cliquer(ui._projets_cartes["pilotis"]["bouton"])
	verifier(str(ui._pose.get("reparer", "")) == "pilotis" and not ui._projets_panneau.visible
		and "pilotis" in ui._projets_bouton.text, "Choisir les pilotis les pose : %s" % ui._projets_bouton.text)
	jeu._rafraichir(false)
	verifier(jeu.apercus_projets.values().all(func(a) -> bool:
		return a.render_target_update_mode == SubViewport.UPDATE_DISABLED),
		"L'écran fermé, les miniatures s'éteignent")
	var caisse1: float = v.caisse_ke(jeu.mois)
	var prix_laureat: float = v.cout_reparation_ke("i", COLOMBIER, false, "pilotis", jeu.mois)
	await cliquer(ui._recap_bouton)
	verifier(v.est_repare("i", COLOMBIER) and v.facon_reparation(COLOMBIER) == "pilotis"
		and absf(caisse1 - v.caisse_ke(jeu.mois) - prix_laureat) < 0.5,
		"Le Colombier se relève sur pilotis, payé au prix lauréat (%.0f k€)" % prix_laureat)

	# --- Le Lavoir : ses maisons tiennent debout, ni projets ni concours.
	jeu.examiner("i", LAVOIR)
	jeu._rafraichir(true)
	verifier(ui._rebatir_boutons["tradition"].visible and not ui._concours_bouton.visible
		and not ui._projets_bouton.visible,
		"Au Lavoir, la fiche n'offre que reconstruire (et les pilotis)")
	await capture("concours_07_lavoir")

	# --- La sauvegarde garde le concours.
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	verifier(not v.concours_lance(), "Recommencer efface le concours")
	jeu._sur_reprise()
	verifier(v.concours_rendu(jeu.mois), "La reprise garde le concours rendu")

	print("CONCOURS : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs > 0 else 0)


func _lignes(ui, f: String) -> String:
	var out := []
	for h in ui._projets_cartes[f]["lignes"].get_children():
		out.append((h.get_child(1) as Label).text)
	return " · ".join(out)
