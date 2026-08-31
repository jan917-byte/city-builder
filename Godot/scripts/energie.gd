extends RefCounted
# L'énergie de Wehrau : la table des quatorze tissus et les formules qui en sortent.
#
# ⚠️ Tout est statique, la ville arrive en paramètre `v` : un preload croisé avec
# `ville.gd` casse au chargement, et un cycle RefCounted fuirait.
# Aucun nœud, aucune couleur, aucun signal. Tout se dérive d'attributs existants
# (décision 56) ; `toit_m2` et `canopee` sont lus sans savoir qui les fabrique
# (décisions 41 · 64 · 64b).

# ==========================================================================
# LA TABLE — 🎚️ c'est ici que l'auteur règle le jeu, pas dans les formules
# ==========================================================================
#   mwh_log  : conso d'un logement, chauffage compris (MWh/an).
#   mwh_emp  : conso d'un emploi, sur les tissus tertiaires SEULEMENT — compter
#              aussi le cœur ancien et le front donnait 56,8 GWh au lieu de 51.
#   batie    : part réellement bâtie. Documentaire : déjà dans `toit_m2`.
#              Repli si le toit redevenait une estimation.
#   equip    : part du toit équipable — c'est elle qui fait le gisement.
#   cout_x   : coût relatif du m² posé (accès, échafaudage, patrimoine).
#   rdt_x    : rendement relatif (orientation moyenne, masques).
#   gain_iso : ce que l'isolation enlève à la conso. 0 = décision indisponible.
#   cout_iso : coût relatif de l'isolation.
#   cap_sol  : capital politique d'un chantier solaire, par îlot.
const ENERGIE := {
	#                      mwh_log mwh_emp batie  equip  cout_x rdt_x  gain_iso cout_iso cap_sol
	"coeur_ancien":       [   21.0,   0.0,  0.70,  0.15,   1.8,  0.75,   0.20,    1.6,  -3.0],
	"front_commercant":   [   18.0,   0.0,  0.80,  0.25,   1.4,  0.90,   0.25,    1.3,  -3.0],
	"maisons_de_ville":   [   17.0,   0.0,  0.55,  0.30,   1.3,  0.95,   0.35,    1.0,  -1.0],
	"pavillonnaire":      [   22.0,   0.0,  0.20,  0.40,   1.2,  1.00,   0.40,    1.5,  -1.0],
	"barre_1970":         [   24.0,   0.0,  0.20,  0.70,   0.8,  1.10,   0.45,    0.7,  -1.0],
	# De grands pans de tuile simples : le 2e gisement de la ville après la barre,
	# et sans argument patrimonial en face. 🔴 cap_sol −2 : c'est le logement le
	# plus récent et le mieux loti, donc celui qui se plaint de l'échafaudage.
	"collectif_1995":     [   16.0,   0.0,  0.25,  0.60,   0.9,  1.05,   0.30,    0.9,  -2.0],
	# Le MWh le moins cher de Wehrau, et il n'y en a presque pas à prendre :
	# toit plat, aucune opposition (cap_sol 0), mais une conso déjà basse.
	# `gain_iso` 0 = décision d'isolation INDISPONIBLE — il n'y a rien à isoler.
	"ilot_compact":       [   11.0,   0.0,  0.33,  0.75,   0.7,  1.15,   0.00,    0.0,   0.0],
	"equipement":         [    0.0,   9.0,  0.40,  0.55,   0.9,  1.05,   0.00,    0.0,  -1.0],
	"friche_industrielle":[    0.0,   9.0,  0.45,  0.65,   0.8,  1.00,   0.00,    0.0,  -1.0],
	"place_minerale":     [    0.0,   0.0,  0.00,  0.00,   0.0,  0.00,   0.00,    0.0,   0.0],
	"parc":               [    0.0,   0.0,  0.00,  0.00,   0.0,  0.00,   0.00,    0.0,   0.0],
	"jardins_familiaux":  [    0.0,   0.0,  0.00,  0.00,   0.0,  0.00,   0.00,    0.0,   0.0],
	"champ":              [    0.0,   0.0,  0.00,  0.00,   0.0,  0.00,   0.00,    0.0,   0.0],
	"riviere":            [    0.0,   0.0,  0.00,  0.00,   0.0,  0.00,   0.00,    0.0,   0.0],
}

const _COLS := ["mwh_log", "mwh_emp", "batie", "equip", "cout_x", "rdt_x",
	"gain_iso", "cout_iso", "cap_sol"]

const RENDEMENT_KWH_M2_AN := 140.0    # Allemagne du sud-ouest, pertes comprises
const OMBRAGE_CANOPEE := 0.4          # rendement × (1 − 0,4 × canopée)
const CO2_KG_KWH := 0.25              # mix + chauffage — vaut aussi t/MWh
const CO2_GRIS_PANNEAU_KG_M2 := 120.0     # payé en une fois, au chantier
const CO2_GRIS_ISOLATION_KG_LOG := 4000.0 # modeste : remboursé en ~2 ans

# ==========================================================================
# LA PETITE ÉCONOMIE — deux prix, et rien d'autre (2026-08-17)
# ==========================================================================
# Coût, recette, donc durée d'amortissement. Aucun taux, aucune subvention.
# 🔴 En euros, plus en « points » : 260 € le m² se discute avec quelqu'un qui a
# déjà fait poser des panneaux.
const COUT_PANNEAU_EUR_M2 := 260.0    # panneau + structure + pose sur toiture existante
const PRIX_ENERGIE_EUR_MWH := 150.0   # ce que vaut le MWh produit plutôt qu'acheté

# ⏸️ Ancienne économie en points (PLAN §5, §6 bis b), hors boucle jouable depuis
# le 2026-08-17 ; seuls `chantiers.gd` et `outils/essai_energie.gd` la lisent.
# ⚠️ Ne pas rebrancher les dérives : composées, elles rongeaient l'amortissement
# de ~7,8 %/an, donc ATTENDRE était toujours le bon coup.
const PANNEAU_M2_PAR_POINT := 120.0   # 1 point de budget pose 120 m²
const RETOUR_PTS_PAR_GWH_AN := 6.0    # 6 points par an et par GWh produit
const DERIVE_COUT_PANNEAU_AN := 0.94  # le panneau coûte −6 % par an
const DERIVE_PRIX_ENERGIE_AN := 1.02  # l'énergie achetée coûte +2 % par an

# Les quatre classes du calque : vite · dans la partie · tout juste · jamais.
# Aucun chiffre sur la carte (décision 60). Vraies années depuis le passage à
# l'euro (barre de 1974 ~9 ans, cœur ancien ~30) ; se relisent sur `-- --essai`.
const CLASSES_ANNEES := [10.0, 17.0, 24.0]


static func ligne(v, fid: int) -> Dictionary:
	var st: String = str(v.ilots.get(fid, {}).get("sous_type", ""))
	var brute: Array = ENERGIE.get(st, [])
	var d := {}
	for i in _COLS.size():
		d[_COLS[i]] = float(brute[i]) if i < brute.size() else 0.0
	return d


## Un facteur annuel appliqué à un temps en mois : 0,94^(t/12).
static func derive_an(annuel: float, t: float) -> float:
	return pow(annuel, t / 12.0)


# ------------------------------------------------------------------ le toit

## `toit_m2` est la surface RÉELLE du toit, pente comprise : pas de part bâtie
## ici. Un îlot sans toit rend 0.
static func toit_equipable_m2(v, fid: int) -> float:
	if v.base("i", fid, "solaire_possible") <= 0.0:
		return 0.0
	return v.base("i", fid, "toit_m2") * ligne(v, fid)["equip"]


## Le toit entièrement équipé, en MWh/an. L'ombrage de la canopée s'applique
## ici : l'antagonisme arbre/panneau.
static func potentiel_mwh(v, fid: int, t: float) -> float:
	var l := ligne(v, fid)
	var ombrage: float = 1.0 - OMBRAGE_CANOPEE * v.valeur("i", fid, "canopee", t)
	return toit_equipable_m2(v, fid) * RENDEMENT_KWH_M2_AN / 1000.0 \
		* l["rdt_x"] * ombrage


## ⚠️ Jamais bornée à la consommation : une friche peut exporter
## (PLAN §3, le piège du bornage).
static func production_mwh(v, fid: int, t: float) -> float:
	return potentiel_mwh(v, fid, t) * v.valeur("i", fid, "part_toit_equipe", t)


# ---------------------------------------------------------- la consommation

## Isolation déduite.
static func conso_mwh(v, fid: int, t: float) -> float:
	var l := ligne(v, fid)
	var iso: float = v.valeur("i", fid, "part_isolee", t)
	return v.valeur("i", fid, "logements", t) * l["mwh_log"] \
		* (1.0 - l["gain_iso"] * iso) \
		+ v.base("i", fid, "emplois") * l["mwh_emp"]


## Ce que l'isolation peut ENCORE enlever, en MWh/an — le calque du gain.
static func gain_isolation_mwh(v, fid: int, t: float) -> float:
	var l := ligne(v, fid)
	return v.valeur("i", fid, "logements", t) * l["mwh_log"] * l["gain_iso"] \
		* (1.0 - v.valeur("i", fid, "part_isolee", t))


# ------------------------------------------------------- coût et amortissement

## En k€. `cout_x` fait qu'un toit de cœur ancien coûte plus du double d'un
## toit de barre au m².
static func cout_pose_ke(v, fid: int, de: float, vers: float) -> float:
	return toit_equipable_m2(v, fid) * maxf(vers - de, 0.0) \
		* COUT_PANNEAU_EUR_M2 * ligne(v, fid)["cout_x"] / 1000.0


## Les panneaux DÉJÀ posés, en k€/an.
static func recette_ke_an(v, fid: int, t: float) -> float:
	return production_mwh(v, fid, t) * PRIX_ENERGIE_EUR_MWH / 1000.0


## ⚠️ Ne dépend PAS de la part équipée — coût et recette sont tous deux
## proportionnels aux m² posés. C'est un critère de CHOIX D'ÎLOT, pas de dosage.
## INF sans toit : à ne jamais peindre ni afficher tel quel.
static func rentabilite_annees(v, fid: int, t: float) -> float:
	var pot := potentiel_mwh(v, fid, t)
	if pot <= 0.0:
		return INF
	return cout_pose_ke(v, fid, 0.0, 1.0) / (pot * PRIX_ENERGIE_EUR_MWH / 1000.0)


## 0 vite · 1 dans la partie · 2 tout juste · 3 jamais.
static func classe_rentabilite(v, fid: int, t: float) -> int:
	var annees := rentabilite_annees(v, fid, t)
	for i in CLASSES_ANNEES.size():
		if annees < CLASSES_ANNEES[i]:
			return i
	return CLASSES_ANNEES.size()


# ------------------------------------------------------------------ la ville

## En MWh/an. Achat = conso − production, pas un troisième chiffre (PLAN §3).
## Des sommes, pas des moyennes (décision 63).
##
## 🌳 LE SEUL TERME QUI NE VIENT PAS D'UN ÎLOT : l'ombre des arbres plantés le
## long des rues, retranchée à la consommation. Compté DEPUIS LE MOIS 0 par le
## noyau, donc nul au chargement — la ville de départ garde ses chiffres.
static func ville_mwh(v, t: float) -> Dictionary:
	var conso := 0.0
	var prod := 0.0
	for fid in v.fids_batis():
		conso += conso_mwh(v, fid, t)
		prod += production_mwh(v, fid, t)
	conso = maxf(conso - v.economie_plantation_mwh(t), 0.0)
	return {"conso": conso, "production": prod, "achat": conso - prod}


## En k€/an. 🔴 Ne passe PAS par la caisse municipale : la facture est payée par
## les OCCUPANTS. Sinon la mairie paierait 7,7 M€/an avec 0,36 M€ de dotation,
## donc un jeu sans décision. La ville est propriétaire-bailleur (décision 70) :
## elle possède murs et toits, ses locataires paient leur électricité.
static func facture_ke(v, t: float) -> float:
	return ville_mwh(v, t)["achat"] * PRIX_ENERGIE_EUR_MWH / 1000.0


## En kt/an, SANS le carbone gris des chantiers — lui vit dans le journal,
## que la ville ne connaît pas (`chantiers.co2_gris_an`).
static func co2_achat_kt(v, t: float) -> float:
	return ville_mwh(v, t)["achat"] * CO2_KG_KWH / 1000.0


# ------------------------------------------------- les champs dérivés (`_`)

## `ville.valeur` délègue ici tous les noms préfixés `_`.
## Un champ inconnu rend 0, comme un champ absent.
static func derive(v, fid: int, champ: String, t: float) -> float:
	match champ:
		"_toit_equipable_m2":
			return toit_equipable_m2(v, fid)
		"_potentiel_gwh":
			return potentiel_mwh(v, fid, t) / 1000.0
		"_production_mwh":
			return production_mwh(v, fid, t)
		"_conso_mwh":
			return conso_mwh(v, fid, t)
		"_gain_isolation_mwh":
			return gain_isolation_mwh(v, fid, t)
		"_classe_solaire":
			return float(classe_rentabilite(v, fid, t))
		"_rentabilite_annees":
			return rentabilite_annees(v, fid, t)
		"_recette_ke_an":
			return recette_ke_an(v, fid, t)
		# Le toit EN ENTIER : de quoi comparer deux îlots avant tout curseur.
		"_cout_total_ke":
			return cout_pose_ke(v, fid, 0.0, 1.0)
		# Lus par NOM DE CHAMP par les chantiers, qui ignorent qu'ils parlent
		# d'énergie — c'est ce qui les garde génériques (décision 64).
		"_cout_x_solaire":
			return ligne(v, fid)["cout_x"]
		"_cout_x_isolation":
			return ligne(v, fid)["cout_iso"]
		"_capital_solaire":
			return ligne(v, fid)["cap_sol"]
	return 0.0
