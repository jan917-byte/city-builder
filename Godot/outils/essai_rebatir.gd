extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_rebatir.gd -- --ouverture [--captures]
## 🏗️ Les façons de relever un îlot sinistré (95) : comme avant, et les trois lauréats de son
## concours, qui dépendent du lieu (auteur, 2026-10-21). Mesurées sur chaque îlot, puis vues aux Forgerons.

const FOUR := 69   # petit, tout est tombé : les lauréats qui rendent le sol


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_rebatir.wehrau"
	jeu._sur_mode(false)
	jeu.recit.terminer()
	jeu._sur_vitesse(0.0)
	# Le chapitre de l'étude, après la première année (2026-10-18).
	jeu.ouverture.premiere_annee = false
	var o = jeu.ouverture
	var ui = jeu.interface
	var v = jeu.ville
	var m: int = o.MAISONS
	var t0 := 3.0

	# --- Le modèle : une partie neuve par îlot et par façon offerte, la même commande.
	var sinistres := []
	for fid in v.ilots:
		if v.concours_utile(int(fid)):
			sinistres.append(int(fid))
	sinistres.sort()
	print("îlot  nom                     situation  façon        coût k€  mois  confiance(déc/livr)  logements  perdus à la prochaine  crue cm  au camp")
	var mesures := {}
	var dernier := []
	for fid in sinistres:
		mesures[fid] = {}
		for f in ["tradition"] + v.laureats(fid):
			_apres_etude(t0, true)
			var duree: float = v.duree_reparation_mois("i", fid, false, f)
			var t1 := t0 + duree + 0.05
			var avant := {"perdus": float(v.prochaine_crue(t1)["logements_perdus"]),
				"eau": float(v.prochaine_crue(t1)["eau_pire_m"]), "camp": v.reloges(t1),
				"k": v.capital(t0)}
			var cout: float = v.cout_reparation_ke("i", fid, false, f)
			# Le Verger coûte plus que la caisse de départ : l'essai mesure, il ne choisit pas.
			v.crediter_essai_ke(cout)
			jeu._sur_commande("i", fid, {"reparer": f})
			actualiser(t0)
			var x := {"cout": cout, "duree": duree,
				"k_decision": v.capital(t0) - float(avant["k"]),
				"k_livraison": v.capital(t1) - float(avant["k"]),
				"logements": v.valeur("i", fid, "logements", t1),
				"exposes": float(v.prochaine_crue(t1)["logements_perdus"]) - float(avant["perdus"]),
				"eau_cm": (float(v.prochaine_crue(t1)["eau_pire_m"]) - float(avant["eau"])) * 100.0,
				"camp": v.reloges(t1) - float(avant["camp"])}
			mesures[fid][f] = x
			dernier = [fid, f]
			verifier(v.est_repare("i", fid) and v.facon_reparation(fid) == f, "%d %s : engagé" % [fid, f])
			print("%4d  %-23s %-9s  %-11s %7.0f  %4.1f  %+5.1f / %+5.1f        %5.1f      %+6.1f              %+6.1f  %+5.0f" % [
				fid, ui.lieux.nom("i", fid).left(23), v.situation(fid), f, x["cout"], x["duree"],
				x["k_decision"], x["k_livraison"], x["logements"], x["exposes"], x["eau_cm"], x["camp"]])
	var tr: Dictionary = mesures[m]["tradition"]
	verifier(is_equal_approx(float(tr["cout"]), v.base("i", m, "cout_reparation_ke"))
		and float(tr["logements"]) == 67.0, "Comme avant : le prix de 04e, 67 logements")
	for fid in mesures:
		var tf: Dictionary = mesures[fid]["tradition"]
		for f in v.laureats(fid):
			var x: Dictionary = mesures[fid][f]
			var r: Dictionary = v.RECONSTRUCTIONS[f]
			if v.sans_retour(f):
				verifier(float(x["k_decision"]) < 0.0 and float(x["eau_cm"]) < 0.0
					and float(x["camp"]) == 0.0 and float(x["exposes"]) <= 0.0,
					"%d %s : coûte la confiance, baisse la crue, ses habitants restent au camp" % [fid, f])
			if float(r["hausse_m"]) > 0.0:
				verifier(float(x["exposes"]) <= float(tf["exposes"]),
					"%d %s : pas plus de logements perdus à la prochaine crue (%+.0f contre %+.0f)" % [
						fid, f, x["exposes"], tf["exposes"]])
			if float(r["logements"]) > 1.0:
				verifier(float(x["logements"]) > float(tf["logements"]), "%d %s : plus de logements" % [fid, f])
			if float(r["eponge"]) > 0.0:
				verifier(float(x["eau_cm"]) < 0.0, "%d %s : la crue baisse dans la ville" % [fid, f])

	# --- La sauvegarde garde la façon.
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	jeu._sur_reprise()
	verifier(v.facon_reparation(int(dernier[0])) == str(dernier[1]), "La reprise garde %s" % dernier[1])

	# --- Le guide et la fiche.
	_apres_etude(t0, true)
	verifier(o.etape == "choix" and not "caisse" in o._texte.text,
		"Le guide ne commente plus la caisse : %s" % o._texte.text)
	jeu._sur_choix("i", m)
	verifier(ui._fiche_fid == m and ui._pose.is_empty() and not ui._repare_bouton.visible
		and ui._rebatir_boutons["tradition"].visible and ui._projets_bouton.visible
		and not ui._concours_bouton.visible,
		"Le concours rendu : reconstruire ou voir les projets des lauréats, aucun posé")
	await cliquer(ui._projets_bouton)
	verifier(ui._projets_panneau.visible and ui._projets_titre.text.begins_with("Lauréats"),
		"« Voir les projets des lauréats » ouvre les trois projets")
	await capture("rebatir_01_quatre_facons")
	var n := 2
	for f in ["tradition"] + v.laureats(m):
		# « Comme avant » se pose à la fiche, pas chez les lauréats.
		if f == "tradition":
			ui.fermer_projets()
			await cliquer(ui._rebatir_boutons["tradition"])
		else:
			if not ui._projets_panneau.visible:
				await cliquer(ui._projets_bouton)
			await cliquer(ui._projets_cartes[v.laureats(m).find(f)]["bouton"])
		verifier(not ui._projets_panneau.visible, "%s : choisir referme l'écran" % f)
		jeu._rafraichir(true)
		var texte := _effets(ui)
		verifier(str(ui._pose.get("reparer")) == f and "logements perdus à la prochaine crue" in texte
			or v.sans_retour(f), "%s : la fiche annonce la prochaine crue — %s" % [f, texte])
		await capture("rebatir_%02d_%s" % [n, f])
		n += 1

	# --- La ville, livrée, au même cadrage : chaque allure, et la ruine partie.
	var vues := []
	for f in ["tradition"] + v.laureats(m):
		vues.append([m, f])
	for f in v.laureats(FOUR):
		vues.append([FOUR, f])
	for k in vues.size():
		var fid: int = vues[k][0]
		var f: String = vues[k][1]
		var b0: AABB = (jeu.noeuds["i"][fid] as MeshInstance3D).get_aabb()
		_apres_etude(t0, true)
		v.crediter_essai_ke(v.cout_reparation_ke("i", fid, false, f))
		jeu._sur_commande("i", fid, {"reparer": f})
		actualiser(t0 + v.duree_reparation_mois("i", fid, false, f) + 0.1)
		jeu.selection.sel_fid = -1
		jeu.interface._fermer_fiche()
		jeu.pivot.viser(Vector2(b0.get_center().x, b0.get_center().z), 110.0)
		jeu.pivot.caler(150.0, 32.0)
		jeu._dernier_peint = -1.0
		jeu._rafraichir(true)
		var neuf: MeshInstance3D = jeu.reparations["i"][fid]
		var parc: bool = v.rendu_de(f) == "parc"
		verifier(neuf.visible == (not parc) and (not parc or jeu._parcs.has(fid)),
			"%d %s livré : %s" % [fid, f, "parc planté" if parc else "bâti neuf visible"])
		await capture("rebatir_ville_%d_%s" % [k + 1, f])

	print("REBÂTIR : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs > 0 else 0)


## Une partie neuve, tout le monde au camp, l'étude lue, pilotis et parc inondable mis au point.
## `concours` : celui de chaque îlot aux maisons tombées, lancé au mois 0 et rendu avant `t`, payé par l'essai.
func _apres_etude(t: float, concours := false) -> void:
	var o = jeu.ouverture
	jeu._sur_reset()
	var champs: Array = o._champs_accessibles()
	jeu.ville.abriter(champs[0], 0.0)
	jeu.ville.abriter(champs[1], 0.0)
	o.pont_termine = true
	o.etude_parue = true
	o.carte_etude = 2
	o.etude_lue = true
	o.prochaine_vue = true
	o.institut_vu = true
	o.biblio_vue = true
	# 🏛️ L'étude parue, la mairie a été vue et le concours adopté (117).
	o.mairie_vue = true
	jeu.ville._programmes["concours"] = 0.0
	jeu.ville._recherche[jeu.Recherche.PILOTIS] = 0.0
	jeu.ville._recherche[jeu.Recherche.PARC] = 0.0
	if concours:
		for fid in jeu.ville.ilots:
			if jeu.ville.concours_utile(int(fid)):
				jeu.ville.crediter_essai_ke(jeu.ville.CONCOURS_KE)
				jeu.ville.lancer_concours(int(fid), 0.0)
	actualiser(t)


func _effets(ui) -> String:
	var out := []
	for h in ui._recap_effets.get_children():
		out.append(str(h.get_meta("texte", "")))
	return " · ".join(out)
