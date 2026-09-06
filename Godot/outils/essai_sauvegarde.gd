extends SceneTree
## Reprise d'une ville neuve depuis le disque, pendant plusieurs chantiers simultanés.
const Maquette := preload("res://scripts/maquette.gd")
const Sauvegarde := preload("res://scripts/sauvegarde.gd")
const CHEMIN := "res://../QGIS/rendus/partie-controle.wehrau"
var echecs := 0

func _initialize() -> void:
	call_deferred("executer")

func verifier(ok: bool, quoi: String) -> void:
	if not ok:
		echecs += 1
		push_error(quoi)

func nettoyer() -> void:
	for suffixe in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(CHEMIN + suffixe):
			DirAccess.remove_absolute(CHEMIN + suffixe)

func nouvelle():
	var m := Maquette.new()
	m.chemin_sauvegarde = CHEMIN
	root.add_child(m)
	m.vitesse = 0.0
	m.horloge_trafic.stop()
	return m

func mesures(m, t: float) -> Dictionary:
	var routes := {}
	for fid in m.ville.routes:
		routes[fid] = [m.ville.valeur("r", fid, "charge", t),
			m.ville.valeur("r", fid, "stationnement", t)]
	return {"indicateurs": m.ville.indicateurs(t), "degats": m.ville.degats(t),
		"routes": routes, "solaire": m.ville.etat_solaire(32, t),
		"vert": m.ville.etat_vert(32, t), "dense": m.ville.etat_dense(50, t),
		"berge": m.ville.berge_etat(6, t), "chantier": m.ville.chantier("i", 66, t)}

func executer() -> void:
	nettoyer()
	var m = nouvelle()
	m.ville.crediter_essai_ke(100000.0)
	verifier(m.ville.lancer_solaire(32, 0.6, 0.0), "Pose solaire de contrôle refusée")
	verifier(m.ville.lancer_vert(32, 0.4, 0.0), "Toit vert de contrôle refusé")
	verifier(m.ville.densifier(50, 0.5, 2, 0.0), "Densification de contrôle refusée")
	verifier(m.ville.reparer("i", 66, 0.0), "Réparation de contrôle refusée")
	verifier(m.ville.transformer_berge(6, 2, 0.0), "Berge de contrôle refusée")
	verifier(m.ville.planter(55, 0.4, 0.0), "Plantation de contrôle refusée")
	m.ville.commander("r", 55, {"axe": true}, 0.0)
	m.trafic.retirer_axe(55, 0.0)
	verifier(m.ville.financer_recherche("rendement", 0.0), "Recherche de contrôle refusée")
	m.ville.basculer_politique("subv_solaire", 0.0)
	m.mois = 0.25
	m.pivot.caler(75.0, 40.0)
	m.pivot.viser(Vector2(20.0, -80.0), 180.0)
	m._fiche("i", 49)
	m._sur_theme("energie")
	var avant: Dictionary = m._partie()
	var attendus := {}
	for t in [0.25, 6.0, 24.0, 240.0]:
		attendus[t] = mesures(m, t)
	m.interface.sauvegarde_demandee.emit()
	verifier(FileAccess.file_exists(CHEMIN), "La commande Sauvegarder n'écrit pas de fichier")
	verifier(m._partie_valide(avant), "Une partie produite par le jeu est refusée")
	m.free()

	m = nouvelle()
	m.interface.reprise_demandee.emit()
	verifier(m.mois == 0.25 and m.vitesse == 0.0, "La reprise doit retrouver le mois en pause")
	verifier(m._partie() == avant, "L'état complet diffère après une reprise dans une ville neuve")
	verifier(m.trafic.axe_ferme(55), "La rue fermée s'est rouverte")
	for t in attendus:
		verifier(mesures(m, t) == attendus[t], "La trajectoire de la ville diffère au mois " + str(t))
	verifier(m.interface._fiche_titre.text == "COUR DES TILLEULS", "Le lieu repris a perdu son nom")
	for couche in ["i", "r", "b"]:
		for fid in m.ville.objets(couche):
			verifier(m.interface.lieux.noms[couche].has(str(fid)), "Lieu sans nom : " + couche + str(fid))
	verifier(Sauvegarde.lire("autre carte", CHEMIN).has("erreur"), "Une autre carte doit être refusée")
	if "--captures" in OS.get_cmdline_user_args():
		m.moniteur_performances.visible = false
		m._sur_theme("")
		m._repere("compact")
		m._rafraichir(true)
		await process_frame
		await process_frame
		await m._capturer("reprise_partie")

	# Deux écritures, puis fichier principal abîmé : la première partie reste récupérable.
	m.mois = 6.0
	m._sur_sauvegarde()
	verifier(Sauvegarde.lire(m._empreinte_carte, CHEMIN)["partie"]["mois"] == 6.0, "Le remplacement n'a pas enregistré le nouveau mois")
	var f := FileAccess.open(CHEMIN, FileAccess.WRITE)
	f.store_8(0)
	f.close()
	m._sur_reprise()
	verifier(m.mois == 0.25, "La copie de secours n'a pas repris l'ancienne partie")
	verifier("secours" in m.interface._etat_partie.text, "La reprise de secours doit être signalée")

	nettoyer()
	var partie_incomplete := avant.duplicate(true)
	partie_incomplete["ville"].erase("_dense")
	Sauvegarde.ecrire(partie_incomplete, m._empreinte_carte, CHEMIN)
	var intact: Dictionary = m._partie()
	m._sur_reprise()
	verifier(m._partie() == intact, "Une sauvegarde incomplète a modifié la ville en cours")
	var toit_inconnu := avant.duplicate(true)
	toit_inconnu["ville"]["_toit_avant"][99999] = 20.0
	verifier(not m._partie_valide(toit_inconnu), "Un bâtiment absent de la carte est accepté")
	var chantier_incomplet := avant.duplicate(true)
	chantier_incomplet["ville"]["_dense"][50].erase("lots")
	verifier(not m._partie_valide(chantier_incomplet), "Une densification incomplète est acceptée")
	m._sur_reset()
	verifier(m.mois == 0.0 and not m.trafic.axe_ferme(55), "Recommencer après une reprise laisse des décisions")
	verifier(m.ville.caisse_ke(0.0) == m.ville.CAISSE_DEPART_KE, "Recommencer garde la caisse sauvée")
	nettoyer()
	m.selection.sel_fid = -1
	m.selection.sel_couche = ""
	m._sur_sauvegarde()
	m._fiche("r", 55)
	m._sur_reprise()
	verifier(m.interface._fiche_fid == -1 and not m.interface._fiche_panneau.visible,
		"Une reprise sans sélection garde une ancienne fiche")
	m._fiche("i", 49)
	verifier(m.interface._fiche_panneau.visible, "La fiche ne se rouvre pas après la reprise")
	m.free()
	nettoyer()
	print("SAUVEGARDE : reprise, trajectoire sur 20 ans, noms, secours, refus et remise à zéro : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
