extends SceneTree
## Godot --headless --path Godot --script res://outils/essai_travaux.gd
## Retirer --headless et ajouter -- --captures (ou --film) pour les aperçus numérotés.
const Maquette := preload("res://scripts/maquette.gd")
var echecs := 0
var jeu


func _initialize() -> void:
	call_deferred("executer")


func verifier(ok: bool, quoi: String) -> void:
	if not ok:
		echecs += 1
		push_error(quoi)


func actualiser(t: float) -> void:
	jeu.mois = t
	jeu._rafraichir(true)
	jeu.travaux.set_process(false)


func executer() -> void:
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.vitesse = 0.0
	jeu.horloge_trafic.stop()
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	actualiser(0.0)
	verifier(jeu.travaux.actifs == 0 and jeu.travaux.sites.is_empty(), "Du matériel précède la commande")
	verifier(not jeu.ville.densifier(50, 1.0, 2, 0.0), "Le contrôle du refus doit dépasser la caisse")
	actualiser(0.0)
	verifier(jeu.travaux.actifs == 0, "Une commande refusée affiche un chantier")
	jeu.ville.crediter_essai_ke(100000.0)
	verifier(jeu.ville.densifier(50, 0.5, 2, 0.0), "Densification refusée")
	verifier(jeu.ville.reparer("i", 66, 0.0), "Reconstruction refusée")
	verifier(jeu.ville.transformer_berge(6, 2, 0.0), "Renaturation refusée")
	verifier(jeu.ville.supprimer_stationnement(55, 0.0), "Retrait des places refusé")
	verifier(jeu.ville.lancer_solaire(32, 0.6, 0.0), "Pose solaire refusée")
	verifier(jeu.ville.lancer_vert(32, 0.4, 0.0), "Toit vert refusé")
	actualiser(0.0)
	verifier(jeu.travaux.actifs == 5, "Les commandes simultanées doivent occuper cinq lieux dès le clic")
	var caches := {}
	for cle in jeu.travaux.sites:
		var site: Node3D = jeu.travaux.sites[cle]
		caches[cle] = site.get_instance_id()
		verifier(site.get_node("Palissades").multimesh.instance_count > 0, "Palissades absentes : " + cle)
	verifier(jeu.travaux.sites["i50"].has_node("Grue"), "La densification n'a pas de grue")
	verifier(jeu.travaux.sites["i66"].has_node("Grue"), "La reconstruction n'a pas de grue")
	verifier(not jeu.travaux.sites["b6"].has_node("Grue"), "Une grue à tour ne sert pas la berge")
	var etat: Dictionary = jeu.ville.exporter_partie()
	actualiser(2.0)
	verifier(not jeu.travaux.sites["r55"].visible, "Le matériel de stationnement reste après livraison")
	verifier(jeu.travaux.sites["i50"].visible, "Un chantier voisin encore actif a disparu")
	actualiser(240.0)
	verifier(jeu.travaux.actifs == 0, "Du matériel reste après la fin de tous les travaux")
	jeu._sur_reset()
	verifier(jeu.travaux.actifs == 0, "Recommencer laisse du matériel")
	jeu.ville.importer_partie(etat)
	actualiser(0.25)
	verifier(jeu.travaux.actifs == 5, "La reprise oublie des travaux")
	for cle in caches:
		verifier(jeu.travaux.sites[cle].get_instance_id() == caches[cle], "Le décor est recréé au lieu d'être réutilisé")
	jeu._sur_theme("energie")
	verifier(not jeu.travaux.visible, "Le diagnostic garde les grues")
	verifier(not jeu.travaux._reperes.visible, "Le diagnostic garde les repères de loin")
	jeu._sur_theme("")
	verifier(jeu.travaux.visible and jeu.travaux.actifs == 5, "Le retour à la ville perd ses chantiers")
	jeu.pivot.viser(Vector2.ZERO, 1200.0)
	verifier(jeu.travaux._reperes.visible, "La vue de ville ne montre aucun repère")
	jeu.pivot.viser(Vector2.ZERO, 100.0)
	verifier(not jeu.travaux._reperes.visible, "Le repère de loin masque le gros plan")
	jeu.travaux.set_process(false)
	if "--captures" in OS.get_cmdline_user_args() or "--film" in OS.get_cmdline_user_args():
		await apercus()
	for fid in jeu.ville.routes:
		if jeu.ville.routes[fid].get("etat_crue", "") != "coupe":
			continue
		verifier(jeu.ville.reparer("r", fid, 0.25), "Réparation du pont refusée")
		actualiser(0.25)
		var lignes: Array = jeu.travaux._lignes("r", fid)
		verifier(not lignes.is_empty(), "Les accès du pont ne sont pas balisés")
		for ligne in lignes:
			verifier(ligne.size() == 2 and ligne[0].distance_to(ligne[1]) < 30.0,
				"Des palissades flottent sur le tablier manquant")
		break
	print("Travaux visibles : apparition, refus, cinq lieux dont commande double, livraison, reset, reprise et diagnostic · %d échec(s)" % echecs)
	quit(1 if echecs else 0)


func apercus() -> void:
	var bandeau := CanvasLayer.new()
	root.add_child(bandeau)
	var legende := Label.new()
	legende.position = Vector2(24, 18)
	legende.add_theme_font_size_override("font_size", 26)
	legende.add_theme_color_override("font_color", Color("203e3b"))
	bandeau.add_child(legende)
	var cadrages := [
		["1 · Densification — grue et palissades", "dense", Vector2(187.0, -279.0), 115.0],
		["2 · Renaturation — balises le long de la rive", "berge", Vector2(120.0, -147.0), 65.0],
		["3 · Reconstruction — chantier dans le faubourg", "reconstruction", Vector2.ZERO, 110.0]]
	var boite: AABB = jeu.noeuds["i"][66].mesh.get_aabb()
	cadrages[2][2] = Vector2(boite.get_center().x, boite.get_center().z)
	jeu.pivot.caler(20.0, 50.0)
	for c in cadrages:
		legende.text = c[0]
		jeu.pivot.viser(c[2], c[3])
		jeu.travaux._process(0.0)
		await jeu._capturer("travaux_" + c[1])
		if "--film" in OS.get_cmdline_user_args():
			var dossier := ProjectSettings.globalize_path("res://../QGIS/rendus/travaux-" + c[1] + "/")
			DirAccess.make_dir_recursive_absolute(dossier)
			for k in 48:
				jeu.travaux._process(0.25)
				await process_frame
				await RenderingServer.frame_post_draw
				var img := root.get_texture().get_image()
				img.resize(960, 540, Image.INTERPOLATE_LANCZOS)
				verifier(img.save_png(dossier + "%03d.png" % k) == OK, "Échec de capture")
	jeu._repere("ville")
	legende.text = "4 · Les chantiers dans la ville"
	await jeu._capturer("travaux_ville")
