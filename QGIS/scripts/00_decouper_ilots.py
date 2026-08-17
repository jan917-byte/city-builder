# -*- coding: utf-8 -*-
"""
Étape 0 du pipeline : découper les îlots là où l'auteur a dessiné une rue.

QGIS fait suivre les bords d'îlots quand on déplace un sommet (édition
topologique), mais il ne sait pas *couper* un polygone quand on trace une
ligne par-dessus. Ce script le fait : tout tronçon de `routes` qui traverse
un îlot de bord à bord le sépare en deux.

    python 00_decouper_ilots.py --blanc     ← calcule et affiche, n'écrit rien
    python 00_decouper_ilots.py             ← écrit dans QGIS/data/source/

⚠️ C'est l'un des TROIS scripts qui écrivent dans la source, avec
`00b_ilots_lisiere.py` et `tracer_chemins.py`. La chaîne 02→04c, elle, ne
la lit que. Faire la passe `--blanc` d'abord : ce qu'on touche ici est du
level design. La source étant du texte, `git diff` montre les îlots
touchés et `git checkout QGIS/data/source` défait la passe.

Trois opérations, dans cet ordre :
  1. les polygones aplatis (surface nulle) sont supprimés — ce sont les
     fantômes que laisse un coin d'îlot ramené sur un autre dans QGIS
  2. un trait qui entre dans un îlot PROTÉGÉ est raccourci jusqu'à son bord
  3. tout le reste des traversées coupe l'îlot en deux

Les moitiés : la plus grande garde le numéro de l'îlot d'origine, la plus
petite en prend un neuf. Ce qui veut dire qu'après un passage il faut
reprendre les listes de `fid` de `02_qualifier.py` — le script imprime
exactement les lignes à changer.
"""

import math
import os
import sys

import carte

for flux in (sys.stdout, sys.stderr):
    try:
        flux.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

ICI = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(os.path.dirname(ICI), "data")
SOURCE = carte.SOURCE          # QGIS/data/source/*.geojson, du texte
SRS = 25832

# ==========================================================================
# CE QUI SE RÈGLE
# ==========================================================================

# Les îlots qu'on ne coupe pas, même si un trait les traverse. Le trait est
# alors raccourci jusqu'au bord de l'îlot protégé — il s'arrête devant.
#   48 = les jardins familiaux : le seul de Wehrau, 0,88 ha. La rue 180 les
#        traversait de part en part ; l'auteur a choisi qu'elle s'arrête sur
#        la rue 72, à leur limite sud. (tranché le 2026-08-13)
NE_PAS_COUPER = [48]

# Un point à moins de ça d'un bord est considéré POSÉ dessus. L'accrochage de
# QGIS donne du 0,000 m ; 5 cm laisse de la marge sans rien avaler d'autre.
TOL = 0.05

# En dessous de cette surface, un polygone n'est plus un îlot mais un fantôme.
AIRE_FANTOME = 1.0

# ==========================================================================
# mécanique — rien à régler en dessous
# ==========================================================================


# 🔄 Retirés le 2026-08-17, quand la source est passée en texte : sept
# fonctions de lecture et d'écriture GeoPackage — `gpkg_vers_wkb`,
# `_lire_simple`, `lire_wkb`, `wkb_polygone`, `wkb_lignes`, `blob_gpkg`,
# `enveloppe` — plus `brancher_fonctions_spatiales`, qui fournissait
# ST_MinX/ST_MaxX/… aux déclencheurs d'index spatial du GeoPackage.
# Ce script ne touche plus une seule ligne de binaire : `carte.py` lit et
# écrit la source, et c'est le seul endroit du dépôt qui connaisse le WKB.
# ⚠️ Ne pas en recopier une ici « pour dépanner » : deux lecteurs de
# géométrie qui divergent, c'est le bug qu'on ne verra pas.



# ------------------------------------------------------------------ géométrie

def aire(anneau):
    s = 0.0
    for i in range(len(anneau) - 1):
        s += anneau[i][0] * anneau[i + 1][1] - anneau[i + 1][0] * anneau[i][1]
    return abs(s) / 2.0


def longueur(pts):
    return sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def dedans(anneau, p):
    x, y = p
    d = False
    for i in range(len(anneau) - 1):
        x1, y1 = anneau[i]
        x2, y2 = anneau[i + 1]
        if (y1 > y) != (y2 > y):
            if x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
                d = not d
    return d


def _proj(p, a, b):
    """-> (distance, paramètre t sur [a,b])."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    if dx == dy == 0:
        return math.dist(p, a), 0.0
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)))
    return math.dist(p, (a[0] + t * dx, a[1] + t * dy)), t


def dist_bord(anneaux, p):
    return min(_proj(p, a[i], a[i + 1])[0]
               for a in anneaux for i in range(len(a) - 1))


def poser_sur_anneau(anneau, p):
    """Insère p dans l'anneau fermé s'il n'y est pas déjà. -> (anneau, index)."""
    for i, q in enumerate(anneau[:-1]):
        if math.dist(p, q) <= TOL:
            return anneau, i
    best = (1e18, None, None)
    for i in range(len(anneau) - 1):
        d, t = _proj(p, anneau[i], anneau[i + 1])
        if d < best[0]:
            best = (d, i, t)
    d, i, t = best
    neuf = anneau[:i + 1] + [p] + anneau[i + 1:]
    return neuf, i + 1


def couper(anneau, ligne):
    """Coupe un anneau fermé par une polyligne dont les deux bouts sont sur
    son bord. -> (moitié A, moitié B), deux anneaux fermés."""
    an, a = poser_sur_anneau(list(anneau), ligne[0])
    an, b = poser_sur_anneau(an, ligne[-1])
    an, a = poser_sur_anneau(an, ligne[0])          # l'index de A a pu glisser
    o = an[:-1]
    n = len(o)

    def avancer(depuis, jusqu):
        out = []
        k = depuis
        for _ in range(n):
            k = (k + 1) % n
            out.append(o[k])
            if k == jusqu:
                return out
        raise SystemExit("parcours d'anneau impossible")

    A = list(ligne) + avancer(b, a)
    B = [o[a]] + avancer(a, b) + list(reversed(ligne[:-1]))
    return A, B


def traversees(ligne, anneaux):
    """Les morceaux de `ligne` qui traversent le polygone de bord à bord.
    -> liste de (i, j) indices de sommets. Un bord suivi de l'extérieur ou
    longé par la rue ne compte pas : le milieu doit être franchement dedans."""
    ext = anneaux[0]
    cls = []
    for p in ligne:
        if dist_bord(anneaux, p) <= TOL:
            cls.append("B")
        elif dedans(ext, p):
            cls.append("I")
        else:
            cls.append("O")
    out = []
    i = 0
    while i < len(cls):
        if cls[i] != "B":
            i += 1
            continue
        j = i + 1
        while j < len(cls) and cls[j] == "I":
            j += 1
        if j < len(cls) and cls[j] == "B":
            dedans_vrai = any(c == "I" for c in cls[i + 1:j])
            if not dedans_vrai:
                m = ((ligne[i][0] + ligne[j][0]) / 2, (ligne[i][1] + ligne[j][1]) / 2)
                dedans_vrai = dedans(ext, m) and dist_bord(anneaux, m) > TOL
            if dedans_vrai:
                out.append((i, j))
                i = j
                continue
        i += 1
    return out


# ---------------------------------------------------------------------- lire

def lire(src):
    """La source est du TEXTE depuis le 2026-08-17 (`carte.py`). On garde
    `src` sous la main : les entités lues portent aussi leurs attributs
    (`hierarchy` sur les rues), et réécrire depuis les seules géométries les
    perdrait en silence."""
    ilots, routes = {}, {}
    for e in src["ilots"]:
        ilots[e["fid"]] = {"anneaux": e["parts"], "typ": 3}
    for e in src["routes"]:
        routes[e["fid"]] = {"parts": e["parts"], "typ": 5 if e["multi"] else 2}
    return ilots, routes


def cadre(titre):
    print()
    print("=" * 70)
    print(titre)
    print("=" * 70)


def main():
    blanc = "--blanc" in sys.argv
    if not os.path.isdir(SOURCE):
        raise SystemExit("source introuvable : %s" % SOURCE)

    src = carte.lire_source(SOURCE)
    ilots, routes = lire(src)

    print("Source : %s" % os.path.basename(SOURCE))
    print("%d îlots, %d tronçons — %s"
          % (len(ilots), len(routes),
             "PASSE À BLANC, rien ne sera écrit" if blanc else "ÉCRITURE"))

    # --- 1. les fantômes ---------------------------------------------------
    fantomes = [f for f, o in ilots.items() if aire(o["anneaux"][0]) < AIRE_FANTOME]
    cadre("1. LES POLYGONES APLATIS")
    if not fantomes:
        print("  aucun — les %d îlots ont une surface." % len(ilots))
    for f in fantomes:
        an = ilots[f]["anneaux"][0]
        c = (sum(p[0] for p in an[:-1]) / (len(an) - 1),
             sum(p[1] for p in an[:-1]) / (len(an) - 1))
        repreneur = [g for g in ilots if g != f and g not in fantomes
                     and dedans(ilots[g]["anneaux"][0], c)]
        print("  îlot %d : %.0f m², %d sommets — supprimé" % (f, aire(an), len(an)))
        print("     sa surface est aujourd'hui dans : %s"
              % (", ".join("îlot %d" % g for g in repreneur) or "AUCUN ÎLOT ⚠️ trou"))
        del ilots[f]

    # --- 2. les traits qui entrent dans un îlot protégé --------------------
    cadre("2. LES TRAITS RACCOURCIS DEVANT UN ÎLOT PROTÉGÉ")
    raccourcis = {}
    protege = [f for f in NE_PAS_COUPER if f in ilots]
    for f in protege:
        for r, o in sorted(routes.items()):
            for pi, part in enumerate(o["parts"]):
                for (i, j) in traversees(part, ilots[f]["anneaux"]):
                    if i == 0:
                        neuf = part[j:]
                        garde = "on garde la partie après le sommet %d" % j
                    elif j == len(part) - 1:
                        neuf = part[:i + 1]
                        garde = "on garde la partie avant le sommet %d" % i
                    else:
                        raise SystemExit(
                            "le tronçon %d traverse l'îlot protégé %d par le "
                            "milieu : le raccourcir le couperait en deux. "
                            "Décider à la main." % (r, f))
                    print("  tronçon %d : %.0f m → %.0f m  (%s, îlot %d protégé)"
                          % (r, longueur(part), longueur(neuf), garde, f))
                    o["parts"][pi] = neuf
                    part = neuf
                    raccourcis[r] = o
    if not raccourcis:
        print("  aucun — %s"
              % ("aucun îlot protégé" if not protege
                 else "aucun trait n'entre dans %s"
                      % ", ".join("l'îlot %d" % f for f in protege)))

    # --- 3. les découpes ---------------------------------------------------
    cadre("3. LES DÉCOUPES")
    suivant = max(ilots) + 1
    coupes = []
    ecart_max = 0.0
    for f in sorted(ilots):
        if f in NE_PAS_COUPER:
            continue
        for r, o in sorted(routes.items()):
            for part in o["parts"]:
                tr = traversees(part, ilots[f]["anneaux"])
                if not tr:
                    continue
                if len(tr) > 1:
                    raise SystemExit(
                        "le tronçon %d traverse l'îlot %d %d fois : il le "
                        "couperait en 3 morceaux ou plus. Non géré."
                        % (r, f, len(tr)))
                i, j = tr[0]
                if len(ilots[f]["anneaux"]) > 1:
                    raise SystemExit("l'îlot %d a un trou : découpe non gérée." % f)
                avant = aire(ilots[f]["anneaux"][0])
                A, B = couper(ilots[f]["anneaux"][0], part[i:j + 1])
                aa, ab = aire(A), aire(B)
                ecart_max = max(ecart_max, abs(aa + ab - avant))
                grand, petit = (A, B) if aa >= ab else (B, A)
                ilots[f]["anneaux"] = [grand]
                ilots[suivant] = {"anneaux": [petit], "typ": 3}
                coupes.append((f, suivant, r, avant, aire(grand), aire(petit)))
                suivant += 1

    if not coupes:
        print("  aucune traversée trouvée : aucun îlot à couper.")
    else:
        print("  îlot | coupé par |     avant |  garde le n° |    nouveau n° |  somme")
        for f, neuf, r, avant, ag, ap in coupes:
            print("  %4d | tronçon %3d | %6.2f ha |  %2d : %5.2f ha | %3d : %5.2f ha | %6.2f ha"
                  % (f, r, avant / 1e4, f, ag / 1e4, neuf, ap / 1e4, (ag + ap) / 1e4))
        print("\n  contrôle de surface : le plus gros écart entre l'îlot d'avant")
        print("  et la somme de ses deux moitiés est de %.4f m². (0 = exact)" % ecart_max)
        if ecart_max > 0.01:
            raise SystemExit("écart de surface trop grand — découpe refusée.")

    # --- le compte rendu ---------------------------------------------------
    cadre("4. CE QUE ÇA CHANGE DANS LE LEVEL DESIGN")
    if fantomes or coupes:
        print("  À reporter à la main dans 02_qualifier.py :")
        for f in fantomes:
            print("    · retirer le %d de sa liste (l'îlot n'existe plus)" % f)
        for f, neuf, r, avant, ag, ap in coupes:
            print("    · ajouter le %d dans la MÊME liste que le %d "
                  "(c'est sa moitié)" % (neuf, f))
        print("\n  Et dans 04_deriver_attributs.py, vérifier que les numéros de")
        print("  FORCE et de PLAIES ne sont pas dans la liste ci-dessus.")
    else:
        print("  rien à changer.")

    cadre("5. LA CARTE APRÈS")
    tailles = sorted((aire(o["anneaux"][0]) for o in ilots.values()), reverse=True)
    print("  îlots        : %d  (avant : %d)" % (len(ilots), len(ilots) - len(coupes) + len(fantomes)))
    print("  surface      : %.0f m² au total" % sum(tailles))
    print("  le plus gros : %.2f ha    médiane : %.2f ha"
          % (tailles[0] / 1e4, tailles[len(tailles) // 2] / 1e4))

    if blanc:
        print("\n[passe à blanc] rien n'a été écrit.")
        return

    # On réécrit `src`, pas des dictionnaires reconstruits : les entités y
    # portent leurs attributs (`hierarchy` sur les rues), qu'aucun calcul
    # d'ici ne connaît. Repartir des seules géométries les effacerait.
    src["ilots"] = [e for e in src["ilots"] if e["fid"] not in fantomes]
    for e in src["ilots"]:
        e["parts"] = ilots[e["fid"]]["anneaux"]
    for r, o in raccourcis.items():
        for e in src["routes"]:
            if e["fid"] == r:
                e["parts"], e["multi"] = o["parts"], o["typ"] in (4, 5)
    for f, neuf, r, avant, ag, ap in coupes:
        src["ilots"].append({"fid": neuf, "parts": ilots[neuf]["anneaux"],
                             "multi": False})

    ecrits = carte.ecrire_source(src, SOURCE)
    print("\n✅ écrit dans %s — %s"
          % (SOURCE, ", ".join("%s %d" % (n, c) for n, c in sorted(ecrits.items()))))
    print("   C'est du texte : `git diff` montre exactement les îlots touchés.")
    print("   Relancer ensuite : python QGIS/scripts/chaine.py")


if __name__ == "__main__":
    main()
