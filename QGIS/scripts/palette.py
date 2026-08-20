#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
La palette — référence couleur unique du projet (décision 33), en Python parce
qu'un `.qml` ne s'importe pas des deux côtés et ne porte pas de commentaires.

    python3 QGIS/scripts/palette.py        # contrôle : couverture et familles

RÈGLES QUI COMMANDENT CE FICHIER — `Vault/Technique/Direction artistique.md`
  « Un `sous_type` = une teinte. Rien à peindre, jamais »        (l.19)
  « Une palette courte et sourde — 8–10 teintes, tenues »        (l.22)
  « Les bâtiments sont pastel. Le sol est de l'asphalte. »       (l.59)
  « aucun état visuel posé à la main, tout dérive d'un attribut »(l.75)

Douze `sous_type` pour 8–10 teintes : la tension se résout en FAMILLES. Une
famille = une teinte ; à l'intérieur, les sous-types se distinguent par la
valeur. Aucune des trois plaies n'a de couleur propre — voir `couleur_sol()`.
"""

# ---------------------------------------------------------------- familles

# Au-delà de 10, la règle « 8–10 teintes » est enfreinte — contrôlé en fin de
# fichier.
FAMILLES = {
    "sable":     "le tissu ancien — chaud, le plus clair de la carte",
    "terre":     "les maisons de ville — rosé, légèrement plus dense",
    "vert_pale": "le pavillonnaire — la seule masse qui tire vers le jardin",
    "ocre":      "l'équipement et la friche — neutre, sans caractère propre",
    "apres_guerre": "gris-bleu FROID. La seule famille froide du bâti : "
                    "c'est elle qui rend la barre étrangère",
    "vegetal":   "parc et jardins",
    "agricole":  "les champs — vert jauni, pas un gazon",
    "eau":       "l'Ilse",
    "mineral":   "l'asphalte. Chaussée, place-parking, sol nu",
}

# ------------------------------------------------------------------ masses
# Les `sous_type` bâtis (hauteur > 0). Tous pastel et chauds SAUF
# `apres_guerre`, et c'est voulu.

MASSES = {
    "coeur_ancien":        "#E6D2B4",   # sable
    "front_commercant":    "#DCC198",   # sable, valeur −  (le front est plus dense)
    "maisons_de_ville":    "#E2C0B4",   # terre
    "pavillonnaire":       "#D9DCC2",   # vert_pale
    "equipement":          "#D7D0C4",   # ocre
    "friche_industrielle": "#B5AA9B",   # ocre, désaturé — une friche n'est pas entretenue
    "barre_1970":          "#C2C9D3",   # apres_guerre        ← la plaie 32, par le froid
}

# -------------------------------------------------------------------- sols
# Les `sous_type` à hauteur nulle : des SURFACES, pas des volumes ratés.
# Teinte à imperméabilisation NULLE ; l'affichée sort de `couleur_sol()`.

SOLS = {
    "parc":              "#9CBD84",   # vegetal
    "jardins_familiaux": "#A8C38E",   # vegetal, valeur +
    "champ":             "#C7C5A0",   # agricole
    # À `impermeabilise = 1.00` elle sort exactement en MINERAL. Cette base
    # pâle est ce qu'elle redeviendrait dépavée : invisible à t0, et c'est le
    # sujet du jeu.
    "place_minerale":    "#CFC7B4",
}

EAU = "#7EA7C3"                        # `sous_type = riviere`

# ================================================== LES MATÉRIAUX DU BÂTI
# 🔄 RETOUR EN ARRIÈRE SIGNALÉ (CLAUDE.md §3 ter). Jusqu'au 2026-08-18 `MASSES`
# posait UNE teinte par `sous_type`, murs et toit compris : la ville sortait en
# blocs de pâte à modeler. Devant une photo aérienne de petite ville allemande,
# l'auteur a demandé l'inverse — une masse de TOITS ROUGES sur des murs clairs.
#
# Ce qui remplace « un sous_type = une teinte » :
#   ① toit et mur sont DEUX matériaux ;
#   ② le matériau vient de l'ÉPOQUE, pas de la fonction — dans une vraie ville
#      la couverture est une trace de la date de construction ;
#   ③ chaque bâtiment tire sa teinte de sa POSITION (décision 35).
#
# 🔴 `MASSES` RESTE : c'est la couleur du calque « tissu » et celle des aperçus
# 2D (`apercu_carte`, `06`), qui lisent une carte et pas une ville.

# --- les toitures ---------------------------------------------------------
# Une famille = un matériau ; les bases d'une famille sont les nuances d'une
# vraie rue.
# ⚠️ Saturation bornée à ~0,55 (DA, « courte et sourde »). Une tuile en plein
# soleil monte à 0,70 et rendrait Wehrau pittoresque au lieu d'ordinaire.
TOITURES = {
    # ⚠️ PONDÉRÉE PAR RÉPÉTITION : à sept bases équiprobables, 28 % de toits
    # sombres, et comme un versant nord est déjà assombri par la lumière, un
    # quartier entier sortait noir. Chaque base sombre pèse 1/14.
    "tuile": [
        "#AC6148", "#AC6148", "#AC6148", "#AC6148",   # la courante — 29 %
        "#B96C4D", "#B96C4D", "#B96C4D",              # neuve, orangée — 21 %
        "#A15845", "#A15845", "#A15845",              # 21 %
        "#96513F",   # vieillie
        "#B3745B",   # délavée, rosée
        "#7C4638",   # brune — 7 %
        "#6B5A52",   # 🔸 la rare sombre — 7 %. Elle empêche la masse de tuiles
                     #    de devenir un aplat ; au-delà, elle troue la ville.
    ],
    "ardoise": [     # l'équipement et l'église
        "#575C63", "#4E535A", "#606670",
    ],
    "etancheite": [  # le toit plat de 1974 — bitume et gravier
        "#6E6E6A", "#77766E", "#666660",
    ],
    "bac_acier": [   # les halles et la friche
        "#5F6367", "#6B6A66", "#585B5F",
        "#726A62",   # une travée rouillée
    ],
}

TOIT_TISSU = {
    "coeur_ancien":        "tuile",
    "front_commercant":    "tuile",
    "maisons_de_ville":    "tuile",
    "pavillonnaire":       "tuile",
    "equipement":          "ardoise",
    "barre_1970":          "etancheite",
    "friche_industrielle": "bac_acier",
}

# --- les enduits de façade ------------------------------------------------
# 🔴 NON NÉGOCIABLE : le mur reste PASTEL et CLAIR (DA l.59). Le toit rouge ne
# contredit pas la règle, il la rend visible — un mur clair a enfin quelque
# chose de sombre à côté de lui.
ENDUITS = {
    # Chaud et varié : c'est là qu'une rue change de couleur tous les 6 m.
    "coeur_ancien": [
        "#E9E3D6",   # blanc cassé
        "#E7DCC2",   # crème
        "#DFCFA8",   # ocre pâle
        "#E0CFC0",   # beige rosé
        "#E5D9AE",   # jaune paille
        "#D7DBC6",   # vert très pâle
    ],
    "front_commercant": [
        "#E7DCC2", "#DFCFA8", "#E9E3D6", "#E5D9AE", "#DFC9C0",
    ],
    "maisons_de_ville": [
        "#E9E3D6", "#DFC9C0", "#DCD9D2", "#E7DCC2", "#D7DBC6",
    ],
    # Plus blanc et plus uniforme : un lotissement se construit d'un coup.
    "pavillonnaire": [
        "#EAE5DA", "#E3E0D6", "#E7DFCD", "#DCD9D2",
    ],
    # 🔄 La barre perd son gris-bleu froid (#C2C9D3), seule teinte de la
    # palette qui disait « étranger ». Son toit plat et SOMBRE au milieu des
    # tuiles rouges dit la plaie 32 sans avoir à colorier.
    "barre_1970": [
        "#C8C6BF", "#C1C2BE", "#CCC8BC",
        "#D2CBB8",   # un pignon repeint
    ],
    "equipement": [
        "#E2DED3", "#DED7C7", "#D8D9D4",
    ],
    "friche_industrielle": [
        "#BEB8AC", "#C4BFB2", "#B2AEA4",
        "#B9BBBA",   # du bardage, pas de l'enduit
    ],
}
ENDUITS_DEFAUT = ["#DED9CC"]

# Brique enduite : plus sombre que le mur, plus chaude que le toit. Une seule
# teinte — à 0,8 m de côté, une variation ne se verrait pas.
# 🔄 Assombrie le 2026-08-18 : à #9C8877 les souches sortaient en confettis
# blancs sur les toits rouges.
CHEMINEE = "#7B6659"

# --- le sol ---------------------------------------------------------------
# Du béton : plus CLAIR et plus CHAUD que l'asphalte. Sans ce liseré, une rue
# et un parking sont la même tache grise vue d'en haut.
# 🔄 ÉCLAIRCI le 2026-08-18 (de #8D8A82) : l'ancien était à 2 % de valeur de
# MINERAL_CLAIR, la teinte du SOL NU qui l'entoure — donc invisible partout
# sauf contre l'asphalte. Il doit se distinguer de DEUX voisins, pas d'un.
TROTTOIR = "#A8A399"

# 🎨 LA PEINTURE DE VOIRIE, et ce n'est PAS un blanc : #FFFFFF sur l'asphalte
# sort plus lumineux que les tuiles et attire l'œil au sol. Peinture usée à
# ~78 % de valeur, assez pour trancher sur MINERAL (~42 %).
MARQUAGE = "#C6C3B9"

# Pas un aplat : un blé n'a pas la couleur d'une prairie. Une base par îlot,
# tirée de sa position.
CHAMPS = [
    "#C9C39A",   # blé mûr
    "#BCC192",   # prairie
    "#D0C7A2",   # chaume
    "#AEB588",   # herbe grasse
    "#C3B896",   # terre travaillée
]

# ----------------------------------------------------------------- minéral
# Un seul gris pour tout le réseau : la hiérarchie s'exprime par la LARGEUR,
# ce qui est le sujet du troisième critère de réussite et économise quatre
# teintes.

MINERAL = "#67676B"                    # la chaussée : EMPRISE_CIRCULATION
MINERAL_CLAIR = "#83838A"              # l'emprise excédentaire et le sol nu

# ------------------------------------------------------------ le décor fixe
# « La lumière : fixe et calme. Pas de météo d'ambiance, pas de golden hour,
#   pas de ciel gris. »  — Direction artistique l.69

CIEL = "#C8CFD4"                       # un jour couvert clair, sans drame
SOLEIL = "#FFF2DC"                     # lumière chaude, basse en intensité
# 🔄 RÉCHAUFFÉ ET AFFAIBLI le 2026-08-18 (de #8FA0AE à 0,85 d'énergie) : sur
# des enduits clairs et neutres, ce bleu repeignait toute façade à l'ombre et
# la ville avait l'air d'un jour de pluie.
AMBIANT = "#A2A29C"                    # le bleu du ciel dans les ombres
FEUILLAGE = "#8FB177"                  # la canopée instanciée
TRONC = "#8A7A66"


# ------------------------------------------------------------------ outils

def hex_vers_rgb(h):
    """'#E6D2B4' → (230, 210, 180)."""
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb_vers_hex(c):
    """(230, 210, 180) → '#e6d2b4'."""
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v)))) for v in c)


def vers_lineaire(h):
    """'#E6D2B4' → (0.78, 0.63, 0.46) en espace LINÉAIRE.

    ⚠️ Une couleur de sommet passée en sRGB est prise pour du linéaire : toute
    la maquette ressort délavée, et le contraste pastel/minéral que la décision
    42c demande de voir s'efface. Seules les couleurs de SOMMET sont
    concernées — Godot convertit lui-même `albedo_color` et les lumières."""
    def c(v):
        v = v / 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return tuple(c(x) for x in hex_vers_rgb(h))


def melanger(a, b, t):
    """Interpolation linéaire entre deux couleurs hex. t=0 → a, t=1 → b."""
    t = max(0.0, min(1.0, t))
    ra, rb = hex_vers_rgb(a), hex_vers_rgb(b)
    return rgb_vers_hex([ra[i] + (rb[i] - ra[i]) * t for i in range(3)])


def couleur_sol(sous_type, impermeabilise):
    """DÉRIVÉE de l'imperméabilisation — la règle centrale de la DA, et la
    seule qui fasse exister une plaie sans qu'on la peigne :

        champ            imperm 0.02  →  98 % agricole
        parc             imperm 0.12  →  88 % végétal
        place_minerale   imperm 1.00  → 100 % minéral, la couleur de la rue

    L'îlot 19 reçoit la couleur de la chaussée parce que son attribut dit
    qu'il EST de la chaussée.
    """
    base = SOLS.get(sous_type, MINERAL_CLAIR)
    return melanger(base, MINERAL, impermeabilise or 0.0)


def couleur_ilot(sous_type, hauteur, impermeabilise):
    """La couleur d'un îlot, quel que soit son registre de rendu."""
    if sous_type == "riviere":
        return EAU
    if sous_type in MASSES and (hauteur or 0.0) > 0.0:
        return MASSES[sous_type]
    return couleur_sol(sous_type, impermeabilise)


def _varier(base, r, amp):
    """Une nuance de `base`, tirée de `r`. DEUX dérives : la VALEUR (±amp),
    qui porte l'essentiel de la variété, et la TEMPÉRATURE (±3,5 %) — sans
    elle, deux bâtiments sur la même base sortent identiques, et ça se voit
    sur un front mitoyen.

    ⚠️ L'amplitude ne monte pas : à ±0,12 la rue clignote et on lit du bruit
    plutôt qu'une ville. Mesuré à l'écran le 2026-08-18.
    """
    rgb = hex_vers_rgb(base)
    f = 1.0 + r.uniform(-amp, amp)
    w = r.uniform(-0.035, 0.035)
    return rgb_vers_hex((rgb[0] * f * (1.0 + w), rgb[1] * f,
                         rgb[2] * f * (1.0 - w)))


def couleur_toit(sous_type, graine):
    """La couverture d'UN bâtiment. `graine` vient de sa position (35)."""
    import random
    r = random.Random(graine ^ 0x7017)
    bases = TOITURES[TOIT_TISSU.get(sous_type, "tuile")]
    return _varier(bases[r.randrange(len(bases))], r, 0.07)


def couleur_mur(sous_type, graine):
    """L'enduit d'UN bâtiment. Amplitude plus faible que le toit : un mur
    clair vire vite au sale ou au surexposé."""
    import random
    r = random.Random(graine ^ 0x3D0C)
    bases = ENDUITS.get(sous_type, ENDUITS_DEFAUT)
    return _varier(bases[r.randrange(len(bases))], r, 0.05)


def couleur_champ(graine, impermeabilise=0.0):
    """La teinte d'un îlot de champ, tirée de sa position."""
    import random
    r = random.Random(graine ^ 0x1C4A)
    base = _varier(CHAMPS[r.randrange(len(CHAMPS))], r, 0.05)
    return melanger(base, MINERAL, impermeabilise or 0.0)


def pour_json():
    """Le bloc `palette` du JSON. Godot ne code jamais une couleur en dur : il
    lit celle-ci et se plaint si un sous_type manque. Les clés `sous_type`
    servent aux aperçus 2D et au calque « tissu »."""
    d = dict(MASSES)
    d.update(SOLS)
    d["riviere"] = EAU
    d["_mineral"] = MINERAL
    d["_mineral_clair"] = MINERAL_CLAIR
    d["_trottoir"] = TROTTOIR
    d["_marquage"] = MARQUAGE
    d["_ciel"] = CIEL
    d["_soleil"] = SOLEIL
    d["_ambiant"] = AMBIANT
    d["_feuillage"] = FEUILLAGE
    d["_tronc"] = TRONC
    return d


# Décision 32b. Un sous_type sans teinte doit être une erreur bruyante, jamais
# un magenta silencieux — d'où le contrôle ci-dessous.
SOUS_TYPES = sorted(list(MASSES) + list(SOLS) + ["riviere"])


def controler():
    manque = [s for s in SOUS_TYPES
              if s not in MASSES and s not in SOLS and s != "riviere"]
    print("Palette — %d sous_type, %d familles" % (len(SOUS_TYPES), len(FAMILLES)))
    if len(FAMILLES) > 10:
        print("  ⚠ %d familles : la règle « 8–10 teintes » est enfreinte"
              % len(FAMILLES))
    if manque:
        raise SystemExit("sous_type sans teinte : %s" % ", ".join(manque))

    print("\n  masses (extrudées)")
    for s, h in MASSES.items():
        print("    %-22s %s" % (s, h))
    print("\n  sols (surface, teinte à imperméabilisation nulle)")
    for s, h in SOLS.items():
        print("    %-22s %s" % (s, h))
    print("    %-22s %s" % ("riviere", EAU))

    print("\n  LE BÂTI RÉEL — toit et mur sont deux matériaux (2026-08-18)")
    print("    %-20s %-11s %-31s %s"
          % ("sous_type", "couverture", "quatre toits", "quatre murs"))
    for s in MASSES:
        fam = TOIT_TISSU.get(s, "tuile")
        # Arbitraires : elles montrent l'étendue de la variation, ce ne sont
        # pas celles des bâtiments de Wehrau.
        gr = [1000 + k * 7919 for k in range(4)]
        print("    %-20s %-11s %-31s %s"
              % (s, fam,
                 " ".join(couleur_toit(s, g) for g in gr),
                 " ".join(couleur_mur(s, g) for g in gr)))
    print("\n    Ce qu'il faut voir : la colonne `toit` est ROUGE partout sauf")
    print("    barre (étanchéité), friche (bac acier) et équipement (ardoise).")
    print("    La colonne des murs reste CLAIRE — c'est la règle « pastel »")
    print("    de la DA, et le toit sombre est ce qui la rend enfin visible.")

    print("\n  la règle du sol, appliquée aux valeurs de TISSU")
    for s, imp in (("champ", 0.02), ("jardins_familiaux", 0.06),
                   ("parc", 0.12), ("place_minerale", 1.00)):
        print("    %-22s imperm %.2f  →  %s" % (s, imp, couleur_sol(s, imp)))
    print("    %-22s              →  %s   (la chaussée)" % ("MINERAL", MINERAL))
    print("\n  Contrôle : place_minerale doit tomber exactement sur MINERAL.")
    if couleur_sol("place_minerale", 1.00).lower() != MINERAL.lower():
        raise SystemExit("la règle du sol ne referme pas la plaie 19")
    print("  ✓")


if __name__ == "__main__":
    # La console Windows est en cp1252 et rejette accents et flèches. Les
    # autres scripts héritent le correctif d'`apercu_carte` ; celui-ci
    # n'importe rien, et un module ne doit pas trafiquer stdout à l'import.
    import sys
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    controler()
