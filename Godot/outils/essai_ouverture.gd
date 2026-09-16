extends SceneTree
## --script res://outils/essai_ouverture.gd -- --ouverture [--captures]
const Maquette := preload("res://scripts/maquette.gd")
var jeu
var echecs := 0


func _initialize() -> void:
	call_deferred("executer")


func verifier(ok: bool, quoi: String) -> void:
	print("%s · %s" % ["OK" if ok else "ÉCHEC", quoi])
	if not ok:
		echecs += 1
		push_error(quoi)


func actualiser(mois: float) -> void:
	jeu.mois = mois
	jeu._rafraichir(true)
	jeu.trafic.avancer(mois)
	jeu.ouverture.actualiser(true)


func cliquer(b: Button) -> void:
	var parent := b.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(b)
		parent = parent.get_parent()
	await process_frame
	await process_frame
	var pos := b.get_global_rect().get_center()
	for presse in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = presse
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if presse else 0
		root.push_input(e, true)
		await process_frame


func bouton(texte: String) -> Button:
	for b in jeu.ouverture._actions.get_children():
		if b.text.begins_with(texte):
			return b
	return null


func capture(nom: String) -> void:
	if not "--captures" in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var chemin := "res://../QGIS/rendus/wehrau_ouverture_%s.png" % nom
	verifier(root.get_texture().get_image().save_png(chemin) == OK, "Capture " + nom)
	# Le panneau doit laisser les commandes du temps et la fiche accessibles.
	verifier(jeu.ouverture.get_global_rect().end.y < root.size.y - 82,
		"Le guide tient au-dessus des commandes du temps")


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_ouverture.wehrau"
	var o = jeu.ouverture
	verifier(o != null and o.etape == "choix" and jeu.vitesse == 0.0,
		"Ouverture en pause avec deux propositions")
	verifier(bouton("①") != null and bouton("②") != null, "Les deux choix sont présents")
	verifier(jeu.ville.cout_reparation_ke("r", o.RUE) < jeu.ville.caisse_ke(0.0)
		and jeu.ville.cout_reparation_ke("i", o.MAISONS) < jeu.ville.caisse_ke(0.0),
		"Les deux réparations sont accessibles sans argent d'essai")
	await capture("01_depart")
	var caisse: float = jeu.ville.caisse_ke(0.0)
	await cliquer(bouton("①"))
	verifier(jeu.interface._fiche_fid == o.RUE and jeu.interface._pose.has("reparer"),
		"Le clic prépare le déblaiement dans la vraie fiche")
	verifier(jeu.ville.caisse_ke(0.0) == caisse and jeu.ville._repare.is_empty(),
		"Comparer ne dépense rien")
	await capture("02_choix_rue")
	await cliquer(jeu.interface._recap_bouton)
	verifier(o.etape == "travaux" and not jeu.ville.route_praticable(o.RUE, 0.0),
		"La commande engage un chantier sans rouvrir la rue")
	actualiser(0.99)
	verifier(o.etape == "travaux" and jeu.trafic.doux_visibles_sur(o.RUE)[0] == 0,
		"Ni réussite ni piéton avant livraison")
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	jeu._sur_reprise()
	verifier(o.etape == "travaux" and jeu.mois == 0.99 and not jeu.ville.route_praticable(o.RUE, jeu.mois),
		"Une reprise pendant le chantier conserve l'attente et la rue fermée")
	await cliquer(bouton("Laisser avancer"))
	verifier(jeu.vitesse == 12.0, "Le joueur lance le temps")
	actualiser(1.0)
	verifier(o.etape == "livraison" and jeu.vitesse == 0.0,
		"La première livraison met le jeu en pause")
	verifier(jeu.ville.route_praticable(o.RUE, 1.0)
		and jeu.reparations["r"][o.RUE].visible, "La rue réparée est visible et praticable")
	var pietons: int = jeu.trafic.doux_visibles_sur(o.RUE)[0]
	verifier(pietons > 0, "Des piétons reviennent sur la rue : %d" % pietons)
	await capture("03_livraison")
	await cliquer(bouton("Et maintenant"))
	verifier(o.etape == "suite", "La réussite conduit au choix de transformation")
	await cliquer(bouton("Protéger"))
	verifier(jeu.interface._fiche_couche == "b" and jeu.interface._fiche_fid == o.BERGE,
		"La protection ouvre la berge qui agit sur ce secteur")
	verifier(jeu.interface._recap_bouton.disabled, "Le prix inaccessible est expliqué et refusé")
	var avant: float = jeu.ville.valeur("i", o.MAISONS, "hauteur_eau_annonce", jeu.mois)
	actualiser(12.0)
	verifier(not jeu.interface._recap_bouton.disabled, "Épargner rend la protection accessible")
	await cliquer(jeu.interface._recap_bouton)
	actualiser(29.99)
	verifier(is_equal_approx(jeu.ville.valeur("i", o.MAISONS, "hauteur_eau_annonce", jeu.mois), avant),
		"La protection attend la livraison")
	actualiser(30.0)
	verifier(jeu.ville.valeur("i", o.MAISONS, "hauteur_eau_annonce", jeu.mois) < avant,
		"La berge livrée réduit réellement l'eau attendue")
	await capture("04_protection")
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	verifier(o.etape == "choix" and jeu.mois == 0.0, "Recommencer remet les premiers pas à zéro")
	jeu._sur_reprise()
	verifier(o.etape == "suite" and jeu.mois == 30.0 and jeu.vitesse == 0.0,
		"La reprise retrouve la boucle, le chantier et le mois")
	await cliquer(bouton("Continuer à mon rythme"))
	verifier(not o.visible and o.termine, "Le guide peut se terminer sans arrêter la partie")
	await cliquer(jeu.interface._debut)
	verifier(o.visible, "DÉBUT rouvre le guide")
	jeu.interface._sur_rail("energie")
	verifier(not o.visible, "Le diagnostic garde son panneau sans superposition")
	await cliquer(jeu.interface._debut)
	verifier(o.visible and jeu.theme == "", "DÉBUT revient depuis le diagnostic")
	jeu._sur_reset()
	await cliquer(bouton("②"))
	await cliquer(jeu.interface._recap_bouton)
	actualiser(12.0)
	verifier(o.etape == "livraison" and jeu.ville.reparation_finie("i", o.MAISONS, 12.0),
		"Les logements peuvent aussi être le premier chantier")
	verifier(jeu.ville.valeur("i", o.MAISONS, "logements", 12.0) == 67.0,
		"Les 43 logements sinistrés rejoignent les 24 restés habitables")
	await capture("05_logements")
	var ancienne: Dictionary = jeu._partie()
	ancienne.erase("ouverture")
	verifier(jeu._partie_valide(ancienne), "Les anciennes sauvegardes restent compatibles")
	ancienne["ouverture"] = {"suite": "invalide"}
	verifier(not jeu._partie_valide(ancienne), "Un état de guide corrompu est refusé")
	print("OUVERTURE : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs > 0 else 0)
