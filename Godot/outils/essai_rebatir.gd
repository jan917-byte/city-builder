extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_rebatir.gd -- --ouverture [--captures]
## 🏗️ Les quatre façons de relever un îlot sinistré (95), mesurées sur les Forgerons.


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
	var o = jeu.ouverture
	var ui = jeu.interface
	var v = jeu.ville
	var m: int = o.MAISONS
	var t0 := 3.0

	# --- Le modèle : une partie neuve par façon, la même commande.
	var mesures := {}
	for f in v.RECONSTRUCTIONS_ORDRE:
		_apres_etude(t0)
		var duree: float = v.duree_reparation_mois("i", m, false, f)
		var t1 := t0 + duree + 0.05
		var avant := {"perdus": float(v.prochaine_crue(t1)["logements_perdus"]),
			"eau": float(v.prochaine_crue(t1)["eau_pire_m"]), "camp": v.reloges(t1),
			"k": v.capital(t0)}
		var cout: float = v.cout_reparation_ke("i", m, false, f)
		jeu._sur_commande("i", m, {"reparer": f})
		actualiser(t0)
		mesures[f] = {"cout": cout, "duree": duree,
			"k_decision": v.capital(t0) - float(avant["k"]),
			"k_livraison": v.capital(t1) - float(avant["k"]),
			"logements": v.valeur("i", m, "logements", t1),
			"exposes": float(v.prochaine_crue(t1)["logements_perdus"]) - float(avant["perdus"]),
			"eau_cm": (float(v.prochaine_crue(t1)["eau_pire_m"]) - float(avant["eau"])) * 100.0,
			"camp": v.reloges(t1) - float(avant["camp"])}
		verifier(v.est_repare("i", m) and v.facon_reparation(m) == f, "%s : engagé" % f)
	print("façon      coût k€  mois  confiance(déc/livr)  logements  perdus à la prochaine  crue cm  au camp")
	for f in mesures:
		var x: Dictionary = mesures[f]
		print("%-10s %7.0f  %4.1f  %+5.1f / %+5.1f        %5.1f      %+6.1f              %+6.1f  %+5.0f" % [
			f, x["cout"], x["duree"], x["k_decision"], x["k_livraison"], x["logements"],
			x["exposes"], x["eau_cm"], x["camp"]])
	var tr: Dictionary = mesures["tradition"]
	verifier(is_equal_approx(float(tr["cout"]), v.base("i", m, "cout_reparation_ke"))
		and float(tr["logements"]) == 67.0, "Comme avant : le prix de 04e, 67 logements")
	verifier(float(mesures["moderne"]["logements"]) > 67.0
		and float(mesures["moderne"]["cout"]) > float(tr["cout"]), "Moderne : plus de logements, plus cher")
	verifier(float(mesures["pilotis"]["exposes"]) < float(tr["exposes"])
		and float(mesures["pilotis"]["cout"]) > float(mesures["moderne"]["cout"]),
		"Pilotis : moins de logements perdus à la prochaine crue, le plus cher")
	verifier(float(mesures["parc"]["k_decision"]) < 0.0 and float(mesures["parc"]["eau_cm"]) < 0.0
		and float(mesures["parc"]["camp"]) == 0.0 and float(mesures["parc"]["exposes"]) <= 0.0,
		"Parc : coûte la confiance à la décision, baisse la crue, ses habitants restent au camp")
	verifier(float(tr["k_livraison"]) > float(mesures["pilotis"]["k_livraison"])
		and float(mesures["pilotis"]["k_livraison"]) > float(mesures["moderne"]["k_livraison"]),
		"La confiance va d'abord à « comme avant », puis aux pilotis, puis au moderne")

	# --- La sauvegarde garde la façon.
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	jeu._sur_reprise()
	verifier(v.facon_reparation(m) == "parc", "La reprise garde le parc")

	# --- Le guide et la fiche.
	_apres_etude(t0)
	verifier(o.etape == "choix" and not "caisse" in o._texte.text,
		"Le guide ne commente plus la caisse : %s" % o._texte.text)
	jeu._sur_choix("i", m)
	verifier(ui._fiche_fid == m and ui._pose.is_empty() and not ui._repare_bouton.visible
		and not ui._rebatir_boutons["tradition"].visible and ui._projets_bouton.visible,
		"Concours rendu : la fiche des Forgerons n'a plus qu'un bouton, les quatre projets, aucun posé")
	await cliquer(ui._projets_bouton)
	verifier(ui._projets_panneau.visible, "« Voir les quatre projets » ouvre l'écran du concours")
	await capture("rebatir_01_quatre_facons")
	var n := 2
	for f in v.RECONSTRUCTIONS_ORDRE:
		if not ui._projets_panneau.visible:
			await cliquer(ui._projets_bouton)
		await cliquer(ui._projets_cartes[f]["bouton"])
		verifier(not ui._projets_panneau.visible, "%s : choisir referme l'écran" % f)
		jeu._rafraichir(true)
		var texte := _effets(ui)
		verifier(str(ui._pose.get("reparer")) == f and "logements perdus à la prochaine crue" in texte
			or f == "parc", "%s : la fiche annonce la prochaine crue — %s" % [f, texte])
		await capture("rebatir_%02d_%s" % [n, f])
		n += 1

	# --- La ville, livrée, au même cadrage : quatre allures, et la ruine partie.
	var b0: AABB = (jeu.noeuds["i"][m] as MeshInstance3D).get_aabb()
	for f in v.RECONSTRUCTIONS_ORDRE:
		_apres_etude(t0)
		jeu._sur_commande("i", m, {"reparer": f})
		actualiser(t0 + v.duree_reparation_mois("i", m, false, f) + 0.1)
		jeu.selection.sel_fid = -1
		jeu.interface._fermer_fiche()
		jeu.pivot.viser(Vector2(b0.get_center().x, b0.get_center().z), 110.0)
		jeu.pivot.caler(150.0, 32.0)
		jeu._dernier_peint = -1.0
		jeu._rafraichir(true)
		var neuf: MeshInstance3D = jeu.reparations["i"][m]
		verifier(neuf.visible == (f != "parc") and (f != "parc" or jeu._parcs.has(m)),
			"%s livré : %s" % [f, "parc planté" if f == "parc" else "bâti neuf visible"])
		await capture("rebatir_ville_%d_%s" % [v.RECONSTRUCTIONS_ORDRE.find(f) + 1, f])
	print("REBÂTIR : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs > 0 else 0)


## Une partie neuve, tout le monde au camp, l'étude lue : le menu des Forgerons s'ouvre.
## `concours` : celui de la zone (104), lancé au mois 0 et rendu avant `t`, payé par l'essai.
func _apres_etude(t: float, concours := true) -> void:
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
	if concours:
		jeu.ville.crediter_essai_ke(jeu.ville.CONCOURS_KE)
		jeu.ville.lancer_concours(o.MAISONS, 0.0)
	actualiser(t)


## 🚪 Le concours attend une berge rendue et un autre sol livré : l'essai les pose
## livrés d'avance, sans rampe ; `fermer` les retire, le concours lancé reste ouvert.
func _portes_concours(ouvrir: bool) -> void:
	var v = jeu.ville
	if ouvrir:
		v._berge[jeu.ouverture.BERGE] = {"cible": v.BERGE_RENATUREE,
			"depuis": v.berge_depart(jeu.ouverture.BERGE), "debut": -40.0, "duree": 1.0, "cout_ke": 0.0}
		v._permeable[jeu.ouverture.PARKING] = {"debut": -40.0, "duree": 1.0, "cout_ke": 0.0}
	else:
		v._berge.erase(jeu.ouverture.BERGE)
		v._permeable.erase(jeu.ouverture.PARKING)


func _effets(ui) -> String:
	var out := []
	for h in ui._recap_effets.get_children():
		out.append((h.get_child(1) as Label).text)
	return " · ".join(out)
