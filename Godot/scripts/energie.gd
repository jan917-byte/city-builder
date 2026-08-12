extends RefCounted
# L'énergie de Wehrau : la table des treize lignes, et les formules qui en sortent.
#
# TOUT EST STATIQUE, et c'est structurel : `ville.gd` précharge ce fichier, donc
# ce fichier ne doit rien savoir de `ville.gd` (un preload croisé casse au
# chargement, et un couple de références RefCounted fuirait — Godot ne collecte
# pas les cycles). La ville arrive toujours en paramètre `v`, jamais en membre.
#
# Même discipline que le reste du noyau : aucun nœud, aucune couleur, aucun
# signal. Une formule sur des attributs existants n'est pas une sous-simulation
# (décision 56) : tout se dérive de `logements`, `emplois`, `toit_m2`, `canopee`.
#
# 🔗 L'interface du toit (décisions 41 · 64) : ce fichier lit `toit_m2` et
# `canopee` (l'ombrage) sans savoir qui les a fabriqués. Aujourd'hui c'est le
# générateur de `07_exporter_godot.py` ; si un jour c'est autre chose, rien ici
# ne bouge. L'énergie n'attend jamais la 3D (64b).

# ==========================================================================
# LE DESIGN — la table de correspondance, 13 lignes
# ==========================================================================
# Même forme que `TISSU` dans `04_deriver_attributs.py` : une ligne par
# `sous_type`, et c'est ici que l'auteur règle le jeu, pas dans les formules.
#
#   mwh_log   : consommation d'un logement, chauffage COMPRIS (MWh/an).
#               24 pour le béton de 1974 sans isolant, 17 pour le mitoyen.
#   mwh_emp   : consommation d'un emploi. 9 sur les trois tissus tertiaires
#               SEULEMENT — les emplois du cœur ancien et du front commerçant
#               sont réputés compris dans le MWh/logement du tissu mixte.
#               (Les compter à part donnerait 56,8 GWh et casserait les 51.)
#   batie     : part de l'emprise réellement bâtie. DOCUMENTAIRE depuis que
#               `toit_m2` est un vrai toit : elle est déjà dedans. Gardée
#               comme repli si un jour le toit redevient une estimation.
#   equip     : part du toit équipable en panneaux (cheminées, pentes nord,
#               patrimoine). C'est elle qui fait la taille du gisement.
#   cout_x    : coût relatif du m² posé (accès, échafaudage, patrimoine).
#   rdt_x     : rendement relatif (orientation moyenne du tissu, masques).
#   gain_iso  : ce que l'isolation enlève à la consommation. 0 = décision
#               indisponible (pas de logements).
#   cout_iso  : coût relatif de l'isolation. Le cœur ancien paie 1,6 pour
#               gagner 20 % : rien par l'extérieur, patrimoine oblige.
#   cap_sol   : capital politique d'un chantier solaire, PAR ÎLOT. −3 là où
#               ça se voit et où le patrimoine proteste.
const ENERGIE := {
	#                      mwh_log mwh_emp batie  equip  cout_x rdt_x  gain_iso cout_iso cap_sol
	"coeur_ancien":       [   21.0,   0.0,  0.70,  0.15,   1.8,  0.75,   0.20,    1.6,  -3.0],
	"front_commercant":   [   18.0,   0.0,  0.80,  0.25,   1.4,  0.90,   0.25,    1.3,  -3.0],
	"maisons_de_ville":   [   17.0,   0.0,  0.55,  0.30,   1.3,  0.95,   0.35,    1.0,  -1.0],
	"pavillonnaire":      [   22.0,   0.0,  0.20,  0.40,   1.2,  1.00,   0.40,    1.5,  -1.0],
	"barre_1970":         [   24.0,   0.0,  0.20,  0.70,   0.8,  1.10,   0.45,    0.7,  -1.0],
	"dalle_commerciale":  [    0.0,   9.0,  0.60,  0.75,   0.7,  1.10,   0.00,    0.0,  -1.0],
	"equipement":         [    0.0,   9.0,  0.40,  0.55,   0.9,  1.05,   0.00,    0.0,  -1.0],
	"friche_industrielle":[    0.0,   9.0,  0.45,  0.65,   0.8,  1.00,   0.00,    0.0,  -1.0],
	"place_minerale":     [    0.0,   0.0,  0.00,  0.00,   0.0,  0.00,   0.00,    0.0,   0.0],
	"parc":               [    0.0,   0.0,  0.00,  0.00,   0.0,  0.00,   0.00,    0.0,   0.0],
	"jardins_familiaux":  [    0.0,   0.0,  0.00,  0.00,   0.0,  0.00,   0.00,    0.0,   0.0],
	"champ":              [    0.0,   0.0,  0.00,  0.00,   0.0,  0.00,   0.00,    0.0,   0.0],
	"riviere":            [    0.0,   0.0,  0.00,  0.00,   0.0,  0.00,   0.00,    0.0,   0.0],
}

# Les colonnes de la table, par nom — `ligne()` fait la traduction.
const _COLS := ["mwh_log", "mwh_emp", "batie", "equip", "cout_x", "rdt_x",
	"gain_iso", "cout_iso", "cap_sol"]

# Le rendement d'un panneau, et ce que coûte l'énergie qu'on n'a pas produite.
const RENDEMENT_KWH_M2_AN := 140.0    # Allemagne du sud-ouest, pertes comprises
const OMBRAGE_CANOPEE := 0.4          # rendement × (1 − 0,4 × canopée)
const CO2_KG_KWH := 0.25              # mix + chauffage — vaut aussi t/MWh
const CO2_GRIS_PANNEAU_KG_M2 := 120.0     # payé en une fois, au chantier
const CO2_GRIS_ISOLATION_KG_LOG := 4000.0 # modeste : remboursé en ~2 ans

# Les deux molettes de la rentabilité — il n'y en a que deux (PLAN §5).
const PANNEAU_M2_PAR_POINT := 120.0   # 1 point de budget pose 120 m²
const RETOUR_PTS_PAR_GWH_AN := 6.0    # 6 points par an et par GWh produit

# Les deux dérives du temps (PLAN §6 bis b). Composées : la rentabilité
# affichée fond d'environ 7,8 % par an, et la zone rouge recule toute seule.
const DERIVE_COUT_PANNEAU_AN := 0.94  # le panneau coûte −6 % par an
const DERIVE_PRIX_ENERGIE_AN := 1.02  # l'énergie achetée coûte +2 % par an

# Les quatre classes du calque : se rembourse vite · dans la partie ·
# tout juste · jamais. Aucun chiffre sur la carte (décision 60) — la précision
# se paie d'un clic, sur la fiche.
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

## Les m² qu'on peut couvrir. `toit_m2` est la surface RÉELLE du toit (pente
## comprise), donc pas de part bâtie ici — elle est déjà dans le toit.
## Un îlot sans toit (parc, rivière) rend 0 : `base()` ne plante pas.
static func toit_equipable_m2(v, fid: int) -> float:
	return v.base("i", fid, "toit_m2") * ligne(v, fid)["equip"]


## Ce que produirait le toit entièrement équipé, en MWh/an. L'ombrage de la
## canopée s'applique ici : l'antagonisme arbre/panneau, gratuit et réel.
static func potentiel_mwh(v, fid: int, t: float) -> float:
	var l := ligne(v, fid)
	var ombrage: float = 1.0 - OMBRAGE_CANOPEE * v.valeur("i", fid, "canopee", t)
	return toit_equipable_m2(v, fid) * RENDEMENT_KWH_M2_AN / 1000.0 \
		* l["rdt_x"] * ombrage


## Ce que le toit produit VRAIMENT : le potentiel × la part équipée.
## ⚠️ Jamais bornée à la consommation : la friche et la dalle exportent
## (PLAN §3, le piège du bornage).
static func production_mwh(v, fid: int, t: float) -> float:
	return potentiel_mwh(v, fid, t) * v.valeur("i", fid, "part_toit_equipe", t)


# ---------------------------------------------------------- la consommation

## La consommation de l'îlot au mois `t`, isolation déduite.
static func conso_mwh(v, fid: int, t: float) -> float:
	var l := ligne(v, fid)
	var iso: float = v.valeur("i", fid, "part_isolee", t)
	return v.valeur("i", fid, "logements", t) * l["mwh_log"] \
		* (1.0 - l["gain_iso"] * iso) \
		+ v.base("i", fid, "emplois") * l["mwh_emp"]


## Ce que l'isolation peut ENCORE enlever, en MWh/an. C'est le calque du
## gain : là où l'enveloppe est mauvaise et où il y a des gens.
static func gain_isolation_mwh(v, fid: int, t: float) -> float:
	var l := ligne(v, fid)
	return v.valeur("i", fid, "logements", t) * l["mwh_log"] * l["gain_iso"] \
		* (1.0 - v.valeur("i", fid, "part_isolee", t))


# ----------------------------------------------------------- la rentabilité

## En combien d'années les panneaux de cet îlot se remboursent, si on décide
## au mois `t`. Les deux dérives se composent : le coût fond, le tarif monte.
## INF si l'îlot n'a pas de toit — à ne JAMAIS peindre tel quel.
static func rentabilite_annees(v, fid: int, t: float) -> float:
	var pot := potentiel_mwh(v, fid, t)
	if pot <= 0.0:
		return INF
	var cout: float = toit_equipable_m2(v, fid) / PANNEAU_M2_PAR_POINT \
		* ligne(v, fid)["cout_x"] * derive_an(DERIVE_COUT_PANNEAU_AN, t)
	var retour_an: float = pot / 1000.0 * RETOUR_PTS_PAR_GWH_AN \
		* derive_an(DERIVE_PRIX_ENERGIE_AN, t)
	return cout / retour_an


## La classe du calque : 0 vite · 1 dans la partie · 2 tout juste · 3 jamais.
static func classe_rentabilite(v, fid: int, t: float) -> int:
	var annees := rentabilite_annees(v, fid, t)
	for i in CLASSES_ANNEES.size():
		if annees < CLASSES_ANNEES[i]:
			return i
	return CLASSES_ANNEES.size()


# ------------------------------------------------------------------ la ville

## Les trois volumes de ville, en MWh/an. Achat = conso − production : pas un
## troisième chiffre, le complément du deuxième (PLAN §3). Des sommes, pas des
## moyennes — rien à pondérer (décision 63).
static func ville_mwh(v, t: float) -> Dictionary:
	var conso := 0.0
	var prod := 0.0
	for fid in v.fids_batis():
		conso += conso_mwh(v, fid, t)
		prod += production_mwh(v, fid, t)
	return {"conso": conso, "production": prod, "achat": conso - prod}


## La facture : le volume acheté × le prix qui monte. C'est elle que le bandeau
## affiche (indexée sur t0) — ne rien faire coûte de plus en plus cher.
static func facture(v, t: float) -> float:
	return ville_mwh(v, t)["achat"] * derive_an(DERIVE_PRIX_ENERGIE_AN, t)


## Le CO2 de l'énergie achetée, en kt/an. SANS le carbone gris des chantiers :
## lui vit dans le journal, que la ville ne connaît pas — `chantiers.co2_gris_an`.
static func co2_achat_kt(v, t: float) -> float:
	return ville_mwh(v, t)["achat"] * CO2_KG_KWH / 1000.0


# ------------------------------------------------- les champs dérivés (`_`)

## Le dispatch des champs calculés : la fiche, les calques et le ciblage des
## décisions passent tous par `ville.valeur`, qui délègue ici les noms
## préfixés `_`. Un champ inconnu rend 0, comme un champ absent.
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
		# Les trois multiplicateurs que la machinerie des chantiers lit par
		# NOM DE CHAMP, sans savoir qu'ils parlent d'énergie : c'est ce qui
		# la garde générique (décision 64, le gabarit).
		"_cout_x_solaire":
			return ligne(v, fid)["cout_x"]
		"_cout_x_isolation":
			return ligne(v, fid)["cout_iso"]
		"_capital_solaire":
			return ligne(v, fid)["cap_sol"]
	return 0.0
