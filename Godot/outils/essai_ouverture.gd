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
	jeu.trafic.avancer(mois)
	jeu._rafraichir(true)
	jeu.ouverture.actualiser(true)


func cliquer(b: Button) -> void:
	await process_frame
	await process_frame
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
	# 📖 Pendant le récit, c'est sa page qui doit tenir dans l'écran : le
	# guide est rangé et son cadre ne veut plus rien dire.
	if jeu.recit != null and jeu.recit.en_cours():
		verifier((jeu.recit.get_child(0) as Control).size.y < root.size.y - 40,
			"La page du récit tient dans l'écran")
	elif jeu.ouverture.visible:
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

	# 📖 LE RÉCIT : quatre pages, une flèche, et les pastilles qui
	# s'allument à la page des dégâts.
	jeu.recit.commencer()
	verifier(jeu.recit.en_cours() and not o.visible,
		"Le récit s'ouvre seul, sans le guide des premiers pas")
	verifier(jeu.pastilles == null, "La ville se montre sans pastille")
	# 📖 RIEN DU JEU PENDANT LES CARTES : ni compteurs, ni rail, ni temps —
	# donc rien qui propose de poser des panneaux avant l'heure.
	verifier(not jeu.interface._ville_panneau.visible
		and not jeu.interface._menu_panneau.visible
		and not jeu.interface._temps_panneau.visible
		and not jeu.interface._fiche_panneau.visible,
		"Le récit cache le tableau de bord, le rail et les commandes du temps")
	verifier(jeu.vitesse == 0.0, "Le temps ne court pas pendant le récit")
	await capture("00_recit_1_ville")
	await cliquer(jeu.recit._fleche)
	await capture("00_recit_2_crue")
	await cliquer(jeu.recit._fleche)
	verifier(jeu.recit.page == 2 and jeu.pastilles == null, "La page des dégâts conserve une carte sans pastille")
	await capture("00_recit_3_degats")
	await cliquer(jeu.recit._fleche)
	verifier(jeu.recit.page == 3 and jeu.recit.en_cours(),
		"La dernière page demande un endroit où installer les sinistrés")
	await capture("00_recit_4_mission")
	await cliquer(jeu.recit._fleche)
	verifier(not jeu.recit.en_cours() and o.visible,
		"La flèche finit le récit et rend la main au jeu")
	verifier(not jeu.interface._ville_panneau.visible
		and jeu.interface._menu_panneau.visible
		and jeu.interface._temps_panneau.visible,
		"La dernière carte rend les commandes, sans les données générales de la ville")

	# 🏕️ LA PREMIÈRE SCÈNE : reloger, avant tout budget de réparation.
	# 🕰️ Et le temps part avec elle : les mois passent pendant que 260
	# personnes dorment dehors.
	verifier(o != null and o.etape == "reloger" and jeu.vitesse == 1.0,
		"Les cartes finies, le temps du jeu commence sur le relogement")
	jeu._sur_vitesse(0.0)
	var champs: Array = o._champs_accessibles()
	verifier(champs.size() == 3, "Trois champs sont atteignables : %s" % [champs])
	var besoin: float = jeu.ville.sans_toit(0.0)
	verifier(besoin > 0.0, "%d personnes sont sans toit" % int(besoin))
	var plus_grand: int = jeu.ville.camp_places_max(champs[0])
	var capacite: int = jeu.ville.camp_capacite(champs[0])
	verifier(capacite < int(besoin),
		"Aucun champ ne loge tout le monde : le plus grand accueille %d personnes" % capacite)
	for fid in jeu.ville.ilots:
		if jeu.ville.camp_possible(int(fid)) and not int(fid) in champs:
			verifier(not jeu.ville.camp_accessible(int(fid)),
				"Les champs de l'autre rive restent hors d'atteinte")
			break
	# 🧭 AUCUN CHAMP N'EST DÉSIGNÉ (auteur, 2026-09-17) : ni chiffre sur la
	# carte, ni bouton qui y mène. Le joueur cherche, la fiche répond.
	verifier(bouton("①") == null and o._reperes.get_child_count() == 0,
		"Le panneau ne désigne aucun champ")
	await capture("01_relogement")
	var lointain := -1
	for fid in jeu.ville.ilots:
		if jeu.ville.camp_possible(int(fid)) and not jeu.ville.camp_accessible(int(fid)):
			lointain = int(fid)
			break
	verifier(lointain > 0, "Un champ de l'autre rive existe")
	# 🏕️ RIEN NE S'ENGAGE AILLEURS tant que les sinistrés sont dehors.
	jeu._sur_choix("i", o.MAISONS)
	verifier(not jeu.interface._repare_bloc.visible
		and not jeu.interface._camp_bloc.visible
		and not jeu.interface._solaire_bloc.visible,
		"Un îlot bâti n'ouvre aucun chantier pendant l'urgence")
	await capture("01b_ilot_muet")
	jeu._sur_choix("r", o.RUE)
	verifier(not jeu.interface._repare_bloc.visible
		and not jeu.interface._trafic_bloc.visible, "Une rue non plus")
	jeu._sur_choix("b", o.BERGE)
	verifier(not jeu.interface._berge_bloc.visible, "Une berge non plus")
	verifier("terrain nu" in o._texte.text,
		"Trois lieux muets, et le panneau rappelle ce qu'un camp demande")
	# 🌉 Le champ de l'autre rive prévient et laisse faire.
	jeu._sur_choix("i", lointain)
	verifier(jeu.interface._camp_bloc.visible
		and not jeu.interface._camp_bouton.disabled
		and "⚠" in jeu.interface._camp_texte.text,
		"Un champ hors d'atteinte prévient sans refuser")
	var caisse0: float = jeu.ville.caisse_ke(0.0)
	var nourris0: float = jeu.ville.nourriture_personnes(0.0)
	jeu._sur_choix("i", champs[0])
	verifier(jeu.interface._camp_bloc.visible
		and not ("terrain nu" in o._texte.text),
		"Le champ atteignable ouvre le relogement, et l'indice s'efface")
	# 🌾 LE COÛT QUI N'EST PAS EN k€, ANNONCÉ AVANT LE BOUTON.
	var nourri_champ: float = jeu.ville.champ_nourriture(champs[0])
	verifier(nourri_champ > 0.0 and "nourrit" in jeu.interface._camp_texte.text,
		"La fiche dit ce que le champ nourrit : %.0f personnes" % nourri_champ)
	# 🗂️ 🔄 LA FICHE EST À ONGLETS depuis le 2026-09-18 : ce qui portait
	# « Nourrit » est l'onglet campagne, et il n'existe que sur un champ.
	verifier(jeu.interface._dispo.has("campagne")
		and "nourries" in jeu.interface._resume_texte.text,
		"La campagne est le seul onglet du champ, et sa ligne du haut le dit")
	await capture("01c_champ")
	verifier(int(jeu.interface.apercu_demande()["camp"]) == 0,
		"Le champ nu ne montre aucun abri tant que rien n'est posé")
	await cliquer(jeu.interface._camp_bouton)
	verifier(jeu.interface._fiche_fid == champs[0] and jeu.interface._pose.has("camp"),
		"Le bouton de la fiche prépare le camp")
	# 🔎 LA MINIATURE PROMET LE CAMP avant qu'il soit payé, comme tout autre
	# réglage : sans ça c'était le seul chantier qu'on engageait à l'aveugle.
	verifier(int(jeu.interface.apercu_demande()["camp"]) == plus_grand,
		"La miniature pose les %d abris avant qu'on paie" % plus_grand)
	jeu._rafraichir(true)
	verifier(jeu.apercu._camp_mmi.multimesh != null
		and jeu.apercu._camp_mmi.multimesh.instance_count == plus_grand,
		"Les abris sont dans la miniature, un par logement")
	await capture("01d_camp_promis")
	# 🔎 L'autre moitié de la comparaison : AVANT rend le champ nu.
	jeu.interface.regarder_avant(true)
	jeu._rafraichir(true)
	verifier(jeu.apercu._camp_mmi.multimesh == null,
		"Le bouton AVANT rend le champ nu")
	jeu.interface.regarder_avant(false)
	jeu._rafraichir(true)
	verifier(jeu.ville.caisse_ke(0.0) == caisse0 and not jeu.ville.camp_pose(champs[0]),
		"Comparer un champ ne dépense rien")
	await cliquer(jeu.interface._recap_bouton)
	verifier(jeu.ville.camp_pose(champs[0]) and jeu.ville.caisse_ke(0.0) < caisse0,
		"Le camp est engagé et payé une fois")
	verifier(jeu.ville.camp_occupants(champs[0], 0.0) == 0.0,
		"Personne n'habite le camp avant la livraison")
	actualiser(0.2)
	verifier(jeu.ville.camp_occupants(champs[0], 0.2) == float(capacite),
		"Les %d logements livrés accueillent %d personnes" % [plus_grand, capacite])
	verifier(jeu.ville.sans_toit(0.2) == besoin - float(capacite),
		"Il reste %d personnes dehors" % int(besoin - float(capacite)))
	# 🏕️ UN ABRI PAR LOGEMENT PAYÉ : ce qui est à l'écran est le nombre annoncé.
	verifier(jeu.camp._mmi.multimesh != null
		and jeu.camp._mmi.multimesh.instance_count == plus_grand,
		"Les %d abris sont posés sur le champ, un par logement" % plus_grand)
	# Le champ est retiré de la production dès la mise en chantier.
	verifier(not jeu.ville.champ_cultive(champs[0], 0.0)
		and not jeu.ville.champ_cultive(champs[0], 0.2),
		"Le champ cesse de nourrir dès la mise en chantier")
	verifier(is_equal_approx(jeu.ville.nourriture_personnes(0.2),
		nourris0 - nourri_champ),
		"La campagne perd les %.0f personnes du champ" % nourri_champ)
	verifier("ne nourrit plus" in jeu.interface._camp_texte.text,
		"La fiche du camp rappelle ce que le champ ne nourrit plus")
	# 🔒 LE RELOGEMENT SE FINIT AVANT LE PONT (auteur, 2026-09-22).
	verifier(o.etape == "reloger" and o.verrou() == "reloger" and "Il manque encore" in o._texte.text,
		"Avec %d personnes dehors, le guide demande un autre terrain" % int(besoin - float(capacite)))
	jeu._sur_choix("r", jeu.ville.ponts_coupes()[0])
	verifier(not jeu.interface._repare_bloc.visible, "Aucun pont ne s'engage tant qu'une personne est dehors")
	jeu._sur_choix("i", champs[1])
	jeu.interface.poser("camp")
	verifier(jeu.ville.camp_taille(champs[1], 0.2) * 2 >= int(besoin - float(capacite))
		and jeu.ville.camp_taille(champs[1], 0.2) < jeu.ville.camp_places_max(champs[1]),
		"Le second camp est taillé sur les %d places qui manquent" % int(besoin - float(capacite)))
	jeu._sur_commande("i", champs[1], jeu.interface._reglages())
	verifier(o.etape == "camp_attente" and o.verrou() == "reloger",
		"Tout le monde a une place commandée : on attend la livraison, rien d'autre ne s'ouvre")
	actualiser(0.4)
	verifier(jeu.ville.sans_toit(0.4) == 0.0 and o.verrou() == "pont", "Tout le monde est abrité, le pont devient la seule suite")
	jeu._sur_choix("i", champs[0])
	await capture("02_camp")
	await essayer_ponts(lointain)
	# Les contrôles locaux suivants isolent la suite, déjà validée après le pont.
	jeu._sur_reset()
	jeu.ville.abriter(champs[0], 0.0)
	jeu.ville.abriter(champs[1], 0.0)
	o.pont_termine = true
	actualiser(0.0)

	verifier(o.etape == "choix", "Le relogement fait, le budget prend la main")
	verifier(bouton("①") != null and bouton("②") != null, "Les deux choix sont présents")
	# Ce contrôle isole les choix locaux sans avoir payé de pont.
	verifier(jeu.ville.cout_reparation_ke("r", o.RUE) < jeu.ville.caisse_ke(0.0),
		"La rue reste finançable après le camp")
	verifier(jeu.ville.cout_reparation_ke("i", o.MAISONS) < jeu.ville.caisse_ke(0.0),
		"Sans pont déjà payé, les logements sont finançables : %.0f k€ pour %.0f k€ en caisse"
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
	verifier(not jeu.interface._recap_bouton.disabled, "Sans pont payé, la caisse couvre aussi la protection")
	var avant: float = jeu.ville.valeur("i", o.MAISONS, "hauteur_eau_annonce", jeu.mois)
	actualiser(20.0)
	verifier(not jeu.interface._recap_bouton.disabled, "La protection reste accessible au mois 20")
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
	o.pont_termine = true
	jeu._sur_choix("i", champs2[0])
	jeu.interface.poser("camp")
	jeu._sur_commande("i", champs2[0], jeu.interface._reglages())
	jeu.ville.abriter(champs2[1], 0.0)
	# Huit mois de dotation : ce que le camp a coûté aux logements.
	actualiser(8.0)
	await cliquer(bouton("②"))
	await cliquer(jeu.interface._recap_bouton)
	actualiser(20.0)
	verifier(o.etape == "livraison" and jeu.ville.reparation_finie("i", o.MAISONS, 20.0),
		"Les logements peuvent aussi être le premier chantier")
	verifier(jeu.ville.valeur("i", o.MAISONS, "logements", 20.0) == 67.0,
		"Les 43 logements sinistrés rejoignent les 24 restés habitables")
	# Tout le monde est déjà abrité : les retours chez soi vident les camps.
	verifier(jeu.ville.reloges(20.0) < jeu.ville.reloges(8.0),
		"Les logements relevés font quitter les camps à %d personnes"
		% int(jeu.ville.reloges(8.0) - jeu.ville.reloges(20.0)))
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


func essayer_ponts(lointain: int) -> void:
	var o = jeu.ouverture
	verifier(o.etape == "trafic", "Tout le monde abrité, le guide passe au trafic")
	# 🔒 PENDANT LA PHASE DU PONT, seuls les ponts et leurs accès s'engagent.
	jeu._sur_choix("i", o.MAISONS)
	verifier(not jeu.interface._repare_bloc.visible and "pont" in jeu.interface._message.text,
		"Un îlot n'ouvre aucun chantier avant qu'un pont soit rouvert")
	verifier(jeu.interface._rail_lieux[0].disabled, "La mairie et l'université attendent le pont")
	jeu._sur_choix("r", jeu.ville.ponts_coupes()[0])
	verifier(jeu.interface._repare_bloc.visible, "Un pont coupé, lui, s'engage")
	await capture("09_decouvrir_trafic")
	await cliquer(jeu.interface._menu_boutons["trafic"])
	verifier(o.etape == "pont_choix" and o.visible and jeu.theme == "trafic",
		"L'icône Trafic présente les trois ponts sur le calque sans superposer les panneaux")
	verifier(o._reperes.get_child_count() == 0, "Le joueur repère les ponts sans numéros sur la carte")
	var caisse: float = jeu.ville.caisse_ke(jeu.mois)
	var pont := -1
	var prix := INF
	for fid in jeu.ville.ponts_coupes():
		var p: Dictionary = jeu.trafic.prevoir_pont(fid, jeu.mois)
		print("PRÉVISION PONT %d · %s · %s" % [fid, o._nom("r", fid), p])
		verifier(jeu.ville.morceaux_accessibles(jeu.mois, fid).has(jeu.ville.morceau("i", lointain)),
			"Le pont %d réunit les deux rives dans la prévision" % fid)
		if jeu.ville.cout_reparation_ke("r", fid) < prix:
			pont = fid
			prix = jeu.ville.cout_reparation_ke("r", fid)
	verifier(jeu.ville._repare.is_empty() and jeu.ville.caisse_ke(jeu.mois) == caisse,
		"Comparer les trois réseaux ne modifie ni la partie ni la caisse")
	await capture("10_comparer_ponts")
	o._choisir_pont(pont)
	verifier(not jeu.interface._camp_bloc.visible, "La fiche du pont ne conserve pas les informations du camp")
	verifier(jeu.interface._pose.has("reparer") and not jeu.interface._recap_bouton.disabled,
		"Le pont choisi est finançable dès le départ dans la fiche")
	await capture("11_fiche_pont")
	var cadrage: Vector3 = jeu.pivot.position
	var taille: float = jeu.pivot.taille
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	jeu._sur_reprise()
	verifier(o.trafic_vu and o.etape == "pont_choix", "La reprise conserve la découverte du trafic")
	verifier(jeu.pivot.position.is_equal_approx(cadrage) and is_equal_approx(jeu.pivot.taille, taille),
		"La reprise du diagnostic conserve le cadrage du pont choisi")
	# Un camp de l'autre rive, posé par erreur AVANT les bons, attend réellement
	# le pont ; aucun argent d'essai. Les bons suivent, sinon rien ne s'ouvre.
	jeu._sur_reset()
	var bons: Array = o._champs_accessibles()
	jeu.ville.abriter(lointain, 0.0)
	jeu.ville.abriter(bons[0], 0.05)
	jeu.ville.abriter(bons[1], 0.05)
	var debut := 0.25
	actualiser(debut)
	verifier(jeu.ville.sans_toit(debut) == 0.0 and jeu.ville.camp_occupants(lointain, debut) == 0.0
		and o.verrou() == "pont", "Le mauvais camp reste vide ; les deux bons abritent tout le monde")
	o._choisir_pont(pont)
	var acces: Dictionary = jeu.trafic.acces_pont(pont, debut)
	for rue in acces["obstacles"]:
		jeu._sur_commande("r", rue, {"reparer": true})
	o._choisir_pont(pont)
	var attendu: Dictionary = jeu.trafic.prevoir_pont(pont, debut)
	await cliquer(jeu.interface._recap_bouton)
	verifier(o.etape == "pont_travaux" and not jeu.ville.route_praticable(pont, debut),
		"L'engagement paie le pont sans ouvrir sa traversée")
	var fin: float = debut + jeu.ville.duree_reparation_mois("r", pont)
	actualiser(fin - 0.01)
	verifier(o.etape == "pont_travaux" and jeu.ville.camp_occupants(lointain, jeu.mois) == 0.0,
		"Le camp de l'autre rive reste vide jusqu'à la livraison")
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	jeu._sur_reprise()
	verifier(o.etape == "pont_travaux", "La reprise conserve le pont en travaux")
	await capture("12_pont_travaux")
	jeu._sur_vitesse(12.0)
	actualiser(fin)
	verifier(o.etape == "pont_livre" and jeu.vitesse == 0.0, "La livraison du premier pont met le jeu en pause")
	verifier(o.verrou() == "", "Le pont rouvert avec ses accès lève le verrou")
	verifier(jeu.ville.route_praticable(pont, fin) and jeu.reparations["r"][pont].visible
		and not jeu.ruines_ponts[pont].visible, "Le tablier livré remplace la ruine")
	verifier(jeu.ville.camp_occupants(lointain, fin) > 0.0
		and not jeu.ville.camp_accessible(lointain, fin - 0.01),
		"La livraison remplit le camp de l'autre rive, sans réécrire le passé")
	verifier(not jeu._diagnostic_marqueurs.visible,
		"Le pont livré ne porte plus de croix de coupure")
	verifier(is_equal_approx(jeu.ville.valeur("r", pont, "charge", fin), float(attendu["charge_pont"])),
		"Le trafic livré correspond à la prévision, même depuis la vue d'ensemble")
	await capture("13_pont_livre_trafic")
	await cliquer(bouton("Voir le pont rouvert"))
	await capture("14_pont_rouvert")
	await cliquer(bouton("Choisir la suite"))
	verifier(o.pont_termine and o.etape in ["choix", "livraison"], "Le pont ouvre la suite des interventions locales")
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	jeu._sur_reprise()
	verifier(o.pont_termine and o.etape in ["choix", "livraison"], "Une reprise après livraison ne redemande pas un pont")
	# Reconstruire directement sur la carte ne dépend pas de la visite du calque.
	jeu._sur_reset()
	jeu.ville.abriter(bons[0], 0.0)
	jeu.ville.abriter(bons[1], 0.0)
	actualiser(debut)
	jeu._sur_commande("r", pont, {"reparer": true})
	verifier(o.etape == "pont_travaux" and not o.trafic_vu,
		"Un pont engagé directement est reconnu sans imposer le clic tutoriel")
	# 🔒 Un camp isolé ne débloque rien : le guide le dit et redemande un terrain.
	jeu._sur_reset()
	jeu.ville.abriter(lointain, 0.0)
	actualiser(0.2)
	verifier(o.etape == "reloger" and "autre rive" in o._texte.text and o.verrou() == "reloger",
		"Un camp vide explique l'isolement et redemande un terrain de ce côté")
	jeu._sur_reset()
	jeu._sur_theme("trafic")
	jeu.ville.abriter(bons[0], 0.0)
	jeu.ville.abriter(bons[1], 0.0)
	actualiser(0.2)
	verifier(o.etape == "pont_choix", "Un calque Trafic déjà ouvert est reconnu à la livraison du camp")
