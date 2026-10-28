extends RefCounted
# 🗳️ LE BUDGET VOTÉ EN JANVIER (décision 124) : une aide fixe, une prime notée sur
# l'an passé, les règles signées. Aucun impôt (auteur, 2026-10-28 : « trop complexe »).
# Fonctions pures du temps, comme la caisse : la note de l'an N se lit au 1er janvier de N.

const Calendrier := preload("res://scripts/calendrier.gd")

# ==========================================================================
# 🎚️ LEVEL DESIGN — à juger devant la fenêtre
# ==========================================================================
## L'aide fixe : 360 k€, la dotation d'avant la décision 124.
const AIDE_ETAT_KE_AN := 240.0
const PART_VILLE_KE_AN := 120.0
const AIDE_KE_AN := AIDE_ETAT_KE_AN + PART_VILLE_KE_AN
## Chaque point de note vaut tant par an : quatre critères à 5 points = 240 k€ au plus.
const PRIME_KE_POINT := 12.0
const NOTE_MAX := 5
const CRITERES := ["logements", "trafic", "economie", "confiance"]
## 🗳️ Confiance au 1er janvier → note : sous 30 → 1, … , 75 et plus → 5. Le seuil de 60 (123) est le 4.
const CONFIANCE_PALIERS := [30.0, 45.0, 60.0, 75.0]
## 🚗 Trafic : un point de moins par pont encore coupé, un par tranche de 3 rues saturées.
const TRAFIC_RUES_PAR_POINT := 3
## 🏭 LA CONJONCTURE, écrite d'avance (60b : elle ne règle jamais la difficulté).
## [premier an jugé, note, phrase] : la période vaut jusqu'à la suivante. 🔴 Phrases flaggables (90).
const CONJONCTURE := [
	[1, 2, "La fonderie de la vallée réduit ses équipes."],
	[3, 3, "Les commandes reprennent à la fonderie."],
	[6, 4, "Une coopérative de menuiserie s'installe à la zone d'activité."],
	[10, 2, "Le sous-traitant automobile ferme son site de la vallée."],
	[12, 3, "L'atelier de vélos-cargos embauche."],
	[15, 4, "La vallée attire de nouvelles entreprises."],
]


## Le mois du 1er janvier de l'an `an` (l'an 2 commence au mois 10).
static func debut_an(an: int) -> float:
	return float(12 * (an - 1) - Calendrier.MOIS_DEPART)


static func note_economie(an_juge: int) -> Array:
	var out: Array = CONJONCTURE[0]
	for c in CONJONCTURE:
		if an_juge >= int(c[0]):
			out = c
	return [int(out[1]), str(out[2])]


## Le bilan voté au 1er janvier de `an`, sur l'an qui finit. Vide pour l'an 1 (la caisse de départ).
## Chaque critère : {note, ke, …} ; les phrases se font à l'interface, qui connaît les noms des lieux.
static func bilan(ville, an: int) -> Dictionary:
	if an < 2:
		return {}
	var etat: String = ville.cle_etat()
	if etat != ville._bilans_etat:
		ville._bilans.clear()
		ville._bilans_etat = etat
	if ville._bilans.has(an):
		return ville._bilans[an]
	var t := debut_an(an)
	var out := {"an": an, "mois": t}
	# 🏠 Quelqu'un dehors : 1. Tous abrités : 2, puis la part revenue dans un vrai logement
	# jusqu'à 5 — un camp n'en est pas un. Sans ce 2, l'ouverture jouée valait l'ouverture ignorée.
	var depart: float = ville._perdus(0.0)
	var perdus: float = ville._perdus(t)
	var dehors: float = ville.sans_toit(t)
	var part := 1.0 if depart <= 0.0 else 1.0 - perdus / depart
	out["logements"] = {"note": 1 if dehors >= 0.5 else clampi(2 + int(floor(part * 3.0 + 0.001)), 2, NOTE_MAX),
		"dehors": int(roundf(dehors)), "au_camp": int(roundf(perdus - dehors))}
	var coupes := []
	for p in ville.ponts_coupes():
		if not ville.route_praticable(p, t):
			coupes.append(p)
	var saturees := []
	for fid in ville.routes:
		if ville.trafic_vu(fid, t) >= 1.0:
			saturees.append(fid)
	saturees.sort_custom(func(a, b) -> bool: return ville.trafic_vu(a, t) > ville.trafic_vu(b, t))
	out["trafic"] = {"note": clampi(NOTE_MAX - coupes.size()
		- int(ceil(saturees.size() / float(TRAFIC_RUES_PAR_POINT))), 1, NOTE_MAX),
		"coupes": coupes, "saturees": saturees}
	var eco := note_economie(an - 1)
	out["economie"] = {"note": eco[0], "phrase": eco[1]}
	var k: float = ville.capital(t)
	var n := 1
	for s in CONFIANCE_PALIERS:
		if k >= s:
			n += 1
	# Le mouvement qui a le plus pesé dans l'année, et l'usure du camp s'il pèse plus.
	var marquant := {}
	for m in ville.capital_mouvements():
		var mm := float(m["mois"])
		if mm > t:
			break
		if mm > t - 12.0 and (marquant.is_empty() or absf(float(m["montant"])) > absf(float(marquant["montant"]))):
			marquant = m
	var usure: float = ville.usure_camp_cumulee(t) - ville.usure_camp_cumulee(maxf(t - 12.0, 0.0))
	if usure > 0.5 and (marquant.is_empty() or usure > absf(float(marquant["montant"]))):
		marquant = {"quoi": "usure", "montant": -usure}
	out["confiance"] = {"note": n, "valeur": k, "marquant": marquant}
	var points := 0
	for c in CRITERES:
		out[c]["ke"] = out[c]["note"] * PRIME_KE_POINT
		points += int(out[c]["note"])
	out["prime_ke"] = points * PRIME_KE_POINT
	ville._bilans[an] = out
	return out


static func prime_ke_an(ville, an: int) -> float:
	return float(bilan(ville, an).get("prime_ke", 0.0))


## Versée chaque mois de l'an voté, au fil du temps comme le stationnement.
static func prime_mensuelle_ke(ville, t: float) -> float:
	return prime_ke_an(ville, Calendrier.an(t)) / 12.0


static func prime_cumulee_ke(ville, t: float) -> float:
	var ke := 0.0
	for an in range(2, Calendrier.an(t) + 1):
		ke += prime_ke_an(ville, an) * clampf((t - debut_an(an)) / 12.0, 0.0, 1.0)
	return ke
