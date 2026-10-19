extends SceneTree
## 📊 Le détail du script : ce que coûtent le bandeau, la repeinte et les sommes, morceau par morceau.
##   Godot_console.exe --path Godot --script res://outils/sonde_cpu.gd -- --ouverture --auteur
const Energie := preload("res://scripts/energie.gd")
var jeu


func _initialize() -> void:
	call_deferred("executer")


func images(n: int) -> void:
	for i in n:
		await process_frame


func chrono(nom: String, f: Callable, n := 30) -> void:
	var t := Time.get_ticks_usec()
	for i in n:
		f.call()
	print("  %-40s %8.0f µs" % [nom, float(Time.get_ticks_usec() - t) / n])


func executer() -> void:
	jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	current_scene = jeu
	await images(60)
	jeu._sur_vitesse(0.0)
	jeu._repere("ville")
	await images(10)
	var ui = jeu.interface
	var v = jeu.ville
	var m: float = jeu.mois
	var indic: Dictionary = jeu._indicateurs(true)
	print("\n=== SONDE CPU ===")
	print("-- le bandeau, à chaque image --")
	chrono("interface.maj entier", func(): ui.maj(indic, m, 0.0))
	chrono("retours.actualiser_affichage", func(): ui.retours.actualiser_affichage())
	chrono("_maj_boue", func(): ui._maj_boue())
	chrono("ville.capital", func(): v.capital(m))
	chrono("ville.usure_camp_mois", func(): v.usure_camp_mois(m))
	chrono("_maj_durabilite", func(): ui._maj_durabilite(indic))
	chrono("actualiser_points", func(): ui.actualiser_points(m))
	chrono("_maj_detail", func(): ui._maj_detail(indic, m))
	chrono("maj_degats", func(): ui.maj_degats(indic["degats"]))
	chrono("_maj_rail", func(): ui._maj_rail())
	chrono("etude_publiee", func(): ui.etude_publiee())
	chrono("_financements", func(): ui._financements())
	chrono("_bilan_differe", func(): ui._bilan_differe())
	chrono("saison.temperature", func(): jeu.saison.temperature(m))
	var o = jeu.ouverture
	chrono("ouverture.actualiser", func(): o.actualiser())
	chrono("  objectifs.actualiser", func(): o.objectifs.actualiser())
	chrono("    _restants + atteint", func():
		for id in o.objectifs._restants():
			o.objectifs.atteint(id))
	chrono("  paraitre", func(): o.paraitre())
	print("-- les sommes de ville --")
	chrono("ville.indicateurs", func(): v.indicateurs(m), 10)
	chrono("  Energie.ville_mwh", func(): Energie.ville_mwh(v, m), 10)
	chrono("  ville.caisse_ke", func(): v.caisse_ke(m), 10)
	chrono("    recette_cumulee_ke", func(): v.recette_cumulee_ke(m), 10)
	chrono("    solde_dense_ke", func(): v.solde_dense_ke(m), 10)
	chrono("    aide_cumulee_ke", func(): v.aide_cumulee_ke(m), 10)
	chrono("    achat_nourriture_cumule_ke", func(): v.achat_nourriture_cumule_ke(m), 10)
	chrono("  nourriture_personnes", func(): v.nourriture_personnes(m), 10)
	chrono("  durabilite", func(): v.durabilite(m, 0.0), 10)
	chrono("ville.degats", func(): v.degats(m), 10)
	chrono("Energie.ligne ×1000", func():
		for i in 1000:
			Energie.ligne(v, 50), 3)
	chrono("ville.valeur ×1000", func():
		for i in 1000:
			v.valeur("i", 50, "logements", m), 3)
	chrono("ville.facteur ×1000", func():
		for i in 1000:
			v.facteur("rendement_x", m), 3)
	print("-- la repeinte --")
	chrono("_peindre", func(): jeu._peindre(), 10)
	var mailles := []
	for c in ["i", "r", "b"]:
		for fid in jeu.noeuds[c]:
			mailles.append(jeu.noeuds[c][fid])
	chrono("%d mailles × 17 set_instance_shader_parameter" % mailles.size(), func():
		for mi in mailles:
			for k in 17:
				(mi as GeometryInstance3D).set_instance_shader_parameter("diagnostic_sol", 0.0), 10)
	chrono("travaux.actualiser", func(): jeu.travaux.actualiser(v, m), 10)
	chrono("retours.actualiser", func(): ui.retours.actualiser(m), 10)
	chrono("_montrer_arbres", func(): jeu._montrer_arbres(), 10)
	print("=== fin ===")
	quit(0)
