extends SceneTree
## --headless --script res://outils/essai_fonds.gd -- --ouverture
## 🏗️ Les deux budgets (118) : l'en dur attend le fonds, le provisoire se remplace, le pont résistant.
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


func executer() -> void:
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_fonds.wehrau"
	var v = jeu.ville
	var ui = jeu.interface
	verifier(not v.reparer("r", 168, 0.0, false), "Sans le fonds, le pont en dur est refusé")
	jeu._sauter_au_pont()
	var t: float = jeu.mois
	var pont := 169
	verifier(v.pont_provisoire(pont, t) and not v.consolidation_possible(pont, t),
		"Le provisoire livré ne se remplace pas sans le fonds")
	# La mairie : la ligne attend le pont rouvert, puis verse une fois.
	jeu.ouverture.pont_termine = false
	ui.ouvrir_lieu("mairie")
	var l: Dictionary = ui._lieu_lignes["fonds"]
	verifier((l["bloc"] as Control).visible and (l["bouton"] as Button).disabled,
		"La ligne du fonds se voit à la mairie, grisée avant le pont rouvert")
	jeu.ouverture.pont_termine = true
	ui._maj_lieu()
	var caisse: float = v.caisse_ke(t)
	(l["bouton"] as Button).pressed.emit()
	verifier(is_equal_approx(v.caisse_ke(t), caisse + v.FONDS_RECONSTRUCTION_KE)
		and not (l["bouton"] as Button).visible, "Demandé, le fonds tombe une seule fois : +%.0f k€" % v.FONDS_RECONSTRUCTION_KE)
	verifier(not v.demander_fonds(t), "Le fonds ne se redemande pas")
	ui._fermer_lieu()
	# Le pont en dur à la place du provisoire : le prix entier, sept mois, le provisoire reste ouvert.
	jeu._sur_choix("r", pont)
	verifier(ui._consolider_bouton.visible, "La fiche du provisoire propose le pont en dur")
	jeu.trafic.avancer(t)
	var r: Dictionary = v.commander("r", pont, {"consolider": true}, t)
	verifier(r["ok"] and is_equal_approx(float(r["cout_ke"]), v.base("r", pont, "cout_reparation_ke")),
		"Le pont en dur engagé : %.0f k€" % r["cout_ke"])
	verifier(v.pont_provisoire(pont, t + 3.0) and v.chantier("r", pont, t + 3.0)["quoi"] == "consolidation",
		"Pendant le chantier, le provisoire reste en service")
	var fin: float = t + v.PONT_MOIS
	jeu.trafic.avancer(fin - 0.01)
	var avant: float = v.valeur("r", pont, "charge", fin)
	jeu.trafic.avancer(fin + 0.01)
	var apres: float = v.valeur("r", pont, "charge", fin + 1.0)
	verifier(not v.pont_provisoire(pont, fin + 0.01) and apres < avant,
		"Livré, le pont en dur porte mieux le trafic : %.2f → %.2f" % [avant, apres])
	verifier(not v.pont_resistant(pont) and v.ponts_emportes_prochaine() == 3,
		"Sans la recherche, la prochaine crue emporterait les trois ponts")
	# 🌉 La recherche de l'institut : un pont en dur engagé après elle tient.
	v._recherche["pont_resistant"] = fin
	v._credit_essai_ke = 5000.0
	verifier(v.reparer("r", 168, fin + 1.0, false) and v.pont_resistant(168)
		and v.ponts_emportes_prochaine() == 2, "Le pont en dur bâti après la recherche est résistant")
	verifier(not v.pont_resistant_livre(168, fin + 2.0) and v.pont_resistant_livre(168, fin + 1.0 + v.PONT_MOIS),
		"Il compte une fois livré")
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	verifier(not v.fonds_recu(fin) and v._consolide.is_empty(), "Recommencer efface le fonds et le pont en dur")
	jeu._sur_reprise()
	verifier(v.fonds_recu(fin) and v.consolidation_finie(pont, fin + 1.0), "La reprise garde le fonds et le pont en dur")
	print("FONDS : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
