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
const BUDGET_MENSUEL := 100.0 / 12.0       # 100 pts par an — Classeur §2
const CAPITAL_DEPART := 50.0               # décision 16b

var ilots := {}            # fid:int -> {champ: float|String}
var routes := {}
var riverains := {}        # fid tronçon -> [fid îlot]
var _rampes := {"i": {}, "r": {}}   # couche -> fid -> [rampe]

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
## — la friche et la dalle EXPORTENT, et l'écrêter fausserait le total.
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
## l'invariant achat + production = conso se vérifie) ; la facture est le
## volume × le prix qui monte de 2 % par an — c'est elle que le bandeau
## affiche, indexée sur t0, parce que ne rien faire doit coûter.
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
		"facture": m["achat"] * Energie.derive_an(Energie.DERIVE_PRIX_ENERGIE_AN, t),
		"co2_kt": m["achat"] * Energie.CO2_KG_KWH / 1000.0,
	}
