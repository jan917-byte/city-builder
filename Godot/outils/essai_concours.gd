extends "res://outils/essai_rebatir.gd"
## --script res://outils/essai_concours.gd -- --ouverture [--captures]
## 🏛️ Le concours (104) : un pour toute la zone sinistrée, puis quatre projets par îlot.

const LAVOIR := 62     # aucune maison détruite : pas de concours (auteur, 2026-10-06)
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
	# ⏸️ Éteint en jeu depuis le 2026-10-08 (l'institut le remplace) : l'essai le rallume.
	jeu.ouverture.concours_actif = true
	var v = jeu.ville
	var ui = jeu.interface
	var m: int = jeu.ouverture.MAISONS
	var t0 := 3.0

	# --- La table : chaque îlot sinistré, chaque façon, une partie neuve.
	var sinistres := []
	for fid in v.ilots:
		if v.base("i", fid, "logements_sinistres") > 0.0:
			sinistres.append(int(fid))
	sinistres.sort()
	print("îlot  nom                        eau m  façon      k€    mois  logts  perdus prochaine  conf. livr.")
	for fid in sinistres:
		for f in v.RECONSTRUCTIONS_ORDRE:
			_apres_etude(t0)
			if not v.facon_permise(fid, f, t0):
				print("%4d  %-26s        %-9s sans concours" % [fid, ui.lieux.nom("i", fid).left(26), f])
				continue
			var duree: float = v.duree_reparation_mois("i", fid, false, f)
			var t1 := t0 + duree + 0.05
			var p0 := float(v.prochaine_crue(t1)["logements_perdus"])
			var k0: float = v.capital(t1)
			var cout: float = v.cout_reparation_ke("i", fid, false, f)
			v.crediter_essai_ke(cout)
			v.commander("i", fid, {"reparer": f}, t0)
			print("%4d  %-26s %5.1f  %-9s %5.0f  %4.1f  %5.0f  %+6.0f            %+5.1f" % [
				fid, ui.lieux.nom("i", fid).left(26),
				v.valeur("i", fid, "hauteur_eau_annonce", t0), f, cout, duree,
				v.valeur("i", fid, "logements", t1),
				float(v.prochaine_crue(t1)["logements_perdus"]) - p0, v.capital(t1) - k0])

	# --- Le noyau : sans concours, seul « comme avant » passe.
	_apres_etude(t0, false)
	v.crediter_essai_ke(5000.0)
	verifier(not v.commander("i", m, {"reparer": "moderne"}, t0)["ok"] and not v.est_repare("i", m),
		"Sans concours, le moderne est refusé")
	verifier(v.facon_permise(m, "tradition", t0), "Sans concours, comme avant reste permis")
	verifier(not v.lancer_concours(LAVOIR, t0), "Le Lavoir, maisons debout, ne lance pas de concours")
	_apres_etude(t0)
	v.crediter_essai_ke(5000.0)
	verifier(not v.commander("i", LAVOIR, {"reparer": "pilotis"}, t0)["ok"],
		"Concours rendu, le Lavoir ne se relève toujours que comme avant")

	# --- 🚪 Le concours vient en dernier : l'étude seule n'en propose pas.
	_apres_etude(t0, false)
	jeu._sur_choix("i", m)
	verifier(ui._fiche_fid == m and ui._rebatir_boutons["tradition"].visible
		and not ui._concours_bouton.visible and not jeu.ouverture.concours_ouvert(),
		"L'étude lue, sans berge rendue, la fiche n'offre que comme avant")
	ui._fermer_fiche()

	# --- La fiche, avant : comme avant, ou le concours.
	_apres_etude(t0, false)
	_portes_concours(true)
	actualiser(t0)
	verifier(jeu.ouverture.concours_ouvert() and "concours" in str(ui.retours.journal[-1]),
		"Une berge rendue et un sol perméable livré : le concours s'annonce : %s" % ui.retours.journal[-1])
	var caisse0: float = v.caisse_ke(t0)
	jeu._sur_choix("i", m)
	verifier(ui._fiche_fid == m and ui._rebatir_boutons["tradition"].visible
		and ui._concours_bouton.visible and not ui._projets_bouton.visible
		and not ui._rebatir_boutons["parc"].visible,
		"Avant le concours, la fiche offre comme avant et « Lancer un concours »")
	jeu.examiner("i", m)
	await capture("concours_01_fiche")
	await cliquer(ui._concours_bouton)
	verifier(ui._pose.get("concours", false) == true, "« Lancer un concours » se pose")
	jeu._rafraichir(true)
	var texte := _effets(ui)
	verifier(texte.begins_with("120") and "mois" in texte, "La fiche annonce son prix et son mois : %s" % texte)
	await cliquer(ui._recap_bouton)
	_portes_concours(false)
	actualiser(t0)
	verifier(v.concours_lance() and absf(caisse0 - v.caisse_ke(t0) - v.CONCOURS_KE) < 0.5,
		"Mettre en place lance le concours et le paie")
	verifier(ui._concours_bouton.visible and ui._concours_bouton.disabled
		and ui._concours_bouton.text == "Concours en cours", "Pendant le mois, la fiche dit qu'on attend")
	await capture("concours_02_en_cours")

	# --- Un mois plus tard : rendu pour toute la zone.
	actualiser(t0 + 1.05)
	verifier(v.concours_rendu(jeu.mois) and ui._projets_bouton.visible and not ui._concours_bouton.visible,
		"Rendu, la fiche ouvre les quatre projets")
	await cliquer(ui._projets_bouton)
	verifier(ui._projets_panneau.visible and "Forgerons" in ui._projets_titre.text,
		"L'écran du concours s'ouvre sur les Forgerons")
	await capture("concours_03_forgerons")

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
		await capture("concours_%02d_%s" % [4 if fid == FOUR else 5, "four" if fid == FOUR else "colombier"])
	verifier(lignes[FOUR]["pilotis"].contains("26 perdus") and lignes[FOUR]["tradition"].contains("26 perdus"),
		"Au Four, les pilotis ne sauvent rien : %s" % lignes[FOUR]["pilotis"])
	verifier(lignes[COLOMBIER]["pilotis"] != lignes[FOUR]["pilotis"],
		"Le Colombier n'a pas les chiffres du Four : %s" % lignes[COLOMBIER]["pilotis"])
	verifier(lignes[COLOMBIER]["parc"].contains("Personne ne rentre"), "Le parc ne rend personne")

	# --- Choisir un projet le pose, l'écran se retire, la fiche engage.
	await cliquer(ui._projets_cartes["pilotis"]["bouton"])
	verifier(str(ui._pose.get("reparer", "")) == "pilotis" and not ui._projets_panneau.visible
		and "pilotis" in ui._projets_bouton.text, "Choisir les pilotis les pose : %s" % ui._projets_bouton.text)
	jeu._rafraichir(false)
	verifier(jeu.apercus_projets.values().all(func(a) -> bool:
		return a.render_target_update_mode == SubViewport.UPDATE_DISABLED),
		"L'écran fermé, les miniatures s'éteignent")
	await cliquer(ui._recap_bouton)
	verifier(v.est_repare("i", COLOMBIER) and v.facon_reparation(COLOMBIER) == "pilotis",
		"Le Colombier se relève sur pilotis")

	# --- Le Lavoir : ses maisons tiennent debout, la fiche n'offre que comme avant.
	jeu.examiner("i", LAVOIR)
	jeu._rafraichir(true)
	verifier(ui._rebatir_boutons["tradition"].visible and not ui._concours_bouton.visible
		and not ui._projets_bouton.visible and ui._repare_texte.text == "",
		"Au Lavoir, concours rendu, la fiche n'offre que comme avant")
	await capture("concours_06_lavoir")

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
