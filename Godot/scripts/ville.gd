extends RefCounted
# L'état de Wehrau, et ce qu'il devient quand le temps passe.
# Que des nombres : aucun nœud, aucune couleur, aucun signal.
#
# La rampe vient de `Classeur/README.md`, déjà éprouvée dans `08_jouer.py`.
# ⚠️ Les deux moteurs doivent donner le même chiffre — contrôle de recoupement
# décrit dans le README de Godot.

const Energie := preload("res://scripts/energie.gd")

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
const CAISSE_DEPART_KE := 800.0            # de quoi équiper deux ou trois bons toits
const DOTATION_KE_MOIS := 30.0             # 360 k€/an votés pour la transition

var ilots := {}            # fid:int -> {champ: float|String}
var routes := {}
var riverains := {}        # fid tronçon -> [fid îlot]
var _rampes := {"i": {}, "r": {}}   # couche -> fid -> [rampe]
var _solaire := {}         # fid -> {debut, duree, cible, cout_ke}
var _stationnement_supprime := {}  # fid -> mois d'engagement
var _depense_ke := 0.0     # tout ce qui a été engagé en poses depuis le mois 0
var _repare := {}          # "i:66" -> le mois où la réparation a été engagée
var _toit_avant := {}      # fid -> `toit_m2` d'avant la reconstruction
var _adaptation_total_ke := 0.0
var _co2_depart_kt := 0.0

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

# Ce qui change dans le temps ; tout le reste est figé volontairement.
# ⚠️ `canopee` reste ici bien que son indicateur soit retiré : c'est elle qui
# fait l'OMBRAGE des toits. Une donnée n'est pas un indicateur.
const CHAMPS_MOBILES := {
	"i": ["canopee", "impermeabilise", "riverain", "logements",
		"part_toit_equipe", "part_isolee"],
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
const DEBLAIEMENT_MOIS := 1.0        # la vase enlevée d'une rue
const PONT_MOIS := 18.0              # un franchissement rebâti


func charger(d: Dictionary) -> void:
	var o: Dictionary = d["objets"]
	for cle in (o["ilots"] as Dictionary):
		ilots[int(cle)] = (o["ilots"] as Dictionary)[cle]
	for cle in (o["routes"] as Dictionary):
		routes[int(cle)] = (o["routes"] as Dictionary)[cle]
	for cle in (d["riverains"] as Dictionary):
		var liste := []
		for f in (d["riverains"] as Dictionary)[cle]:
			liste.append(int(f))
		riverains[int(cle)] = liste

	# La jauge d'adaptation porte l'urgence vitale : logements à relever et
	# franchissements à rétablir. Le déblaiement des rues reste visible dans le
	# diagnostic, mais ne retient pas indéfiniment l'ouverture de la réduction.
	for fid in ilots:
		if base("i", fid, "logements_sinistres") > 0.0:
			_adaptation_total_ke += base("i", fid, "cout_reparation_ke")
	for fid in routes:
		if str(routes[fid].get("etat_crue", "")) == "coupe":
			_adaptation_total_ke += base("r", fid, "cout_reparation_ke")
	var m := Energie.ville_mwh(self, 0.0)
	_co2_depart_kt = float(m["achat"]) * Energie.CO2_KG_KWH / 1000.0


func objets(couche: String) -> Dictionary:
	return ilots if couche == "i" else routes


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
	var v := base(couche, fid, champ)
	for r in _rampes[couche].get(fid, []):
		if r["champ"] == champ:
			v += float(r["ecart"]) * avancement(t, r["d"], r["L"], r["M"])
	return _borner(champ, v)


static func _borner(champ: String, v: float) -> float:
	match champ:
		"canopee", "impermeabilise", "riverain", "alea", "charge", "desserte_tc", \
		"part_toit_equipe", "part_isolee":
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


func ajouter_rampe(couche: String, fid: int, champ: String, ecart: float,
		d: float, L: float, M: float) -> void:
	if not _rampes[couche].has(fid):
		_rampes[couche][fid] = []
	_rampes[couche][fid].append({
		"champ": champ, "ecart": ecart, "d": d, "L": L, "M": M,
	})


func vider_rampes() -> void:
	_rampes = {"i": {}, "r": {}}


func supprimer_stationnement(fid: int, t: float) -> bool:
	if _stationnement_supprime.has(fid):
		return false
	var actuel := valeur("r", fid, "stationnement", t)
	if actuel <= 0.0:
		return false
	_stationnement_supprime[fid] = t
	ajouter_rampe("r", fid, "stationnement", -actuel, t, 0.0, 2.0)
	return true


func stationnement_en_suppression(fid: int) -> bool:
	return _stationnement_supprime.has(fid)


## Une rue envasée ou un tablier emporté ne redevient praticable qu'à la fin
## de son chantier. Le prix exporté est le seul marqueur commun aux deux cas.
func route_praticable(fid: int, t: float) -> bool:
	return base("r", fid, "cout_reparation_ke") <= 0.0 \
		or reparation_finie("r", fid, t)


## Retour au mois 0. Rien n'ayant été écrit en base, il n'y a rien d'autre à
## défaire — et ni géométrie ni caméra ne sont concernées.
func reinitialiser() -> void:
	_solaire.clear()
	_stationnement_supprime.clear()
	_depense_ke = 0.0
	# Les toits reconstruits redeviennent des ruines : `toit_m2` est la seule
	# donnée que `reparer` écrit en base, donc la seule à défaire.
	for fid in _toit_avant:
		ilots[fid]["toit_m2"] = _toit_avant[fid]
	_toit_avant.clear()
	_repare.clear()
	vider_rampes()


## En k€, depuis la part atteinte au mois `t`. Annoncé par la fiche avant
## validation.
func cout_solaire_ke(fid: int, part: float, t: float) -> float:
	if not ilots.has(fid):
		return 0.0
	return Energie.cout_pose_ke(self, fid,
		valeur("i", fid, "part_toit_equipe", t), clampf(part, 0.0, 1.0))


## `false` si rien n'est lancé (cible trop basse, chantier en cours, caisse
## insuffisante). L'interface pré-vérifie et explique ; ici, le verrou seul.
##
## 🔴 La rampe s'AJOUTE. Réécrire l'histoire de la pose fausserait la recette
## encaissée, qui en est l'intégrale — d'où le prix payé : une pose engagée ne
## se révise plus.
func lancer_solaire(fid: int, part: float, t: float) -> bool:
	# Décision 72 : tant que la ville ne tient pas de nouveau, la réduction
	# n'est pas une décision disponible — même un appel qui contourne l'UI est
	# refusé ici.
	if not reduction_deverrouillee(t) \
			or not ilots.has(fid) or etat_solaire(fid, t)["en_cours"]:
		return false
	if Energie.toit_equipable_m2(self, fid) <= 0.0:
		return false
	var actuelle := valeur("i", fid, "part_toit_equipe", t)
	var cible := clampf(part, 0.0, 1.0)
	if cible <= actuelle + 0.0001:
		return false

	# ⚠️ Le coût se lit AVANT la rampe : `caisse_ke` intègre les rampes
	# existantes, et la nouvelle n'a encore rien rapporté.
	var cout := Energie.cout_pose_ke(self, fid, actuelle, cible)
	if cout > caisse_ke(t) + 0.001:
		return false

	var duree := duree_solaire_mois(actuelle, cible)
	ajouter_rampe("i", fid, "part_toit_equipe", cible - actuelle, t, 0.0, duree)
	_solaire[fid] = {"debut": t, "duree": duree, "cible": cible, "cout_ke": cout}
	_depense_ke += cout
	return true


func duree_solaire_mois(depart: float, cible: float) -> float:
	return maxf(cible - depart, 0.0) * SOLAIRE_MOIS_POUR_100


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


# ==================================================================== la caisse

## ∫ `part_toit_equipe` de 0 à `t`, en « part × mois » : combien de temps chaque
## panneau a produit.
## 🔴 Exacte, et c'est l'intérêt : le solde doit être le même à 5 ou 500 images
## par seconde, et l'essai saute 1,5 mois d'un coup.
func _integrale_part(fid: int, t: float) -> float:
	var s := base("i", fid, "part_toit_equipe") * t
	for r in _rampes["i"].get(fid, []):
		if r["champ"] == "part_toit_equipe":
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
## ⚠️ Le potentiel est sorti de l'intégrale : la canopée ne bouge pas dans ce
## prototype. À reprendre le jour où une décision plantera des arbres.
func recette_cumulee_ke(t: float) -> float:
	var ke := 0.0
	for fid in fids_batis():
		var pot := Energie.potentiel_mwh(self, fid, t)
		if pot > 0.0:
			ke += pot * _integrale_part(fid, t) / 12.0 \
				* Energie.PRIX_ENERGIE_EUR_MWH / 1000.0
	return ke


## En k€. Fonction PURE du temps et des chantiers engagés : « Recommencer »
## n'a rien à rembobiner, et deux parties jouées pareil donnent le même solde.
func caisse_ke(t: float) -> float:
	return CAISSE_DEPART_KE + DOTATION_KE_MOIS * t \
		+ recette_cumulee_ke(t) - _depense_ke


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
	}
	out.merge(durabilite(t, co2))
	return out


# --------------------------------------------------- réparer après la crue

## Ce que `04e` a chiffré pour cet objet, 0 s'il n'y a rien à réparer ou si
## c'est déjà payé.
func cout_reparation_ke(couche: String, fid: int) -> float:
	if est_repare(couche, fid):
		return 0.0
	return base(couche, fid, "cout_reparation_ke")


func est_repare(couche: String, fid: int) -> bool:
	return _repare.has(couche + ":" + str(fid))


## Combien de mois dure CE chantier-là. Un pont n'est pas une rue.
func duree_reparation_mois(couche: String, fid: int) -> float:
	if couche == "i":
		return RECONSTRUCTION_MOIS
	var coupe := str(objets("r").get(fid, {}).get("etat_crue", "")) == "coupe"
	return PONT_MOIS if coupe else DEBLAIEMENT_MOIS


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


## Le seuil visible du prologue : les logements sinistrés sont relevés et les
## franchissements rouverts. Les rues encore sales restent une dette, pas une
## serrure sur tout le reste du jeu.
func reduction_deverrouillee(t: float) -> bool:
	for fid in ilots:
		if base("i", fid, "logements_sinistres") > 0.0 \
				and not reparation_finie("i", fid, t):
			return false
	for fid in routes:
		if str(routes[fid].get("etat_crue", "")) == "coupe" \
				and not reparation_finie("r", fid, t):
			return false
	return _adaptation_total_ke > 0.0


## Les deux jauges de durabilité. L'adaptation avance au rythme réel des
## chantiers essentiels ; la réduction mesure le CO₂ évité depuis t0.
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
				/ RECONSTRUCTION_MOIS, 0.0, 1.0)
		reste_ke += base("i", fid, "cout_reparation_ke") * part
		logements += perdus * part
	for fid in routes:
		if str(routes[fid].get("etat_crue", "")) != "coupe":
			continue
		var part := 1.0
		if est_repare("r", fid):
			part = clampf(reste_reparation_mois("r", fid, t) / PONT_MOIS, 0.0, 1.0)
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
		"reduction_verrouillee": not reduction_deverrouillee(t),
		"adaptation_logements": logements,
		"adaptation_ponts": ponts,
	}


## `false` si rien à réparer, si c'est déjà engagé, ou si la caisse ne suit pas.
## L'interface pré-vérifie et explique ; ici, le verrou seul — même partage que
## `lancer_solaire`.
func reparer(couche: String, fid: int, t: float) -> bool:
	var cout := cout_reparation_ke(couche, fid)
	if cout <= 0.0 or cout > caisse_ke(t) + 0.001:
		return false
	_repare[couche + ":" + str(fid)] = t
	_depense_ke += cout
	if couche == "i":
		# 🔗 CE QUE LA RECONSTRUCTION REND, et c'est tout : les logements que
		# `04e` avait retirés du parc, et le toit qu'il avait emporté. Les deux
		# étaient déjà dans la fiche — on ne fabrique aucun nombre ici.
		# ⚠️ Le budget de la ville ne dépend pas encore de `logements` (dette
		# nommée du prototype) : reconstruire ne rapporte donc rien d'autre que
		# des toits équipables. C'est un manque, pas un choix.
		var perdus := base("i", fid, "logements_sinistres")
		if perdus > 0.0:
			ajouter_rampe("i", fid, "logements", perdus, t, 0.0,
				RECONSTRUCTION_MOIS)
		var neuf := base("i", fid, "toit_m2_neuf")
		if neuf > 0.0:
			_toit_avant[fid] = ilots[fid].get("toit_m2", 0.0)
			ilots[fid]["toit_m2"] = neuf
	return true


## Ce que la crue a pris à la ville, et ce qu'il en reste à cet instant. Deux
## nombres seulement : sans eux, réparer un îlot ne change rien de VISIBLE au
## bandeau de gauche et la décision n'a pas de contrepartie lisible.
func degats(t: float) -> Dictionary:
	var perdus := 0.0
	var a_reparer := 0.0
	var coupes := 0
	for fid in ilots:
		if est_repare("i", fid):
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
		"caisse_ke": caisse_ke(t),
	}
