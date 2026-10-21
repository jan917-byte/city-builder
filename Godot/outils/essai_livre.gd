extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_livre.gd -- --ouverture [--captures]
## 📖 Le livre des concepts (101) : la carte des sols, la place-parking rendue
## perméable, les leviers grisés, la jauge de la prochaine crue, la page qui s'ouvre.


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_livre.wehrau"
	jeu._sur_mode(false)
	jeu.recit.terminer()
	jeu._sur_vitesse(0.0)
	# Le chapitre de l'étude, après la première année (2026-10-18).
	jeu.ouverture.premiere_annee = false
	var o = jeu.ouverture
	var ui = jeu.interface
	var v = jeu.ville
	jeu._sur_reset()
	var champs: Array = o._champs_accessibles()
	v.abriter(champs[0], 0.0)
	v.abriter(champs[1], 0.0)
	actualiser(1.0)
	verifier(not o.concept_ouvert("eponge") and not ui._menu_boutons["sols"].visible,
		"Avant l'étude, ni page ni carte des sols")

	# --- L'étude parue : la ville-éponge s'ouvre, le reste attend.
	var pont: int = v.ponts_coupes()[0]
	v.reparer("r", pont, 0.0, true)
	o.pont_termine = true
	o.pont_termine_mois = 4.0
	o.etude_parue = true
	o.etude_mois = 4.0
	o.carte_etude = 2
	o.etude_lue = true
	o.prochaine_vue = true
	o.institut_vu = true
	o.biblio_vue = true
	var t := 4.0
	actualiser(t)
	# 🌳 L'étude ouvre la page ; les leviers s'achètent à l'institut (auteur, 2026-10-18).
	# 🌊 Berge et pré mis de côté (auteur, 2026-10-21) : fermés, même achetés.
	verifier(o.concept_ouvert("eponge") and o.levier_ferme("berge") == "Plus tard."
		and o.levier_ferme("pre") == "Plus tard." and not ui._menu_boutons["sols"].visible,
		"L'étude parue : la page de la ville-éponge, la berge et le pré pour plus tard")
	# Comme en jeu : abriter et rouvrir le pont ont payé deux points.
	v._objectifs["abriter"] = t
	v._objectifs["pont"] = t
	for l in ["permeable", "vert"]:
		verifier("institut" in o.levier_ferme(l), "Fermé tant qu'il n'est pas acheté : %s" % l)
	jeu._repere("ville")
	ui.ouvrir_lieu("universite")
	actualiser(t)
	verifier(ui._etude_bloc.visible and not ui._leviers_crue["berge"].is_visible_in_tree()
		and not ui._etude_biblio.has_meta("anneau") and o.page_nouvelle("eponge"),
		"L'université renvoie à la bibliothèque, sans jaune ; aucun levier chez elle")
	await cliquer(ui._etude_biblio)
	actualiser(t)
	verifier(ui._page_bloc.visible and not ui._leviers_crue["berge"].is_visible_in_tree()
		and not ui._leviers_crue["vert"].is_visible_in_tree()
		and not ui._leviers_crue["permeable"].is_visible_in_tree() and not ui._leviers_crue["pre"].is_visible_in_tree(),
		"La page de la ville-éponge ne propose aucun levier avant l'institut")
	await capture("livre_00_page_eponge")
	ui._fermer_campus()
	ui._sur_rail("dangers")
	await cliquer(ui._onglets_crue["prochaine"])
	verifier(not ui._leviers_crue["berge"].is_visible_in_tree(), "Dangers ne propose aucun levier")
	jeu._sur_theme("")
	# L'îlot relevé, un objectif de plus : de quoi acheter le sol perméable.
	v._objectifs["ilot"] = t
	verifier(v.acquerir_recherche("permeable", t), "Les objectifs achètent le sol perméable")
	actualiser(t)
	verifier(ui._menu_boutons["sols"].visible and o.levier_ferme("permeable") == ""
		and o.levier_ferme("vert") != "" and o.levier_ferme("pre") != "",
		"Le sol perméable acheté ouvre la carte des sols, pas les toits verts ni le pré")
	verifier(not "concours" in str(ui.retours.journal).to_lower(), "Le concours ne s'annonce pas : la fiche le propose")
	for l in ["solaire", "rue", "arbres"]:
		verifier(o.levier_ferme(l) != "", "Fermé : %s · %s" % [l, o.levier_ferme(l)])
	var conds: Array = o.conditions_reparee()
	print("Ville réparée : ", conds)
	verifier(conds[0][1] and conds[1][1] and not conds[2][1],
		"Abrités et rien de coupé, mais aucun îlot relevé : la ville n'est pas réparée")

	# --- La carte des sols.
	ui._sur_rail("sols")
	jeu._repere("ville")
	actualiser(t)
	var part0: float = v.part_sol_permeable(t)
	verifier(ui._sols_bloc.visible and "%" in ui._sols_chiffre.text,
		"La carte des sols dit la part qui boit : %s" % ui._sols_chiffre.text)
	await capture("livre_01_sols")
	jeu._viser_objet("i", o.PARKING, 260.0)
	actualiser(t)
	await capture("livre_02_sols_parking")

	# --- Une fiche dont l'onglet attend une page : le solaire n'y est pas encore.
	jeu._sur_theme("")
	jeu._sur_choix("i", o.SOLAIRE)
	ui.ouvrir_onglet("energie")
	ui._maj_fiche()
	verifier(not ui._solaire_bloc.visible, "Le solaire n'est pas encore dans la fiche")
	await capture("livre_03_solaire_ferme")

	# --- La jauge : le levier du parking, pris à la bibliothèque, ouvre Dangers › Prochaine crue.
	jeu._repere("ville")
	ui.ouvrir_lieu("bibliotheque", "eponge")
	actualiser(t)
	await cliquer(ui._prochaine_valeurs["levier_permeable"])
	ui._maj_fiche()
	actualiser(t)
	ui._maj_prochaine()
	var j = ui._jauge_crue
	print("Jauge, en m d'eau en moins : livré %.2f · engagé %.2f · avec le réglage %.2f · seuil %.2f" % [j.livre, j.engage, j.apercu, j.seuil])
	verifier(jeu.theme == "dangers" and ui._diagnostic_panneau.visible and ui._fiche_fid == o.PARKING,
		"Le levier ouvre la place-parking, la prochaine crue reste à côté")
	verifier(ui._permeable_bloc.visible and ui._reglages().has("permeable"),
		"Le sol perméable est posé dans la fiche : %s" % ui._permeable_bouton.text)
	# Seuil 0 possible : dès 25 cm de moins, les îlots 62, 63 et 64 gardent des maisons.
	verifier(j.apercu > j.engage + 0.05 and j.seuil >= 0.0,
		"La jauge montre le réglage avant de payer : %.2f m" % j.apercu)
	await capture("livre_04_jauge_apercu")

	# --- On paie : le sol boit, la crue baisse partout.
	var eau0 := float(v.prochaine_crue(t)["eau_pire_m"])
	v.crediter_essai_ke(2000.0)
	var cout: float = v.cout_permeable_ke(o.PARKING)
	await cliquer(ui._recap_bouton)
	verifier(v._permeable.has(o.PARKING) and v.permeable_en_cours(o.PARKING, t),
		"Engagé : %.0f k€, %s" % [cout, ui._duree(v.PERMEABLE_MOIS)])
	actualiser(t + 0.1)
	ui._maj_prochaine()
	verifier(j.engage > j.livre + 0.05 and j.apercu < 0.0,
		"Pendant le chantier, la jauge hachure ce qui va baisser : %.2f m" % j.engage)
	var t2: float = t + v.PERMEABLE_MOIS + 0.2
	actualiser(t2)
	var eau1: float = float(v.prochaine_crue(t2)["eau_pire_m"])
	print("Place-parking : %.0f k€, sol en dur %d %% → %d %%, crue %.2f → %.2f m, ville qui boit %d %% → %d %%" % [
		cout, int(v.base("i", o.PARKING, "impermeabilise") * 100.0),
		int(v.valeur("i", o.PARKING, "impermeabilise", t2) * 100.0), eau0, eau1,
		int(part0 * 100.0), int(v.part_sol_permeable(t2) * 100.0)])
	verifier(eau1 < eau0 - 0.05 and v.part_sol_permeable(t2) > part0,
		"Livré : la crue baisse et la ville boit plus")
	# 🏛️ Le concours est facultatif (104 revue, 2026-10-19) : aucun sol ne l'ouvre, aucune annonce.
	verifier(not "concours" in str(ui.retours.journal[-1]),
		"Un sol livré n'annonce pas de concours : %s" % ui.retours.journal[-1])
	verifier(v.valeur("i", o.PARKING, "stationnement", t2) >= v.base("i", o.PARKING, "stationnement"),
		"Les places restent")
	ui._fermer_fiche()
	ui._sur_rail("sols")
	jeu._viser_objet("i", o.PARKING, 260.0)
	actualiser(t2)
	await capture("livre_05_sols_parking_apres")

	# --- La bibliothèque.
	jeu._sur_theme("")
	ui.ouvrir_lieu("bibliotheque")
	actualiser(t2)
	verifier(ui._biblio_bloc.visible and not ui._etude_bloc.visible and not o.page_nouvelle("eponge"),
		"La bibliothèque a son îlot, la ville-éponge y est déjà lue")
	await capture("livre_06_bibliotheque")
	ui.ouvrir_page("eponge")
	actualiser(t2)
	verifier(ui._page_bloc.visible and not o.page_nouvelle("eponge") and "pluie" in ui._page_texte.text,
		"La page s'ouvre et n'est plus nouvelle")
	await capture("livre_07_page_eponge")
	await cliquer(ui._page_voir)
	verifier(jeu.theme == "sols", "« Voir à Wehrau » ouvre la carte des sols")
	await capture("livre_08_voir_a_wehrau")

	# --- La ville réparée : un îlot sinistré relevé, la page « Ne pas aggraver » s'ouvre.
	jeu._sur_theme("")
	# Comme avant : au Lavoir, aucune maison n'est tombée.
	var lavoir := 62
	jeu._sur_commande("i", lavoir, {"reparer": "tradition"})
	var t3: float = t2 + v.duree_reparation_mois("i", lavoir, false, "tradition") + 0.1
	actualiser(t3)
	verifier(o.ville_reparee() and o.concept_ouvert("attenuer") and o.levier_ferme("solaire") != "",
		"Un îlot relevé : la page s'ouvre, le solaire attend l'institut")
	v._recherche["vert"] = t3
	v._recherche["solaire"] = t3
	# ⚡ Mis de côté (auteur, 2026-10-21) : même acheté, le solaire reste fermé.
	verifier(o.levier_ferme("solaire") == "Plus tard.", "Acheté, le solaire reste pour plus tard")
	verifier("Ne pas aggraver" in str(ui.retours.journal[-1]), "Le bandeau annonce la page : %s" % ui.retours.journal[-1])
	jeu._sur_choix("i", o.SOLAIRE)
	ui.ouvrir_onglet("energie")
	ui._maj_fiche()
	# ⚡ L'onglet énergie est caché pour l'instant (auteur, 2026-10-21).
	verifier(not ui._onglet_boutons["energie"].visible, "La fiche du toit n'a pas d'onglet énergie")
	verifier(o.levier_ferme("arbres") != "", "Les arbres attendent l'institut")

	jeu._sur_sauvegarde()
	jeu._sur_reset()
	verifier(o.pages_lues.is_empty() and not o.concept_ouvert("eponge"), "Recommencer referme le livre")
	jeu._sur_reprise()
	actualiser(jeu.mois)
	verifier(o.pages_lues.has("eponge") and v._permeable.has(o.PARKING),
		"La reprise garde la page lue et le parking")
	print("LIVRE : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs else 0)
