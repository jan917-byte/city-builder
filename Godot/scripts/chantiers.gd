extends RefCounted
# Les décisions, et les chantiers qu'on en lance.
#
# Une seule décision pour l'instant — D07, reprise ligne à ligne de
# `Classeur/decisions.csv` et `Classeur/effets.csv`. Le circuit complet doit
# marcher avant qu'on en ajoute une deuxième.
#
# Ce qui structure le jeu, et qu'il ne faut pas perdre en route
# (`Classeur/README.md` §4) :
#   · le BUDGET se paie ÉTALÉ sur délai + montée
#   · le CAPITAL politique se paie EN ENTIER au mois où on décide
# On encaisse le coût politique tout de suite et on récolte huit ans plus tard.
# Si cette asymétrie disparaît, il n'y a plus de jeu, il y a une liste de
# courses.

const Ville := preload("res://scripts/ville.gd")

const DECISIONS := {
	"D07": {
		"nom": "Planter l'alignement",
		"resume": "On plante les deux rives de la rue. L'arbre met cinq ans à"
			+ " faire de l'ombre : c'est la décision dont on ne voit rien"
			+ " avant la fin du mandat.",
		"couche": "r",
		"champ_cible": "emprise_libre_m",   # cible : emprise_libre_m > S
		"seuil_defaut": 6.0,
		"seuil_min": 2.0,
		"seuil_max": 11.0,
		"libelle_seuil": "emprise libre au-delà de",
		"unite_seuil": " m",
		"cout_base": 3.0,          # par CHANTIER, pas par tronçon
		"cout_unitaire": 1.8,      # par 100 m linéaires
		"capital_base": -1.0,
		"capital_unitaire": 0.0,
		"delai": 3.0,
		"montee": 60.0,
		"effets": [
			{"portee": "cible", "couche": "r", "champ": "canopee", "valeur": 0.25},
			{"portee": "riverains", "couche": "i", "champ": "canopee", "valeur": 0.10},
			{"portee": "cible", "couche": "r", "champ": "emprise_libre_m", "valeur": -1.5},
		],
	},
}

var ville: Ville
var journal := []           # [{id, mois, fids, quantite, cout, capital}]
var _engages := {}          # "r:55" -> true


func _init(v: Ville) -> void:
	ville = v


# ------------------------------------------------------------------ la cible

func engage(couche: String, fid: int) -> bool:
	return _engages.has("%s:%d" % [couche, fid])


## Les objets qu'une décision attrape à ce seuil. On évalue sur l'état COURANT,
## pas sur t0 : c'est ce qui fait qu'une décision peut en ouvrir une autre en
## libérant des mètres. Sans ça, D06 n'aurait aucun sens.
func eligibles(id: String, seuil: float, t: float) -> Array:
	var D: Dictionary = DECISIONS[id]
	var couche: String = D["couche"]
	var out := []
	for fid in ville.objets(couche):
		if engage(couche, fid):
			continue
		if ville.valeur(couche, fid, D["champ_cible"], t) > seuil:
			out.append(fid)
	out.sort()
	return out


## `_t` n'est pas encore lu : la longueur d'un tronçon ne bouge pas. Il reste
## dans la signature parce que la prochaine décision comptera des LOGEMENTS,
## et ceux-là changent avec le temps.
func devis(id: String, fids: Array, _t: float) -> Dictionary:
	var D: Dictionary = DECISIONS[id]
	var couche: String = D["couche"]
	var q := 0.0
	for fid in fids:
		# L'unité de D07 est le 100 ml. Une décision d'îlot compterait des
		# logements — c'est là que ça se branchera.
		q += ville.base(couche, fid, "longueur_m") / 100.0
	return {
		"quantite": q,
		"cout": float(D["cout_base"]) + float(D["cout_unitaire"]) * q,
		"capital": float(D["capital_base"]) + float(D["capital_unitaire"]) * q,
	}


# ----------------------------------------------------------------- le budget

## Ce qui a été versé au mois `t`.
##
## Le `+ 1` n'est pas cosmétique : `08_jouer.py` paie sur les mois `d` à
## `d + étale − 1` INCLUS, donc une première mensualité tombe au moment même où
## on décide. Sans lui les deux moteurs décalent d'un mois et le recoupement
## sort 397 d'un côté, 399 de l'autre — assez peu pour qu'on l'ignore, ce qui
## est exactement le danger.
func paye(t: float) -> float:
	var total := 0.0
	for c in journal:
		var etale: float = maxf(1.0, float(c["L"]) + float(c["M"]))
		total += float(c["cout"]) \
			* clampf((t - float(c["mois"]) + 1.0) / etale, 0.0, 1.0)
	return total


func solde(t: float) -> float:
	return Ville.BUDGET_MENSUEL * (t + 1.0) - paye(t)


func capital(t: float) -> float:
	var k := Ville.CAPITAL_DEPART
	for c in journal:
		if float(c["mois"]) <= t:
			k += float(c["capital"])
	return k


## Pourquoi on ne peut pas, ou "" si on peut.
##
## Le budget se vérifie sur TOUTE la durée du chantier, pas seulement au mois
## où on décide : un chantier de 60 mois engage 60 mois de budget, et le dire
## après coup ne servirait à rien.
func refus(id: String, fids: Array, t: float) -> String:
	if fids.is_empty():
		return "Aucune cible à ce seuil."
	var D: Dictionary = DECISIONS[id]
	var d := devis(id, fids, t)
	var cout: float = d["cout"]
	var etale: float = maxf(1.0, float(D["delai"]) + float(D["montee"]))
	var m := t
	while m <= Ville.HORIZON_MOIS:
		var futur: float = cout * clampf((m - t) / etale, 0.0, 1.0)
		if solde(m) - futur < -0.01:
			return "Budget insuffisant : %.0f pts feraient passer le solde sous zéro." % cout
		m += 1.0
	return ""


# ---------------------------------------------------------------- engager

func engager(id: String, fids: Array, t: float) -> Dictionary:
	var pourquoi := refus(id, fids, t)
	if pourquoi != "":
		return {"ok": false, "message": pourquoi}

	var D: Dictionary = DECISIONS[id]
	var couche: String = D["couche"]
	var d := devis(id, fids, t)
	var L: float = D["delai"]
	var M: float = D["montee"]

	for fid in fids:
		_engages["%s:%d" % [couche, fid]] = true

	for e in D["effets"]:
		var cibles := _portee(e["portee"], couche, fids)
		for f in cibles:
			ville.ajouter_rampe(e["couche"], f, e["champ"],
				float(e["valeur"]), t, L, M)

	journal.append({
		"id": id, "mois": t, "fids": fids.duplicate(),
		"quantite": d["quantite"], "cout": d["cout"], "capital": d["capital"],
		"L": L, "M": M,
	})
	return {"ok": true, "cout": d["cout"], "capital": d["capital"],
		"quantite": d["quantite"]}


## Qui reçoit l'effet.
##
## `riverains` est le lien tronçon → îlots que 07 exporte, construit
## géométriquement (178/178, zéro orphelin). Il n'est dans aucune table du
## GeoPackage : `adjacences` est îlot↔îlot. Sans lui, planter une rue ne
## verdirait rien autour d'elle.
func _portee(portee: String, _couche_dec: String, fids: Array) -> Array:
	match portee:
		"cible":
			return fids
		"riverains":
			var vus := {}
			for f in fids:
				for i in ville.riverains.get(f, []):
					vus[i] = true
			return vus.keys()
	push_error("portée inconnue : %s" % portee)
	return []
