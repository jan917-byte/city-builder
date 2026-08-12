# -*- coding: utf-8 -*-
"""
Étape 5 du pipeline : les attributs dérivés.

Deux champs sont saisis à la main (`fonction`, `sous_type`, dans 02_qualifier.py).
Tout le reste se dérive. Ce script écrit ce « tout le reste ».

Il s'inspire du brainstorm du 2026-08-10 (inondation) : les attributs écrits
ici ne sont pas une fiche d'identité de l'îlot, ce sont **les entrées des
décisions**. Chaque colonne répond à « quelle décision devient possible ? » :

  ÎLOTS
    densite · logements · hauteur   densifier / seuil de viabilité TC
    impermeabilise                  désimperméabiliser · ruissellement
    canopee                         planter · confort d'été
    desserte_tc                     le seuil que la densité doit atteindre
    riverain                        fragilité sociale — la boucle gentrification
    stationnement                   le coût politique de la place-parking
    altitude_relative · alea        ⏸️ à 0 : carte plate, crue hors prototype
    position_fil_eau                la portée « aval » d'une décision
    rive                            l'asymétrie des deux rives

  RUES
    emprise_libre_m                 arbres vs désimperméabiliser vs stationner,
                                    et l'entrée de la « doctrine à seuil »
    stationnement                   ce que retirer la voiture coûte vraiment
    charge                          le modèle de trafic minimal : charge → report
    canopee                         l'alignement existant, à t0 quasi nul

    python 04_deriver_attributs.py            # écrit
    python 04_deriver_attributs.py --blanc    # n'écrit rien, montre seulement

Travaille sur `Prototype_qualifie.gpkg`. Ne touche pas à `Vallmar2.gpkg`.
Aucune géométrie n'est modifiée. Relançable autant de fois qu'on veut.
"""

import heapq
import math
import os
import sqlite3
import struct
import sys

for flux in (sys.stdout, sys.stderr):
    try:
        flux.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

ICI = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(os.path.dirname(ICI), "data")
BLANC = "--blanc" in sys.argv          # dry-run : calcule et affiche, n'écrit pas
# `python 04_deriver_attributs.py une_copie.gpkg` — même convention
# qu'apercu_carte.py : travailler sur une copie sans toucher au fichier de
# travail. C'est la façon de relire un changement de TISSU avant de l'écrire.
_ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
GPKG = _ARGS[0] if _ARGS else os.path.join(DATA, "Prototype_qualifie.gpkg")

# ==========================================================================
# LE DESIGN — la table de correspondance, 13 lignes
# ==========================================================================
# Une ligne par `sous_type`. C'est ici que se décide le comportement de toute
# la carte, et c'est du design, pas de la mesure.
#
#   densite     logements par hectare d'îlot (densité nette, hors voirie)
#   hauteur     étages moyens
#   imperm      part de la surface imperméabilisée, 0..1
#   canopee     part couverte par la canopée, 0..1
#   riverain    fragilité du riverain, 0 = encaisse un choc, 1 = ne l'encaisse pas
#   park        part de la surface de l'îlot occupée par du stationnement, 0..1
#   emploi      emplois par hectare d'îlot — nul hors `industrie` et `mixte`

# Les densités sont nettes (par hectare d'îlot, voirie exclue) et calées sur
# du tissu allemand réel : emprise au sol × niveaux ÷ surface par logement.
TISSU = {
    #                       densite hauteur imperm canopee riverain  park emploi
    "coeur_ancien":       (   170,    4.0,   0.85,   0.08,   0.45,   0.05,  110),
    "front_commercant":   (   150,    4.0,   0.90,   0.04,   0.35,   0.10,  140),
    "maisons_de_ville":   (   100,    3.0,   0.68,   0.18,   0.50,   0.05,    0),
    "pavillonnaire":      (    20,    2.0,   0.42,   0.42,   0.25,   0.05,    0),
    "barre_1970":         (   130,    9.0,   0.55,   0.32,   0.85,   0.15,    0),
    "dalle_commerciale":  (     0,    2.0,   0.97,   0.00,   0.20,   0.60,   70),
    "equipement":         (     0,    3.0,   0.72,   0.18,   0.00,   0.20,   80),
    "friche_industrielle":(     0,    1.0,   0.80,   0.20,   0.00,   0.05,   25),
    "place_minerale":     (     0,    0.0,   1.00,   0.02,   0.00,   0.55,    0),
    "parc":               (     0,    0.0,   0.12,   0.70,   0.00,   0.00,    0),
    "jardins_familiaux":  (     0,    0.0,   0.06,   0.30,   0.00,   0.00,    0),
    "champ":              (     0,    0.0,   0.02,   0.04,   0.00,   0.00,    0),
    "riviere":            (     0,    0.0,   0.00,   0.00,   0.00,   0.00,    0),
}

# Les emplois. Un seul coefficient par sous-type, et il ne concerne que les
# îlots `industrie` et `mixte` : le tissu résidentiel de Wehrau porte zéro
# emploi, ce qui est une décision, pas un oubli.
#
# ⚠ La friche industrielle est une FRICHE. Lui donner 25 emplois/ha, c'est dire
# qu'il reste un atelier et un dépôt dans une halle qui en abritait cent. Si on
# monte ce chiffre, on efface la raison d'être des deux îlots.
#
# Ce que ces coefficients produisent, il faut le regarder en face : Wehrau ne
# porte que 10,4 ha d'activité sur 38 ha bâtis. Quel que soit le coefficient,
# la ville sortira à ~0,15 emploi par habitant — un dortoir dont les gens
# partent travailler ailleurs. C'est cohérent avec l'axe de transit saturé et
# avec la voiture-dépendance, mais ce n'est pas un réglage : c'est la géométrie
# qui le dit. Pour en faire autre chose il faudrait du sol d'activité en plus.

PERSONNES_PAR_LOGEMENT = 2.1
SURFACE_PAR_PLACE = 25.0        # m² par place, accès compris
HABITANTS_VAULT = 5350          # ce que le vault annonce — contrôlé, pas subi.
                                # C'était 18000 (Vallmar) : périmé depuis que le
                                # prototype est Wehrau. → Décisions arrêtées 13d

# --- l'eau ----------------------------------------------------------------
# 🔄 LA CARTE EST PLATE depuis le 2026-08-12, à la demande de l'auteur — dans
# l'image ET dans la donnée. `altitude_relative` vaut donc 0 partout.
#
# Ce qu'il y avait avant, et qu'il faudrait réécrire pour revenir en arrière :
# une vallée sans MNT, remontant de part et d'autre de l'Ilse avec une pente
# qui s'adoucissait vers l'aval (3,2 % → 1,3 %, plafond à 9 m). Elle ne s'est
# jamais vue à l'écran — 9 m de relief sur 898 m de large.
#
# 🔴 LA CRUE SORT DU PROTOTYPE, décidé par l'auteur le 2026-08-12 : *« pas de
# crue. on oublie la crue pour ce prototype »*. `alea` n'est donc plus dérivé
# de rien — la colonne reste dans le GeoPackage, à 0, pour que rien de ce qui
# la lit ne casse, mais elle ne prétend plus mesurer quoi que ce soit.
#
# Ce qu'il faudrait pour la rallumer : une règle qui dise jusqu'où l'eau monte.
# Elle tenait à l'altitude, qui n'existe plus ; sur une carte plate elle
# tiendrait à la DISTANCE À L'EAU (une portée de crue en mètres, modulée de
# l'amont vers l'aval). Mesuré avant de renoncer : à 250 m de portée, l'aléa
# moyen par rive retombait à 0,74 rive gauche et 0,39 rive droite, contre 0,75
# et 0,43 par l'altitude. La règle changeait, pas la carte du risque.
#
# ⚠️ Ce qui RESTE, et qui n'est pas de la crue : `rive` et `position_fil_eau`.
# Ce sont des positions le long de l'eau, pas des risques — et c'est
# `position_fil_eau` qui porte la portée « aval » d'une décision (08).

# --- les rues -------------------------------------------------------------
# Ce qu'il faut réserver à la circulation, par hiérarchie : chaussée + trottoirs.
# Le reste est l'emprise disponible — pour des arbres, une noue, ou des voitures.
EMPRISE_CIRCULATION = {
    "autoroute": 25.0, "boulevard": 10.5, "rue": 8.5,
    "ruelle": 4.0, "rive": 6.5, "voie ferree": 8.0,
}
LONGUEUR_PLACE = 5.5            # m de bordure par place en stationnement long.
LARGEUR_QUAI = 22.0             # la voie rapide de berge — ses mètres libres
                                # sont des files de circulation, pas du parking
CANOPEE_RUE = {"boulevard": 0.18, "rue": 0.10, "ruelle": 0.02,
               "rive": 0.05, "autoroute": 0.0, "voie ferree": 0.0}

# Vitesse retenue pour l'affectation du trafic. Le trafic ne prend pas le
# chemin le plus court, il prend le plus rapide : c'est ce qui charge l'axe
# de transit plutôt que les ruelles du cœur.
VITESSE = {"autoroute": 70.0, "boulevard": 50.0, "rue": 30.0,
           "ruelle": 12.0, "rive": 25.0, "voie ferree": 0.0}
PART_TRANSIT = 0.55             # trafic d'échange (par les radiales) vs local

# --- les saisies à la main, protégées du recalcul -------------------------
# `exception = 1`. C'est le level design qui ne se déduit d'aucune règle.
FORCE = {
    # Cœurs d'îlot verts privatisés : invisibles depuis la rue, et pourtant le
    # seul vrai gisement de fraîcheur du centre. → [[Wehrau]]
    44: {"canopee": 0.55, "impermeabilise": 0.50},
    49: {"canopee": 0.55, "impermeabilise": 0.50},
}

# Les îlots que le vault raconte. On les relit dans les données pour vérifier
# que le récit et la géométrie disent la même chose. → [[Wehrau]]
PLAIES = {
    19: "la place-parking",
    45: "la galerie de 1971",
    32: "le grand ensemble 1974",
    31: "la friche du moulin",
    65: "la friche de la brasserie",
}


# ==========================================================================
# mécanique — rien à régler en dessous
# ==========================================================================

def gpkg_vers_wkb(blob):
    return blob[8 + {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[(blob[3] >> 1) & 0x07]:]


def _e(buf, off, o):
    return struct.unpack_from(o + "I", buf, off)[0], off + 4


def _p(buf, off, o, n):
    c = struct.unpack_from(o + "%dd" % (2 * n), buf, off)
    return [(c[i], c[i + 1]) for i in range(0, 2 * n, 2)], off + 16 * n


def lire_wkb(buf, off=0):
    o = "<" if buf[off] == 1 else ">"
    off += 1
    g, off = _e(buf, off, o)
    base = g % 1000
    if base == 2:
        n, off = _e(buf, off, o)
        pts, off = _p(buf, off, o, n)
        return [pts], off
    if base == 3:
        na, off = _e(buf, off, o)
        r = []
        for _ in range(na):
            n, off = _e(buf, off, o)
            pts, off = _p(buf, off, o, n)
            r.append(pts)
        return r, off
    if base in (5, 6):
        ng, off = _e(buf, off, o)
        t = []
        for _ in range(ng):
            p, off = lire_wkb(buf, off)
            t.extend(p)
        return t, off
    raise ValueError("WKB %d" % base)


def enveloppe(blob):
    ind = (blob[3] >> 1) & 0x07
    if ind in (1, 2, 3, 4):
        return struct.unpack_from(("<" if blob[3] & 1 else ">") + "4d", blob, 8)
    parts, _ = lire_wkb(gpkg_vers_wkb(blob))
    xs = [p[0] for pa in parts for p in pa]
    ys = [p[1] for pa in parts for p in pa]
    return (min(xs), max(xs), min(ys), max(ys))


def brancher_fonctions_spatiales(con):
    """Les déclencheurs d'index spatial du GeoPackage appellent ST_*, que
    SQLite seul n'a pas. La géométrie n'étant jamais modifiée, ces fonctions
    ne font que relire ce qui est déjà écrit."""
    con.create_function("ST_IsEmpty", 1, lambda b: 0 if b else 1)
    for i, nom in enumerate(("ST_MinX", "ST_MaxX", "ST_MinY", "ST_MaxY")):
        con.create_function(
            nom, 1, (lambda k: lambda b: enveloppe(b)[k] if b else None)(i))


def centroide(anneau):
    cx = cy = a = 0.0
    for i in range(len(anneau) - 1):
        x1, y1 = anneau[i]
        x2, y2 = anneau[i + 1]
        cr = x1 * y2 - x2 * y1
        a += cr
        cx += (x1 + x2) * cr
        cy += (y1 + y2) * cr
    if a == 0:
        return anneau[0]
    return (cx / (3 * a), cy / (3 * a))


def dist_pt_seg(p, a, b):
    px, py = p
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    if L2 == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def borne(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def axe_principal(points):
    """Direction dominante d'un nuage de points (analyse en composantes
    principales, forme close en 2D)."""
    n = len(points)
    mx = sum(p[0] for p in points) / n
    my = sum(p[1] for p in points) / n
    sxx = sxy = syy = 0.0
    for x, y in points:
        dx, dy = x - mx, y - my
        sxx += dx * dx
        sxy += dx * dy
        syy += dy * dy
    tr, det = (sxx + syy) / n, (sxx * syy - sxy * sxy) / (n * n)
    lam = tr / 2 + math.sqrt(max(0.0, tr * tr / 4 - det))
    vx, vy = (lam - syy / n, sxy / n) if abs(sxy) > 1e-9 else (1.0, 0.0)
    L = math.hypot(vx, vy) or 1.0
    return (mx, my), (vx / L, vy / L)


# ---------------------------------------------------------------- le trafic

def charge_reseau(rues):
    """Affectation de trafic minimale : le plus court chemin en TEMPS entre
    les nœuds du réseau. Deux demandes superposées — l'échange (entre les
    radiales qui sortent de la carte) et le local (tous les nœuds entre eux).

    Ce n'est pas une simulation : c'est le socle sur lequel « fermer une rue
    reporte sa charge sur les voisines » devient calculable. → brainstorm §5
    """
    G = 0.5

    def cle(p):
        return (round(p[0] / G), round(p[1] / G))

    # Un nœud par SOMMET, pas seulement par extrémité de tronçon : sinon les
    # rues qui se raccordent en T au milieu d'un tronçon sont vues comme
    # déconnectées, et le réseau tombe en morceaux.
    # Une berge à largeur nulle est une rive, pas une voie : hors graphe.
    voisins = {}
    for fid, d in rues.items():
        h = d["hier"]
        if h == "rive" and not d["largeur"]:
            continue
        v = VITESSE.get(h, 30.0)
        if v <= 0:
            continue
        for p in d["parts"]:
            for i in range(len(p) - 1):
                a, b = cle(p[i]), cle(p[i + 1])
                if a == b:
                    continue
                L = math.hypot(p[i + 1][0] - p[i][0], p[i + 1][1] - p[i][1])
                t = L / (v / 3.6)
                voisins.setdefault(a, []).append((b, t, fid))
                voisins.setdefault(b, []).append((a, t, fid))
    if not voisins:
        return {}, []

    degre = {n: len(v) for n, v in voisins.items()}
    portes = [n for n, k in degre.items() if k == 1]      # sorties de carte
    # les sommets de degré 2 ne sont que des points de courbure : le trafic
    # naît et meurt aux carrefours
    carrefours = [n for n, k in degre.items() if k != 2]

    def dijkstra(src):
        dist = {src: 0.0}
        prec = {}
        tas = [(0.0, src)]
        while tas:
            dt, u = heapq.heappop(tas)
            if dt > dist.get(u, 1e18) + 1e-9:
                continue
            for v, t, fid in voisins.get(u, ()):
                nd = dt + t
                if nd < dist.get(v, 1e18) - 1e-9:
                    dist[v] = nd
                    prec[v] = (u, fid)
                    heapq.heappush(tas, (nd, v))
        return dist, prec

    def accumuler(sources, cibles, compteur):
        for s in sources:
            _, prec = dijkstra(s)
            for t in cibles:
                if t == s or t not in prec:
                    continue
                u = t
                while u in prec:
                    u, fid = prec[u]
                    compteur[fid] = compteur.get(fid, 0) + 1

    c_transit, c_local = {}, {}
    accumuler(portes, portes, c_transit)
    accumuler(carrefours, carrefours, c_local)

    def norme(c):
        """Normaliser par le maximum écraserait tout : un seul tronçon porte
        l'essentiel des plus courts chemins. On cale sur le 9e décile et on
        étire le bas de l'échelle, pour que « chargée » et « très chargée »
        restent distinguables à l'œil."""
        if not c:
            return {}
        v = sorted(c.values())
        p95 = v[int(0.95 * (len(v) - 1))] or 1.0
        return {k: min(1.0, x / p95) ** 0.6 for k, x in c.items()}

    ct, cl = norme(c_transit), norme(c_local)
    charge = {}
    for fid in rues:
        charge[fid] = round(borne(PART_TRANSIT * ct.get(fid, 0.0)
                                  + (1 - PART_TRANSIT) * cl.get(fid, 0.0)), 3)

    # composantes connexes : le réseau routier doit tenir d'un seul tenant
    vus, morceaux = set(), []
    for n in voisins:
        if n in vus:
            continue
        pile, taille = [n], 0
        vus.add(n)
        while pile:
            u = pile.pop()
            taille += 1
            for v, _t, _f in voisins[u]:
                if v not in vus:
                    vus.add(v)
                    pile.append(v)
        morceaux.append(taille)
    return charge, sorted(morceaux, reverse=True)


# ------------------------------------------------------------------- main

def main():
    if not os.path.exists(GPKG):
        raise SystemExit("introuvable : %s\nLancer 02 puis 03 d'abord." % GPKG)
    con = sqlite3.connect(GPKG)
    brancher_fonctions_spatiales(con)
    cur = con.cursor()

    # ------------------------------------------------------ lecture
    ilots = {}
    for fid, blob, st, surf in cur.execute(
            "SELECT fid, geom, sous_type, surface_m2 FROM ilots"):
        anneaux, _ = lire_wkb(gpkg_vers_wkb(blob))
        ilots[fid] = {"anneaux": anneaux, "st": st, "surf": surf or 0.0,
                      "c": centroide(anneaux[0])}

    rues = {}
    for fid, blob, h, w in cur.execute(
            "SELECT fid, geom, hierarchie, largeur_m FROM routes"):
        parts, _ = lire_wkb(gpkg_vers_wkb(blob))
        rues[fid] = {"parts": parts, "hier": (h or "").strip().lower(),
                     "largeur": w or 0.0,
                     "long": sum(math.hypot(p[i + 1][0] - p[i][0],
                                            p[i + 1][1] - p[i][1])
                                 for p in parts for i in range(len(p) - 1))}

    adj = list(cur.execute("SELECT id_a, id_b, hierarchie_separatrice, "
                           "longueur_m FROM adjacences"))

    inconnus = sorted({d["st"] for d in ilots.values()} - set(TISSU))
    if inconnus:
        raise SystemExit("sous_type sans ligne dans TISSU : %s" % inconnus)

    # ------------------------------------------------------ l'eau
    riv = [f for f, d in ilots.items() if d["st"] == "riviere"]
    if not riv:
        raise SystemExit("aucun îlot `riviere` : le fil de l'eau est indéfini.")
    sommets = [p for f in riv for a in ilots[f]["anneaux"] for p in a]
    _, u = axe_principal(sommets)
    if u[1] > 0:                        # l'Ilse coule vers le sud
        u = (-u[0], -u[1])

    segs_riv = [(a[i], a[i + 1])
                for f in riv for a in ilots[f]["anneaux"]
                for i in range(len(a) - 1)]
    # Le fil de l'eau se mesure en latitude, pas en projection sur un axe
    # droit : l'Ilse décrit un grand S d'ouest en est, et une droite la
    # décrirait mal. Elle traverse toute la carte du nord au sud, donc
    # « où est-on le long de la rivière » = « à quelle hauteur est-on ».
    ynord = max(p[1] for p in sommets)
    ysud = min(p[1] for p in sommets)

    for fid, d in ilots.items():
        c = d["c"]
        # le segment de berge le plus proche : c'est lui qui donne à la fois
        # la distance à l'eau et le sens local du courant
        proche = min(((dist_pt_seg(c, a, b), a, b) for a, b in segs_riv),
                     key=lambda t: t[0])
        d["dist_eau"] = 0.0 if d["st"] == "riviere" else proche[0]
        d["fil"] = round(borne((ynord - c[1]) / (ynord - ysud)), 3)

        # rive gauche / droite : face à l'aval, la gauche est à gauche. On
        # prend la direction LOCALE de la berge, orientée vers l'aval —
        # sur un méandre, un axe global se tromperait de rive.
        a, b = proche[1], proche[2]
        vx, vy = b[0] - a[0], b[1] - a[1]
        if vx * u[0] + vy * u[1] < 0:
            vx, vy = -vx, -vy
        cote = vx * (c[1] - a[1]) - vy * (c[0] - a[0])
        d["rive"] = "lit" if d["st"] == "riviere" else \
            ("gauche" if cote > 0 else "droite")

        # Carte plate, crue hors prototype : les deux colonnes restent, à 0.
        d["alt"] = 0.0
        d["alea"] = 0.0

    # ------------------------------------------------------ desserte TC
    # Le bus passe où la rue est large. Une frontière de boulevard trop courte
    # ne dessert pas : d'où la pondération par le linéaire.
    BASE_TC = {"boulevard": 0.85, "rue": 0.40, "ruelle": 0.15,
               "rive": 0.0, "sans_rue": 0.0, "voie ferree": 0.0,
               "autoroute": 0.0}
    tc = {f: 0.0 for f in ilots}
    for a, b, h, L in adj:
        v = BASE_TC.get(h, 0.0) * min(1.0, (L or 0.0) / 60.0)
        for f in (a, b):
            if f in tc and v > tc[f]:
                tc[f] = v

    # ------------------------------------------------------ le tissu
    for fid, d in ilots.items():
        dens, haut, imp, can, riv_frag, park, emploi = TISSU[d["st"]]
        ha = d["surf"] / 1e4
        d["densite"] = float(dens)
        d["logements"] = int(round(dens * ha))
        d["emplois"] = int(round(emploi * ha))
        d["hauteur"] = haut
        d["impermeabilise"] = imp
        d["canopee"] = can
        d["riverain"] = riv_frag
        d["stationnement"] = int(round(d["surf"] * park / SURFACE_PAR_PLACE))
        d["desserte_tc"] = round(tc[fid], 2)
        d["forcé"] = False

    for fid, vals in FORCE.items():
        if fid not in ilots:
            raise SystemExit("FORCE : l'îlot %d n'existe pas" % fid)
        ilots[fid].update(vals)
        ilots[fid]["forcé"] = True

    # ------------------------------------------------------ les rues
    charge, morceaux = charge_reseau(rues)
    for fid, d in rues.items():
        h = d["hier"]
        libre = max(0.0, d["largeur"] - EMPRISE_CIRCULATION.get(h, 8.5))
        d["libre"] = round(libre, 1)
        # la voie rapide de berge : ses mètres libres sont des files, pas des
        # places. C'est précisément ce que sa suppression rendrait.
        quai = (h == "boulevard" and abs(d["largeur"] - LARGEUR_QUAI) < 0.1)
        cotes = 0 if (libre < 2.0 or quai) else (2 if libre >= 4.5 else 1)
        d["places"] = int(round(cotes * d["long"] / LONGUEUR_PLACE))
        d["canopee"] = 0.0 if quai else CANOPEE_RUE.get(h, 0.05)
        d["charge"] = charge.get(fid, 0.0)

    # ------------------------------------------------------ écriture
    COLS_I = [("densite", "REAL"), ("logements", "INTEGER"),
              ("emplois", "INTEGER"),
              ("hauteur", "REAL"), ("impermeabilise", "REAL"),
              ("canopee", "REAL"), ("desserte_tc", "REAL"),
              ("riverain", "REAL"), ("stationnement", "INTEGER"),
              ("altitude_relative", "REAL"), ("alea", "REAL"),
              ("position_fil_eau", "REAL"), ("rive", "TEXT")]
    COLS_R = [("emprise_libre_m", "REAL"), ("stationnement", "INTEGER"),
              ("charge", "REAL"), ("canopee", "REAL")]

    if not BLANC:
        for t, cols in (("ilots", COLS_I), ("routes", COLS_R)):
            for c, typ in cols:
                try:
                    cur.execute('ALTER TABLE %s ADD COLUMN %s %s' % (t, c, typ))
                except sqlite3.OperationalError:
                    pass
        for fid, d in ilots.items():
            cur.execute(
                "UPDATE ilots SET densite=?, logements=?, emplois=?, hauteur=?, "
                "impermeabilise=?, canopee=?, desserte_tc=?, riverain=?, "
                "stationnement=?, altitude_relative=?, alea=?, "
                "position_fil_eau=?, rive=? WHERE fid=?",
                (d["densite"], d["logements"], d["emplois"], d["hauteur"],
                 d["impermeabilise"], d["canopee"], d["desserte_tc"],
                 d["riverain"], d["stationnement"], d["alt"], d["alea"],
                 d["fil"], d["rive"], fid))
        for fid in FORCE:
            cur.execute("UPDATE ilots SET exception=1 WHERE fid=?", (fid,))
        for fid, d in rues.items():
            cur.execute("UPDATE routes SET emprise_libre_m=?, stationnement=?, "
                        "charge=?, canopee=? WHERE fid=?",
                        (d["libre"], d["places"], d["charge"], d["canopee"], fid))
        con.commit()

    # ------------------------------------------------------ compte rendu
    W = 74
    print("=" * W)
    print("ATTRIBUTS DÉRIVÉS%s" % ("   [--blanc : rien n'est écrit]" if BLANC else ""))
    print("=" * W)

    print("\nLE TISSU")
    print("  %-20s %3s %7s %6s %6s %5s %5s %5s %5s %5s"
          % ("sous_type", "n", "ha", "log.", "empl.", "ét.", "imp", "can",
             "frag", "park"))
    par_st = {}
    for fid, d in ilots.items():
        par_st.setdefault(d["st"], []).append(fid)
    tot_log = tot_park_i = tot_emp = 0
    for st in sorted(par_st, key=lambda k: -sum(ilots[f]["logements"]
                                                for f in par_st[k])):
        fs = par_st[st]
        ha = sum(ilots[f]["surf"] for f in fs) / 1e4
        log = sum(ilots[f]["logements"] for f in fs)
        emp = sum(ilots[f]["emplois"] for f in fs)
        park = sum(ilots[f]["stationnement"] for f in fs)
        tot_log += log
        tot_emp += emp
        tot_park_i += park
        t = TISSU[st]
        print("  %-20s %3d %7.1f %6d %6d %5.1f %5.2f %5.2f %5.2f %5d"
              % (st, len(fs), ha, log, emp, t[1], t[2], t[3], t[4], park))

    hab = tot_log * PERSONNES_PAR_LOGEMENT
    ha_bati = sum(d["surf"] for d in ilots.values()
                  if d["st"] not in ("champ", "riviere")) / 1e4
    print("\n  → %d logements · %.0f habitants sur %.1f ha bâtis"
          % (tot_log, hab, ha_bati))
    print("    (%.0f hab/ha bâti — un centre allemand dense plafonne vers 350)"
          % (hab / max(1.0, ha_bati)))
    print("    CONTRÔLE — le vault annonce %d habitants pour Wehrau."
          % HABITANTS_VAULT)
    ecart = hab / float(HABITANTS_VAULT)
    if 0.9 <= ecart <= 1.1:
        print("    ✅ cohérent (%.0f %% de la cible)" % (ecart * 100))
    else:
        print("    ⚠️  la carte n'en porte que %.0f %%, et la table de densité"
              % (ecart * 100))
        print("       est déjà au plafond du réalisme. Il faudrait %.0f hab/ha"
              % (HABITANTS_VAULT / max(1.0, ha_bati)))
        print("       bâti pour tenir le chiffre. La géométrie est la source de")
        print("       vérité (décision 31b) : c'est le vault qu'il faut corriger.")

    ha_act = sum(d["surf"] for d in ilots.values() if d["emplois"]) / 1e4
    print("\nLES EMPLOIS")
    print("  → %d emplois sur %.1f ha d'activité (industrie + mixte)"
          % (tot_emp, ha_act))
    print("    soit %.2f emploi par habitant." % (tot_emp / max(1.0, hab)))
    if tot_emp / max(1.0, hab) < 0.35:
        print("    ⚠️  Wehrau est un dortoir : la ville n'a que %.0f %% du sol"
              % (100 * ha_act / max(1.0, ha_bati)))
        print("       bâti en activité. Ce n'est pas un coefficient trop bas,")
        print("       c'est la géométrie — il faudrait dessiner du sol d'activité.")
        print("       Cohérent avec l'axe de transit saturé : les gens sortent.")

    print("\nL'EAU  (crue hors prototype — il reste les DEUX RIVES et l'amont/aval)")
    for cote in ("gauche", "droite", "lit"):
        fs = [f for f, d in ilots.items() if d["rive"] == cote]
        if not fs:
            continue
        log = sum(ilots[f]["logements"] for f in fs)
        print("  rive %-8s %2d îlots · %5d logements · %3.0f m de l'eau en moyenne"
              % (cote, len(fs), log,
                 sum(ilots[f]["dist_eau"] for f in fs) / len(fs)))
    amont = [f for f, d in ilots.items() if d["fil"] < 0.34 and d["st"] != "riviere"]
    aval = [f for f, d in ilots.items() if d["fil"] > 0.66 and d["st"] != "riviere"]
    for nom, fs in (("amont", amont), ("aval", aval)):
        if fs:
            print("  %-6s      %2d îlots · %4d logements · fragilité %.2f"
                  % (nom, len(fs), sum(ilots[f]["logements"] for f in fs),
                     sum(ilots[f]["riverain"] for f in fs) / len(fs)))

    print("\n  LES QUATRE PLAIES DE 1965, RELUES DANS LES DONNÉES")
    print("  (le vault les raconte ; voici où elles tombent vraiment)")
    for fid, nom in sorted(PLAIES.items()):
        if fid not in ilots:
            continue
        d = ilots[fid]
        print("    %-24s îlot %-3d rive %-7s fil %.2f · %3.0f m de l'eau"
              % (nom, fid, d["rive"], d["fil"], d["dist_eau"]))
        print("    %-24s %d places · fragilité %.2f"
              % ("", d["stationnement"], d["riverain"]))

    # 🔄 IL Y AVAIT ICI le tableau « si le jeu s'ouvrait sur une crue » — trois
    # hauteurs d'eau, les logements et la fragilité touchés. La crue sort du
    # prototype le 2026-08-12 ; le tableau part avec elle.

    print("\nLES RUES")
    print("  %-12s %3s %8s %8s %8s %6s"
          % ("hiérarchie", "n", "km", "libre m", "places", "charge"))
    par_h = {}
    for fid, d in rues.items():
        par_h.setdefault(d["hier"], []).append(fid)
    tot_places = 0
    for h in sorted(par_h, key=lambda k: -sum(rues[f]["long"] for f in par_h[k])):
        fs = par_h[h]
        pl = sum(rues[f]["places"] for f in fs)
        tot_places += pl
        lib = [rues[f]["libre"] for f in fs]
        print("  %-12s %3d %8.2f %8s %8d %6.2f"
              % (h, len(fs), sum(rues[f]["long"] for f in fs) / 1000,
                 "%.1f–%.1f" % (min(lib), max(lib)) if min(lib) != max(lib)
                 else "%.1f" % lib[0],
                 pl, sum(rues[f]["charge"] for f in fs) / len(fs)))
    print("\n  → %d places sur rue + %d places sur îlot = %d au total"
          % (tot_places, tot_park_i, tot_places + tot_park_i))
    print("    soit %.2f place par logement." % ((tot_places + tot_park_i)
                                                 / max(1, tot_log)))
    if morceaux and len(morceaux) > 1:
        print("  ⚠️  réseau routier en %d morceaux %s" % (len(morceaux), morceaux))
    else:
        print("  ✅ réseau routier d'un seul tenant (%d nœuds)"
              % (morceaux[0] if morceaux else 0))

    print("\n  LA DOCTRINE À SEUIL — « je plante sur toute rue dont l'emprise")
    print("  libre dépasse X mètres » (brainstorm §7). Ce que X change :")
    print("    %5s %6s %8s   %s" % ("X", "rues", "km", "ce que ça touche"))
    for X in (2.0, 3.0, 4.0, 5.0, 7.0, 9.0):
        fs = [f for f, d in rues.items() if d["libre"] >= X]
        km = sum(rues[f]["long"] for f in fs) / 1000
        hs = {}
        for f in fs:
            hs[rues[f]["hier"]] = hs.get(rues[f]["hier"], 0) + 1
        desc = " · ".join("%s %d" % (k, v)
                          for k, v in sorted(hs.items(), key=lambda x: -x[1]))
        print("    %5.0f %6d %8.2f   %s" % (X, len(fs), km, desc or "—"))
    print("    Le cœur ancien n'est jamais concerné : ses ruelles n'ont pas")
    print("    1,1 m de libre. L'effet est spatialement inégal par construction.")

    print("\n  LES CINQ RUES LES PLUS CHARGÉES")
    top = sorted(rues, key=lambda f: -rues[f]["charge"])[:5]
    for f in top:
        d = rues[f]
        print("    tronçon %-4d %-10s %5.0f m · charge %.2f · %d places"
              % (f, d["hier"], d["long"], d["charge"], d["places"]))

    print("\nSAISIES PROTÉGÉES  %d îlots %s (exception=1)"
          % (len(FORCE), sorted(FORCE)))
    print("\n%s" % ("rien écrit (--blanc)" if BLANC
                    else "→ écrit dans %s" % os.path.basename(GPKG)))
    print("=" * W)
    con.close()


if __name__ == "__main__":
    main()
