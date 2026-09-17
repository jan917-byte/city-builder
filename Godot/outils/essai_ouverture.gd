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
	jeu._sur_mode(false)

	# 🏕️ LA PREMIÈRE SCÈNE : reloger, avant tout budget de réparation.
	verifier(o != null and o.etape == "reloger" and jeu.vitesse == 0.0,
		"Ouverture en pause sur le relogement")
	var champs: Array = o._champs_accessibles()
	verifier(champs.size() == 3, "Trois champs sont atteignables : %s" % [champs])
	var besoin: float = jeu.ville.sans_toit(0.0)
	verifier(besoin > 0.0, "%d personnes sont sans toit" % int(besoin))
	var plus_grand: int = jeu.ville.camp_places_max(champs[0])
	verifier(plus_grand < int(besoin),
		"Aucun champ ne loge tout le monde : le plus grand tient %d places" % plus_grand)
	for fid in jeu.ville.ilots:
		if jeu.ville.camp_possible(int(fid)) and not int(fid) in champs:
			verifier(not jeu.ville.camp_accessible(int(fid)),
				"Les champs de l'autre rive restent hors d'atteinte")
			break
	verifier(bouton("①") != null and bouton("③") != null,
		"Les trois champs sont proposés")
	await capture("01_relogement")
	var caisse0: float = jeu.ville.caisse_ke(0.0)
	await cliquer(bouton("①"))
	verifier(jeu.interface._fiche_fid == champs[0] and jeu.interface._pose.has("camp"),
		"Le clic prépare le camp dans la fiche du champ")
	verifier(jeu.ville.caisse_ke(0.0) == caisse0 and not jeu.ville.camp_pose(champs[0]),
		"Comparer un champ ne dépense rien")
	await cliquer(jeu.interface._recap_bouton)
	verifier(jeu.ville.camp_pose(champs[0]) and jeu.ville.caisse_ke(0.0) < caisse0,
		"Le camp est engagé et payé une fois")
	verifier(jeu.ville.camp_occupants(champs[0], 0.0) == 0.0,
		"Personne n'habite le camp avant la livraison")
	actualiser(0.2)
	verifier(jeu.ville.camp_occupants(champs[0], 0.2) == float(plus_grand),
		"Le camp livré en quelques jours abrite %d logements" % plus_grand)
	verifier(jeu.ville.sans_toit(0.2) == besoin - float(plus_grand),
		"Il reste %d personnes dehors" % int(besoin - float(plus_grand)))
	verifier(jeu.camp._mmi.multimesh != null
		and jeu.camp._mmi.multimesh.instance_count == plus_grand * 2,
		"Les containers sont posés sur le champ")
	await capture("02_camp")
	actualiser(0.0)

	verifier(o.etape == "choix", "Le relogement fait, le budget prend la main")
	verifier(bouton("①") != null and bouton("②") != null, "Les deux choix sont présents")
	# 🔴 LE CAMP A MANGÉ LA MOITIÉ DE LA CAISSE, et c'est la contrepartie du
	# relogement : la rue reste finançable tout de suite, les logements
	# demandent d'épargner. Mesuré, pas décidé ici.
	verifier(jeu.ville.cout_reparation_ke("r", o.RUE) < jeu.ville.caisse_ke(0.0),
		"La rue reste finançable après le camp")
	verifier(jeu.ville.cout_reparation_ke("i", o.MAISONS) > jeu.ville.caisse_ke(0.0),
		"Relever les logements demande d'épargner : %.0f k€ pour %.0f k€ en caisse"
		% [jeu.ville.cout_reparation_ke("i", o.MAISONS), jeu.ville.caisse_ke(0.0)])
	await capture("03_depart")
	var caisse: float = jeu.ville.caisse_ke(0.0)
	await cliquer(bouton("①"))
	verifier(jeu.interface._fiche_fid == o.RUE and jeu.interface._pose.has("reparer"),
		"Le clic prépare le déblaiement dans la vraie fiche")
	verifier(jeu.ville.caisse_ke(0.0) == caisse and jeu.ville._repare.is_empty(),
		"Comparer ne dépense rien")
	await capture("04_choix_rue")
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
	await capture("05_livraison")
	await cliquer(bouton("Et maintenant"))
	verifier(o.etape == "suite", "La réussite conduit au choix de transformation")
	await cliquer(bouton("Protéger"))
	verifier(jeu.interface._fiche_couche == "b" and jeu.interface._fiche_fid == o.BERGE,
		"La protection ouvre la berge qui agit sur ce secteur")
	verifier(jeu.interface._recap_bouton.disabled, "Le prix inaccessible est expliqué et refusé")
	var avant: float = jeu.ville.valeur("i", o.MAISONS, "hauteur_eau_annonce", jeu.mois)
	actualiser(20.0)
	verifier(not jeu.interface._recap_bouton.disabled, "Épargner rend la protection accessible")
	await cliquer(jeu.interface._recap_bouton)
	actualiser(37.99)
	verifier(is_equal_approx(jeu.ville.valeur("i", o.MAISONS, "hauteur_eau_annonce", jeu.mois), avant),
		"La protection attend la livraison")
	actualiser(38.0)
	verifier(jeu.ville.valeur("i", o.MAISONS, "hauteur_eau_annonce", jeu.mois) < avant,
		"La berge livrée réduit réellement l'eau attendue")
	await capture("06_protection")
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	verifier(o.etape == "reloger" and jeu.mois == 0.0, "Recommencer remet les premiers pas à zéro")
	jeu._sur_reprise()
	verifier(o.etape == "suite" and jeu.mois == 38.0 and jeu.vitesse == 0.0,
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
	verifier(o.etape == "reloger", "Recommencer ramène au relogement")

	# 🌉 LE MAUVAIS CHAMP : il se pose, il se paie, et il reste vide.
	var lointain := -1
	for fid in jeu.ville.ilots:
		if jeu.ville.camp_possible(int(fid)) and not jeu.ville.camp_accessible(int(fid)):
			lointain = int(fid)
			break
	verifier(lointain > 0, "Un champ de l'autre rive existe")
	var dehors: float = jeu.ville.sans_toit(0.0)
	var avant_caisse: float = jeu.ville.caisse_ke(0.0)
	jeu._sur_choix("i", lointain)
	jeu.interface.poser("camp")
	verifier(not jeu.interface._camp_bouton.disabled,
		"Le jeu prévient mais laisse poser le camp")
	jeu._sur_commande("i", lointain, jeu.interface._reglages())
	actualiser(0.2)
	verifier(jeu.ville.camp_pose(lointain) and jeu.ville.caisse_ke(0.2) < avant_caisse,
		"Le camp inaccessible est bel et bien payé")
	verifier(jeu.ville.camp_occupants(lointain, 0.2) == 0.0
		and jeu.ville.sans_toit(0.2) == dehors,
		"Personne ne peut y aller : le camp reste vide")
	await capture("08_camp_vide")
	jeu._sur_reset()
	actualiser(0.0)

	var champs2: Array = o._champs_accessibles()
	jeu._sur_choix("i", champs2[0])
	jeu.interface.poser("camp")
	jeu._sur_commande("i", champs2[0], jeu.interface._reglages())
	# Huit mois de dotation : ce que le camp a coûté aux logements.
	actualiser(8.0)
	await cliquer(bouton("②"))
	await cliquer(jeu.interface._recap_bouton)
	actualiser(20.0)
	verifier(o.etape == "livraison" and jeu.ville.reparation_finie("i", o.MAISONS, 20.0),
		"Les logements peuvent aussi être le premier chantier")
	verifier(jeu.ville.valeur("i", o.MAISONS, "logements", 20.0) == 67.0,
		"Les 43 logements sinistrés rejoignent les 24 restés habitables")
	# 🔴 LE CAMP RESTE PLEIN, et c'est juste : 195 places pour 260 personnes,
	# donc il y a une file. Ce que la réparation vide, c'est la FILE — et c'est
	# la pastille de l'îlot relevé qui le montre, pas le camp.
	verifier(jeu.ville.sans_toit(20.0) < jeu.ville.sans_toit(8.0),
		"Les logements relevés sortent %d personnes de la file"
		% int(jeu.ville.sans_toit(8.0) - jeu.ville.sans_toit(20.0)))
	await capture("07_logements")
	# 🛠️ LE MODE AUTEUR : mêmes prix, même caisse, livraison immédiate.
	jeu._sur_reset()
	jeu._sur_mode(true)
	var caisse_avant: float = jeu.ville.caisse_ke(0.0)
	var prix_rue: float = jeu.ville.cout_reparation_ke("r", o.RUE)
	jeu._sur_choix("r", o.RUE)
	jeu.interface.poser("reparer")
	jeu._sur_commande("r", o.RUE, jeu.interface._reglages())
	actualiser(0.0)
	verifier(jeu.ville.reparation_finie("r", o.RUE, 0.0),
		"Mode auteur : la rue est livrée au clic, sans attendre le mois")
	verifier(is_equal_approx(jeu.ville.caisse_ke(0.0), caisse_avant - prix_rue),
		"Mode auteur : le prix reste celui du jeu (%.0f k€)" % prix_rue)
	jeu._sur_mode(false)
	verifier(jeu.ville.duree_reparation_mois("i", o.MAISONS) > 0.0,
		"Revenir en mode histoire rend leur durée aux chantiers")
	jeu._sur_reset()

	var ancienne: Dictionary = jeu._partie()
	ancienne.erase("ouverture")
	verifier(jeu._partie_valide(ancienne), "Les anciennes sauvegardes restent compatibles")
	ancienne["ouverture"] = {"suite": "invalide"}
	verifier(not jeu._partie_valide(ancienne), "Un état de guide corrompu est refusé")
	print("OUVERTURE : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs > 0 else 0)
