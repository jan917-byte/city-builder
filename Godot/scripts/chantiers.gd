extends RefCounted
# Les décisions, et les chantiers qu'on en lance.
#
# Deux décisions de NATURE OPPOSÉE (PLAN §5 bis) : les panneaux achètent de
# l'argent, l'isolation de la légitimité. N'en jouer qu'une ne marche pas.
#
# La machinerie ne parle d'aucun thème : elle lit des clés et des noms de
# champs (décision 64, « le prototype énergie est le gabarit »).
#
# 🔴 L'ASYMÉTRIE, à ne pas perdre en route (`Classeur/README.md`) : le
# BUDGET se paie étalé sur délai + travaux, le CAPITAL en entier au mois de la
# décision, le RETOUR n'arrive qu'à la fin des travaux au tarif du jour. Sans
# elle, il n'y a plus de jeu.
#
# ⏱️ TROIS durées, pas deux (PLAN §6 ter) : délai · travaux · montée. Un
# chantier fini n'est plus un chantier même si son effet monte encore. Ici
# travaux = montée ; D07 (archivée) ferait 3 · 2 · 58.

const Ville := preload("res://scripts/ville.gd")
const Energie := preload("res://scripts/energie.gd")

const DECISIONS := {
	"PAN": {
		"nom": "Poser des panneaux",
		"resume": "Rentable sur les grands toits plats. Jamais dans le cœur ancien.",
		"couche": "i",
		"champ_cible": "_toit_equipable_m2",
		"seuil_defaut": 500.0, "seuil_min": 0.0, "seuil_max": 5000.0,
		"libelle_seuil": "toit équipable au-delà de", "unite_seuil": " m²",
		"delai": 6.0, "travaux": 6.0, "montee": 6.0,
		# 1 point pose 120 m², × le coût du tissu, × le prix qui fond.
		"quantite_champ": "_toit_equipable_m2",
		"quantite_par": Energie.PANNEAU_M2_PAR_POINT,
		"unite_quantite": "× 120 m² de panneaux",
		"cout_base": 0.0, "cout_unitaire": 1.0,
		"cout_x_champ": "_cout_x_solaire",
		"cout_derive_an": Energie.DERIVE_COUT_PANNEAU_AN,
		# Le capital se paie PAR ÎLOT : -1, et -3 là où le patrimoine proteste.
		"capital_base": 0.0, "capital_unitaire": 0.0,
		"capital_cible_champ": "_capital_solaire",
		# Au tarif du jour de la décision.
		"retour_champ": "_potentiel_gwh",
		"retour_unitaire": Energie.RETOUR_PTS_PAR_GWH_AN,
		"retour_derive_an": Energie.DERIVE_PRIX_ENERGIE_AN,
		"co2_gris_par_quantite": 14400.0,   # 120 kg/m² × 120 m² par unité
		"effets": [
			{"portee": "cible", "couche": "i",
				"champ": "part_toit_equipe", "valeur": 1.0},
		],
	},
	"ISO": {
		"nom": "Isoler les logements",
		"resume": "Jamais rentable, et c'est un fait du métier. La facture tombe, la légitimité monte.",
		"couche": "i",
		"champ_cible": "logements",
		"seuil_defaut": 20.0, "seuil_min": 0.0, "seuil_max": 200.0,
		"libelle_seuil": "îlots de plus de", "unite_seuil": " logements",
		# 9 mois d'études ET de concertation : des gens habitent là.
		"delai": 9.0, "travaux": 18.0, "montee": 18.0,
		# 1 point par logement, × le coût du tissu. Pas de dérive : un
		# échafaudage ne devient pas moins cher tout seul.
		"quantite_champ": "logements", "quantite_par": 1.0,
		"unite_quantite": "logements",
		"cout_base": 0.0, "cout_unitaire": 1.0,
		"cout_x_champ": "_cout_x_isolation",
		"cout_derive_an": 1.0,
		# L'isolation REND du capital, et ne rapporte jamais d'argent.
		"capital_base": 3.0, "capital_unitaire": 1.0 / 30.0,
		"co2_gris_par_quantite": Energie.CO2_GRIS_ISOLATION_KG_LOG,
		"effets": [
			{"portee": "cible", "couche": "i",
				"champ": "part_isolee", "valeur": 1.0},
		],
	},
}

var ville: Ville
var journal := []   # [{id, mois, fids, quantite, cout, capital, L, T, M,
					#   fin_travaux, retour_mensuel, co2_gris_kg}]
var _engages := {}  # PAR DÉCISION : équiper un îlot n'interdit pas de l'isoler.


func _init(v: Ville) -> void:
	ville = v


# ------------------------------------------------------------------ la cible

func engage(id: String, couche: String, fid: int) -> bool:
	return _engages.has("%s|%s:%d" % [id, couche, fid])


## Évalué sur l'état COURANT, pas sur t0 : c'est ce qui permet à une décision
## d'en ouvrir une autre.
func eligibles(id: String, seuil: float, t: float) -> Array:
	var D: Dictionary = DECISIONS[id]
	var couche: String = D["couche"]
	var out := []
	for fid in ville.objets(couche):
		if engage(id, couche, fid):
			continue
		if ville.valeur(couche, fid, D["champ_cible"], t) > seuil:
			out.append(fid)
	out.sort()
	return out


## ÎLOT PAR ÎLOT : coût et capital dépendent du tissu de chaque cible, pas
## d'une quantité globale. Retour et carbone gris sont figés au mois `t`.
func devis(id: String, fids: Array, t: float) -> Dictionary:
	var D: Dictionary = DECISIONS[id]
	var couche: String = D["couche"]
	var q := 0.0
	var cout: float = D["cout_base"]
	var cap: float = D["capital_base"]
	var retour_an := 0.0
	for fid in fids:
		var q_fid: float = ville.valeur(couche, fid, D["quantite_champ"], t) \
			/ float(D["quantite_par"])
		var x := 1.0
		if D.has("cout_x_champ"):
			x = ville.valeur(couche, fid, D["cout_x_champ"], t)
		q += q_fid
		cout += float(D["cout_unitaire"]) * q_fid * x
		cap += float(D["capital_unitaire"]) * q_fid
		if D.has("capital_cible_champ"):
			cap += ville.valeur(couche, fid, D["capital_cible_champ"], t)
		if D.has("retour_champ"):
			retour_an += ville.valeur(couche, fid, D["retour_champ"], t) \
				* float(D["retour_unitaire"])
	# Coût qui fond, tarif qui monte, tous deux FIGÉS au mois de la décision :
	# c'est ce qui rend le remboursement exact, et un tarif d'achat se signe.
	cout *= Energie.derive_an(float(D.get("cout_derive_an", 1.0)), t)
	retour_an *= Energie.derive_an(float(D.get("retour_derive_an", 1.0)), t)
	return {
		"quantite": q,
		"cout": cout,
		"capital": cap,
		"retour_mensuel": retour_an / 12.0,
		"co2_gris_kg": q * float(D.get("co2_gris_par_quantite", 0.0)),
	}


# ----------------------------------------------------------------- le budget

## L'étalement court sur délai + TRAVAUX : on paie l'entreprise, pas la
## maturation de l'effet.
## ⚠️ Le `+ 1` n'est pas cosmétique — `08_jouer.py` paie de `d` à `d + étale − 1`
## INCLUS. Sans lui les deux moteurs sortent 397 et 399, l'écart qu'on ignore.
func paye(t: float) -> float:
	var total := 0.0
	for c in journal:
		var etale: float = maxf(1.0, float(c["L"]) + float(c["T"]))
		total += float(c["cout"]) \
			* clampf((t - float(c["mois"]) + 1.0) / etale, 0.0, 1.0)
	return total


## Tarif figé au journal, donc rien n'est recalculé — et le chantier en cours
## d'évaluation n'y est pas encore, donc il ne peut pas se financer lui-même
## (défaut mesuré en session 10).
func retours(t: float) -> float:
	var total := 0.0
	for c in journal:
		var depuis: float = t - float(c["fin_travaux"]) + 1.0
		if depuis > 0.0:
			total += float(c["retour_mensuel"]) * depuis
	return total


func solde(t: float) -> float:
	return Ville.BUDGET_MENSUEL * (t + 1.0) - paye(t) + retours(t)


func capital(t: float) -> float:
	var k := Ville.CAPITAL_DEPART
	for c in journal:
		if float(c["mois"]) <= t:
			k += float(c["capital"])
	return k


## Chantiers EN COURS, en kt/an, étalé sur la fenêtre de travaux : la courbe
## monte d'abord puis redescend plus bas. Si elle descend tout de suite, le
## gris n'est pas branché (PLAN §8.8).
func co2_gris_an(t: float) -> float:
	var total := 0.0
	for c in journal:
		var debut: float = float(c["mois"]) + float(c["L"])
		var fin: float = float(c["fin_travaux"])
		if t >= debut and t < fin:
			total += float(c["co2_gris_kg"]) / 1e6 \
				/ maxf(float(c["T"]) / 12.0, 1.0 / 12.0)
	return total


## Pourquoi on ne peut pas, ou "" si on peut.
##
## Le CAPITAL se vérifie au mois de la décision, et seulement quand le devis en
## coûte : un chantier qui en rend ne doit jamais être refusé pour ça.
## Le BUDGET se vérifie sur TOUTE la durée : un chantier de 24 mois engage
## 24 mois de budget. Les retours des chantiers déjà engagés comptent (ils sont
## dans `solde`) ; celui du candidat, non.
func refus(id: String, fids: Array, t: float) -> String:
	if fids.is_empty():
		return "Aucune cible à ce seuil."
	var D: Dictionary = DECISIONS[id]
	var d := devis(id, fids, t)
	var cout: float = d["cout"]
	if d["capital"] < 0.0 and capital(t) + d["capital"] < 0.0:
		return "Capital politique insuffisant : il en faudrait %.0f, il en reste %.0f." \
			% [-d["capital"], capital(t)]
	var etale: float = maxf(1.0, float(D["delai"]) + float(D["travaux"]))
	var m := t
	while m <= Ville.HORIZON_MOIS:
		var futur: float = cout * clampf((m - t + 1.0) / etale, 0.0, 1.0)
		if solde(m) - futur < -0.01:
			return "Budget insuffisant : %.0f pts feraient passer le solde sous zéro." % cout
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
	var T: float = D["travaux"]
	var M: float = D["montee"]

	for fid in fids:
		_engages["%s|%s:%d" % [id, couche, fid]] = true

	for e in D["effets"]:
		var cibles := _portee(e["portee"], couche, fids)
		for f in cibles:
			ville.ajouter_rampe(e["couche"], f, e["champ"],
				float(e["valeur"]), t, L, M)

	journal.append({
		"id": id, "mois": t, "fids": fids.duplicate(),
		"quantite": d["quantite"], "cout": d["cout"], "capital": d["capital"],
		"L": L, "T": T, "M": M,
		"fin_travaux": t + L + T,
		"retour_mensuel": d["retour_mensuel"],
		"co2_gris_kg": d["co2_gris_kg"],
	})
	return {"ok": true, "cout": d["cout"], "capital": d["capital"],
		"quantite": d["quantite"]}


## Qui reçoit l'effet. `riverains` est le lien tronçon → îlots exporté par 07
## (178/178, zéro orphelin) ; il n'est dans aucune table du GeoPackage, où
## `adjacences` est îlot↔îlot.
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
