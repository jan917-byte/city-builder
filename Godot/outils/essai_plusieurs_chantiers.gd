extends SceneTree
## --headless --script res://outils/essai_plusieurs_chantiers.gd -- --ouverture
## 🏗️ Attendre au ×4 coûte, et le guide dit qu'on peut lancer un autre îlot (auteur, 2026-10-28).
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
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_plusieurs_chantiers.wehrau"
	var v = jeu.ville
	var o = jeu.ouverture
	jeu._sauter_au_pont()
	var t: float = jeu.mois
	# ⏳ Amélioré, le camp use encore, à moitié.
	var attendu: float = v.reloges(t) * v.CAMP_USURE_PERSONNE_MOIS * v.CAMP_USURE_AMELIORE
	verifier(v.demande_livree("amelioration", t) and v.usure_camp_mois(t) > 0.0
		and is_equal_approx(v.usure_camp_mois(t), attendu),
		"Camp amélioré : %.0f personnes, −%.2f confiance par mois" % [v.reloges(t), v.usure_camp_mois(t)])
	# Ce que la caisse paie au pont livré, la première année.
	var lignes := []
	for fid in o.ilots_a_rebatir():
		lignes.append("%s %.0f k€" % [o._nom("i", fid), v.cout_reparation_ke("i", fid)])
	print("au pont · caisse %.0f k€ · %s" % [v.caisse_ke(t), ", ".join(lignes)])
	# Le pont rouvert, le fonds demandé : la caisse paie plusieurs îlots.
	o.pont_termine = true
	o.pont_termine_mois = t
	o.mairie_vue = true
	o.plainte = 2
	v.demander_fonds(t)
	verifier(o.ilot_abordable(), "Le fonds reçu, un îlot est payable (caisse %.0f k€)" % v.caisse_ke(t))
	jeu._sur_commande("i", o.LAVOIR, {"reparer": "tradition"})
	o.actualiser(true)
	verifier(o.etape == "travaux" and o.DIRE_AUTRE_ILOT in o._texte.text and "au camp" in o._texte.text,
		"Le premier chantier en cours, le guide propose d'en lancer un autre et compte le camp")
	verifier(not o.groupe_carte().is_empty() and not o.LAVOIR in o.groupe_carte(),
		"Les autres îlots clignotent pendant le chantier (%d)" % o.groupe_carte().size())
	# ⏩ Au ×4, guide fermé : une nouvelle, puis plus avant six mois.
	o.ouvert = false
	o.actualiser(true)
	var avant: int = jeu.interface.retours.journal.size()
	jeu._sur_vitesse(4.0)
	verifier(jeu.interface.retours.journal.size() == avant + 1
		and "Rien n'oblige à attendre" in str(jeu.interface.retours.journal[-1]),
		"Au ×4, une nouvelle dit qu'on peut lancer un autre îlot")
	jeu._sur_vitesse(1.0)
	jeu._sur_vitesse(4.0)
	verifier(jeu.interface.retours.journal.size() == avant + 1, "Elle ne revient pas tout de suite")
	# Plus rien de payable : ni rappel, ni consigne.
	var caisse: float = v.caisse_ke(t)
	v._depenser("essai", caisse)
	jeu._sur_vitesse(1.0)
	o._accelerer_mois = -INF
	jeu._sur_vitesse(4.0)
	verifier(not o.ilot_abordable() and jeu.interface.retours.journal.size() == avant + 1,
		"Caisse vide : pas de rappel au ×4")
	print("PLUSIEURS CHANTIERS : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)
