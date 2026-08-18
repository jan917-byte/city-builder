extends RefCounted
# L'état de Wehrau, et ce qu'il devient quand le temps passe.
#
# AUCUN accès aux nœuds, aucune couleur, aucun signal : ce fichier ne connaît
# que des nombres. Même discipline que `constructeur.gd`, et pour la même
# raison — c'est ce qui permet de le tester, de le relire et, le jour venu, de
# le porter ailleurs.
#
# La formule de la rampe vient du `Classeur/README.md` §4 et elle est déjà
# éprouvée dans `08_jouer.py`. Les deux moteurs doivent donner le même chiffre :
# c'est le contrôle de recoupement, et il est dans le README de Godot.

const Energie := preload("res://scripts/energie.gd")

const HORIZON_MOIS := 240                  # 20 ans. Le classeur s'arrête à 60.

# ⏸️ Le budget en POINTS de l'ancien prototype. Plus lu par la boucle jouable
# depuis le 2026-08-17 ; `chantiers.gd` les lit encore, d'où leur survie.
const BUDGET_MENSUEL := 100.0 / 12.0       # 100 pts par an — Classeur §2
const CAPITAL_DEPART := 50.0               # décision 16b

# ==========================================================================
# LA CAISSE — la petite économie, demandée le 2026-08-17
# ==========================================================================
# Deux nombres, et ils décrivent une mairie, pas un pays : ce qu'elle a devant
# elle au premier jour, et ce qu'elle remet au pot chaque mois. Tout le reste
# vient des panneaux — ce qu'ils coûtent, ce qu'ils rapportent.
#
# 🔴 Ce sont deux réglages de LEVEL DESIGN, pas des constantes physiques. Ils
# décident à eux seuls si le jeu est « dur mais possible » : trop haut, on
# équipe la ville sans choisir ; trop bas, on regarde le temps passer. Le
# repère est imprimé par `-- --essai` — combien d'îlots la caisse paie au mois 0,
# et ce que coûterait la ville entière.
const CAISSE_DEPART_KE := 800.0            # de quoi équiper deux ou trois bons toits
const DOTATION_KE_MOIS := 30.0             # 360 k€/an votés pour la transition

var ilots := {}            # fid:int -> {champ: float|String}
var routes := {}
var riverains := {}        # fid tronçon -> [fid îlot]
var _rampes := {"i": {}, "r": {}}   # couche -> fid -> [rampe]
var _solaire := {}         # fid -> {debut, duree, cible, cout_ke}
var _depense_ke := 0.0     # tout ce qui a été engagé en poses depuis le mois 0

# 🔄 Il y avait ici un `_base_avant` : `lancer_solaire` FIGEAIT EN BASE la part
# déjà posée avant de remplacer la rampe, ce qui permettait de réviser une cible
# en cours de chantier, et ce dictionnaire servait à défaire ça au retour au
# mois 0. Retiré avec l'arrivée de la caisse, et pas par goût du ménage :
# réécrire la base efface l'HISTOIRE de la pose, or la recette encaissée est
# l'intégrale de cette histoire. Une révision à mi-parcours aurait fait croire
# à la caisse que le toit était équipé depuis le premier jour.
# Ce qui remplace : les rampes s'ADDITIONNENT (voir `lancer_solaire`), et un
# chantier engagé ne se révise plus tant qu'il n'est pas fini.

# Une pose complète dure au plus UN mois. Une hausse plus petite prend une
# fraction de ce temps : ajouter 50 points de toiture demande donc 15 jours.
# 🔄 C'était 3 mois jusqu'au 2026-08-17, quand une minute réelle valait encore
# un mois : la pose durait alors trois minutes de montre, trop long pour juger
# le geste. Passer à 1 fait aussi tomber la plupart des poses sous le mois,
# donc `interface._duree` les annonce désormais EN JOURS.
const SOLAIRE_MOIS_POUR_100 := 1.0

# Ce qui change dans le temps. Tout le reste est figé, et c'est volontaire :
# une variable qui bouge sans qu'on sache pourquoi coûte une soirée.
#
# ⚠️ `canopee` reste de la partie alors que son indicateur a été retiré : c'est
# elle qui fait l'OMBRAGE des toits — le rendement d'un panneau est multiplié
# par `1 − 0,4 × canopee`. Une donnée n'est pas un indicateur.
const CHAMPS_MOBILES := {
	"i": ["canopee", "impermeabilise", "riverain", "logements",
		"part_toit_equipe", "part_isolee"],
	"r": ["canopee", "emprise_libre_m", "stationnement", "charge"],
}


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


func objets(couche: String) -> Dictionary:
	return ilots if couche == "i" else routes


func base(couche: String, fid: int, champ: String) -> float:
	var o: Dictionary = objets(couche).get(fid, {})
	var v: Variant = o.get(champ)
	return 0.0 if v == null else float(v)


## La valeur d'un champ au mois `t` : la base plus les rampes en cours.
##
## Un champ préfixé `_` n'est pas stocké, il se CALCULE — c'est l'énergie qui
## le sait. La fiche, les calques et le ciblage des décisions passent tous par
## ici, donc tous voient les mêmes nombres. C'est l'interface du toit
## (décision 41) : personne en aval ne sait qui a fabriqué le chiffre.
##
## Les bornes ne sont pas cosmétiques : une part reste une part. Sans elles une
## canopée grimpe au-dessus de 1 et l'indicateur de ville ment. La production,
## elle, n'est jamais bornée : champ calculé, elle ne passe pas par `_borner`
## — une friche peut EXPORTER, et l'écrêter fausserait le total.
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


## La rampe du Classeur §4 : rien pendant le délai, puis la montée, puis le
## plein effet. En continu, parce qu'ici le temps ne saute pas de mois en mois.
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


## La ville au mois 0, comme au chargement : les rampes tombent, les chantiers
## lancés disparaissent et la caisse retrouve sa dotation de départ. Rien n'est
## écrit en base, donc il n'y a rien d'autre à défaire. Ce que ça NE touche
## pas : la géométrie, les nœuds, la caméra — ce fichier ne les connaît pas, et
## le retour au mois 0 n'a rien à leur dire.
func reinitialiser() -> void:
	_solaire.clear()
	_depense_ke = 0.0
	vider_rampes()


## Ce que coûte, en k€, d'amener cet îlot à la part `part` à partir d'où il en
## est au mois `t`. C'est le nombre que la fiche annonce AVANT de valider.
func cout_solaire_ke(fid: int, part: float, t: float) -> float:
	if not ilots.has(fid):
		return 0.0
	return Energie.cout_pose_ke(self, fid,
		valeur("i", fid, "part_toit_equipe", t), clampf(part, 0.0, 1.0))


## Lance la pose vers une cible plus haute, si la caisse suit. Rend `false`
## quand rien n'est lancé — cible trop basse, chantier déjà en cours, ou
## caisse insuffisante. L'interface pré-vérifie et explique ; ici c'est le
## verrou, pas le message.
##
## 🔴 La rampe s'AJOUTE, elle ne remplace rien. Deux raisons, et la seconde est
## la vraie : ① l'avancement déjà visible reste visible ; ② l'histoire de la
## pose n'est jamais réécrite, donc la recette encaissée — qui est l'intégrale
## de cette histoire — reste juste. Une pose engagée ne se révise plus : c'est
## le prix à payer pour ça, et il est honnête (les travaux sont commandés).
func lancer_solaire(fid: int, part: float, t: float) -> bool:
	if not ilots.has(fid) or etat_solaire(fid, t)["en_cours"]:
		return false
	if Energie.toit_equipable_m2(self, fid) <= 0.0:
		return false
	var actuelle := valeur("i", fid, "part_toit_equipe", t)
	var cible := clampf(part, 0.0, 1.0)
	if cible <= actuelle + 0.0001:
		return false

	# ⚠️ Le coût se lit AVANT d'ajouter la rampe : `caisse_ke` intègre les
	# rampes existantes, et la nouvelle n'a encore rien rapporté.
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


## Tout ce dont l'interface a besoin pour distinguer la cible du réalisé.
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

## L'intégrale de `part_toit_equipe` entre le mois 0 et le mois `t`, en
## « part × mois ». C'est elle qui dit combien de temps chaque panneau a
## réellement produit.
##
## 🔴 Exacte, et c'est tout l'intérêt : la caisse doit valoir la même chose que
## la maquette tourne à 5 ou à 500 images par seconde, et l'essai fait sauter
## 1,5 mois d'un coup. Un compteur incrémenté à chaque image ne tiendrait ni
## l'un ni l'autre — et deux parties identiques n'auraient pas le même solde.
func _integrale_part(fid: int, t: float) -> float:
	var s := base("i", fid, "part_toit_equipe") * t
	for r in _rampes["i"].get(fid, []):
		if r["champ"] == "part_toit_equipe":
			s += float(r["ecart"]) * _integrale_avancement(t, r["d"], r["L"], r["M"])
	return s


## ∫ `avancement` de 0 à t : rien, puis un quart de parabole pendant la montée,
## puis une droite. La primitive de la rampe du Classeur §4.
static func _integrale_avancement(t: float, d: float, L: float, M: float) -> float:
	var u := t - d - L
	if u <= 0.0:
		return 0.0
	if M <= 0.0:
		return u
	if u < M:
		return u * u / (2.0 * M)
	return M * 0.5 + (u - M)


## Ce que les panneaux ont rapporté depuis le mois 0, en k€.
##
## ⚠️ Le potentiel est sorti de l'intégrale : rien ne fait bouger la canopée
## dans ce prototype, donc il est constant dans le temps et le raccourci est
## exact. Le jour où une décision plantera des arbres, il faudra le reprendre —
## l'ombrage changerait la production d'un toit déjà posé.
func recette_cumulee_ke(t: float) -> float:
	var ke := 0.0
	for fid in fids_batis():
		var pot := Energie.potentiel_mwh(self, fid, t)
		if pot > 0.0:
			ke += pot * _integrale_part(fid, t) / 12.0 \
				* Energie.PRIX_ENERGIE_EUR_MWH / 1000.0
	return ke


## Ce qu'il y a en caisse au mois `t`, en k€. Fonction PURE du temps et des
## chantiers engagés : aucune accumulation, donc « Recommencer » n'a rien à
## rembobiner et deux parties jouées pareil donnent le même solde.
func caisse_ke(t: float) -> float:
	return CAISSE_DEPART_KE + DOTATION_KE_MOIS * t \
		+ recette_cumulee_ke(t) - _depense_ke


func fids_batis() -> Array:
	var out := []
	for fid in ilots:
		if ilots[fid].get("fonction") != "riviere":
			out.append(fid)
	return out


## Les indicateurs de ville : les quatre nombres de l'énergie (PLAN §3).
##
## Des SOMMES, pas des moyennes — rien à pondérer, la décision 63 est
## satisfaite par construction. Les volumes sont en MWh (c'est sur eux que
## l'invariant achat + production = conso se vérifie).
##
## 🔄 Il y avait ici une `facture` indexée sur t0, qui montait de 2 % par an
## pour que ne rien faire coûte. Elle est partie avec l'arrivée de la caisse :
## deux monnaies à l'écran — une facture qu'on ne paie pas et une caisse qu'on
## paie — se seraient contredites. La facture de ville reste calculable,
## `Energie.facture_ke`, mais elle n'est plus affichée.
##
## ⚠️ Le CO2 est celui de l'énergie ACHETÉE, sans le carbone gris des
## chantiers : le gris vit dans le journal, que la ville ne connaît pas —
## l'interface et l'essai ajoutent `chantiers.co2_gris_an(t)` à cette case.
func indicateurs(t: float) -> Dictionary:
	var m := Energie.ville_mwh(self, t)
	return {
		"conso_mwh": m["conso"],
		"production_mwh": m["production"],
		"achat_mwh": m["achat"],
		"co2_kt": m["achat"] * Energie.CO2_KG_KWH / 1000.0,
		# Les deux nombres de la petite économie. La recette est ce que les
		# panneaux déjà posés rapportent CHAQUE ANNÉE ; la caisse est ce qui
		# reste après les avoir payés.
		"recette_ke_an": m["production"] * Energie.PRIX_ENERGIE_EUR_MWH / 1000.0,
		"caisse_ke": caisse_ke(t),
	}
