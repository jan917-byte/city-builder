extends RefCounted
# L'état de Wehrau, et ce qu'il devient quand le temps passe.
# Que des nombres : aucun nœud, aucune couleur, aucun signal.
#
# La rampe vient de `Classeur/README.md`, déjà éprouvée dans `08_jouer.py`.
# ⚠️ Les deux moteurs doivent donner le même chiffre — contrôle de recoupement
# décrit dans le README de Godot.

const Energie := preload("res://scripts/energie.gd")
const Recherche := preload("res://scripts/recherche.gd")
const Politiques := preload("res://scripts/politiques.gd")
var _ponts: Array[int] = []

const HORIZON_MOIS := 240                  # 20 ans. Le classeur s'arrête à 60.

# ⏸️ Budget en POINTS de l'ancien prototype, hors boucle jouable depuis le
# 2026-08-17 ; seul `chantiers.gd` les lit encore.
const BUDGET_MENSUEL := 100.0 / 12.0       # 100 pts par an — Classeur §2
const CAPITAL_DEPART := 50.0               # décision 16b

# ==========================================================================
# LA CAISSE — deux nombres, et ils décrivent une mairie (2026-08-17)
# ==========================================================================
# 🎚️ LEVEL DESIGN, pas physique : à eux seuls ils décident si le jeu est « dur
# mais possible ». Trop haut, on équipe sans choisir ; trop bas, on regarde le
# temps passer. Repère imprimé par `-- --essai`.
const CAISSE_DEPART_KE := 3500.0           # relogement, un pont au choix et déblaiement (auteur, 2026-09-20)
const DOTATION_KE_MOIS := 30.0             # 360 k€/an votés pour la transition

# 🌳 CE QU'IL RESTE DE TRAFIC AU VERGER tant que la boue y est — voir
# `part_trafic`. 🎚️ Level design, à juger devant l'image.
const PART_TRAFIC_VERGER := 0.20

# 🟤 L'ILSE SE DÉCANTE SEULE (89, auteur) : chargée de la crue au mois 0,
# redevenue normale après ce nombre de mois. 🎚️ Level design.
const EAU_DECANTATION_MOIS := 4.0

var ilots := {}            # fid:int -> {champ: float|String}
var routes := {}
var berges := {}           # 8 objets : une par rive et par bief (07)
var crue := {}             # le contrat de `04e` : niveau annoncé, paliers, bande
var riverains := {}        # fid tronçon -> [fid îlot]
var _rampes := {"i": {}, "r": {}}   # couche -> fid -> [rampe]
var _solaire := {}         # fid -> {debut, duree, cible, cout_ke}
var _vert := {}            # fid -> idem, pour les toits verts
var _stationnement_supprime := {}  # fid -> mois d'engagement
var _dense := {}           # fid -> {debut, duree, etages, logements, cout_ke}
## 🎓 Sujet de recherche -> mois d'engagement. Un sujet engagé ne s'arrête plus.
var _recherche := {}
## 🏛️ Politique -> [[début, fin], …] ; fin = -1 tant qu'elle est en vigueur.
var _politiques := {}
var _depense_ke := 0.0     # tout ce qui a été engagé en poses depuis le mois 0
var _depense_genre := {}   # le même total, par genre : ce que le détail de l'argent affiche
## 🧪 OUTIL D'ESSAI, PAS UNE RÈGLE DU JEU : de l'argent tombé du ciel, pour
## atteindre en un clic un état que vingt ans de dotation mettraient à payer.
## Le jour où la boucle se juge pour de bon, ce champ et son bouton sautent.
var _credit_essai_ke := 0.0
var _repare := {}          # "i:66" -> le mois où la réparation a été engagée
var _provisoire := {}      # fid pont -> true : rétabli par un pont provisoire
## 🧹 Le déblaiement groupé (auteur, 2026-10-05) : fid rue -> rang. Une seule
## équipe : la rue de rang k se libère (k + 1) × deux jours après l'engagement.
var _file_deblaiement := {}
## 🎚️ Tout déblayer d'un coup n'est proposé qu'après autant de rues faites à la main.
const DEBLAIEMENT_SEUIL := 3
var _rebati := {}          # fid îlot -> la façon de le relever (`RECONSTRUCTIONS`)
var _concours := {}        # {debut, fid} : le concours de la zone sinistrée (104), lancé depuis cet îlot
var _berge := {}           # fid -> {cible, debut, depuis, cout_ke}
var _toit_avant := {}      # fid -> `toit_m2` d'avant la reconstruction
var _plantation := {}      # fid tronçon -> {debut, duree, cible, cout_ke, arbres}
## Les seuils de canopée des emplacements d'alignement, triés, un tableau par
## tronçon. C'est `07` qui les pose ; ici on ne fait que les compter.
var _seuils := {}          # fid tronçon -> [seuil]
var _adaptation_total_ke := 0.0
var _co2_depart_kt := 0.0
## 🏕️ Champ -> {debut, places, cout_ke}. Un camp posé ne se démonte pas : ce
## qu'on en fait au bout de vingt ans reste une question ouverte.
var _camps := {}
## 🚿 Demande du camp -> mois de la commande. Elles valent pour tous les camps.
var _demandes := {}
## Le morceau de réseau du faubourg sinistré, mesuré au chargement.
var _morceau_sinistres := -1
## 🌳 Les tronçons du verger, relevés au chargement : `part_boue` les nomme.
var _verger := PackedInt32Array()
## Le mois du dernier calcul de `verger_sous_boue`, et sa réponse.
var _verger_vu := -1.0
var _verger_sale := true
## 🛠️ MODE AUTEUR, PAS UNE RÈGLE DU JEU : tout chantier engagé est livré
## immédiatement. Les prix, la caisse et la dotation restent ceux du jeu — sans
## ça, juger la vingtième minute coûterait vingt minutes à chaque essai.
var livraison_immediate := false


## La durée annoncée ET vécue d'un chantier. Le mode auteur passe par ici et
## par nulle part ailleurs : une durée annoncée qui ne serait pas celle du
## chantier ferait mentir la fiche.
func _delai(mois: float) -> float:
	return 0.0 if livraison_immediate else mois


## 🟤 Ce que l'Ilse garde de la crue : 1 au mois 0, 0 une fois décantée.
static func limon_eau(t: float) -> float:
	return clampf(1.0 - t / EAU_DECANTATION_MOIS, 0.0, 1.0)

# 🔄 Un `_base_avant` figeait en base la part posée pour permettre de réviser
# une cible en cours de chantier. Retiré avec la caisse : réécrire la base
# efface l'HISTOIRE de la pose, dont la recette encaissée est l'intégrale — le
# toit aurait semblé équipé depuis le mois 0. Désormais les rampes s'ADDITIONNENT
# et un chantier engagé ne se révise plus.

# Une pose complète dure au plus UN mois, une hausse partielle au prorata.
# 🔄 C'était 3 jusqu'au 2026-08-17 : trois minutes de montre, trop long pour
# juger le geste. La plupart des poses tombant sous le mois, `interface._duree`
# les annonce EN JOURS.
const SOLAIRE_MOIS_POUR_100 := 1.0

# ==========================================================================
# LE TOIT VERT — le second usage du même toit (2026-08-31)
# ==========================================================================
# 🌿 LES DEUX DÉCISIONS SE PARTAGENT UN SEUL 100 % : un TOIT porte des panneaux
# OU du substrat, jamais les deux — la règle est au bâtiment, et c'est 07 qui
# range les volumes pour que la maquette la tienne. Le vert est en plus borné
# par la part PLATE du toit — `Energie.part_plate`, mesurée volume par volume.
# 🌿 CE QU'IL FAIT, et rien d'autre : il retient la pluie, donc il abaisse la
# prochaine crue — DANS TOUTE LA VILLE, pas dans un bief. C'est ce qui le
# distingue de la berge, qui ne soulage que la section qu'elle élargit.
# 🎚️ LEVEL DESIGN, et c'est LE nombre du jeu : verdir les 1,58 ha plats et
# équipables de Wehrau rachète 0,40 m de crue pour ~1 800 k€. Les deux repères
# qui le tiennent — renaturer les huit berges coûte 8 166 k€ pour ~0,84 m par
# bief, et sous 0,75 m PAS UN bâtiment du faubourg ne sort de la ruine. Le toit
# vert est donc le mètre le moins cher, et le seul qui ne se voie pas d'en bas.
const TOIT_VERT_MOIS_POUR_100 := 2.0        # étanchéité reprise, puis substrat
const TOIT_VERT_BAISSE_M_PAR_HA := 0.25     # de crue en moins, par hectare verdi

# Ce qui change dans le temps ; tout le reste est figé volontairement.
# ⚠️ `canopee` reste ici bien que son indicateur soit retiré : c'est elle qui
# fait l'OMBRAGE des toits. Une donnée n'est pas un indicateur.
# 🪜 `part_rendue` est le JUMEAU de `part_toit_equipe` : l'une est la surface
# couverte — ce que le shader peint —, l'autre le rendement obtenu, qui n'est
# pas droit (`Energie.courbe_rendue`). Deux rampes plutôt qu'une courbe lue au
# vol, pour que la recette encaissée reste une intégrale exacte.
# 🏢 `part_dense` est la part des bâtiments montables déjà montés : le curseur
# de la densification, et l'avancement que le shader compare aux rangs de 07.
const CHAMPS_MOBILES := {
	"i": ["canopee", "impermeabilise", "riverain", "logements",
		"part_toit_equipe", "part_rendue", "part_toit_vert", "part_isolee",
		"part_dense"],
	"r": ["canopee", "emprise_libre_m", "stationnement", "charge"],
}


# ==========================================================================
# LA CRUE — trois réparations, un seul mécanisme (04e · décision 23b)
# ==========================================================================
# 🔴 LE NOYAU NE SAIT RIEN DE LA CRUE. Chaque objet porte SON prix, calculé par
# `04e_crue.py` et posé dans sa fiche : un îlot à reconstruire, une rue à
# déblayer, un tablier à rebâtir. Ici on compare un nombre à la caisse, et on
# note ce qui est engagé. Le jour où le level design change les prix, pas une
# ligne de GDScript ne bouge.
#
# 🎚️ LES TROIS DURÉES, elles, sont d'ici — ce sont des durées de JEU, pas des
# chiffres de la carte. Repère : la pose solaire d'un îlot tient en un mois.
const RECONSTRUCTION_MOIS := 12.0    # un îlot relevé : un an de chantier
const DEBLAIEMENT_MOIS := 2.0 / 30.0 # la vase enlevée d'une rue : deux jours (auteur, 2026-09-26)
const PONT_MOIS := 8.0               # un franchissement rebâti en dur (87)
# 🌉 LE PONT PROVISOIRE (87). 🎚️ Proposition à juger : durée, part du prix en
# dur, débit d'une voie en alternat (lu par `trafic.gd`).
const PONT_PROVISOIRE_MOIS := 3.0
const PONT_PROVISOIRE_PART := 0.25
const PONT_PROVISOIRE_CAPACITE := 0.5
# 🏗️ REBÂTIR UN ÎLOT SINISTRÉ, quatre façons qui se valent (95, auteur 2026-10-02) :
# chacune gagne sur un seul plan. 🎚️ LEVEL DESIGN, tout ce bloc, proposé.
# `hausse_m` : 2,5 m, le dernier palier que `04e` a mesuré (`ruine_apres_baisse`).
const RECONSTRUCTIONS := {
	"tradition": {"nom": "Comme avant", "prix": 1.0, "duree": 1.0, "logements": 1.0,
		"confiance": 1.0, "hausse_m": 0.0},
	"moderne": {"nom": "Moderne", "prix": 1.3, "duree": 1.5, "logements": 1.3,
		"confiance": 0.5, "hausse_m": 0.0},
	"pilotis": {"nom": "Sur pilotis", "prix": 1.6, "duree": 1.25, "logements": 1.0,
		"confiance": 0.75, "hausse_m": 2.5},
	"parc": {"nom": "Parc inondable", "prix": 0.2, "duree": 0.5, "logements": 0.0,
		"confiance": -1.0, "hausse_m": 0.0},
}
const RECONSTRUCTIONS_ORDRE := ["tradition", "moderne", "pilotis", "parc"]
# 🏛️ UN CONCOURS POUR TOUTE LA ZONE SINISTRÉE (104, auteur 2026-10-06) : il coûte
# et prend un mois, puis chaque îlot montre ses quatre projets. « Comme avant »
# n'en a pas besoin. 🎚️ Prix proposé, à juger : ~4 mois de dotation.
const CONCOURS_KE := 120.0
const CONCOURS_MOIS := 1.0
const PARC_BAISSE_M_PAR_HA := 0.10   # de crue en moins dans toute la ville, par hectare rendu


# ==========================================================================
# LA BERGE — trois états francs (2026-08-26)
# ==========================================================================
# 🎚️ LEVEL DESIGN, les cinq nombres : ce sont EUX qui disent si rendre l'Ilse à
# la ville tient dans un mandat ou dans vingt ans. Le prix est CUMULÉ depuis
# l'asphalte, donc passer par le quai apaisé ne coûte pas plus cher que d'aller
# droit à la berge renaturée — sinon le jeu punirait la prudence.
# 🌊 CE QU'ELLE CHANGE (question 24, tranchée le 2026-08-26) : la RÉSILIENCE À
# LA PROCHAINE CRUE, et rien d'autre pour l'instant. Rendre une rive au fleuve
# élargit la section : le niveau de la crue annoncée baisse sur toute la
# traversée du bief, LES DEUX RIVES — donc l'aléa des îlots, et la part que la
# prochaine reprendrait. Le trafic de la voie de berge, la canopée et
# l'imperméabilisation restent à trancher.
# 🎚️ LE SIXIÈME NOMBRE, et c'est le plus lourd : combien de crue un mètre de
# rive rendue rachète. Repère mesuré par `04e` — sous 0,75 m de baisse, PAS UN
# bâtiment du faubourg ne sort de la ruine ; à 2,00 m, 56 des 135 en sortent.
const BERGE_ASPHALTE := 0
const BERGE_APAISEE := 1
const BERGE_RENATUREE := 2
const BERGE_NOMS := ["asphalte", "quai apaisé", "berge renaturée"]
const BERGE_PRIX_KE_M := [0.0, 1.2, 3.4]     # k€ par mètre de rive, cumulés
const BERGE_MOIS := [0.0, 6.0, 18.0]         # depuis l'asphalte, cumulés aussi
const BERGE_BAISSE_M_PAR_M := 0.12          # de crue en moins par mètre de rive rendue


# ==========================================================================
# PLANTER UNE RUE — quatre nombres (2026-08-31)
# ==========================================================================
# 🌳 OÙ, ET POURQUOI PAS AILLEURS : un îlot bâti porte 8,78 ha de canopée que
# la maquette de masses ne peut pas montrer — le pâté est plein, il n'y a pas
# de sol dessous. La rue, si : `07` tient 821 emplacements en réserve, chacun
# avec son seuil, et sait déjà n'en révéler aucun dans l'Ilse ni sur la
# chaussée. La décision est donc SUR LA RUE, et elle se voit.
# 🎚️ LEVEL DESIGN, les quatre : ce sont eux qui disent si planter vaut mieux
# que poser des panneaux avec le même argent.
## Planté de bout en bout, un arbre tous les 12 m. 🔴 LE MÊME NOMBRE que
## `CANOPEE_ALIGNEMENT_MAX` dans `07_exporter_godot.py` — écrit deux fois,
## contrôlé au chargement. Aucun tronçon de Wehrau ne dépasse 0,20 aujourd'hui.
const PLANTATION_CANOPEE_MAX := 0.40
## Un arbre de rue, fosse et reprise comprises. À discuter avec quelqu'un qui
## en a fait planter, comme les 260 €/m² du panneau.
const PLANTATION_PRIX_KE_ARBRE := 1.5
## Planter est rapide, l'ombre ne l'est pas. 🔄 La montée de D07 est de 60 mois
## dans le classeur : trop long pour qu'on voie la concurrence se jouer dans une
## partie, c'est une dette nommée du prototype.
const PLANTATION_MOIS := 24.0
## 🎚️ CE QU'UN ARBRE ÉPARGNE, et c'est le nombre qui décide si la plantation est
## une décision ou une décoration : l'ombre portée sur les façades qu'il borde,
## en MWh/an de moins à consommer. Repère : les 821 emplacements de Wehrau tous
## occupés font 821 fois ce nombre, à comparer aux ~51 GWh de la ville.
const PLANTATION_MWH_ARBRE_AN := 0.25


func charger(d: Dictionary) -> void:
	var o: Dictionary = d["objets"]
	crue = d.get("crue", {})
	for cle in (o.get("berges", {}) as Dictionary):
		berges[int(cle)] = (o["berges"] as Dictionary)[cle]
	for cle in (o["ilots"] as Dictionary):
		ilots[int(cle)] = (o["ilots"] as Dictionary)[cle]
	for cle in (o["routes"] as Dictionary):
		routes[int(cle)] = (o["routes"] as Dictionary)[cle]
		if str(routes[int(cle)].get("etat_crue", "")) == "coupe":
			_ponts.append(int(cle))
	_ponts.sort()
	for cle in (d["riverains"] as Dictionary):
		var liste := []
		for f in (d["riverains"] as Dictionary)[cle]:
			liste.append(int(f))
		riverains[int(cle)] = liste

	# 🌳 Les emplacements d'alignement, réduits à leur seuil : c'est tout ce que
	# le noyau a besoin de savoir pour compter des arbres et les faire payer.
	for cle in (d.get("alignements", {}) as Dictionary):
		var s := PackedFloat32Array()
		for a in ((d["alignements"] as Dictionary)[cle] as Array):
			s.append(float(a[5]))
		s.sort()
		_seuils[int(cle)] = s
		# 🔴 CONTRÔLE NOMMÉ : le plafond d'ici et `CANOPEE_ALIGNEMENT_MAX` de
		# `07` sont le MÊME nombre écrit deux fois. S'ils divergent, le curseur
		# promet des arbres qui n'existent pas dans l'export.
		if s.size() > 0 and s[s.size() - 1] > PLANTATION_CANOPEE_MAX + 0.001:
			push_error("plantation : le tronçon %d a un seuil à %.2f, au-dessus du plafond %.2f — voir CANOPEE_ALIGNEMENT_MAX dans 07_exporter_godot.py"
				% [int(cle), s[s.size() - 1], PLANTATION_CANOPEE_MAX])

	# La jauge d'adaptation porte l'urgence vitale : logements à relever et
	# franchissements à rétablir. Le déblaiement des rues reste visible dans le
	# diagnostic, mais ne retient pas indéfiniment l'ouverture de la réduction.
	for fid in ilots:
		if base("i", fid, "logements_sinistres") > 0.0:
			_adaptation_total_ke += base("i", fid, "cout_reparation_ke")
	for fid in routes:
		if str(routes[fid].get("etat_crue", "")) == "coupe":
			_adaptation_total_ke += base("r", fid, "cout_reparation_ke")
	var pire := -1
	var perdus := -1.0
	for fid in ilots:
		var n := base("i", fid, "logements_sinistres")
		if n > perdus:
			perdus = n
			pire = int(fid)
	_morceau_sinistres = morceau("i", pire) if pire >= 0 else -1
	_verger.clear()
	for fid in routes:
		if base("r", fid, "part_boue") > 0.0:
			_verger.append(int(fid))
	var m := Energie.ville_mwh(self, 0.0)
	_co2_depart_kt = float(m["achat"]) * Energie.CO2_KG_KWH / 1000.0


func objets(couche: String) -> Dictionary:
	match couche:
		"i": return ilots
		"b": return berges
	return routes


## L'historique des décisions suffit : les indicateurs se recalculent au mois repris.
const CHAMPS_PARTIE := ["_rampes", "_solaire", "_vert", "_stationnement_supprime",
	"_dense", "_recherche", "_politiques", "_depense_ke", "_credit_essai_ke",
	"_repare", "_berge", "_toit_avant", "_plantation", "_camps", "_provisoire",
	"_cultures", "_demandes", "_depense_genre", "_rebati", "_file_deblaiement",
	"_permeable", "_concours"]

## Champs apparus après coup : une partie sauvegardée avant eux reste jouable.
const CHAMPS_PARTIE_NEUFS := ["_camps", "_provisoire", "_cultures", "_demandes", "_depense_genre",
	"_rebati", "_file_deblaiement", "_permeable", "_concours"]

func exporter_partie() -> Dictionary:
	var etat := {}
	for champ in CHAMPS_PARTIE:
		etat[champ] = get(champ)
	return etat.duplicate(true)

func valider_partie(etat: Dictionary) -> bool:
	for champ in CHAMPS_PARTIE:
		if not etat.has(champ):
			if champ in CHAMPS_PARTIE_NEUFS:
				continue
			return false
		if typeof(etat[champ]) != typeof(get(champ)):
			return false
	if not etat["_rampes"].has_all(["i", "r"]):
		return false
	for couche in ["i", "r"]:
		if not etat["_rampes"][couche] is Dictionary:
			return false
		for fid in etat["_rampes"][couche]:
			if not objets(couche).has(fid) or not etat["_rampes"][couche][fid] is Array:
				return false
			for rampe in etat["_rampes"][couche][fid]:
				if not _forme_partie(rampe, {"champ": "", "ecart": 0.0, "d": 0.0, "L": 0.0, "M": 0.0}):
					return false
				if not rampe["champ"] in CHAMPS_MOBILES[couche]:
					return false
	var pose := {"debut": 0.0, "duree": 0.0, "cible": 0.0, "cout_ke": 0.0}
	var formes := {"_solaire": [ilots, pose], "_vert": [ilots, pose],
		"_dense": [ilots, {"debut": 0.0, "duree": 0.0, "etages": 0,
			"cible": 0.0, "cout_ke": 0.0, "lots": [{"debut": 0.0, "duree": 0.0, "logements": 0.0}]}],
		"_berge": [berges, {"debut": 0.0, "duree": 0.0, "cible": 0,
			"depuis": 0, "cout_ke": 0.0}],
		"_plantation": [routes, {"debut": 0.0, "duree": 0.0, "cible": 0.0,
			"cout_ke": 0.0, "arbres": 0}],
		"_camps": [ilots, {"debut": 0.0, "places": 0, "cout_ke": 0.0}],
		"_permeable": [ilots, {"debut": 0.0, "duree": 0.0, "cout_ke": 0.0}],
		"_cultures": [ilots, [{"debut": 0.0, "culture": 0, "cout_ke": 0.0}]],
		"_toit_avant": [ilots, 0.0], "_stationnement_supprime": [routes, 0.0],
		"_provisoire": [routes, true],
		"_file_deblaiement": [routes, 0.0],
		"_rebati": [ilots, ""],
		"_demandes": [DEMANDES, 0.0],
		"_recherche": [Recherche.SUJETS, 0.0]}
	for champ in formes:
		if not etat.has(champ):
			continue
		for fid in etat[champ]:
			if not formes[champ][0].has(fid) or not _forme_partie(etat[champ][fid], formes[champ][1]):
				return false
	for fid in etat.get("_rebati", {}):
		if not RECONSTRUCTIONS.has(etat["_rebati"][fid]):
			return false
	for fid in etat.get("_cultures", {}):
		for d in etat["_cultures"][fid]:
			if int(d["culture"]) < 0 or int(d["culture"]) >= CULTURES.size():
				return false
	for cle in etat["_politiques"]:
		if not Politiques.POLITIQUES.has(cle) or not _forme_partie(etat["_politiques"][cle], [[0.0]]):
			return false
		for periode in etat["_politiques"][cle]:
			if periode.size() != 2:
				return false
	for cle in etat["_repare"]:
		if not cle is String or not _forme_partie(etat["_repare"][cle], 0.0):
			return false
		var morceaux: PackedStringArray = cle.split(":")
		if morceaux.size() != 2 or not morceaux[0] in ["i", "r"] or not morceaux[1].is_valid_int():
			return false
		if not objets(morceaux[0]).has(int(morceaux[1])):
			return false
	for champ in ["_depense_ke", "_credit_essai_ke"]:
		if not is_finite(etat[champ]) or etat[champ] < 0.0:
			return false
	return true

static func _forme_partie(valeur_sauvee: Variant, modele: Variant) -> bool:
	if modele is float:
		return (valeur_sauvee is float or valeur_sauvee is int) and is_finite(float(valeur_sauvee))
	if typeof(valeur_sauvee) != typeof(modele):
		return false
	if modele is Dictionary:
		for cle in modele:
			if not valeur_sauvee.has(cle) or not _forme_partie(valeur_sauvee[cle], modele[cle]):
				return false
	elif modele is Array:
		for element in valeur_sauvee:
			if not _forme_partie(element, modele[0]):
				return false
	return true

func importer_partie(etat: Dictionary) -> void:
	reinitialiser()
	for champ in CHAMPS_PARTIE:
		if not etat.has(champ):
			continue
		var valeur_sauvee: Variant = etat[champ]
		set(champ, valeur_sauvee.duplicate(true) if valeur_sauvee is Dictionary else valeur_sauvee)
	for fid in _toit_avant:
		ilots[fid]["toit_m2"] = ilots[fid]["toit_m2_neuf"]
	_vert_ha_mois = INF
	_crue_champs_mois = INF
	_rampes_version += 1


## 🌊 L'état de DÉPART se mesure, il ne se choisit pas : une berge que nul mur
## ne tient ne porte pas d'asphalte — elle est déjà rendue au fleuve.
func berge_depart(fid: int) -> int:
	return BERGE_ASPHALTE if base("b", fid, "mur_m") > 1.0 else BERGE_RENATUREE


## L'état VU : la cible une fois le chantier livré, l'état d'avant tant qu'il
## dure. Une berge qui verdirait à l'engagement dirait qu'on plante en un jour.
func berge_etat(fid: int, t: float) -> int:
	if not _berge.has(fid):
		return berge_depart(fid)
	var c: Dictionary = _berge[fid]
	return int(c["cible"]) if t >= float(c["debut"]) + float(c["duree"]) 		else int(c["depuis"])


func berge_cible(fid: int) -> int:
	return int(_berge[fid]["cible"]) if _berge.has(fid) else berge_depart(fid)


func berge_reste_mois(fid: int, t: float) -> float:
	if not _berge.has(fid):
		return 0.0
	var c: Dictionary = _berge[fid]
	return maxf(0.0, float(c["debut"]) + float(c["duree"]) - t)


func berge_en_cours(fid: int, t: float) -> bool:
	return berge_reste_mois(fid, t) > 0.0


## En k€. La différence des deux prix cumulés, sur la longueur de la rive.
func cout_berge_ke(fid: int, cible: int, t: float) -> float:
	var de := berge_etat(fid, t)
	if cible <= de:
		return 0.0
	return (BERGE_PRIX_KE_M[cible] - BERGE_PRIX_KE_M[de]) 		* base("b", fid, "longueur_m")


## `false` si rien à faire, si un chantier court déjà, ou si la caisse ne suit
## pas. Même partage que `lancer_solaire` : l'interface explique, ici le verrou.
## 🔴 UNE BERGE NE REVIENT PAS EN ARRIÈRE. Rendre l'asphalte au fleuve démolit
## un mur ; le refaire serait une autre décision, et elle n'existe pas.
func transformer_berge(fid: int, cible: int, t: float) -> bool:
	if not berges.has(fid) or berge_en_cours(fid, t):
		return false
	var de := berge_etat(fid, t)
	if cible <= de or cible > BERGE_RENATUREE:
		return false
	var cout := cout_berge_ke(fid, cible, t)
	if cout > caisse_ke(t):
		return false
	_berge[fid] = {"cible": cible, "depuis": de, "debut": t,
		"duree": _delai(BERGE_MOIS[cible] - BERGE_MOIS[de]), "cout_ke": cout}
	_depenser("berge", cout)
	return true


## 🌊 CE QU'UNE BERGE REND AU FLEUVE, en mètres de largeur : l'asphalte posé
## au-dessus de l'Ilse dès le quai apaisé, la bande de rive en plus une fois
## renaturée. Les deux sont MESURÉS sur la carte — aucun n'est un réglage, et
## c'est ce qui fait qu'une berge large rachète plus qu'une berge étroite.
func berge_largeur_rendue_m(fid: int, etat: int) -> float:
	if etat <= BERGE_ASPHALTE:
		return 0.0
	var lg := base("b", fid, "longueur_m")
	var l := (base("b", fid, "debord_m2") / lg) if lg > 0.0 else 0.0
	if etat >= BERGE_RENATUREE:
		l += float(crue.get("berge_bande_m", 0.0))
	return l


## En mètres de crue annoncée en moins, une fois le chantier LIVRÉ : `berge_etat`
## ne bascule qu'à la livraison, donc la protection non plus.
## 🔴 DEPUIS L'ÉTAT DE DÉPART, jamais depuis l'asphalte. Les berges 4 et 8 n'ont
## pas de mur : elles partent renaturées, et l'`alea` exporté par `04e` les
## compte déjà. Les créditer au mois 0 protègerait la ville d'une crue qui a
## déjà eu lieu.
func berge_baisse_m(fid: int, t: float) -> float:
	return (berge_largeur_rendue_m(fid, berge_etat(fid, t))
		- berge_largeur_rendue_m(fid, berge_depart(fid))) * BERGE_BAISSE_M_PAR_M


## Ce que les berges livrées retirent à la crue annoncée SUR CET ÎLOT. Une berge
## ne soulage que le bief qu'elle borde — mais sur les DEUX rives, car c'est la
## même section qui s'élargit. Les deux berges d'un bief s'additionnent : finir
## un bief vaut mieux qu'effleurer les quatre.
func baisse_crue_m(fid: int, t: float) -> float:
	var fil := base("i", fid, "position_fil_eau")
	# 🌿 Les toits verts entrent ICI, et pour toute la ville : ce qui n'est pas
	# tombé dans les gouttières n'arrive pas dans l'Ilse, où que soit le toit.
	var v := baisse_crue_toits_m(t) + baisse_crue_champs_m(t) + baisse_crue_parcs_m(t) \
		+ baisse_crue_sols_m(t)
	for b in berges:
		if fil >= base("b", b, "fil_amont") - 0.001 \
				and fil <= base("b", b, "fil_aval") + 0.001:
			v += berge_baisse_m(b, t)
	return v


## 🌿 Un parc inondable retient l'eau pour toute la ville, comme un toit vert :
## la part ruinée de l'îlot, rendue au sol.
func baisse_crue_parcs_m(t: float) -> float:
	var ha := 0.0
	for fid in _rebati:
		if _rebati[fid] == "parc" and reparation_finie("i", fid, t):
			ha += base("i", fid, "surface_m2") * base("i", fid, "part_sinistree") / 10000.0
	return ha * PARC_BAISSE_M_PAR_HA


## Les îlots qu'une berge soulage, du plus exposé au moins. La fiche en a besoin
## AVANT de décider : sans eux, 763 k€ s'engagent sans contrepartie lisible.
func ilots_du_bief(fid_berge: int) -> Array:
	var a0 := base("b", fid_berge, "fil_amont") - 0.001
	var a1 := base("b", fid_berge, "fil_aval") + 0.001
	var out := []
	for f in ilots:
		var fil := base("i", f, "position_fil_eau")
		if fil >= a0 and fil <= a1 and base("i", f, "part_ruinee_apres") > 0.0:
			out.append(f)
	out.sort_custom(func(x, y): return base("i", x, "alea") > base("i", y, "alea"))
	return out


## 🌊 LES TROIS CHAMPS QUE LA BERGE DÉPLACE. La hauteur d'eau annoncée perd les
## mètres rachetés, `alea` la suit, et `part_ruinee_apres` se lit sur la courbe
## que `04e` a mesurée bâtiment par bâtiment — le profil de terrain n'existe pas
## ici, on ne le réinvente pas.
func _crue_apres_berges(fid: int, champ: String, t: float) -> float:
	var baisse := baisse_crue_m(fid, t)
	if champ == "part_ruinee_apres":
		return _sur_la_courbe(fid, baisse)
	var h := maxf(0.0, base("i", fid, "hauteur_eau_annonce") - baisse)
	if champ == "hauteur_eau_annonce":
		return h
	var niveau := float(crue.get("niveau_annonce_m", 0.0))
	return 0.0 if niveau <= 0.0 else clampf(h / niveau, 0.0, 1.0)


## Les 11 paliers de `04e`, interpolés. Au-delà du dernier on garde le dernier :
## une baisse plus forte que tout ce qui a été mesuré ne doit pas sortir un
## nombre inventé.
func _sur_la_courbe(fid: int, baisse: float) -> float:
	var c: Array = ilots.get(fid, {}).get("ruine_apres_baisse", [])
	var paliers: Array = crue.get("baisses_m", [])
	if c.is_empty() or paliers.size() != c.size():
		return base("i", fid, "part_ruinee_apres")
	if baisse <= float(paliers[0]):
		return float(c[0])
	for k in range(1, c.size()):
		var p0 := float(paliers[k - 1])
		var p1 := float(paliers[k])
		if baisse <= p1:
			return lerpf(float(c[k - 1]), float(c[k]),
				0.0 if p1 <= p0 else (baisse - p0) / (p1 - p0))
	return float(c[c.size() - 1])


func base(couche: String, fid: int, champ: String) -> float:
	var o: Dictionary = objets(couche).get(fid, {})
	var v: Variant = o.get(champ)
	return 0.0 if v == null else float(v)


## La base plus les rampes en cours. Un champ préfixé `_` se CALCULE, côté
## énergie ; fiche, calques et ciblage passent tous par ici, donc voient les
## mêmes nombres sans savoir qui les fabrique (décision 41).
##
## Les bornes ne sont pas cosmétiques : sans elles une canopée dépasse 1 et
## l'indicateur ment. Les champs calculés, eux, échappent à `_borner` — une
## friche peut EXPORTER.
func valeur(couche: String, fid: int, champ: String, t: float) -> float:
	if champ.begins_with("_"):
		return Energie.derive(self, fid, champ, t) if couche == "i" else 0.0
	# 🌊 La berge passe AVANT les rampes : ces trois champs n'en portent aucune,
	# et c'est ici que la seule contrepartie non monétaire du jeu entre.
	if couche == "i" and champ in ["alea", "part_ruinee_apres",
			"hauteur_eau_annonce"]:
		return _crue_apres_berges(fid, champ, t)
	var v := base(couche, fid, champ)
	for r in _rampes[couche].get(fid, []):
		if r["champ"] == champ:
			v += float(r["ecart"]) * avancement(t, r["d"], r["L"], r["M"])
	return _borner(champ, v)


static func _borner(champ: String, v: float) -> float:
	match champ:
		"canopee", "impermeabilise", "riverain", "alea", "charge", "desserte_tc", \
		"part_toit_equipe", "part_rendue", "part_toit_vert", "part_isolee", \
		"part_dense":
			return clampf(v, 0.0, 1.0)
		"emprise_libre_m", "stationnement", "logements", "emplois":
			return maxf(v, 0.0)
	return v


## La rampe du Classeur §4 : délai, montée, plein effet. En continu, le temps
## ne sautant pas de mois en mois ici.
static func avancement(t: float, d: float, L: float, M: float) -> float:
	if t < d + L:
		return 0.0
	if M <= 0.0:
		return 1.0
	return clampf((t - d - L) / M, 0.0, 1.0)


## Ce qui a changé dans les rampes : le capital relit la charge des rues.
var _rampes_version := 0


func ajouter_rampe(couche: String, fid: int, champ: String, ecart: float,
		d: float, L: float, M: float, cause := -1) -> void:
	_vert_ha_mois = INF
	_rampes_version += 1
	if not _rampes[couche].has(fid):
		_rampes[couche][fid] = []
	var rampe := {"champ": champ, "ecart": ecart, "d": d, "L": L, "M": M}
	if cause >= 0:
		rampe["cause"] = cause
	_rampes[couche][fid].append(rampe)


func vider_rampes() -> void:
	_vert_ha_mois = INF
	_rampes_version += 1
	_rampes = {"i": {}, "r": {}}


## Le temps qu'on met à enlever des places : deux mois de peinture et de
## panneaux. C'est la barre de la fiche qui le lit aussi (`chantier`).
const STATIONNEMENT_MOIS := 2.0


func supprimer_stationnement(fid: int, t: float) -> bool:
	if _stationnement_supprime.has(fid):
		return false
	var actuel := valeur("r", fid, "stationnement", t)
	if actuel <= 0.0:
		return false
	_stationnement_supprime[fid] = t
	ajouter_rampe("r", fid, "stationnement", -actuel, t, 0.0,
		_delai(STATIONNEMENT_MOIS))
	return true


func stationnement_en_suppression(fid: int) -> bool:
	return _stationnement_supprime.has(fid)


# ------------------------------------------------------------ planter une rue

## Combien d'arbres sont en terre à cette canopée-là. Un COMPTE, pas une part :
## c'est ce qu'on paie, et c'est exactement ce qu'on voit à l'écran — les mêmes
## seuils servent au prix, à l'économie d'énergie et au rendu.
func arbres_a(fid: int, canopee: float) -> int:
	var n := 0
	for seuil in _seuils.get(fid, PackedFloat32Array()):
		if seuil <= canopee:
			n += 1
	return n


## Ce que la rue porterait plantée de bout en bout. 0 = pas la place d'un arbre
## entre la chaussée et la limite d'emprise ; `07` l'a déjà tranché.
func arbres_plantables(fid: int) -> int:
	return arbres_a(fid, PLANTATION_CANOPEE_MAX)


func cout_plantation_ke(fid: int, cible: float, t: float) -> float:
	var neufs := arbres_a(fid, cible) - arbres_a(fid, valeur("r", fid, "canopee", t))
	return maxf(neufs, 0) * PLANTATION_PRIX_KE_ARBRE


## `false` si la rue n'est pas plantable, si un chantier y court déjà, si la
## cible ne dépasse pas l'existant ou si la caisse ne suit pas. Même partage que
## `lancer_solaire` : l'interface pré-vérifie et explique, ici le verrou seul.
func planter(fid: int, cible: float, t: float) -> bool:
	if not routes.has(fid) or _plantation.has(fid):
		return false
	var actuelle := valeur("r", fid, "canopee", t)
	var c := clampf(cible, 0.0, PLANTATION_CANOPEE_MAX)
	var neufs := arbres_a(fid, c) - arbres_a(fid, actuelle)
	if neufs <= 0:
		return false
	var cout := float(neufs) * PLANTATION_PRIX_KE_ARBRE
	if cout > caisse_ke(t) + 0.001:
		return false
	ajouter_rampe("r", fid, "canopee", c - actuelle, t, 0.0, _delai(PLANTATION_MOIS))
	_plantation[fid] = {"debut": t, "duree": _delai(PLANTATION_MOIS), "cible": c,
		"cout_ke": cout, "arbres": neufs}
	_depenser("plantation", cout)
	return true


func plantation_reste_mois(fid: int, t: float) -> float:
	if not _plantation.has(fid):
		return 0.0
	return maxf(float(_plantation[fid]["debut"])
		+ float(_plantation[fid]["duree"]) - t, 0.0)


func plantation_en_cours(fid: int, t: float) -> bool:
	return plantation_reste_mois(fid, t) > 0.0


## 🌳 CE QUE LES ARBRES ÉPARGNENT À LA VILLE, en MWh/an, DEPUIS LE MOIS 0 — pas
## en absolu : la canopée de départ est déjà dans la consommation de base, et la
## compter deux fois ferait bouger le t0 sans qu'on ait rien décidé.
## ⚠️ Un ESCALIER, pas une courbe : on compte les arbres réellement en terre à
## la canopée du moment. C'est ce qui fait que le chiffre et l'image disent la
## même chose — un arbre de plus à l'écran, un arbre de plus au compteur.
func economie_plantation_mwh(t: float) -> float:
	var n := 0
	for fid in _plantation:
		n += arbres_a(fid, valeur("r", fid, "canopee", t)) \
			- arbres_a(fid, base("r", fid, "canopee"))
	return float(n) * PLANTATION_MWH_ARBRE_AN


## Une rue envasée ou un tablier emporté ne redevient praticable qu'à la fin
## de son chantier. Le prix exporté est le seul marqueur commun aux deux cas.
func route_praticable(fid: int, t: float) -> bool:
	return base("r", fid, "cout_reparation_ke") <= 0.0 \
		or reparation_finie("r", fid, t)


## 🌳 LE VERGER — le quartier de rive droite que le limon a couvert (nommé par
## l'auteur le 2026-09-17). `04e` mesure la boue SUR LA CHAUSSÉE et l'exporte
## en `part_boue` ; ici on ne fait qu'en lire les deux conséquences.
func au_verger(fid: int) -> bool:
	return base("r", fid, "part_boue") > 0.0


## Reste-t-il de la boue dans le verger ? Tant qu'un seul de ses tronçons n'est
## pas déblayé, oui. Relu une fois par mois : `part_trafic` est appelé pour les
## 177 rues à chaque pulsation.
func verger_sous_boue(t: float) -> bool:
	if not is_equal_approx(t, _verger_vu):
		_verger_vu = t
		_verger_sale = false
		for fid in _verger:
			if not reparation_finie("r", fid, t):
				_verger_sale = true
				break
	return _verger_sale


## 🚗 LA PART DE SON TRAFIC QU'UNE RUE PORTE ENCORE. Deux règles, demandées
## le 2026-09-17 : aucune voiture ne roule dans la boue — un tronçon envasé est
## impraticable jusqu'à son déblaiement, comme un tablier emporté —, et tant
## qu'il reste de la boue au verger, ses rues déblayées n'en retrouvent qu'une
## fraction : le quartier est coupé de ses trois ponts et ses maisons sont
## vides.
func part_trafic(fid: int, t: float) -> float:
	if not route_praticable(fid, t):
		return 0.0
	if au_verger(fid) and verger_sous_boue(t):
		return PART_TRAFIC_VERGER
	return 1.0


## La charge telle qu'on la VOIT : celle du réseau, moins ce que la boue retire.
## Fiche, voitures et foule lisent celle-ci ; l'affectation, elle, travaille sur
## `charge` seule — sinon une fermeture se calculerait sur un trafic déjà rogné.
func trafic_vu(fid: int, t: float) -> float:
	return valeur("r", fid, "charge", t) * part_trafic(fid, t)


## Retour au mois 0. Rien n'ayant été écrit en base, il n'y a rien d'autre à
## défaire — et ni géométrie ni caméra ne sont concernées.
func reinitialiser() -> void:
	_solaire.clear()
	_recherche.clear()
	_politiques.clear()
	_vert.clear()
	_stationnement_supprime.clear()
	_dense.clear()
	_plantation.clear()
	_berge.clear()
	_camps.clear()
	_demandes.clear()
	_cultures.clear()
	_permeable.clear()
	_crue_champs_mois = INF
	_depense_ke = 0.0
	_depense_genre = {}
	_credit_essai_ke = 0.0
	# Les toits reconstruits redeviennent des ruines : `toit_m2` est la seule
	# donnée que `reparer` écrit en base, donc la seule à défaire.
	for fid in _toit_avant:
		ilots[fid]["toit_m2"] = _toit_avant[fid]
	_toit_avant.clear()
	_repare.clear()
	_provisoire.clear()
	_file_deblaiement.clear()
	_rebati.clear()
	_concours.clear()
	_verger_vu = -1.0
	vider_rampes()


## En k€, depuis la part atteinte au mois `t`. Annoncé par la fiche avant
## validation.
func cout_solaire_ke(fid: int, part: float, t: float) -> float:
	if not ilots.has(fid):
		return 0.0
	return Energie.cout_pose_ke(self, fid,
		valeur("i", fid, "part_toit_equipe", t), clampf(part, 0.0, 1.0), t)


## `false` si rien n'est lancé (cible trop basse, chantier en cours, caisse
## insuffisante). L'interface pré-vérifie et explique ; ici, le verrou seul.
##
## 🔴 La rampe s'AJOUTE. Réécrire l'histoire de la pose fausserait la recette
## encaissée, qui en est l'intégrale — d'où le prix payé : une pose engagée ne
## se révise plus.
## 🔄 RETOUR EN ARRIÈRE SIGNALÉ (2026-08-31) : la décision 72 verrouillait TOUTE
## décision de réduction tant que les logements sinistrés et les trois ponts
## n'étaient pas relevés. Mesuré : 14 445 k€ de seuil pour 8 000 k€ de caisse en
## vingt ans — le solaire n'existait plus dans la partie. Réparer et équiper se
## disputent maintenant la même caisse dès le mois 0, et c'est ça, l'arbitrage.
func lancer_solaire(fid: int, part: float, t: float) -> bool:
	if not ilots.has(fid) or etat_solaire(fid, t)["en_cours"]:
		return false
	if Energie.toit_equipable_m2(self, fid) <= 0.0:
		return false
	var actuelle := valeur("i", fid, "part_toit_equipe", t)
	var cible := clampf(minf(part, part_solaire_max(fid, t)), 0.0, 1.0)
	if cible <= actuelle + 0.0001:
		return false

	# ⚠️ Le coût se lit AVANT la rampe : `caisse_ke` intègre les rampes
	# existantes, et la nouvelle n'a encore rien rapporté.
	var cout := Energie.cout_pose_ke(self, fid, actuelle, cible, t)
	if cout > caisse_ke(t) + 0.001:
		return false

	var duree := duree_solaire_mois(actuelle, cible)
	ajouter_rampe("i", fid, "part_toit_equipe", cible - actuelle, t, 0.0, duree)
	# 🪜 LA SECONDE RAMPE, ET ELLE EST LE RENDEMENT. Ce chantier-ci gagne un
	# écart FIXE de production ; posé comme une rampe droite, il s'intègre
	# exactement, alors qu'une courbe relue chaque image ne s'intégrerait pas.
	ajouter_rampe("i", fid, "part_rendue",
		Energie.courbe_rendue(cible) - Energie.courbe_rendue(actuelle),
		t, 0.0, duree)
	_solaire[fid] = {"debut": t, "duree": duree, "cible": cible, "cout_ke": cout}
	_depenser("solaire", cout)
	return true


func duree_solaire_mois(depart: float, cible: float) -> float:
	return _delai(maxf(cible - depart, 0.0) * SOLAIRE_MOIS_POUR_100)


## De quoi distinguer la cible du réalisé.
func etat_solaire(fid: int, t: float) -> Dictionary:
	var actuel := valeur("i", fid, "part_toit_equipe", t)
	var c: Dictionary = _solaire.get(fid, {})
	var cible: float = maxf(actuel, float(c.get("cible", actuel)))
	var fin: float = float(c.get("debut", t)) + float(c.get("duree", 0.0))
	return {
		"actuel": actuel,
		"cible": cible,
		"reste_mois": maxf(fin - t, 0.0),
		"en_cours": cible > actuel + 0.0001 and t < fin,
		"a_commence": not c.is_empty(),
		"cout_ke": float(c.get("cout_ke", 0.0)),   # celui du DERNIER chantier
	}


# ------------------------------------------------------------- le toit vert

## 🌿 LE PARTAGE DU TOIT, écrit UNE FOIS et lu par les deux curseurs. Ce que
## l'autre décision a posé ou vise est retiré du plafond : le 100 % est celui du
## TOIT, pas celui d'un curseur.
func part_solaire_max(fid: int, t: float) -> float:
	return clampf(1.0 - etat_vert(fid, t)["cible"], 0.0, 1.0)


## Ce que la pente laisse, moins ce que les panneaux prennent. Un îlot tout en
## versants rend 0, et la fiche n'affiche alors pas le bloc.
func part_vert_max(fid: int, t: float) -> float:
	return clampf(minf(Energie.part_plate(self, fid),
		1.0 - etat_solaire(fid, t)["cible"]), 0.0, 1.0)


## En k€, depuis la part atteinte au mois `t`.
func cout_vert_ke(fid: int, part: float, t: float) -> float:
	if not ilots.has(fid):
		return 0.0
	return Energie.cout_vert_ke(self, fid,
		valeur("i", fid, "part_toit_vert", t), clampf(part, 0.0, 1.0), t)


## Même partage que `lancer_solaire` : l'interface pré-vérifie et explique, ici
## le verrou seul — et la rampe s'AJOUTE, pour la même raison.
func lancer_vert(fid: int, part: float, t: float) -> bool:
	if not ilots.has(fid) or etat_vert(fid, t)["en_cours"]:
		return false
	if Energie.toit_plat_equipable_m2(self, fid) <= 0.0:
		return false
	var actuelle := valeur("i", fid, "part_toit_vert", t)
	var cible := clampf(minf(part, part_vert_max(fid, t)), 0.0, 1.0)
	if cible <= actuelle + 0.0001:
		return false
	var cout := Energie.cout_vert_ke(self, fid, actuelle, cible, t)
	if cout > caisse_ke(t) + 0.001:
		return false
	var duree := duree_vert_mois(actuelle, cible)
	ajouter_rampe("i", fid, "part_toit_vert", cible - actuelle, t, 0.0, duree)
	_vert[fid] = {"debut": t, "duree": duree, "cible": cible, "cout_ke": cout}
	_vert_ha_mois = INF
	_depenser("vert", cout)
	return true


func duree_vert_mois(depart: float, cible: float) -> float:
	return _delai(maxf(cible - depart, 0.0) * TOIT_VERT_MOIS_POUR_100)


func etat_vert(fid: int, t: float) -> Dictionary:
	var actuel := valeur("i", fid, "part_toit_vert", t)
	var c: Dictionary = _vert.get(fid, {})
	var cible: float = maxf(actuel, float(c.get("cible", actuel)))
	var fin: float = float(c.get("debut", t)) + float(c.get("duree", 0.0))
	return {
		"actuel": actuel,
		"cible": cible,
		"reste_mois": maxf(fin - t, 0.0),
		"en_cours": cible > actuel + 0.0001 and t < fin,
		"a_commence": not c.is_empty(),
		"cout_ke": float(c.get("cout_ke", 0.0)),
	}


## La somme de ville du dernier mois demandé. `degats()` la redemandait une fois
## PAR ÎLOT — 71 × 71 passages par image, 5,2 ms. La clé est le mois AU BIT PRÈS
## et non « à peu près » : dans une image tous les appels partagent le même mois,
## d'une image à l'autre il change, et toute décision qui verdit remet INF.
var _vert_ha_mois := INF
var _vert_ha := 0.0


## 🌿 EN HECTARES VERDIS DANS TOUTE LA VILLE — le seul terme de la crue qui ne
## vienne pas du fleuve. La pluie retenue sur un toit du plateau soulage l'Ilse
## autant que celle d'un toit de berge : ici, aucun bief.
func toit_vert_ha(t: float) -> float:
	if t == _vert_ha_mois:
		return _vert_ha
	var m2 := 0.0
	for fid in fids_batis():
		m2 += Energie.toit_vert_m2(self, fid, t)
	_vert_ha_mois = t
	_vert_ha = m2 / 10000.0
	return _vert_ha


## En mètres de crue annoncée en moins, partout. Sur ce qui est LIVRÉ :
## `part_toit_vert` monte en rampe, donc la protection aussi.
func baisse_crue_toits_m(t: float) -> float:
	return toit_vert_ha(t) * TOIT_VERT_BAISSE_M_PAR_HA


# ==========================================================================
# 🅿️💧 LE SOL RENDU PERMÉABLE — la place-parking (101, 2026-10-06)
# ==========================================================================
# Dalles drainantes, noues, arbres : les places restent, le sol boit. Retient la
# pluie pour TOUTE la ville, comme un toit vert. 🎚️ LEVEL DESIGN, à tester sur
# la jauge de Dangers (auteur) : même prix et même retenue par hectare que le
# toit vert pour commencer.
const PERMEABLE_SOUS_TYPES := ["place_minerale"]
const PERMEABLE_PRIX_KE_M2 := 0.14          # par m² rendu perméable
const PERMEABLE_MOIS := 6.0
const PERMEABLE_RESTE := 0.30               # allées et bordures restent dures
const PERMEABLE_BAISSE_M_PAR_HA := 0.25
var _permeable := {}       # fid -> {debut, duree, cout_ke}


func permeable_possible(fid: int) -> bool:
	return str(ilots.get(fid, {}).get("sous_type", "")) in PERMEABLE_SOUS_TYPES \
		and base("i", fid, "impermeabilise") > PERMEABLE_RESTE


func _permeable_m2(fid: int) -> float:
	return base("i", fid, "surface_m2") * maxf(0.0, base("i", fid, "impermeabilise") - PERMEABLE_RESTE)


func cout_permeable_ke(fid: int) -> float:
	return 0.0 if _permeable.has(fid) or not permeable_possible(fid) \
		else _permeable_m2(fid) * PERMEABLE_PRIX_KE_M2


func rendre_permeable(fid: int, t: float) -> bool:
	if _permeable.has(fid) or not permeable_possible(fid):
		return false
	var cout := cout_permeable_ke(fid)
	if cout > caisse_ke(t) + 0.001:
		return false
	var duree := _delai(PERMEABLE_MOIS)
	ajouter_rampe("i", fid, "impermeabilise",
		PERMEABLE_RESTE - base("i", fid, "impermeabilise"), t, 0.0, duree)
	_permeable[fid] = {"debut": t, "duree": duree, "cout_ke": cout}
	_depenser("permeable", cout)
	return true


func permeable_en_cours(fid: int, t: float) -> bool:
	return _permeable.has(fid) and t < float(_permeable[fid]["debut"]) + float(_permeable[fid]["duree"])


func permeable_reste_mois(fid: int, t: float) -> float:
	if not _permeable.has(fid):
		return 0.0
	return maxf(0.0, float(_permeable[fid]["debut"]) + float(_permeable[fid]["duree"]) - t)


## Sur ce qui est livré : `impermeabilise` descend en rampe, la retenue aussi.
func baisse_crue_sols_m(t: float) -> float:
	var ha := 0.0
	for fid in _permeable:
		ha += base("i", fid, "surface_m2") * maxf(0.0,
			base("i", fid, "impermeabilise") - valeur("i", fid, "impermeabilise", t)) / 10000.0
	return ha * PERMEABLE_BAISSE_M_PAR_HA


## 💧 La part du sol de la ville bâtie qui boit la pluie, toits verts compris ;
## les rues comptent pour du dur, les champs hors compte (ils noieraient tout).
## Le chiffre du calque Sols.
func part_sol_permeable(t: float) -> float:
	var boit := 0.0
	var tout := 0.0
	for fid in ilots:
		if str(ilots[fid].get("sous_type", "")) in ["riviere", "champ"]:
			continue
		var s := base("i", fid, "surface_m2")
		tout += s
		boit += s * (1.0 - valeur("i", fid, "impermeabilise", t)) + Energie.toit_vert_m2(self, fid, t)
	for fid in routes:
		tout += base("r", fid, "longueur_m") * base("r", fid, "largeur_m")
	return 0.0 if tout <= 0.0 else clampf(boit / tout, 0.0, 1.0)


# ============================================== densifier (auteur, 2026-09-03)

# 🏢 UN ÉTAGE OU DEUX, DU BÂTIMENT LE PLUS BAS AU PLUS HAUT. Ces cinq nombres
# sont du LEVEL DESIGN. 07 dit combien de logements un étage ajoute par îlot.
# ⚠️ Le patrimoine ne monte pas, et c'est 07 qui le sait (DENSE_INTERDIT) : ici,
# un îlot qui ne peut pas monter annonce simplement zéro bâtiment.
const DENSE_ETAGES_MAX := 2
const DENSE_ETAGE_M := 2.7                # le même étage que 07 (ETAGE_M)
const DENSE_PRIX_KE_LOGEMENT := 95.0      # poser un logement sur de l'existant
const DENSE_MOIS_PAR_ETAGE := 18.0        # les bâtiments montent l'un après l'autre
# 🔴 LE CONTRÔLE NOMMÉ DE LA DETTE 59 — une densification pure ne doit pas
# s'autofinancer. Loyer net moins entretien laisse 0,25 k€ par logement et par
# mois : 380 mois pour rembourser une pose, contre 240 de partie.
const DENSE_LOYER_KE_MOIS_LOGEMENT := 0.42
const DENSE_CHARGE_KE_MOIS_LOGEMENT := 0.17


## Combien de bâtiments de cet îlot ont le droit de monter. 0 = pas de menu,
## et c'est aussi le NOMBRE DE CRANS du curseur : un cran, un bâtiment.
func dense_batiments(fid: int) -> int:
	return int(base("i", fid, "dense_n"))


## Les logements qu'UN étage ajoute sur TOUS les bâtiments montables — mesuré
## par 07 sur les emprises qui montent, au même m² brut par logement que le
## plancher de 04d.
func dense_logements_etage(fid: int) -> int:
	return int(base("i", fid, "dense_logements_etage"))


## 🪜 LE PROFIL DES PALIERS, posé par 07 : `[k]` = la part de l'emprise qui
## monte atteinte aux k+1 premiers bâtiments. Un export d'avant le 2026-09-03
## n'en a pas ; on retombe alors sur des bâtiments de poids égal.
func dense_cumul(fid: int) -> Array:
	var v: Variant = ilots.get(fid, {}).get("dense_cumul")
	return v as Array if v is Array else []


## La part des LOGEMENTS atteinte quand la part `part` des BÂTIMENTS est montée.
## Les deux ne vont pas au même rythme : monter le plus petit bâtiment ne loge
## pas autant que monter le plus grand.
func dense_part_logements(fid: int, part: float) -> float:
	var n := dense_batiments(fid)
	if n <= 0:
		return 0.0
	var c := dense_cumul(fid)
	var x := clampf(part, 0.0, 1.0) * float(n)
	if c.size() != n:
		return x / float(n)
	var k := int(floor(x))
	if k >= n:
		return 1.0
	return lerpf(0.0 if k == 0 else float(c[k - 1]), float(c[k]), x - float(k))


## Le cran le plus proche : le curseur ne s'arrête qu'entre deux bâtiments.
func dense_cran(fid: int, part: float) -> float:
	var n := dense_batiments(fid)
	if n <= 0:
		return 0.0
	return clampf(roundf(clampf(part, 0.0, 1.0) * float(n)) / float(n), 0.0, 1.0)


## Les étages arrêtés pour cet îlot, 0 si rien n'est encore engagé. 🔴 Ils se
## choisissent UNE FOIS : le shader n'a qu'une hauteur pour tout l'îlot, donc
## deux bâtiments ne peuvent pas monter de deux nombres d'étages différents.
func dense_etages(fid: int) -> int:
	return int((_dense.get(fid, {}) as Dictionary).get("etages", 0))


func dense_engage(fid: int) -> bool:
	return _dense.has(fid)


## En k€, de la part `de` à la part `vers` des bâtiments.
## 🪜 Progressif comme les panneaux, et pour la même raison : 07 range les
## bâtiments DU PLUS BAS AU PLUS HAUT, donc les premiers montés sont les moins
## chers. Monter l'îlot ENTIER coûte le même prix qu'avant — seul l'ordre change.
func cout_dense_ke(fid: int, de: float, vers: float, etages: int) -> float:
	var e := mini(etages, DENSE_ETAGES_MAX)
	if e <= 0:
		return 0.0
	return float(dense_logements_etage(fid)) * float(e) \
		* maxf(Energie.courbe_payee(dense_part_logements(fid, vers))
			- Energie.courbe_payee(dense_part_logements(fid, de)), 0.0) \
		* DENSE_PRIX_KE_LOGEMENT


## Les bâtiments montent l'un après l'autre : n'en monter que la moitié prend
## la moitié du temps.
func duree_dense_mois(etages: int, de: float, vers: float) -> float:
	return _delai(DENSE_MOIS_PAR_ETAGE * float(mini(etages, DENSE_ETAGES_MAX)) \
		* maxf(vers - de, 0.0))


## Les logements ajoutés par la tranche, étages compris.
func dense_logements_tranche(fid: int, de: float, vers: float, etages: int) -> float:
	return (dense_part_logements(fid, vers) - dense_part_logements(fid, de)) \
		* float(dense_logements_etage(fid)) * float(mini(etages, DENSE_ETAGES_MAX))


## Engage une TRANCHE de bâtiments, et c'est définitif : un étage ne se
## démolit pas. Le curseur repart ensuite du cran atteint — même partage que
## `lancer_solaire` : l'interface pré-vérifie et explique, ici le verrou seul.
## 🔴 `logements` monte en RAMPE, donc tout ce qui le lit suit la montée des
## bâtiments et non l'engagement — la fiche, l'écart au mois 0, et la
## consommation d'énergie, qui est proportionnelle aux logements. Densifier
## est donc aussi ce qui fait remonter la facture de la ville.
func densifier(fid: int, part: float, etages: int, t: float) -> bool:
	if dense_batiments(fid) <= 0 or dense_logements_etage(fid) <= 0:
		return false
	var etat := etat_dense(fid, t)
	if etat["en_cours"]:
		return false
	var e: int = int(etat["etages"]) if int(etat["etages"]) > 0 \
		else mini(etages, DENSE_ETAGES_MAX)
	if e <= 0:
		return false
	var de: float = float(etat["cible"])
	var vers := clampf(dense_cran(fid, part), de, 1.0)
	if vers <= de + 0.0001:
		return false
	var cout := cout_dense_ke(fid, de, vers, e)
	if cout > caisse_ke(t) + 0.001:
		return false
	var duree := duree_dense_mois(e, de, vers)
	var neufs := dense_logements_tranche(fid, de, vers, e)
	var lots: Array = (_dense.get(fid, {}) as Dictionary).get("lots", []) as Array
	lots.append({"debut": t, "duree": duree, "logements": neufs})
	_dense[fid] = {"debut": t, "duree": duree, "etages": e, "cible": vers,
		"cout_ke": cout, "lots": lots}
	_depenser("dense", cout)
	ajouter_rampe("i", fid, "part_dense", vers - de, t, 0.0, duree)
	ajouter_rampe("i", fid, "logements", neufs, t, 0.0, duree)
	return true


## Ce que le shader a besoin de savoir — l'avancement, la part d'UN bâtiment et
## les mètres gagnés — et ce que la fiche annonce.
## 🪜 `avancement` est désormais la part LIVRÉE (`part_dense`), pas une rampe
## reconstruite : un îlot densifié en trois fois a trois chantiers derrière lui,
## et le shader n'en voit qu'un seul nombre.
func etat_dense(fid: int, t: float) -> Dictionary:
	var c: Dictionary = _dense.get(fid, {})
	var n := dense_batiments(fid)
	var etages := int(c.get("etages", 0))
	var actuel := valeur("i", fid, "part_dense", t)
	var cible: float = maxf(actuel, float(c.get("cible", actuel)))
	var fin: float = float(c.get("debut", t)) + float(c.get("duree", 0.0))
	return {
		"etages": etages,
		"batiments": n,
		"actuel": actuel,
		"cible": cible,
		"montes": int(roundf(actuel * float(n))),
		"vises": int(roundf(cible * float(n))),
		"logements": dense_logements_tranche(fid, 0.0, actuel, etages),
		"logements_vises": dense_logements_tranche(fid, 0.0, cible, etages),
		"cout_ke": float(c.get("cout_ke", 0.0)),   # celui du DERNIER chantier
		"avancement": actuel,
		"pas": 1.0 / maxf(float(n), 1.0),
		"metres": float(etages) * DENSE_ETAGE_M,
		"reste_mois": maxf(fin - t, 0.0),
		"en_cours": cible > actuel + 0.0001 and t < fin,
		"a_commence": not c.is_empty(),
	}


## En k€ depuis le mois 0, sur ce qui est LIVRÉ : l'intégrale des rampes, donc
## un logement ne paie qu'à partir du mois où il est habitable.
func solde_dense_ke(t: float) -> float:
	var s := 0.0
	for fid in _dense:
		for lot in ((_dense[fid] as Dictionary)["lots"] as Array):
			s += float(lot["logements"]) * _integrale_avancement(
				t, float(lot["debut"]), 0.0, float(lot["duree"]))
	return s * (DENSE_LOYER_KE_MOIS_LOGEMENT - DENSE_CHARGE_KE_MOIS_LOGEMENT)


# ============================ LE RELOGEMENT (auteur, 2026-09-17) ============
# 🏕️ LA PREMIÈRE DÉCISION DE LA PARTIE : 260 personnes sont dehors, et le seul
# terrain qu'elles peuvent atteindre est celui que la rivière reprend en
# premier. Trois champs de rive droite, aucun assez grand à lui seul.
#
# 🌉 CE QUI DÉCIDE OÙ, et ce n'est pas une liste de fid : `morceau` est le
# morceau de réseau que `07` a mesuré une fois les ponts emportés. Un champ
# d'un autre morceau se pose et se paie — personne ne peut y aller.
#
# 🎚️ LEVEL DESIGN, les deux nombres : le prix d'un logement de containers, et
# le temps de montage. Le nombre de PLACES, lui, est mesuré champ par champ
# (`camp_places`) — il se règle dans `export_godot/reglages.py`, pas ici.
const CAMP_KE_LOGEMENT := 1.5
const CAMP_MOIS := 0.2                     # une semaine de grue
const CAMP_PERSONNES_LOGEMENT := 2        # Deux places par container, ouverture du 18 septembre.


## Le morceau de réseau qui porte cet objet, −1 s'il n'en a aucun.
func morceau(couche: String, fid: int) -> int:
	return int(objets(couche).get(fid, {}).get("morceau", -1))


## Le morceau où sont les sinistrés — celui qu'un camp doit partager. Mesuré
## une fois au chargement, sur l'îlot le plus touché : c'est lui qui porte le
## gros du faubourg, et `camp_accessible` est appelé en boucle.
func morceau_sinistres() -> int:
	return _morceau_sinistres


## Un champ, et rien d'autre, peut accueillir un camp.
func camp_possible(fid: int) -> bool:
	return str(ilots.get(fid, {}).get("sous_type", "")) == "champ" \
		and camp_places_max(fid) > 0


## Les emplacements de logements semés par `07`, pas le nombre de personnes.
func camp_places_max(fid: int) -> int:
	return int(base("i", fid, "camp_places"))


func camp_capacite(fid: int) -> int:
	return camp_places_max(fid) * CAMP_PERSONNES_LOGEMENT


## 🌉 Les sinistrés peuvent-ils y aller à pied ? Même morceau de réseau, donc
## aucun pont emporté entre eux et lui.
func camp_accessible(fid: int, t := 0.0) -> bool:
	return morceaux_accessibles(t).has(morceau("i", fid))


func ponts_coupes() -> Array[int]:
	return _ponts


## La marche retrouve les composantes exportées seulement à la livraison.
func morceaux_accessibles(t: float, pont_essai := -1) -> Dictionary:
	var accessibles := {}
	if morceau_sinistres() < 0:
		return accessibles
	accessibles[morceau_sinistres()] = true
	for _tour in _ponts.size():
		for fid in _ponts:
			if fid != pont_essai and not reparation_finie("r", fid, t):
				continue
			var reunis: Array = routes[fid].get("morceaux_reunis", [])
			var rejoint := false
			for m in reunis:
				rejoint = rejoint or accessibles.has(int(m))
			if rejoint:
				for m in reunis:
					accessibles[int(m)] = true
	return accessibles


func camp_pose(fid: int) -> bool:
	return _camps.has(fid)


func camp_livre(fid: int, t: float) -> bool:
	return _camps.has(fid) and t >= float(_camps[fid]["debut"]) + _delai(CAMP_MOIS)


func camp_reste_mois(fid: int, t: float) -> float:
	if not _camps.has(fid):
		return 0.0
	return maxf(float(_camps[fid]["debut"]) + _delai(CAMP_MOIS) - t, 0.0)


## Les logements commandés, distincts des personnes : le dernier peut rester à moitié occupé.
## 🔄 Taillé sur ce qui n'a pas encore de place COMMANDÉE, et non plus sur les
## sinistrés dehors : on doit pouvoir abriter tout le monde avant la première
## livraison (auteur, 2026-09-22) sans payer deux fois les mêmes places.
func camp_taille(fid: int, t: float) -> int:
	if _camps.has(fid):
		return int(_camps[fid]["places"])
	return mini(camp_places_max(fid), int(ceil(besoin_non_couvert(t) / CAMP_PERSONNES_LOGEMENT)))


## Les places que promettent les camps commandés ET atteignables, livrés ou non.
func places_commandees(t: float) -> int:
	var n := 0
	for fid in _camps:
		if camp_accessible(int(fid), t):
			n += int(_camps[fid]["places"]) * CAMP_PERSONNES_LOGEMENT
	return n


func besoin_non_couvert(t: float) -> float:
	return maxf(0.0, _perdus(t) - float(places_commandees(t)))


func cout_camp_ke(fid: int, t: float) -> float:
	if _camps.has(fid):
		return 0.0
	return float(camp_taille(fid, t)) * CAMP_KE_LOGEMENT


## `false` si ce n'est pas un champ, s'il en porte déjà un, s'il n'y a personne
## à loger ou si la caisse ne suit pas. Même partage que `lancer_solaire` :
## l'interface pré-vérifie et explique, ici le verrou seul.
## 🔴 UN CHAMP INACCESSIBLE N'EST PAS REFUSÉ (auteur, 2026-09-17) : le camp se
## construit, il reste vide, et réparer un pont le remplira. L'erreur coûte du
## temps et de l'argent, elle ne ferme aucune porte.
func abriter(fid: int, t: float) -> bool:
	if not camp_possible(fid) or _camps.has(fid):
		return false
	var places := camp_taille(fid, t)
	if places <= 0:
		return false
	var cout := float(places) * CAMP_KE_LOGEMENT
	if cout > caisse_ke(t) + 0.001:
		return false
	_camps[fid] = {"debut": t, "places": places, "cout_ke": cout}
	_depenser("camp", cout)
	_crue_champs_mois = INF
	return true


## Les places pour les personnes, LIVRÉES et atteignables. Un camp de l'autre rive n'en
## apporte aucune — c'est le seul endroit où l'inaccessibilité se paie.
func abris_places(t: float) -> int:
	var n := 0
	for fid in _camps:
		if camp_livre(int(fid), t) and camp_accessible(int(fid), t):
			n += int(_camps[fid]["places"]) * CAMP_PERSONNES_LOGEMENT
	return n


## Les sinistrés encore sans toit : ceux dont l'îlot n'est pas RELEVÉ, moins
## ceux qu'un camp abrite.
## 🔴 `reparation_finie` et non `est_repare` : on rentre chez soi à la
## livraison, pas à la signature du marché. C'est ce qui fait que le nombre est
## une fonction du temps, et que la file se vide quand le chantier se termine.
## 🏠 Les logements neufs d'ailleurs — un îlot rebâti plus dense, une densification
## livrée — logent ceux qu'un parc ne fera pas rentrer (auteur, 2026-10-02).
func _perdus(t: float) -> float:
	var perdus := 0.0
	var ailleurs := 0.0
	for fid in ilots:
		var s := base("i", fid, "logements_sinistres")
		if s <= 0.0:
			continue
		if not reparation_finie("i", fid, t) or facon_reparation(fid) == "parc":
			perdus += s
		else:
			ailleurs += s * (float(RECONSTRUCTIONS[facon_reparation(fid)]["logements"]) - 1.0)
	for fid in _dense:
		ailleurs += float(etat_dense(fid, t)["logements"])
	return maxf(0.0, perdus - ailleurs)


func sans_toit(t: float) -> float:
	return maxf(0.0, _perdus(t) - float(abris_places(t)))


## Une densification loge aussi des sinistrés (`_perdus`) : ses livraisons comptent.
func _fins_dense() -> Array:
	var out := []
	for fid in _dense:
		for lot in _dense[fid].get("lots", []):
			out.append(float(lot["debut"]) + float(lot["duree"]))
	return out


func reloges(t: float) -> float:
	return minf(_perdus(t), float(abris_places(t)))


## 🆘 CE QUE COÛTE UNE PERSONNE DEHORS, chaque mois : repas, couvertures, soins
## (auteur, 2026-09-22). Sans ce prix, 22 personnes restaient dehors trois ans
## sans que rien ne bouge. 🎚️ LEVEL DESIGN : 260 dehors = 104 k€ par mois.
const AIDE_KE_PERSONNE_MOIS := 0.4
var _aide_cle := ""
var _aide_marches := []   # [début, personnes dehors], triés


func aide_mensuelle_ke(t: float) -> float:
	return sans_toit(t) * AIDE_KE_PERSONNE_MOIS


## ∫ `sans_toit` de 0 à `t`, exacte : le nombre ne change qu'à une livraison
## de camp ou de réparation. Les marches sont gardées tant que rien n'est commandé.
func aide_cumulee_ke(t: float) -> float:
	var cle := "%d/%d/%d/%s/%d/%d" % [_repare.hash(), _provisoire.hash(), _camps.hash(),
		livraison_immediate, _rebati.hash(), _dense.hash()]
	if cle != _aide_cle:
		_aide_cle = cle
		var dates := [0.0]
		for c in _repare:
			var m: PackedStringArray = str(c).split(":")
			dates.append(float(_repare[c]) + duree_reparation_mois(m[0], int(m[1])))
		for fid in _camps:
			dates.append(float(_camps[fid]["debut"]) + _delai(CAMP_MOIS))
		dates.append_array(_fins_dense())
		dates.sort()
		_aide_marches = []
		for d in dates:
			_aide_marches.append([d, sans_toit(d)])
	var ke := 0.0
	for i in _aide_marches.size():
		var debut: float = _aide_marches[i][0]
		if debut >= t:
			break
		var fin: float = minf(t, float(_aide_marches[i + 1][0])) if i + 1 < _aide_marches.size() else t
		ke += float(_aide_marches[i][1]) * (fin - debut)
	return ke * AIDE_KE_PERSONNE_MOIS


## Qui vit dans CE camp-là. Les camps se vident dans l'ordre inverse de leur
## pose : le dernier posé est le premier que les réparations libèrent.
func camp_occupants(fid: int, t: float) -> float:
	if not camp_livre(fid, t) or not camp_accessible(fid, t):
		return 0.0
	var ordre := []
	for f in _camps:
		if camp_livre(int(f), t) and camp_accessible(int(f), t):
			ordre.append(int(f))
	ordre.sort_custom(func(a, b) -> bool:
		return float(_camps[a]["debut"]) < float(_camps[b]["debut"]))
	var reste := reloges(t)
	for f in ordre:
		var pris: float = minf(reste, float(_camps[f]["places"]) * CAMP_PERSONNES_LOGEMENT)
		if f == fid:
			return pris
		reste -= pris
	return 0.0


# ============================ 🚿 LA VIE AU CAMP (auteur, 2026-10-02) ========
# Un toit rend de la confiance à la livraison, puis le camp l'use chaque mois
# tant qu'on y vit ; l'améliorer arrête l'usure.
# 🎚️ LEVEL DESIGN, tout ce bloc : 260 au camp = +10 puis −2,6 par mois.
const CAPITAL_PAR_PERSONNE_ABRITEE := 0.04
const CAMP_USURE_PERSONNE_MOIS := 0.01
## L'usure part ce délai après le LANCEMENT du premier pont : une minute à ×1 de
## déblaiement, pendant le chantier (auteur, 2026-10-02).
const CAMP_USURE_APRES_PONT_MOIS := 1.0
const CAPITAL_PAR_DEMANDE := 6.0
# 🔄 Un seul bouton au lieu de trois (sanitaires, cantine, classe), même prix et
# même effet cumulés (auteur, 2026-10-02). 🔴 Noms affichés, flaggables (90).
const DEMANDES := {
	"amelioration": {"nom": "Améliorer le campement", "fait": "Campement amélioré", "ke": 130.0, "mois": 0.7},   # 3 semaines (auteur, 2026-10-02)
}
const DEMANDES_ORDRE := ["amelioration"]

var _usure_cle := ""
var _usure_marches := []   # [début, confiance perdue par mois], triés


func demande_engagee(cle: String) -> bool:
	return _demandes.has(cle)


func demande_livree(cle: String, t: float) -> bool:
	return _demandes.has(cle) and t >= _fin_demande(cle)


func _fin_demande(cle: String) -> float:
	return float(_demandes[cle]) + _delai(float(DEMANDES[cle]["mois"]))


## La demande engagée et pas encore livrée : [clé, durée, reste], ou [] — un chantier à la fois.
func demande_en_cours(t: float) -> Array:
	for cle in _demandes:
		if not demande_livree(cle, t):
			return [cle, _delai(float(DEMANDES[cle]["mois"])), _fin_demande(cle) - t]
	return []


## Le camp qui porte la ligne de l'amélioration dans la liste : le premier posé
## qu'on peut rejoindre. L'amélioration vaut pour tous ; la liste veut un lieu.
func camp_principal(t: float) -> int:
	var choisi := -1
	for f in _camps:
		if camp_accessible(f, t) and (choisi < 0
				or float(_camps[f]["debut"]) < float(_camps[choisi]["debut"])):
			choisi = f
	return choisi


func cout_demande_ke(cle: String) -> float:
	return 0.0 if _demandes.has(cle) else float(DEMANDES[cle]["ke"])


func equiper_camp(cle: String, t: float) -> bool:
	if not DEMANDES.has(cle) or _demandes.has(cle) or _camps.is_empty():
		return false
	var cout := cout_demande_ke(cle)
	if cout > caisse_ke(t) + 0.001:
		return false
	# ⚠️ Le prix AVANT l'inscription : `cout_demande_ke` vaut 0 une fois la demande faite.
	_demandes[cle] = t
	_depenser("demande", cout)
	return true


## Le mois où le camp commence à user la confiance ; INF tant qu'aucun pont n'est lancé.
func usure_debut() -> float:
	var debut := INF
	for c in _repare:
		var m: PackedStringArray = str(c).split(":")
		if m[0] == "r" and int(m[1]) in _ponts:
			debut = minf(debut, float(_repare[c]))
	return debut + CAMP_USURE_APRES_PONT_MOIS


## La confiance que le camp use ce mois-ci, positive.
func usure_camp_mois(t: float) -> float:
	if t < usure_debut():
		return 0.0
	var faites := 0
	for cle in _demandes:
		if demande_livree(cle, t):
			faites += 1
	return reloges(t) * CAMP_USURE_PERSONNE_MOIS * (1.0 - float(faites) / DEMANDES.size())


## ∫ `usure_camp_mois` de 0 à `t`, exacte : même marches que `aide_cumulee_ke`,
## plus les demandes livrées.
func usure_camp_cumulee(t: float) -> float:
	var cle := "%d/%d/%d/%d/%s" % [_repare.hash(), _provisoire.hash(), _camps.hash(),
		_demandes.hash(), livraison_immediate]
	if cle != _usure_cle:
		_usure_cle = cle
		var dates := [0.0]
		for c in _repare:
			var m: PackedStringArray = str(c).split(":")
			dates.append(float(_repare[c]) + duree_reparation_mois(m[0], int(m[1])))
		for fid in _camps:
			dates.append(float(_camps[fid]["debut"]) + _delai(CAMP_MOIS))
		for d in _demandes:
			dates.append(_fin_demande(d))
		if usure_debut() < INF:
			dates.append(usure_debut())
		dates.sort()
		_usure_marches = []
		for d in dates:
			_usure_marches.append([d, usure_camp_mois(d)])
	var k := 0.0
	for i in _usure_marches.size():
		var debut: float = _usure_marches[i][0]
		if debut >= t:
			break
		var fin: float = minf(t, float(_usure_marches[i + 1][0])) if i + 1 < _usure_marches.size() else t
		k += float(_usure_marches[i][1]) * (fin - debut)
	return k


# ======================================== 🌾 CE QUE LES CHAMPS NOURRISSENT
#
# Poser des logements sur un champ est toujours possible ; ce bloc est ce que
# ça coûte. La surface est MESURÉE (`surface_m2`), la conversion ne l'est pas.
#
# 🎚️ LEVEL DESIGN : combien de personnes un hectare de CÉRÉALES, la culture
# de départ, nourrit sur l'année. Les 68,9 ha mesurés couvrent 15 % de la ville.
# 🔴 À 3 pers./ha — la moyenne française toutes productions confondues — la
# campagne ne couvrirait que 4 %, et prendre un champ ne coûterait rien de
# lisible. C'est ce nombre qui décide si le coût se voit.
const NOURRITURE_PERSONNES_HA := 12.0
## Les habitants de Wehrau : le seul endroit où le chiffre du dossier entre
## dans le moteur, la carte ne portant que des logements.
const HABITANTS := 5350.0


func est_champ(fid: int) -> bool:
	return str(ilots.get(fid, {}).get("sous_type", "")) == "champ"


# 🌾 CE QUE PORTE UN CHAMP (auteur, 2026-09-29) : un usage à la fois (77c).
# 🎚️ LEVEL DESIGN, choisi « toute l'assiette, chiffres de jeu » : gonflés pour
# que l'autonomie demande ~60 % des champs en maraîchage (77d : on gonfle
# tout pareil, on ne choisit pas le gagnant). `attente` : mois entre la fin
# du chantier et la première récolte. `crue_m_ha` : comme les toits verts,
# pour toute la ville. 🔴 Tous à juger devant l'écran.
const CEREALES := 0
const CULTURES := [
	{"nom": "céréales", "personnes_ha": NOURRITURE_PERSONNES_HA, "prix_ke_ha": 10.0,
		"mois": 6.0, "attente": 0.0, "crue_m_ha": 0.0},
	{"nom": "maraîchage", "personnes_ha": 120.0, "prix_ke_ha": 60.0,
		"mois": 12.0, "attente": 0.0, "crue_m_ha": 0.0},
	{"nom": "verger", "personnes_ha": 70.0, "prix_ke_ha": 25.0,
		"mois": 12.0, "attente": 48.0, "crue_m_ha": 0.002},
	{"nom": "prairie", "personnes_ha": 0.0, "prix_ke_ha": 5.0,
		"mois": 6.0, "attente": 0.0, "crue_m_ha": 0.005},
]
## 🎚️ Ce que la ville paie par personne qu'elle ne nourrit pas. La dotation
## couvre déjà l'achat du mois 0 : la caisse ne voit que l'écart au départ.
## Un hectare de maraîchage se rembourse ainsi en ~9 ans, comme un toit solaire.
const NOURRITURE_KE_PERSONNE_MOIS := 0.005
## fid champ -> [{debut, culture, cout_ke}], dans l'ordre : la dernière gagne.
var _cultures := {}
var _agri_cle := ""
var _agri_marches := []   # [début, personnes nourries], triés
var _crue_champs_mois := INF
var _crue_champs := 0.0


func _hectares(fid: int) -> float:
	return base("i", fid, "surface_m2") / 10000.0


func _derniere_culture(fid: int, t: float) -> Dictionary:
	var h: Array = _cultures.get(fid, [])
	for i in range(h.size() - 1, -1, -1):
		if float(h[i]["debut"]) <= t:
			return h[i]
	return {}


## La culture visée au mois `t` : en place, ou en cours de mise en place.
func champ_culture(fid: int, t: float) -> int:
	var d := _derniere_culture(fid, t)
	return CEREALES if d.is_empty() else int(d["culture"])


func culture_reste_mois(fid: int, t: float) -> float:
	var d := _derniere_culture(fid, t)
	if d.is_empty():
		return 0.0
	return maxf(0.0, float(d["debut"]) + _delai(CULTURES[int(d["culture"])]["mois"]) - t)


func culture_en_cours(fid: int, t: float) -> bool:
	return culture_reste_mois(fid, t) > 0.0


## Mois jusqu'à la première récolte, chantier compris ; 0 si elle est faite.
func recolte_dans_mois(fid: int, t: float) -> float:
	var d := _derniere_culture(fid, t)
	if d.is_empty():
		return 0.0
	var c: Dictionary = CULTURES[int(d["culture"])]
	return maxf(0.0, float(d["debut"]) + _delai(c["mois"]) + _delai(c["attente"]) - t)


## Ce que ce champ nourrit une fois sa culture en production.
func champ_nourriture(fid: int, t := 0.0) -> float:
	if not est_champ(fid):
		return 0.0
	return _hectares(fid) * float(CULTURES[champ_culture(fid, t)]["personnes_ha"])


## Ce qu'il nourrit CE mois-ci : rien sous un camp, pendant le chantier, ni
## avant la première récolte.
func champ_rendement(fid: int, t: float) -> float:
	if not champ_cultive(fid, t) or recolte_dans_mois(fid, t) > 0.0:
		return 0.0
	return champ_nourriture(fid, t)


## 🔴 UN CAMP PREND LE CHAMP ENTIER, ET POUR DE BON : les containers coupent la
## parcelle en deux, et rien dans le jeu ne les enlève. La perte suit la
## mise en chantier : le champ n'est plus cultivable dès l'engagement.
func champ_cultive(fid: int, t: float) -> bool:
	return est_champ(fid) and (not _camps.has(fid) or t < float(_camps[fid]["debut"]))


func cout_culture_ke(fid: int, culture: int) -> float:
	return _hectares(fid) * float(CULTURES[culture]["prix_ke_ha"])


## `false` si ce n'est pas un champ libre, si le chantier d'avant court encore,
## si la culture est déjà celle-là, ou si la caisse ne suit pas.
func cultiver(fid: int, culture: int, t: float) -> bool:
	if not est_champ(fid) or _camps.has(fid) or culture < 0 or culture >= CULTURES.size():
		return false
	if culture == champ_culture(fid, t) or culture_en_cours(fid, t):
		return false
	var cout := cout_culture_ke(fid, culture)
	if cout > caisse_ke(t) + 0.001:
		return false
	if not _cultures.has(fid):
		_cultures[fid] = []
	_cultures[fid].append({"debut": t, "culture": culture, "cout_ke": cout})
	_depenser("culture", cout)
	_crue_champs_mois = INF
	return true


## Ce que toute la campagne nourrit ce mois-ci.
func nourriture_personnes(t: float) -> float:
	var n := 0.0
	for fid in ilots:
		if est_champ(int(fid)):
			n += champ_rendement(int(fid), t)
	return n


## Le départ, carte intacte : l'étalon de ce que la caisse paie en plus ou en moins.
func nourriture_depart() -> float:
	var n := 0.0
	for fid in ilots:
		if est_champ(int(fid)):
			n += _hectares(int(fid)) * NOURRITURE_PERSONNES_HA
	return n


func nourriture_part(t: float) -> float:
	return nourriture_personnes(t) / HABITANTS


func achat_nourriture_ke_mois(t: float) -> float:
	return maxf(0.0, HABITANTS - nourriture_personnes(t)) * NOURRITURE_KE_PERSONNE_MOIS


## ∫ (départ − nourris) de 0 à `t`, exacte : le nombre ne change qu'aux dates
## des camps, des chantiers et des premières récoltes. Négatif = économisé.
func achat_nourriture_cumule_ke(t: float) -> float:
	var cle := "%d/%d/%s" % [_cultures.hash(), _camps.hash(), livraison_immediate]
	if cle != _agri_cle:
		_agri_cle = cle
		var dates := [0.0]
		for fid in _camps:
			dates.append(float(_camps[fid]["debut"]))
		for fid in _cultures:
			for d in _cultures[fid]:
				var c: Dictionary = CULTURES[int(d["culture"])]
				dates.append(float(d["debut"]))
				dates.append(float(d["debut"]) + _delai(c["mois"]))
				dates.append(float(d["debut"]) + _delai(c["mois"]) + _delai(c["attente"]))
		dates.sort()
		_agri_marches = []
		for d in dates:
			_agri_marches.append([d, nourriture_personnes(d)])
	var depart := nourriture_depart()
	var ke := 0.0
	for i in _agri_marches.size():
		var debut: float = _agri_marches[i][0]
		if debut >= t:
			break
		var fin: float = minf(t, float(_agri_marches[i + 1][0])) if i + 1 < _agri_marches.size() else t
		ke += (depart - float(_agri_marches[i][1])) * (fin - debut)
	return ke * NOURRITURE_KE_PERSONNE_MOIS


## 🎨 Ce que le shader lit (`champs.gdshaderinc`) : 1 + culture, +10 pendant
## le chantier, + 0,9 × maturité du verger. `visee` ≥ 0 : l'état livré, pour
## la miniature.
func parcelle_code(fid: int, t: float, visee := -1) -> float:
	if not est_champ(fid):
		return 0.0
	if visee >= 0:
		return 1.0 + visee + (0.0 if visee == CEREALES else 0.9)
	var c := champ_culture(fid, t)
	if culture_en_cours(fid, t):
		return 11.0 + c
	if c == CEREALES:
		return 1.0
	var attente: float = _delai(CULTURES[c]["attente"])
	var mat := 1.0 if attente <= 0.0 else clampf(1.0 - recolte_dans_mois(fid, t) / attente, 0.0, 1.0)
	return 1.0 + c + 0.9 * mat


## 🌿 Prairies et vergers retiennent la pluie, pour toute la ville — même
## règle que les toits verts. Sur ce qui est LIVRÉ et hors camp.
func baisse_crue_champs_m(t: float) -> float:
	if t == _crue_champs_mois:
		return _crue_champs
	var m := 0.0
	for fid in _cultures:
		if champ_cultive(fid, t) and not culture_en_cours(fid, t):
			m += _hectares(fid) * float(CULTURES[champ_culture(fid, t)]["crue_m_ha"])
	_crue_champs_mois = t
	_crue_champs = m
	return m


# ================================== l'université et la mairie (décisions 79 · 80)

## Le coefficient d'un prix ou d'un rendement : les paliers acquis ET les
## politiques en vigueur, multipliés. Le seul point d'entrée — `energie.gd` ne
## sait pas d'où vient le coefficient.
func facteur(effet: String, t: float) -> float:
	return Recherche.facteur(self, effet, t) * Politiques.facteur(self, effet, t)


## `false` si le sujet est déjà financé, ou si la caisse ne tient pas le premier
## mois. Une fois engagé, il court jusqu'au palier : c'est un chantier.
func financer_recherche(cle: String, t: float) -> bool:
	if not Recherche.SUJETS.has(cle) or _recherche.has(cle):
		return false
	if caisse_ke(t) < float(Recherche.SUJETS[cle]["ke_mois"]):
		return false
	_recherche[cle] = t
	return true


## Signer, ou retirer. 🔴 Retirer arrête la dépense et ne rembourse rien ;
## re-signer ouvre une nouvelle période.
func basculer_politique(cle: String, t: float) -> bool:
	if not Politiques.POLITIQUES.has(cle):
		return false
	if not _politiques.has(cle):
		_politiques[cle] = []
	var p: Array = _politiques[cle]
	if Politiques.active(self, cle):
		p[-1][1] = t
	else:
		p.append([t, -1.0])
	return true


func recherche_engagee(cle: String) -> bool:
	return _recherche.has(cle)


## Ce que l'université et la mairie prélèvent CE mois-ci, en k€.
func charge_mensuelle_ke(t: float) -> float:
	var ke := 0.0
	for cle in _recherche:
		if not Recherche.acquis(self, cle, t):
			ke += float(Recherche.SUJETS[cle]["ke_mois"])
	for cle in _politiques:
		if Politiques.active(self, cle):
			ke += float(Politiques.POLITIQUES[cle]["ke_mois"])
	return ke


# ==================================================================== la caisse

## ∫ `part_rendue` de 0 à `t`, en « part × mois » : combien de temps chaque
## panneau a produit. 🪜 `part_rendue` et non `part_toit_equipe` — c'est le
## rendement qu'on encaisse, pas la surface.
## 🔴 Exacte, et c'est l'intérêt : le solde doit être le même à 5 ou 500 images
## par seconde, et l'essai saute 1,5 mois d'un coup.
func _integrale_part(fid: int, t: float) -> float:
	var s := base("i", fid, "part_rendue") * t
	for r in _rampes["i"].get(fid, []):
		if r["champ"] == "part_rendue":
			s += float(r["ecart"]) * _integrale_avancement(t, r["d"], r["L"], r["M"])
	return s


## ∫ `avancement` de 0 à t : la primitive de la rampe du Classeur §4.
static func _integrale_avancement(t: float, d: float, L: float, M: float) -> float:
	var u := t - d - L
	if u <= 0.0:
		return 0.0
	if M <= 0.0:
		return u
	if u < M:
		return u * u / (2.0 * M)
	return M * 0.5 + (u - M)


## En k€ depuis le mois 0.
## ⚠️ Le potentiel est sorti de l'intégrale : c'est la canopée de L'ÎLOT qui
## ombre ses toits, et aucune décision ne la fait bouger. 🔄 Planter, depuis le
## 2026-08-31, monte `routes.canopee` — une autre couche, sans effet ici. À
## reprendre le jour où une décision plantera DANS un îlot.
func recette_cumulee_ke(t: float) -> float:
	var ke := 0.0
	for fid in fids_batis():
		var pot := Energie.potentiel_mwh(self, fid, t)
		if pot > 0.0:
			ke += pot * _integrale_part_rendue(fid, t) / 12.0 \
				* Energie.PRIX_ENERGIE_EUR_MWH / 1000.0
	return ke


## ∫ `part` × le rendement du moment. 🔴 C'est ici que le palier de 79 est
## RÉTROACTIF sans être un cadeau : il vaut pour tout ce qui est déjà posé, à
## partir du mois où il tombe — jamais pour les MWh vendus avant lui.
func _integrale_part_rendue(fid: int, t: float) -> float:
	var m := Recherche.marches(self, "rendement_x")
	if m.size() == 1:
		return _integrale_part(fid, t)
	var s := 0.0
	for i in m.size():
		var bas: float = minf(float(m[i][0]), t)
		var haut: float = minf(float(m[i + 1][0]), t) if i + 1 < m.size() else t
		if haut > bas:
			s += float(m[i][1]) * (_integrale_part(fid, haut) - _integrale_part(fid, bas))
	return s


## En k€. Fonction PURE du temps et des chantiers engagés : « Recommencer »
## n'a rien à rembobiner, et deux parties jouées pareil donnent le même solde.
func caisse_ke(t: float) -> float:
	return CAISSE_DEPART_KE + DOTATION_KE_MOIS * t \
		+ recette_cumulee_ke(t) + solde_dense_ke(t) + _credit_essai_ke \
		- _depense_ke - aide_cumulee_ke(t) - achat_nourriture_cumule_ke(t) \
		- Recherche.depense_ke(self, t) - Politiques.depense_ke(self, t)


func _depenser(genre: String, ke: float) -> void:
	_depense_ke += ke
	_depense_genre[genre] = float(_depense_genre.get(genre, 0.0)) + ke


func _genre_reparation(couche: String, fid: int) -> String:
	if couche == "i":
		return "ilot"
	return "pont" if fid in _ponts else "rue"


## Ce que les chantiers ont coûté, par genre. Une partie sauvée avant le détail
## n'a que le total : l'écart va dans « autres ».
func depenses_par_genre() -> Dictionary:
	var out := _depense_genre.duplicate()
	var reste := _depense_ke
	for g in out:
		reste -= float(out[g])
	if reste > 0.5:
		out["autres"] = reste
	return out


## 🧪 Le bouton d'essai. Rendu à zéro par « Recommencer », comme tout le reste.
func crediter_essai_ke(montant: float) -> void:
	_credit_essai_ke += maxf(montant, 0.0)


# ==========================================================================
# LE CAPITAL POLITIQUE — un compteur, pas une jauge (16b · 17 · 58 · 95)
# Le joueur lit « confiance » (auteur, 2026-09-30, décision 97) ; le code garde « capital ».
# ==========================================================================
# Il ne s'achète pas : il se dépense à la décision et se regagne à la LIVRAISON,
# quand ça se voit. Fonction pure du temps, comme la caisse — rien à sauvegarder.
# 🎚️ LEVEL DESIGN, tout ce bloc (auteur, 2026-09-30) : les habitants qui rentrent
# et le pont rouvert rapportent « bien plus » que le reste ; retirer des places
# coûte tout de suite et rapporte plus tard.
const CAPITAL_PAR_LOGEMENT_RENTRE := 0.25   # îlot 59 : 43 logements → +11
const CAPITAL_PONT_ROUVERT := 15.0
const CAPITAL_TOUS_ABRITES := 5.0
const CAPITAL_PAR_PLACE_RETIREE := 0.2      # axe 55 : 47 places → −9
# 🚶 LE RETOUR SE JUGE SUR LA RUE (auteur, 2026-09-30, décision 99) : × MIN si
# elle garde ses voitures, × MAX si elle s'est vidée de son trafic sans le
# reporter ; un report de CAPITAL_REPORT_INSUPPORTABLE sur une voisine ramène à MIN.
const CAPITAL_RETOUR_PLACES_X_MIN := 0.5
const CAPITAL_RETOUR_PLACES_X_MAX := 1.5
const CAPITAL_REPORT_INSUPPORTABLE := 0.3   # de charge en plus sur la rue qui encaisse le plus
# En charge ABSOLUE, pas en part : la foule suit la charge perdue, et une rue déjà
# vide qu'on ferme ne se remplit de rien (sinon 0,06 → 0 valait un axe vidé).
const CAPITAL_CHARGE_RETIREE_PLEINE := 0.5
const CAPITAL_RETOUR_PLACES_MOIS := 12.0    # après la livraison — pas un chantier, le mode auteur n'y touche pas

var _capital_cle := ""
var _capital_mvts := []   # [{mois, montant, quoi, couche, fid}], triés


func capital(t: float) -> float:
	var k := CAPITAL_DEPART - usure_camp_cumulee(t)
	for m in capital_mouvements():
		if float(m["mois"]) > t:
			break
		k += float(m["montant"])
	return k


## Chaque gain et chaque dépense, datés : c'est ce que `retours.gd` annonce, pour
## que le compteur ne bouge jamais sans qu'une phrase dise pourquoi (☐ de Ressources).
## 🔗 Le pont compte à sa livraison, accès ou non : le noyau ne voit pas le réseau.
func capital_mouvements() -> Array:
	var cle := "%d/%d/%d/%d/%d/%s/%d" % [_repare.hash(), _camps.hash(), _demandes.hash(),
		_stationnement_supprime.hash(), _rampes_version, livraison_immediate, _rebati.hash()]
	if cle == _capital_cle:
		return _capital_mvts
	_capital_cle = cle
	_capital_mvts = []
	for c in _repare:
		var m: PackedStringArray = str(c).split(":")
		var couche := m[0]
		var fid := int(m[1])
		var fin := float(_repare[c]) + duree_reparation_mois(couche, fid)
		if couche == "i" and base("i", fid, "logements_sinistres") > 0.0:
			var k := float(RECONSTRUCTIONS[facon_reparation(fid)]["confiance"])
			# Le parc se paie à la décision ; les autres rapportent à la livraison.
			_capital_mvts.append({"mois": float(_repare[c]) if k < 0.0 else fin,
				"quoi": "parc" if k < 0.0 else "rentres", "couche": "i", "fid": fid,
				"montant": base("i", fid, "logements_sinistres") * CAPITAL_PAR_LOGEMENT_RENTRE * k})
		elif couche == "r" and fid in _ponts:
			_capital_mvts.append({"mois": fin, "quoi": "pont", "couche": "r", "fid": fid,
				"montant": CAPITAL_PONT_ROUVERT})
	# 🚿 Un toit pour la nuit : ce que la livraison d'un camp ajoute aux abrités.
	for fid in _camps:
		var livre := float(_camps[fid]["debut"]) + _delai(CAMP_MOIS)
		# Ses occupants à la livraison : deux camps livrés le même jour ne comptent pas deux fois.
		var gain := camp_occupants(int(fid), livre) * CAPITAL_PAR_PERSONNE_ABRITEE
		if gain >= 0.05:
			_capital_mvts.append({"mois": livre, "quoi": "camp", "couche": "i", "fid": int(fid),
				"montant": gain})
	for d in _demandes:
		_capital_mvts.append({"mois": _fin_demande(d), "quoi": "demande", "couche": d, "fid": -1,
			"montant": CAPITAL_PAR_DEMANDE})
	var abrites := _mois_tous_abrites()
	if abrites >= 0.0:
		_capital_mvts.append({"mois": abrites, "quoi": "abrites", "couche": "", "fid": -1,
			"montant": CAPITAL_TOUS_ABRITES})
	for fid in _stationnement_supprime:
		var debut := float(_stationnement_supprime[fid])
		var cout := base("r", fid, "stationnement") * CAPITAL_PAR_PLACE_RETIREE
		_capital_mvts.append({"mois": debut, "quoi": "places", "couche": "r", "fid": fid,
			"montant": -cout})
		var retour := debut + _delai(STATIONNEMENT_MOIS) + CAPITAL_RETOUR_PLACES_MOIS
		var bilan := bilan_rue(fid, debut, retour)
		var mvt := {"mois": retour, "quoi": "places_retour", "couche": "r", "fid": fid,
			"montant": cout * lerpf(CAPITAL_RETOUR_PLACES_X_MIN, CAPITAL_RETOUR_PLACES_X_MAX,
				float(bilan["videe"]) * (1.0 - float(bilan["report_part"])))}
		mvt.merge(bilan)
		_capital_mvts.append(mvt)
	_capital_mvts.sort_custom(func(a, b): return float(a["mois"]) < float(b["mois"]))
	return _capital_mvts


## 🚶 CE QUE LA RUE EST DEVENUE, un an après : la part de son trafic qu'elle a
## perdue — c'est elle qui ramène les piétons (`trafic.gd`, la foule est l'inverse
## de la charge) — et le pire report sur une autre rue, lu sur les rampes que
## `trafic.retirer_axe` marque de sa `cause` : ni la crue ni un pont rouvert le
## même mois ne sont mis sur le compte de la rue.
func bilan_rue(fid: int, debut: float, retour: float) -> Dictionary:
	var avant := valeur("r", fid, "charge", debut)
	var videe := clampf((avant - trafic_vu(fid, retour)) / CAPITAL_CHARGE_RETIREE_PLEINE, 0.0, 1.0)
	var report := 0.0
	var rue := -1
	for f in _rampes["r"]:
		if f == fid:
			continue
		var e := 0.0
		for r in _rampes["r"][f]:
			if r["champ"] == "charge" and int(r.get("cause", -1)) == fid:
				e += float(r["ecart"])
		if e > report:
			report = e
			rue = f
	return {"videe": videe, "report": report, "report_rue": rue,
		"report_part": clampf(report / CAPITAL_REPORT_INSUPPORTABLE, 0.0, 1.0)}


## Le mois où plus personne ne dort dehors, -1 si ce n'est pas encore arrivé. Le
## nombre ne baisse qu'à une livraison : on ne teste que celles-là.
func _mois_tous_abrites() -> float:
	if _perdus(0.0) <= 0.0:
		return -1.0
	var dates := []
	for c in _repare:
		var m: PackedStringArray = str(c).split(":")
		dates.append(float(_repare[c]) + duree_reparation_mois(m[0], int(m[1])))
	for fid in _camps:
		dates.append(float(_camps[fid]["debut"]) + _delai(CAMP_MOIS))
	dates.append_array(_fins_dense())
	dates.sort()
	for d in dates:
		if sans_toit(d) <= 0.0:
			return d
	return -1.0


## Ce qu'une commande dépense EN CAPITAL au mois de la décision, positif. Seules
## les places retirées en coûtent ; tout le reste en rapporte à la livraison.
func capital_commande(couche: String, fid: int, r: Dictionary, t: float) -> float:
	# 🌿 Un parc coûte la confiance des habitants qui ne rentreront pas (95).
	if couche == "i" and r.has("reparer") and str(r["reparer"]) == "parc" and not est_repare("i", fid):
		return base("i", fid, "logements_sinistres") * CAPITAL_PAR_LOGEMENT_RENTRE
	if couche != "r" or not (r.has("places") or r.has("axe")) \
			or _stationnement_supprime.has(fid) or valeur("r", fid, "stationnement", t) <= 0.0:
		return 0.0
	return base("r", fid, "stationnement") * CAPITAL_PAR_PLACE_RETIREE


func fids_batis() -> Array:
	var out := []
	for fid in ilots:
		if ilots[fid].get("fonction") != "riviere":
			out.append(fid)
	return out


## Les quatre nombres de l'énergie (PLAN §3). Des SOMMES, pas des moyennes
## (décision 63). En MWh : c'est là que l'invariant achat + production = conso
## se vérifie.
##
## 🔄 Une `facture` montant de 2 %/an vivait ici ; partie avec la caisse, car
## deux monnaies — une qu'on paie, une qu'on ne paie pas — se contredisaient.
## Toujours calculable via `Energie.facture_ke`, mais plus affichée.
##
## ⚠️ CO2 de l'énergie ACHETÉE seulement ; l'interface et l'essai y ajoutent
## `chantiers.co2_gris_an(t)`.
func indicateurs(t: float) -> Dictionary:
	var m := Energie.ville_mwh(self, t)
	var co2 := float(m["achat"]) * Energie.CO2_KG_KWH / 1000.0
	var out := {
		"conso_mwh": m["conso"],
		"production_mwh": m["production"],
		"achat_mwh": m["achat"],
		"co2_kt": co2,
		# La petite économie : ce que les panneaux posés rapportent chaque année,
		# et ce qui reste en caisse après les avoir payés.
		"recette_ke_an": m["production"] * Energie.PRIX_ENERGIE_EUR_MWH / 1000.0,
		"caisse_ke": caisse_ke(t),
		# 🌾 Ce que la campagne nourrit, et la part de la ville que ça couvre.
		# Un champ bâti ne revient pas ; un champ cultivé autrement, si.
		"nourriture_personnes": nourriture_personnes(t),
		"nourriture_part": nourriture_part(t),
		"achat_nourriture_ke_mois": achat_nourriture_ke_mois(t),
	}
	out.merge(durabilite(t, co2))
	return out


# --------------------------------------------------- réparer après la crue

## Ce que `04e` a chiffré pour cet objet, 0 s'il n'y a rien à réparer ou si
## c'est déjà payé.
func cout_reparation_ke(couche: String, fid: int, provisoire := false, facon := "") -> float:
	if est_repare(couche, fid):
		return 0.0
	var part := PONT_PROVISOIRE_PART if provisoire and fid in _ponts and couche == "r" else 1.0
	if couche == "i":
		part = float(RECONSTRUCTIONS[facon_reparation(fid, facon)]["prix"])
	return base(couche, fid, "cout_reparation_ke") * part


## La façon engagée, sinon celle qu'on demande (`reparer` de la commande), sinon comme avant.
func facon_reparation(fid: int, demandee := "") -> String:
	if _rebati.has(fid):
		return str(_rebati[fid])
	return demandee if RECONSTRUCTIONS.has(demandee) else "tradition"


## 🏗️ Ce que le shader lit d'une façon (`densification.w`, `.z`) : le mode, et
## l'attique du moderne ou la levée des pilotis, en mètres.
static func rendu_rebati(facon: String) -> Vector2:
	match facon:
		"moderne":
			return Vector2(1.0, DENSE_ETAGE_M)
		"pilotis":
			return Vector2(2.0, float(RECONSTRUCTIONS["pilotis"]["hausse_m"]))
		"parc":
			return Vector2(3.0, 0.0)
	return Vector2.ZERO


## 🏗️ Les logements rebâtis en moderne, déjà livrés : ils naissent isolés (`Energie.conso_mwh`).
func logements_neufs_isoles(fid: int, t: float) -> float:
	if not est_repare("i", fid) or facon_reparation(fid) != "moderne":
		return 0.0
	return maxf(0.0, valeur("i", fid, "logements", t) - base("i", fid, "logements"))


## 🏗️ Les pilotis lèvent le plancher : la prochaine crue le voit plus bas d'autant.
func hausse_m(fid: int) -> float:
	return float(RECONSTRUCTIONS[facon_reparation(fid)]["hausse_m"]) if est_repare("i", fid) else 0.0


## Rétabli par un pont provisoire, engagé ou livré.
func pont_provisoire(fid: int) -> bool:
	return _provisoire.has(fid)


func est_repare(couche: String, fid: int) -> bool:
	return _repare.has(couche + ":" + str(fid))


## Combien de mois dure CE chantier-là. Un pont n'est pas une rue. Engagé,
## le pont garde son mode ; sinon `provisoire` dit lequel on annonce.
func duree_reparation_mois(couche: String, fid: int, provisoire := false, facon := "") -> float:
	if couche == "i":
		return _delai(_reconstruction_mois(fid, facon))
	var coupe := str(objets("r").get(fid, {}).get("etat_crue", "")) == "coupe"
	if not coupe:
		return _delai(DEBLAIEMENT_MOIS) * (1.0 + float(_file_deblaiement.get(fid, 0.0)))
	if est_repare("r", fid):
		provisoire = _provisoire.has(fid)
	return _delai(PONT_PROVISOIRE_MOIS if provisoire else PONT_MOIS)


func _reconstruction_mois(fid: int, facon := "") -> float:
	return RECONSTRUCTION_MOIS * float(RECONSTRUCTIONS[facon_reparation(fid, facon)]["duree"])


## Ce qui reste avant que la géométrie neuve n'apparaisse. 0 = c'est fini.
func reste_reparation_mois(couche: String, fid: int, t: float) -> float:
	var cle := couche + ":" + str(fid)
	if not _repare.has(cle):
		return 0.0
	return maxf(float(_repare[cle]) + duree_reparation_mois(couche, fid) - t, 0.0)


## `true` quand le chantier est terminé : c'est CE test que la maquette
## interroge pour montrer le maillage neuf. Une géométrie qui apparaîtrait à
## l'engagement dirait qu'un pont se rebâtit en une image.
func reparation_finie(couche: String, fid: int, t: float) -> bool:
	return est_repare(couche, fid) and reste_reparation_mois(couche, fid, t) <= 0.0


## Les deux jauges de durabilité. L'adaptation avance au rythme réel des
## chantiers essentiels ; la réduction mesure le CO₂ évité depuis t0.
## 🔄 Elles avancent ENSEMBLE depuis le 2026-08-31 : la réduction n'attend plus
## la fin de l'urgence (voir `lancer_solaire`).
func durabilite(t: float, co2_kt: float) -> Dictionary:
	var reste_ke := 0.0
	var logements := 0.0
	var ponts := 0
	for fid in ilots:
		var perdus := base("i", fid, "logements_sinistres")
		if perdus <= 0.0:
			continue
		var part := 1.0
		if est_repare("i", fid):
			part = clampf(reste_reparation_mois("i", fid, t) \
				/ _reconstruction_mois(fid), 0.0, 1.0)
		reste_ke += base("i", fid, "cout_reparation_ke") * part
		logements += perdus * part
	for fid in routes:
		if str(routes[fid].get("etat_crue", "")) != "coupe":
			continue
		var part := 1.0
		if est_repare("r", fid):
			part = clampf(reste_reparation_mois("r", fid, t)
				/ maxf(duree_reparation_mois("r", fid), 0.001), 0.0, 1.0)
		reste_ke += base("r", fid, "cout_reparation_ke") * part
		ponts += int(part > 0.0)
	var adaptation := 1.0 if _adaptation_total_ke <= 0.0 else \
		clampf(1.0 - reste_ke / _adaptation_total_ke, 0.0, 1.0)
	var reduction := 0.0 if _co2_depart_kt <= 0.0 else \
		clampf(1.0 - co2_kt / _co2_depart_kt, 0.0, 1.0)
	return {
		"adaptation_part": adaptation,
		"reduction_part": reduction,
		"reduction_ecart_kt": _co2_depart_kt - co2_kt,
		"adaptation_logements": logements,
		"adaptation_ponts": ponts,
	}


## Les rues encore sous la boue, ponts exclus.
func rues_boueuses() -> Array:
	var out := []
	for fid in routes:
		if not est_repare("r", fid) and base("r", fid, "cout_reparation_ke") > 0.0 \
				and _genre_chantier("r", fid) == "deblaiement":
			out.append(fid)
	return out


## Les rues déblayées une à une, engagées ou livrées.
func rues_deblayees_main() -> int:
	var n := 0
	for cle in _repare:
		var m: PackedStringArray = str(cle).split(":")
		if m[0] == "r" and _genre_chantier("r", int(m[1])) == "deblaiement" \
				and not _file_deblaiement.has(int(m[1])):
			n += 1
	return n


## 🧹 Un seul chantier, payé à l'engagement, livré rue après rue dans l'ordre de `rues`.
func deblayer_tout(rues: Array, t: float) -> Dictionary:
	var cout := 0.0
	for fid in rues:
		cout += cout_reparation_ke("r", int(fid))
	if rues.is_empty() or cout > caisse_ke(t) + 0.001:
		return {"ok": false, "cout_ke": cout, "manque": maxf(cout - caisse_ke(t), 0.0)}
	for i in rues.size():
		_file_deblaiement[int(rues[i])] = float(i)
		reparer("r", int(rues[i]), t)
	return {"ok": true, "cout_ke": cout, "duree": duree_reparation_mois("r", int(rues[-1]))}


## `false` si rien à réparer, si c'est déjà engagé, ou si la caisse ne suit pas.
## L'interface pré-vérifie et explique ; ici, le verrou seul — même partage que
## `lancer_solaire`.
func reparer(couche: String, fid: int, t: float, provisoire := false, facon := "") -> bool:
	var cout := cout_reparation_ke(couche, fid, provisoire, facon)
	if cout <= 0.0 or cout > caisse_ke(t) + 0.001:
		return false
	if couche == "i" and not facon_permise(fid, facon, t):
		return false
	if couche == "i":
		_rebati[fid] = facon_reparation(fid, facon)
	_repare[couche + ":" + str(fid)] = t
	if provisoire and couche == "r" and fid in _ponts:
		_provisoire[fid] = true
	# ⚠️ En mode auteur le chantier est livré SANS que le mois bouge : le
	# verger redeviendrait propre au mois suivant seulement.
	_verger_vu = -1.0
	_depenser(_genre_reparation(couche, fid), cout)
	if couche == "i":
		# 🔗 CE QUE LA RECONSTRUCTION REND, et c'est tout : les logements que
		# `04e` avait retirés du parc, et le toit qu'il avait emporté. Les deux
		# étaient déjà dans la fiche — on ne fabrique aucun nombre ici.
		# ⚠️ Le budget de la ville ne dépend pas encore de `logements` (dette
		# nommée du prototype) : reconstruire ne rapporte donc rien d'autre que
		# des toits équipables. C'est un manque, pas un choix.
		# 🌿 Un parc ne rend ni logement ni toit.
		var f: Dictionary = RECONSTRUCTIONS[_rebati[fid]]
		var perdus := base("i", fid, "logements_sinistres") * float(f["logements"])
		if perdus > 0.0:
			ajouter_rampe("i", fid, "logements", perdus, t, 0.0,
				_reconstruction_mois(fid))
		var neuf := base("i", fid, "toit_m2_neuf")
		if neuf > 0.0 and float(f["logements"]) > 0.0:
			_toit_avant[fid] = ilots[fid].get("toit_m2", 0.0)
			ilots[fid]["toit_m2"] = neuf
			_vert_ha_mois = INF
	return true


func concours_lance() -> bool:
	return not _concours.is_empty()


func concours_reste_mois(t: float) -> float:
	if _concours.is_empty():
		return 0.0
	return maxf(float(_concours["debut"]) + _delai(CONCOURS_MOIS) - t, 0.0)


func concours_rendu(t: float) -> bool:
	return concours_lance() and concours_reste_mois(t) <= 0.0


func cout_concours_ke() -> float:
	return 0.0 if concours_lance() else CONCOURS_KE


## 🏛️ Sans maison détruite, pas de concours : on remet en état (auteur, 2026-10-06, le Lavoir).
func concours_utile(fid: int) -> bool:
	return base("i", fid, "batiments_ruines") > 0.0


## Sans concours rendu, un îlot ne se relève que comme avant (une façon inconnue en est une).
func facon_permise(fid: int, facon: String, t: float) -> bool:
	return not RECONSTRUCTIONS.has(facon) or facon == "tradition" \
		or (concours_rendu(t) and concours_utile(fid))


func lancer_concours(fid: int, t: float) -> bool:
	var cout := cout_concours_ke()
	if cout <= 0.0 or cout > caisse_ke(t) + 0.001 or not concours_utile(fid):
		return false
	_concours = {"debut": t, "fid": fid}
	_depenser("concours", cout)
	return true


## Ce que la crue a pris à la ville, et ce qu'il en reste à cet instant. Deux
## nombres seulement : sans eux, réparer un îlot ne change rien de VISIBLE au
## bandeau de gauche et la décision n'a pas de contrepartie lisible.
func degats(t: float) -> Dictionary:
	var perdus := 0.0
	var a_reparer := 0.0
	var coupes := 0
	# 🌊 LE NOMBRE QUE LA BERGE FAIT BOUGER, et le seul indicateur de ville qui
	# ne soit pas de l'argent : la crue annoncée sur l'îlot le plus enfoncé. Un
	# MAXIMUM, pas une moyenne — une moyenne de ville dilue le faubourg dans les
	# 58 îlots que l'eau n'atteint pas, et ne bougerait pas de 5 cm.
	# ⚠️ Sur les îlots BÂTIS que la prochaine ruinerait, pas sur toute la ville :
	# les quatre champs riverains prennent 5 m d'eau et c'est leur rôle — ils
	# tenaient le maximum à eux seuls, et rien ne l'aurait fait bouger.
	var eau_prochaine := 0.0
	for fid in ilots:
		if base("i", fid, "part_ruinee_apres") > 0.0:
			eau_prochaine = maxf(eau_prochaine,
				valeur("i", fid, "hauteur_eau_annonce", t))
		if est_repare("i", fid):
			# 🌿 Un parc ne rend pas les logements : ils restent perdus.
			if facon_reparation(fid) == "parc":
				perdus += base("i", fid, "logements_sinistres")
			continue
		perdus += base("i", fid, "logements_sinistres")
		a_reparer += base("i", fid, "cout_reparation_ke")
	for fid in routes:
		if est_repare("r", fid):
			continue
		a_reparer += base("r", fid, "cout_reparation_ke")
		if str(routes[fid].get("etat_crue", "")) == "coupe":
			coupes += 1
	return {
		"logements_perdus": perdus,
		"a_reparer_ke": a_reparer,
		"franchissements_coupes": coupes,
		"eau_prochaine_m": eau_prochaine,
		"caisse_ke": caisse_ke(t),
	}


## 🎓 CE QUE L'ÉTUDE DE L'UNIVERSITÉ ANNONCE (auteur, 2026-09-30) : la crue de
## `04e` à 6 m, relue au mois `t`. Une ruine ne se reperd pas : relever un îlot
## du faubourg fait MONTER les logements perdus (95). Pertes du bâti seulement —
## 94 demande tous les thèmes.
func prochaine_crue(t: float) -> Dictionary:
	var sous_eau := 0
	var cette_annee := 0
	var logements := 0.0
	for fid in ilots:
		if str(ilots[fid].get("sous_type", "")) in ["champ", "riviere"]:
			continue
		if base("i", fid, "hauteur_eau_max") > SEUIL_EAU_M:
			cette_annee += 1
		if valeur("i", fid, "hauteur_eau_annonce", t) > SEUIL_EAU_M:
			sous_eau += 1
		var part := valeur("i", fid, "part_ruinee_apres", t)
		var tous := valeur("i", fid, "logements", t)
		# 🏗️ Seuls les logements rebâtis sont sur pilotis ; l'ancien reste au sol.
		var leves := maxf(0.0, tous - base("i", fid, "logements")) if hausse_m(fid) > 0.0 else 0.0
		logements += part * (tous - leves) \
			+ _sur_la_courbe(fid, baisse_crue_m(fid, t) + hausse_m(fid)) * leves
	return {
		"ilots_sous_eau": sous_eau,
		"ilots_cette_annee": cette_annee,
		"logements_perdus": logements,
		"eau_pire_m": float(degats(t)["eau_prochaine_m"]),
	}
## Le seuil de `04e` (`SEUIL_MOUILLE`) : en dessous, l'eau ne passe pas la bordure.
const SEUIL_EAU_M := 0.10


# ==========================================================================
# LA COMMANDE — on règle, puis on met en place (2026-08-31)
# ==========================================================================
# 🔴 UN OBJET, UNE COMMANDE, UN CHANTIER. La fiche laisse poser plusieurs
# réglages sur le même objet ; ils partent ENSEMBLE, sur une seule caisse
# vérifiée une seule fois. Sans ça, cinq boutons faisaient cinq fois « il
# manque 214 k€ » et le joueur ne savait jamais ce qu'il pouvait s'offrir.
#
# 🔧 CE QUE LA COMMANDE NE FAIT PAS : fermer une rue aux voitures. Le report de
# trafic vit dans `trafic.gd`, qui touche des nœuds — le noyau n'en sait rien et
# le renvoie à l'appelant dans `axe`.
#
# Les réglages reconnus, tous facultatifs :
#   solaire  float  la part de toit visée          (îlot)
#   vert     float  la part de toit verdie visée   (îlot)
#   reparer  true   relever, déblayer ou rebâtir   (îlot, rue)
#            "provisoire"  un pont provisoire à la place du pont en dur
#   arbres   float  la canopée visée               (rue)
#   places   true   retirer le stationnement       (rue)
#   axe      true   fermer aux voitures            (rue) — rendu à l'appelant,
#                   et il emporte les places : une rue fermée n'a plus où garer
#   berge    int    l'état visé                    (berge)
#   camp     true   accueillir les sinistrés       (champ)
#   permeable true  rendre le sol perméable        (place-parking)
#   dense    dict   {part, etages} : la part des bâtiments visée et la
#                   hauteur — 🪜 un cran du curseur = un bâtiment  (îlot)


## Le prix de l'ensemble, annoncé AVANT d'engager quoi que ce soit. C'est lui
## que la fiche compare à la caisse, et c'est le seul endroit où le total se
## calcule : deux additions dans deux fichiers finissent par diverger.
func cout_commande_ke(couche: String, fid: int, r: Dictionary, t: float) -> float:
	var ke := 0.0
	if r.has("solaire"):
		ke += cout_solaire_ke(fid, float(r["solaire"]), t)
	if r.has("vert"):
		ke += cout_vert_ke(fid, float(r["vert"]), t)
	if r.has("arbres"):
		ke += cout_plantation_ke(fid, float(r["arbres"]), t)
	if r.has("berge"):
		ke += cout_berge_ke(fid, int(r["berge"]), t)
	if r.has("dense"):
		ke += cout_dense_ke(fid, etat_dense(fid, t)["cible"],
			float(r["dense"]["part"]), int(r["dense"]["etages"]))
	if r.has("camp"):
		ke += cout_camp_ke(fid, t)
	if r.has("permeable"):
		ke += cout_permeable_ke(fid)
	for d in DEMANDES_ORDRE:
		if r.has("demande_" + d):
			ke += cout_demande_ke(d)
	if r.has("culture"):
		ke += cout_culture_ke(fid, int(r["culture"]))
	if r.has("concours"):
		ke += cout_concours_ke()
	if r.has("reparer"):
		ke += cout_reparation_ke(couche, fid, str(r["reparer"]) == "provisoire", str(r["reparer"]))
	return ke


## La durée de l'ensemble : LA PLUS LONGUE. L'objet reste en travaux jusqu'à ce
## que le dernier corps de métier ait fini — même règle que `chantier()`.
func duree_commande_mois(couche: String, fid: int, r: Dictionary, t: float) -> float:
	var m := 0.0
	if r.has("solaire"):
		m = maxf(m, duree_solaire_mois(valeur("i", fid, "part_toit_equipe", t),
			float(r["solaire"])))
	if r.has("vert"):
		m = maxf(m, duree_vert_mois(valeur("i", fid, "part_toit_vert", t),
			float(r["vert"])))
	if r.has("arbres"):
		m = maxf(m, _delai(PLANTATION_MOIS))
	# 🅿️ La fermeture emporte les places : même chantier de deux mois, donc
	# même durée annoncée — mais seulement s'il reste des places à retirer.
	if r.has("places") or (couche == "r" and r.has("axe")
			and valeur("r", fid, "stationnement", t) >= 0.5):
		m = maxf(m, _delai(STATIONNEMENT_MOIS))
	if r.has("dense"):
		m = maxf(m, duree_dense_mois(int(r["dense"]["etages"]),
			etat_dense(fid, t)["cible"], float(r["dense"]["part"])))
	if r.has("berge"):
		m = maxf(m, _delai(BERGE_MOIS[int(r["berge"])]
			- BERGE_MOIS[berge_etat(fid, t)]))
	if r.has("camp"):
		m = maxf(m, _delai(CAMP_MOIS))
	if r.has("permeable") and not _permeable.has(fid):
		m = maxf(m, _delai(PERMEABLE_MOIS))
	for d in DEMANDES_ORDRE:
		if r.has("demande_" + d) and not _demandes.has(d):
			m = maxf(m, _delai(float(DEMANDES[d]["mois"])))
	if r.has("culture"):
		m = maxf(m, _delai(CULTURES[int(r["culture"])]["mois"]))
	if r.has("concours") and not concours_lance():
		m = maxf(m, _delai(CONCOURS_MOIS))
	if r.has("reparer"):
		m = maxf(m, duree_reparation_mois(couche, fid, str(r["reparer"]) == "provisoire",
			str(r["reparer"])))
	return m


## Engage tout, ou rien. Rend ce qui s'est passé — `manque` non nul est le seul
## refus du jeu, et la fiche l'écrit en toutes lettres.
##
## 🔴 L'ORDRE N'EST PAS LIBRE : réparer EN DERNIER, parce qu'il remplace
## `toit_m2` par le toit d'un îlot relevé. Placé avant, la pose solaire aurait
## coûté plus cher que le prix annoncé quelques lignes plus haut.
## ⚠️ Le total étant déjà couvert par la caisse, chaque verrou individuel passe
## forcément : ce qui reste après une dépense couvre toujours le reste à payer.
func commander(couche: String, fid: int, r: Dictionary, t: float) -> Dictionary:
	var cout := cout_commande_ke(couche, fid, r, t)
	var caisse := caisse_ke(t)
	if cout > caisse + 0.001:
		return {"ok": false, "manque": cout - caisse, "cout_ke": cout,
			"faits": [], "axe": false}
	# 🗳️ Le second refus du jeu, même règle que l'argent : à zéro, on ne dépense
	# plus de capital (auteur, 2026-09-30) — ce qui en rapporte passe toujours.
	var manque_capital := capital_commande(couche, fid, r, t) - capital(t)
	if manque_capital > 0.001:
		return {"ok": false, "manque": 0.0, "manque_capital": manque_capital,
			"cout_ke": cout, "faits": [], "axe": false}
	var capital_depense := capital_commande(couche, fid, r, t)
	var faits := []
	if r.has("solaire") and lancer_solaire(fid, float(r["solaire"]), t):
		faits.append("solaire")
	if r.has("vert") and lancer_vert(fid, float(r["vert"]), t):
		faits.append("toit vert")
	if r.has("arbres") and planter(fid, float(r["arbres"]), t):
		faits.append("plantation")
	# 🅿️ FERMER AUX VOITURES RETIRE LES PLACES (auteur, 2026-09-04) : la
	# fermeture les emporte sans qu'on ait à les demander.
	if (r.has("places") or r.has("axe")) and supprimer_stationnement(fid, t):
		faits.append("stationnement")
	if r.has("dense") and densifier(fid, float(r["dense"]["part"]),
			int(r["dense"]["etages"]), t):
		faits.append("densification")
	if r.has("berge") and transformer_berge(fid, int(r["berge"]), t):
		faits.append("berge")
	if r.has("camp") and abriter(fid, t):
		faits.append("relogement")
	if r.has("permeable") and rendre_permeable(fid, t):
		faits.append("sol perméable")
	for d in DEMANDES_ORDRE:
		if r.has("demande_" + d) and equiper_camp(d, t):
			faits.append(str(DEMANDES[d]["nom"]).to_lower())
	if r.has("culture") and cultiver(fid, int(r["culture"]), t):
		faits.append("culture")
	if r.has("concours") and lancer_concours(fid, t):
		faits.append("concours")
	if r.has("reparer") and reparer(couche, fid, t, str(r["reparer"]) == "provisoire",
			str(r["reparer"])):
		faits.append("reparation")
	return {"ok": not faits.is_empty() or r.has("axe"), "manque": 0.0,
		"cout_ke": cout, "faits": faits, "axe": r.has("axe"),
		"capital": capital_depense if "stationnement" in faits else 0.0}


# ------------------------------------------------- la ville en travaux

# 🔧 LA VUE CHANTIERS (touche X) lit ces deux fonctions et rien d'autre. Un
# objet est CASSÉ, EN CHANTIER ou FAIT — jamais deux à la fois, sinon la
# couleur ment. Le solaire en est : « tous les chantiers » n'en exclut aucun.
# ⚠️ Rien à voir avec `chantiers.gd`, l'ancien prototype à deux décisions.
const CHANTIER_INTACT := 0
const CHANTIER_CASSE := 1
const CHANTIER_EN_COURS := 2
const CHANTIER_FAIT := 3


func etat_chantier(couche: String, fid: int, t: float) -> int:
	if couche == "i" and camp_pose(fid):
		return CHANTIER_FAIT if camp_livre(fid, t) else CHANTIER_EN_COURS
	# La pose passe devant : sur un îlot déjà relevé, c'est elle le chantier.
	if couche == "i" and culture_en_cours(fid, t):
		return CHANTIER_EN_COURS
	if couche == "i" and ((_solaire.has(fid) and etat_solaire(fid, t)["en_cours"])
			or (_vert.has(fid) and etat_vert(fid, t)["en_cours"])
			or (_dense.has(fid) and etat_dense(fid, t)["en_cours"])
			or permeable_en_cours(fid, t)):
		return CHANTIER_EN_COURS
	if base(couche, fid, "cout_reparation_ke") <= 0.0:
		return CHANTIER_INTACT
	if reparation_finie(couche, fid, t):
		return CHANTIER_FAIT
	return CHANTIER_EN_COURS if est_repare(couche, fid) else CHANTIER_CASSE


## 🔧 OÙ EN EST LE CHANTIER DE CET OBJET-LÀ — ce que la barre de la fiche
## montre. Quand deux courent ensemble, celui qui finit le DERNIER : l'objet
## reste en travaux jusque-là. Mêmes mots que `chantiers()`, l'interface traduit.
func chantier(couche: String, fid: int, t: float) -> Dictionary:
	var out := {"actif": false, "part": 0.0, "reste_mois": 0.0, "quoi": ""}
	if fid < 0:
		return out
	var lot := []   # [quoi, durée totale, ce qui reste]
	if couche == "i" and camp_pose(fid) and not camp_livre(fid, t):
		lot.append(["relogement", _delai(CAMP_MOIS), camp_reste_mois(fid, t)])
	if couche == "i" and camp_livre(fid, t) and camp_accessible(fid, t):
		var d := demande_en_cours(t)
		if not d.is_empty():
			lot.append([d[0], d[1], d[2]])
	if couche == "i" and int(_concours.get("fid", -1)) == fid and not concours_rendu(t):
		lot.append(["concours", _delai(CONCOURS_MOIS), concours_reste_mois(t)])
	if est_repare(couche, fid) and not reparation_finie(couche, fid, t):
		lot.append([_genre_chantier(couche, fid),
			duree_reparation_mois(couche, fid),
			reste_reparation_mois(couche, fid, t)])
	if couche == "i" and _solaire.has(fid) and etat_solaire(fid, t)["en_cours"]:
		lot.append(["solaire", float(_solaire[fid]["duree"]),
			float(etat_solaire(fid, t)["reste_mois"])])
	if couche == "i" and _vert.has(fid) and etat_vert(fid, t)["en_cours"]:
		lot.append(["toit vert", float(_vert[fid]["duree"]),
			float(etat_vert(fid, t)["reste_mois"])])
	if couche == "i" and _dense.has(fid) and etat_dense(fid, t)["en_cours"]:
		lot.append(["densification", float(_dense[fid]["duree"]),
			float(etat_dense(fid, t)["reste_mois"])])
	if couche == "i" and permeable_en_cours(fid, t):
		lot.append(["sol perméable", float(_permeable[fid]["duree"]),
			permeable_reste_mois(fid, t)])
	if couche == "i" and culture_en_cours(fid, t):
		lot.append(["culture", _delai(CULTURES[champ_culture(fid, t)]["mois"]),
			culture_reste_mois(fid, t)])
	if couche == "b" and berge_en_cours(fid, t):
		lot.append(["berge", float(_berge[fid]["duree"]),
			berge_reste_mois(fid, t)])
	if couche == "r" and plantation_en_cours(fid, t):
		lot.append(["plantation", float(_plantation[fid]["duree"]),
			plantation_reste_mois(fid, t)])
	if couche == "r" and _stationnement_supprime.has(fid):
		var reste: float = maxf(0.0,
			float(_stationnement_supprime[fid]) + STATIONNEMENT_MOIS - t)
		if reste > 0.0:
			lot.append(["stationnement", STATIONNEMENT_MOIS, reste])
	for c in lot:
		if float(c[2]) <= float(out["reste_mois"]):
			continue
		out = {"actif": true, "quoi": str(c[0]), "reste_mois": float(c[2]),
			"part": clampf(1.0 - float(c[2]) / maxf(float(c[1]), 0.001), 0.0, 1.0)}
	return out


## Ce qui est cassé, ce qui se répare, ce qui est fait — à cet instant.
## Les genres sont des mots, pas des couleurs : l'interface les traduit.
##
## ⚠️ Les chantiers EN COURS se listent, le cassé se COMPTE : au mois 0 le
## cassé se compte en centaines d'objets, et c'est la couleur au sol qui dit où
## ils sont. Appelée à chaque image tant que le panneau est ouvert — d'où
## l'absence d'une liste qu'il faudrait allouer puis trier pour rien.
func chantiers(t: float) -> Dictionary:
	var en_cours := []
	var faits := 0
	var casses := 0
	var reste_ke := 0.0
	var casses_par_genre := {"reconstruction": 0, "pont": 0, "deblaiement": 0}
	# 🧹 Le déblaiement groupé est UN chantier : ses rues ne se listent pas une à une.
	var groupe := {"rues": 0, "reste": 0.0, "cout": 0.0}
	for couche in ["i", "r"]:
		for fid in objets(couche):
			var prix := base(couche, fid, "cout_reparation_ke")
			if prix <= 0.0:
				continue
			var genre := _genre_chantier(couche, fid)
			if not est_repare(couche, fid):
				casses += 1
				casses_par_genre[genre] += 1
				reste_ke += prix
			elif reparation_finie(couche, fid, t):
				faits += 1
			elif couche == "r" and _file_deblaiement.has(fid):
				groupe["rues"] += 1
				groupe["reste"] = maxf(groupe["reste"], reste_reparation_mois(couche, fid, t))
			else:
				en_cours.append({"couche": couche, "fid": fid,
					"genre": genre, "cout_ke": prix,
					"reste_mois": reste_reparation_mois(couche, fid, t),
					"duree": duree_reparation_mois(couche, fid)})
	if groupe["rues"] > 0:
		for fid in _file_deblaiement:
			groupe["cout"] += base("r", fid, "cout_reparation_ke")
		en_cours.append({"couche": "r", "fid": -1, "genre": "deblaiement_groupe",
			"rues": groupe["rues"], "cout_ke": groupe["cout"], "reste_mois": groupe["reste"],
			"duree": _delai(DEBLAIEMENT_MOIS) * _file_deblaiement.size()})
	# La pose est un chantier comme un autre : sans elle, « tous les chantiers
	# en cours » en oublierait un, et l'îlot ambre ne serait dans aucune liste.
	for fid in _solaire:
		var e := etat_solaire(fid, t)
		if not e["en_cours"]:
			continue
		en_cours.append({"couche": "i", "fid": fid, "genre": "solaire",
			"cout_ke": float(e["cout_ke"]), "reste_mois": float(e["reste_mois"]),
			"duree": float(_solaire[fid]["duree"])})
	for fid in _vert:
		var ev := etat_vert(fid, t)
		if not ev["en_cours"]:
			continue
		en_cours.append({"couche": "i", "fid": fid, "genre": "toit vert",
			"cout_ke": float(ev["cout_ke"]), "reste_mois": float(ev["reste_mois"]),
			"duree": float(_vert[fid]["duree"])})
	# La transformation d'une berge dure 6 à 18 mois : c'est le chantier le plus
	# long du jeu après un pont, et il doit se voir dans la liste.
	for fid in _berge:
		if not berge_en_cours(fid, t):
			continue
		en_cours.append({"couche": "b", "fid": fid, "genre": "berge",
			"cout_ke": float(_berge[fid]["cout_ke"]),
			"reste_mois": berge_reste_mois(fid, t), "duree": float(_berge[fid]["duree"])})
	# 🌳 La plantation est le chantier le plus long après un pont : deux ans
	# avant que l'ombre y soit. Elle se liste comme les autres.
	for fid in _plantation:
		if not plantation_en_cours(fid, t):
			continue
		en_cours.append({"couche": "r", "fid": fid, "genre": "plantation",
			"cout_ke": float(_plantation[fid]["cout_ke"]),
			"reste_mois": plantation_reste_mois(fid, t),
			"duree": float(_plantation[fid]["duree"])})
	for fid in _camps:
		if not camp_livre(fid, t):
			en_cours.append({"couche": "i", "fid": fid, "genre": "relogement",
				"cout_ke": float(_camps[fid]["cout_ke"]), "reste_mois": camp_reste_mois(fid, t),
				"duree": _delai(CAMP_MOIS)})
	if concours_lance() and not concours_rendu(t):
		en_cours.append({"couche": "i", "fid": int(_concours["fid"]), "genre": "concours",
			"cout_ke": CONCOURS_KE, "reste_mois": concours_reste_mois(t),
			"duree": _delai(CONCOURS_MOIS)})
	var dem := demande_en_cours(t)
	if not dem.is_empty() and camp_principal(t) >= 0:
		en_cours.append({"couche": "i", "fid": camp_principal(t), "genre": dem[0],
			"cout_ke": float(DEMANDES[dem[0]]["ke"]), "reste_mois": dem[2], "duree": dem[1]})
	for fid in _cultures:
		if culture_en_cours(fid, t):
			en_cours.append({"couche": "i", "fid": fid, "genre": "culture",
				"cout_ke": float(_derniere_culture(fid, t)["cout_ke"]),
				"reste_mois": culture_reste_mois(fid, t),
				"duree": _delai(CULTURES[champ_culture(fid, t)]["mois"])})
	for fid in _permeable:
		if permeable_en_cours(fid, t):
			en_cours.append({"couche": "i", "fid": fid, "genre": "sol perméable",
				"cout_ke": float(_permeable[fid]["cout_ke"]),
				"reste_mois": permeable_reste_mois(fid, t), "duree": float(_permeable[fid]["duree"])})
	for fid in _dense:
		var d := etat_dense(fid, t)
		if d["en_cours"]:
			en_cours.append({"couche": "i", "fid": fid, "genre": "densification",
				"cout_ke": d["cout_ke"], "reste_mois": d["reste_mois"],
				"duree": float(_dense[fid]["duree"])})
	for fid in _stationnement_supprime:
		var reste := float(_stationnement_supprime[fid]) + _delai(STATIONNEMENT_MOIS) - t
		if reste > 0.0:
			en_cours.append({"couche": "r", "fid": fid, "genre": "stationnement",
				"cout_ke": 0.0, "reste_mois": reste, "duree": _delai(STATIONNEMENT_MOIS)})
	# `part` : ce qui est fait, 0 → 1 — les barres du coin bas-droit.
	for c in en_cours:
		c["part"] = clampf(1.0 - float(c["reste_mois"]) / maxf(float(c["duree"]), 0.001), 0.0, 1.0)
	# Le plus proche de sa fin en tête : c'est l'ordre dans lequel on lit une
	# liste qui ne tient pas entière à l'écran.
	en_cours.sort_custom(func(a, b): return a["reste_mois"] < b["reste_mois"])
	return {
		"en_cours": en_cours,
		"casses": casses,
		"casses_par_genre": casses_par_genre,
		"faits": faits,
		"reste_ke": reste_ke,
	}


func _genre_chantier(couche: String, fid: int) -> String:
	if couche == "i":
		return "reconstruction"
	return "pont" if str(objets("r").get(fid, {}).get("etat_crue", "")) == "coupe" \
		else "deblaiement"
