extends "res://outils/essai_rebatir.gd"
## --script res://outils/essai_concours.gd -- --ouverture [--captures]
## 🏛️ Le concours d'architecture, un par îlot (auteur, 2026-10-21) : seul chemin vers les projets
## neufs ; annoncé par une carte, 15 jours et 50 k€, puis trois lauréats qui dépendent du lieu.

const LAVOIR := 62     # aucune maison détruite : ni projets ni concours (auteur, 2026-10-06)
const COLOMBIER := 63  # pavillons


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

	# --- La table : chaque îlot aux maisons tombées, sa situation, ses lauréats et leur prix.
	_apres_etude(t0, true)
	print("îlot  nom                        situation  lauréats (k€)")
	var situations := {}
	for fid in v.ilots:
		if not v.concours_utile(int(fid)):
			continue
		var prix := []
		for f in v.laureats(int(fid)):
			prix.append("%s %.0f" % [f, v.cout_reparation_ke("i", int(fid), false, f)])
		situations[v.situation(int(fid))] = true
		print("%4d  %-26s %-9s  %s" % [fid, ui.lieux.nom("i", int(fid)).left(26), v.situation(int(fid)),
			", ".join(prix)])
	verifier(situations.size() >= 3, "Au moins trois situations, donc trois listes de lauréats : %s"
		% ", ".join(situations.keys()))

	# --- Le noyau : sans concours, comme avant seul ; le Lavoir, comme avant seul.
	_apres_etude(t0)
	v.crediter_essai_ke(5000.0)
	verifier(not v.facon_permise(m, "moderne", t0) and not v.facon_permise(m, "surelevees", t0)
		and not v.commander("i", m, {"reparer": "moderne"}, t0)["ok"] and v.facon_permise(m, "tradition", t0),
		"Sans concours, aucun projet neuf")
	verifier(not v.facon_permise(LAVOIR, "moderne", t0) and v.facon_permise(LAVOIR, "tradition", t0)
		and v.laureats(LAVOIR).is_empty(), "Au Lavoir, comme avant seul")
	verifier(not v.lancer_concours(LAVOIR, t0), "Le Lavoir, maisons debout, ne lance pas de concours")

	# --- La fiche, l'étude parue : la carte du concours, puis deux choix.
	_apres_etude(t0)
	var caisse0: float = v.caisse_ke(t0)
	jeu._sur_choix("i", m)
	jeu._rafraichir(true)
	var o = jeu.ouverture
	verifier(o.carte == "concours" and o.annonce.visible and "50 k€" in o._annonce_texte.text
		and "jours" in o._annonce_texte.text,
		"La première fiche aux maisons tombées annonce le concours (%s, %s) : %s" % [o.carte,
			o.annonce.visible, o._annonce_texte.text])
	await capture("concours_00_carte")
	await cliquer(o.annonce_principal)
	jeu._rafraichir(true)
	verifier(not o.annonce.visible and o.carte_concours == 2, "La carte se ferme au clic")
	verifier(ui._fiche_fid == m and ui._rebatir_boutons["tradition"].visible
		and ui._rebatir_boutons["tradition"].text == "Reconstruire l'îlot"
		and not ui._rebatir_boutons["pilotis"].visible and not ui._projets_bouton.visible
		and ui._concours_bouton.visible and ui._concours_bouton.text == "Lancer un concours d'architecture",
		"La fiche n'offre que reconstruire et le concours : %s" % ui._concours_bouton.text)
	jeu.examiner("i", m)
	jeu._rafraichir(true)
	verifier(o.carte == "", "La carte ne revient pas")
	await capture("concours_01_fiche")
	await cliquer(ui._concours_bouton)
	verifier(ui._pose.get("concours", false) == true, "« Lancer un concours » se pose")
	jeu._rafraichir(true)
	# 💶 Prix et durée sur le bouton, plus dans les conséquences (auteur, 2026-10-20).
	var texte := str(ui._recap_bouton.get_meta("prix", ""))
	verifier("50 k€" in texte and "jours" in texte, "Le bouton annonce son prix et sa durée : %s" % texte)
	await cliquer(ui._recap_bouton)
	actualiser(t0)
	verifier(v.concours_lance(m) and absf(caisse0 - v.caisse_ke(t0) - v.CONCOURS_KE) < 0.5,
		"Mettre en place lance le concours et le paie")
	verifier(not v.concours_lance(COLOMBIER), "Le concours ne vaut que pour son îlot")
	verifier(ui._concours_bouton.visible and ui._concours_bouton.disabled
		and ui._concours_bouton.text == "Concours en cours" and ui._rebatir_boutons["tradition"].visible
		and not ui._projets_bouton.visible,
		"Pendant le concours, la fiche dit qu'on attend, et reconstruire reste offert")
	var site := "i%d" % m
	verifier(not jeu.travaux.sites.has(site) or not (jeu.travaux.sites[site] as Node3D).visible,
		"Pendant le concours, ni grue ni palissade sur l'îlot")
	await capture("concours_03_en_cours")

	# --- Quinze jours plus tard : les lauréats de CET îlot, au prix plein.
	actualiser(t0 + v.CONCOURS_MOIS + 0.05)
	verifier(v.concours_rendu(m, jeu.mois) and ui._projets_bouton.visible and not ui._concours_bouton.visible
		and ui._projets_bouton.text == "Voir les projets des lauréats",
		"Rendu, le concours s'efface et les projets paraissent : %s" % ui._projets_bouton.text)
	verifier("trois projets" in str(ui.retours.journal[-1]), "Le bandeau le dit : %s" % ui.retours.journal[-1])
	verifier(is_equal_approx(v.cout_reparation_ke("i", m, false, "moderne", jeu.mois),
		v.base("i", m, "cout_reparation_ke") * 1.3), "Plus de rabais : le moderne au prix plein")
	var lm: Array = v.laureats(m)
	verifier(lm.all(func(f) -> bool: return v.facon_permise(m, f, jeu.mois))
		and not v.facon_permise(m, "parc", jeu.mois),
		"Rendu, ses trois lauréats s'offrent, pas ceux d'ailleurs : %s" % ", ".join(lm))
	await _ouvrir_projets(ui)
	verifier(ui._projets_panneau.visible and "Forgerons" in ui._projets_titre.text
		and ui._projets_titre.text.begins_with("Lauréats") and _noms(ui) == _noms_attendus(v, m)
		and not "concours" in _lignes(ui, 0),
		"L'écran des lauréats : %s" % ", ".join(_noms(ui)))
	await capture("concours_04_forgerons")

	# --- D'autres îlots, d'autres lauréats ; l'institut garde ce qui est nouveau.
	var vus := {}
	for fid in [FOUR, COLOMBIER]:
		v.crediter_essai_ke(v.CONCOURS_KE)
		verifier(v.lancer_concours(fid, jeu.mois), "Le concours se lance aussi à l'îlot %d" % fid)
	v._recherche.erase(jeu.Recherche.PILOTIS)
	v._recherche.erase(jeu.Recherche.PARC)
	actualiser(jeu.mois + v.CONCOURS_MOIS + 0.05)
	for fid in [FOUR, COLOMBIER]:
		jeu.examiner("i", fid)
		jeu._rafraichir(true)
		verifier(not ui._projets_panneau.visible, "Changer d'îlot referme l'écran")
		await _ouvrir_projets(ui)
		jeu._rafraichir(false)
		verifier(jeu.selection.sel_fid == fid and jeu._contour_fid == fid
			and jeu.cam_masque.global_transform == jeu.pivot.camera.global_transform,
			"Le trait entoure l'îlot %d, avec la caméra recadrée" % fid)
		verifier(jeu.apercus_projets.values().all(func(a) -> bool:
			return a.render_target_update_mode != SubViewport.UPDATE_DISABLED),
			"Les trois cartes montrent leur miniature")
		verifier(_noms(ui) == _noms_attendus(v, fid), "Îlot %d : %s" % [fid, ", ".join(_noms(ui))])
		vus[fid] = _noms(ui)
		await capture("concours_%02d_%s" % [5 if fid == FOUR else 6, "four" if fid == FOUR else "colombier"])
		if fid == FOUR:
			# 🔒 Pilotis et parc pas encore mis au point : bloqués, et la carte dit où les apprendre.
			for f in ["pilotis", "parc"]:
				var i: int = v.laureats(FOUR).find(f)
				verifier(i >= 0 and ui._projets_cartes[i]["bouton"].disabled
					and ui._projets_cartes[i]["bouton"].text == "À mettre au point à l'institut"
					and "pas encore maîtrisée" in _lignes(ui, i)
					and ui._projets_cartes[i]["vue"].modulate.a < 1.0,
					"Au Four, %s attend l'institut : %s" % [f, _lignes(ui, max(i, 0))])
			# 🏢 Le moderne s'offre sans l'institut (auteur, 2026-10-21).
			var moderne: int = v.laureats(FOUR).find("moderne")
			verifier(moderne >= 0 and not ui._projets_cartes[moderne]["bouton"].disabled
				and not "pas encore maîtrisée" in _lignes(ui, moderne),
				"Au Four, le moderne s'offre sans l'institut : %s" % _lignes(ui, max(moderne, 0)))
			v._recherche[jeu.Recherche.PILOTIS] = 0.0
			v._recherche[jeu.Recherche.PARC] = 0.0
			jeu._rafraichir(true)
			verifier(not ui._projets_cartes[v.laureats(FOUR).find("pilotis")]["bouton"].disabled,
				"Mis au point, les pilotis s'offrent sans rouvrir l'écran")
	verifier(vus[FOUR] != vus[COLOMBIER] and vus[FOUR] != _noms_attendus(v, m),
		"Trois îlots, trois listes de lauréats")

	# --- Choisir un projet le pose, l'écran se retire, la fiche engage au prix plein.
	var k: int = v.laureats(COLOMBIER).find("pilotis")
	await cliquer(ui._projets_cartes[k]["bouton"])
	verifier(str(ui._pose.get("reparer", "")) == "pilotis" and not ui._projets_panneau.visible
		and "pilotis" in ui._projets_bouton.text, "Choisir les pilotis les pose : %s" % ui._projets_bouton.text)
	jeu._rafraichir(false)
	verifier(jeu.apercus_projets.values().all(func(a) -> bool:
		return a.render_target_update_mode == SubViewport.UPDATE_DISABLED),
		"L'écran fermé, les miniatures s'éteignent")
	var caisse1: float = v.caisse_ke(jeu.mois)
	var prix: float = v.base("i", COLOMBIER, "cout_reparation_ke") * 1.6
	await cliquer(ui._recap_bouton)
	verifier(v.est_repare("i", COLOMBIER) and v.facon_reparation(COLOMBIER) == "pilotis"
		and absf(caisse1 - v.caisse_ke(jeu.mois) - prix) < 0.5,
		"Le Colombier se relève sur pilotis, au prix plein (%.0f k€)" % prix)

	# --- Le Lavoir : ses maisons tiennent debout, ni projets ni concours.
	jeu.examiner("i", LAVOIR)
	jeu._rafraichir(true)
	verifier(ui._rebatir_boutons["tradition"].visible and not ui._concours_bouton.visible
		and not ui._projets_bouton.visible
		and ui._rebatir_boutons["tradition"].text == "Nettoyer et remettre en état",
		"Au Lavoir, la fiche n'offre que nettoyer : %s" % ui._rebatir_boutons["tradition"].text)
	await capture("concours_07_lavoir")

	# --- La sauvegarde garde les concours.
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	verifier(not v.concours_lance_ailleurs(), "Recommencer efface les concours")
	jeu._sur_reprise()
	verifier(v.concours_rendu(m, jeu.mois) and v.concours_rendu(FOUR, jeu.mois),
		"La reprise garde les concours rendus")

	print("CONCOURS : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs > 0 else 0)


## ⚠️ Avec fenêtre sur Mac, ce clic se perd (2026-10-19) : l'écran s'ouvre alors à la main.
func _ouvrir_projets(ui) -> void:
	await cliquer(ui._projets_bouton)
	if not ui._projets_panneau.visible and DisplayServer.get_name() != "headless":
		ui.ouvrir_projets()
		jeu._rafraichir(true)


func _noms(ui) -> Array:
	var out := []
	for i in ui._projets_cartes:
		out.append((ui._projets_cartes[i]["nom"] as Label).text)
	return out


func _noms_attendus(v, fid: int) -> Array:
	return v.laureats(fid).map(func(f) -> String: return str(v.RECONSTRUCTIONS[f]["nom"]))


func _lignes(ui, i: int) -> String:
	var out := []
	for h in ui._projets_cartes[i]["lignes"].get_children():
		out.append((h.get_child(1) as Label).text)
	return " · ".join(out)
