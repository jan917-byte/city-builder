#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
La palette — référence couleur unique du projet.

    python3 QGIS/scripts/palette.py        # contrôle : couverture et familles

Ce module remplace le `.qml` que la décision 33 désignait comme « référence
couleur unique QGIS ↔ Godot ». Ce fichier n'a jamais existé, et Godot ne sait
pas lire un `.qml`. Un module Python, lui, s'importe des deux côtés — et il
porte des commentaires, ce qu'un fichier de style ne fait pas. Or ici chaque
teinte est une décision de design.

RÈGLES QUI COMMANDENT CE FICHIER — `Vault/Technique/Direction artistique.md`

  « Un `sous_type` = une teinte. Rien à peindre, jamais »       (l.19)
  « Une palette courte et sourde — 8–10 teintes, tenues »        (l.22)
  « Les bâtiments sont pastel. Le sol est de l'asphalte. »       (l.59)
  « La part minérale du sol — c'est elle qui porte tout,
    dérivée de `impermeabilise`, `canopee`, `stationnement` »    (l.73)
  « aucun état visuel posé à la main, tout dérive d'un attribut »(l.75)

Douze `sous_type` pour une cible de 8–10 teintes : la tension se résout en
**familles**. Une famille = une teinte. À l'intérieur, les sous-types se
distinguent par la **valeur** (clair/sombre), pas par la teinte. Neuf familles.

Aucune des trois plaies ne reçoit de couleur particulière — elles ressortent
par les attributs et la géométrie. Voir `couleur_sol()` pour l'îlot 19.
"""

# ---------------------------------------------------------------- familles

# Une entrée par famille. Sert au contrôle de fin de fichier : si ce nombre
# dépasse 10, la règle « 8–10 teintes » est enfreinte et il faut regrouper.
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
# Les 8 `sous_type` bâtis (hauteur > 0). Extrudés en volume.
# Tous pastel et chauds SAUF la famille `apres_guerre`, et c'est voulu.

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
# Les `sous_type` à hauteur nulle. Ce sont des SURFACES, pas des volumes ratés.
# La valeur ci-dessous est la teinte à imperméabilisation NULLE : ce que la
# surface serait si elle était entièrement perméable. La couleur réellement
# affichée sort de `couleur_sol()`, qui la tire vers le minéral.

SOLS = {
    "parc":              "#9CBD84",   # vegetal
    "jardins_familiaux": "#A8C38E",   # vegetal, valeur +
    "champ":             "#C7C5A0",   # agricole
    # La place du marché à `impermeabilise = 1.00` sort exactement en MINERAL :
    # elle se lit comme un élargissement de la chaussée, une rue qui a enflé
    # jusqu'à devenir une place. Cette base pâle est ce qu'elle redeviendrait
    # si on la dépavait — elle ne se voit pas à t0, et c'est le sujet du jeu.
    "place_minerale":    "#CFC7B4",
}

EAU = "#7EA7C3"                        # `sous_type = riviere`

# ================================================== LES MATÉRIAUX DU BÂTI
# 🔄 RETOUR EN ARRIÈRE SIGNALÉ (CLAUDE.md §3 ter), et c'est le plus gros de ce
# fichier. Jusqu'au 2026-08-18, `MASSES` ci-dessus donnait UNE teinte par
# `sous_type`, posée à la fois sur les murs ET sur le toit : la ville sortait
# en blocs de pâte à modeler roses, crème et blancs. L'auteur a demandé un
# rendu réaliste devant une photo aérienne de petite ville allemande, où la
# ville se lit exactement à l'inverse — une masse de TOITS ROUGES sur des murs
# clairs qui passent au second plan.
#
# Ce qui remplace la règle « un sous_type = une teinte » :
#
#   ① le toit et le mur sont DEUX matériaux distincts ;
#   ② le matériau découle de l'ÉPOQUE du bâti, pas de sa fonction — tuile sur
#      l'ancien, étanchéité sombre sur la barre de 1974, bac acier sur la
#      halle, ardoise sur l'équipement. C'est déjà ce que fait une vraie
#      ville : le matériau EST une trace de la date de construction ;
#   ③ chaque bâtiment tire sa teinte de sa POSITION (décision 35), donc deux
#      maisons mitoyennes ne sont plus jumelles.
#
# 🔴 CE QUE `MASSES` DEVIENT, ET POURQUOI IL RESTE. Il n'est plus la couleur
# par défaut de la maquette, mais il reste la couleur du CALQUE « tissu » —
# la touche qui rend au joueur la lecture qu'on vient de lui retirer — et il
# reste la couleur des aperçus 2D (`apercu_carte`, `06`), qui eux lisent une
# carte et pas une ville. Ne pas le supprimer.

# --- les toitures ---------------------------------------------------------
# Une famille = un matériau de couverture. Les bases d'une même famille sont
# les nuances qu'on voit sur une vraie rue : la tuile ne sort pas d'une usine
# unique et ne vieillit pas au même rythme selon l'exposition.
#
# ⚠️ La saturation est bornée à ~0,55 pour tenir le « palette courte et
# sourde » de la DA. Une tuile photographiée en plein soleil monte à 0,70 et
# ferait crier toute la ville, ce qui est l'autre erreur — celle qui rendrait
# Wehrau pittoresque au lieu d'ordinaire.
TOITURES = {
    # ⚠️ LA LISTE EST PONDÉRÉE PAR RÉPÉTITION, et il a fallu deux passes pour
    # trouver le bon dosage. Au premier essai, sept bases également probables
    # donnaient 28 % de toits sombres (la brune et la rare) — et comme un
    # versant au nord est déjà assombri par la lumière, un quartier entier
    # sortait noir. Chaque base sombre ne pèse plus que 1/14.
    "tuile": [
        "#AC6148", "#AC6148", "#AC6148", "#AC6148",   # la courante — 29 %
        "#B96C4D", "#B96C4D", "#B96C4D",              # neuve, orangée — 21 %
        "#A15845", "#A15845", "#A15845",              # 21 %
        "#96513F",   # vieillie
        "#B3745B",   # délavée, rosée
        "#7C4638",   # brune — 7 %
        "#6B5A52",   # 🔸 la rare toiture sombre au milieu des rouges — 7 %.
                     #    C'est elle qui empêche la masse de tuiles de devenir
                     #    un aplat ; au-delà, elle troue la ville.
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
# 🔴 CE QUI EST TENU ICI, et qui n'est pas négociable : le mur reste PASTEL et
# CLAIR. « Les bâtiments sont pastel. Le sol est de l'asphalte » (DA l.59) ne
# tombe pas avec la couleur par tissu — au contraire, c'est le toit rouge qui
# le rend enfin visible, parce qu'un mur clair a maintenant quelque chose de
# sombre à côté de lui.
ENDUITS = {
    # Le tissu ancien : chaud et varié, c'est là qu'une rue change de couleur
    # tous les six mètres.
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
    # Le pavillonnaire est plus blanc et plus uniforme que le centre : un
    # lotissement se construit d'un coup, avec le même enduit.
    "pavillonnaire": [
        "#EAE5DA", "#E3E0D6", "#E7DFCD", "#DCD9D2",
    ],
    # 🔄 La barre perd son gris-bleu FROID (#C2C9D3), qui était le seul endroit
    # de la palette où une teinte disait « étranger ». Ce que ça enlève est
    # rendu ailleurs, et mieux : son toit est maintenant plat et SOMBRE quand
    # tout le reste de la ville est en tuile rouge, et sa silhouette est déjà
    # la plus longue de Wehrau. Le froid disait la plaie 32 ; le toit la dit
    # sans avoir à colorier.
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

# La souche de cheminée : de la brique enduite, plus sombre que le mur et plus
# chaude que le toit. Une seule teinte — à 0,8 m de côté, une variation ne se
# verrait pas et coûterait un tirage.
# 🔄 Assombrie le 2026-08-18 après regard : à #9C8877 les souches sortaient en
# points BLANCS sur les toits rouges, comme un semis de confettis.
CHEMINEE = "#7B6659"

# --- le sol ---------------------------------------------------------------
# Le trottoir : du béton, donc plus CLAIR et plus CHAUD que l'asphalte. C'est
# ce liseré qui sépare la chaussée du bâti — sans lui, une rue et un parking
# sont la même tache grise vue d'en haut.
# 🔄 ÉCLAIRCI le 2026-08-18, de #8D8A82. Il fallait le mesurer pour le voir :
# l'ancien trottoir était à 2 % de valeur de MINERAL_CLAIR, la teinte du SOL NU
# — c'est-à-dire du terrain qui l'entoure des deux côtés. Il était donc invisible
# partout sauf contre l'asphalte, et la « bande claire de part et d'autre de la
# rue » qu'on croyait voir était en fait le sol nu. Le trottoir doit se
# distinguer de DEUX voisins, pas d'un.
TROTTOIR = "#A8A399"

# 🎨 LA PEINTURE DE VOIRIE — axe, rives, passages piétons. Ce n'est PAS un
# blanc : un blanc pur (#FFFFFF) sur l'asphalte sort plus lumineux que les
# toits de tuile et attire l'œil au sol, alors que le marquage est censé
# n'être qu'une trame de lecture. Celui-ci est une peinture usée, à ~78 % de
# valeur — assez pour trancher nettement sur MINERAL (#67676B, ~42 %) sans
# devenir le point le plus clair de l'image.
MARQUAGE = "#C6C3B9"

# Les champs ne sont pas un aplat : un blé n'a pas la couleur d'une prairie ni
# d'une terre labourée. Une base par îlot de champ, tirée de sa position.
CHAMPS = [
    "#C9C39A",   # blé mûr
    "#BCC192",   # prairie
    "#D0C7A2",   # chaume
    "#AEB588",   # herbe grasse
    "#C3B896",   # terre travaillée
]

# ----------------------------------------------------------------- minéral
# Un seul gris pour tout le réseau viaire. La hiérarchie ne s'exprime PAS par
# la couleur, elle s'exprime par la largeur — ce qui est précisément le sujet
# du troisième critère de réussite (« trouver monstrueuses les rues à 20 et
# 22 m »), et ce qui économise quatre teintes.

MINERAL = "#67676B"                    # la chaussée : EMPRISE_CIRCULATION
MINERAL_CLAIR = "#83838A"              # l'emprise excédentaire et le sol nu

# ------------------------------------------------------------ le décor fixe
# « La lumière : fixe et calme. Pas de météo d'ambiance, pas de golden hour,
#   pas de ciel gris. »  — Direction artistique l.69

CIEL = "#C8CFD4"                       # un jour couvert clair, sans drame
SOLEIL = "#FFF2DC"                     # lumière chaude, basse en intensité
# 🔄 RÉCHAUFFÉ ET AFFAIBLI le 2026-08-18. Il valait #8FA0AE à 0,85 d'énergie,
# et c'était le réglage d'une ville dont les murs ÉTAIENT la couleur : un
# ambiant bleu généreux ne se voyait pas sur du rose et du crème saturés.
# Maintenant que les murs sont des enduits clairs et neutres, ce bleu les
# repeignait — toute façade non exposée au soleil sortait gris-bleu, et la
# ville avait l'air d'un jour de pluie. Le ciel garde sa part froide, il ne
# commande plus l'image.
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

    Godot rend en linéaire. Une couleur de sommet passée telle quelle en sRGB
    y est interprétée comme déjà linéaire, donc affichée bien plus claire
    qu'elle ne devrait : toute la maquette ressort délavée, et le contraste
    entre le pastel des bâtiments et le minéral du sol s'efface — c'est-à-dire
    exactement ce que la décision 42c demande de voir.

    Les couleurs passées à `albedo_color`, `background_color` ou à une lumière
    n'ont PAS besoin de ça : Godot les convertit lui-même. Seules les couleurs
    de SOMMET sont concernées."""
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
    """La couleur d'une surface au sol, DÉRIVÉE de son imperméabilisation.

    C'est la règle centrale de la direction artistique, et la seule qui fasse
    exister une plaie sans qu'on la peigne :

        champ            imperm 0.02  →  98 % agricole
        jardins          imperm 0.06  →  94 % végétal
        parc             imperm 0.12  →  88 % végétal
        place_minerale   imperm 1.00  → 100 % minéral, la couleur de la rue

    L'îlot 19 ne reçoit pas une couleur « de plaie ». Il reçoit la couleur de
    la chaussée, parce que son attribut dit qu'il EST de la chaussée.
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
    """Une nuance de `base`, tirée de `r`. Deux dérives et pas une seule :

      · la VALEUR (±amp) — le même enduit prend la lumière autrement selon
        l'exposition, et c'est elle qui porte l'essentiel de la variété ;
      · la TEMPÉRATURE (±3,5 %, rouge et bleu en sens opposés) — sans elle,
        deux bâtiments qui tirent la même base et la même valeur sortent
        strictement identiques, et ça se voit sur un front mitoyen.

    ⚠️ L'amplitude ne monte pas : à ±0,12 la rue se met à clignoter et on ne
    lit plus une ville, on lit du bruit. Mesuré à l'écran le 2026-08-18.
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
    clair pardonne moins l'écart, il vire vite au sale ou au surexposé."""
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
    """Le bloc `palette` du JSON lu par Godot. Godot ne code jamais une
    couleur en dur : il lit celle-ci, et se plaint si un sous_type manque.

    Les clés `sous_type` y restent, et elles servent maintenant à DEUX
    choses : les aperçus 2D, et le calque « tissu » de la maquette — celui
    qui rend au joueur, à la demande, la lecture par typologie que le rendu
    réaliste lui a retirée."""
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


# Les treize `sous_type` de la décision 32b. Le contrôle ci-dessous vérifie
# qu'aucun n'est orphelin — un sous_type sans teinte doit être une erreur
# bruyante, jamais un magenta silencieux.
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
        # Des graines arbitraires : elles ne servent qu'à MONTRER l'étendue de
        # la variation, elles ne sont pas celles des bâtiments de Wehrau.
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
    # La console Windows est en cp1252 et rejette les flèches et les accents.
    # Les autres scripts héritent ce correctif de l'import d'`apercu_carte` ;
    # ce module n'importe rien, donc il le pose lui-même — et seulement ici :
    # un module de bibliothèque ne doit pas trafiquer stdout à l'import.
    import sys
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    controler()
