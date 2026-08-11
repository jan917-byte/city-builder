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

Treize `sous_type` pour une cible de 8–10 teintes : la tension se résout en
**familles**. Une famille = une teinte. À l'intérieur, les sous-types se
distinguent par la **valeur** (clair/sombre), pas par la teinte. Neuf familles.

Aucune des quatre plaies ne reçoit de couleur particulière — elles ressortent
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
                    "c'est elle qui rend la barre et la galerie étrangères",
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
    "dalle_commerciale":   "#ABB3BE",   # apres_guerre, valeur −  ← la plaie 45
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
SOLEIL = "#FFF4E2"                     # lumière chaude, basse en intensité
AMBIANT = "#8FA0AE"                    # le bleu du ciel dans les ombres
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


def pour_json():
    """Le bloc `palette` du JSON lu par Godot. Godot ne code jamais une
    couleur en dur : il lit celle-ci, et se plaint si un sous_type manque."""
    d = dict(MASSES)
    d.update(SOLS)
    d["riviere"] = EAU
    d["_mineral"] = MINERAL
    d["_mineral_clair"] = MINERAL_CLAIR
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
