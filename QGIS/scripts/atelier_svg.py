# -*- coding: utf-8 -*-
"""
LE PONT AVEC ILLUSTRATOR — l'auteur dessine en SVG, la chaîne reprend.

    python QGIS/scripts/atelier_svg.py --exporter            fabrique le gabarit
    python QGIS/scripts/atelier_svg.py --reprendre --blanc   montre, n'écrit rien
    python QGIS/scripts/atelier_svg.py --reprendre           écrit dans la SOURCE

Même famille qu'`atelier.py`, mêmes garde-fous : arbre git propre exigé,
`--blanc` disponible, contrôles en français.

🔴 CE QUI SE DESSINE OÙ, ET POURQUOI CE N'EST PAS SYMÉTRIQUE
Illustrator n'a pas d'accrochage topologique : deux polygones voisins y sont
voisins À L'ŒIL, jamais dans les données, et `03` perd « qui touche qui » sans
rien dire. D'où deux régimes :

  calque `coupes`          des TRAITS OUVERTS. Un trait qui traverse un champ
                           le coupe en deux — c'est `00_decouper_ilots` qui
                           fabrique la géométrie, donc la topologie est juste
                           par construction. Rien à faire coïncider.
  `eau` `relief` `bois`    des FORMES FERMÉES, hors du rectangle jouable, où
                           aucune adjacence n'est calculée. Le tracé libre y
                           est sans risque.

Le repère est le rectangle `cadre-geo`, sur un calque verrouillé. Le déplacer
ou le supprimer casse le géoréférencement : le script refuse alors d'écrire.
"""
import math
import os
import re
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import carte
import atelier
import importlib
decouper = importlib.import_module("00_decouper_ilots")

# Deux fichiers, et les confondre écraserait le dessin : `--exporter` fabrique
# un CALQUE DE DÉPART jetable dans `travail/`, `--reprendre` lit LE DESSIN de
# l'auteur, suivi par git.
GABARIT_NEUF = os.path.join(carte.TRAVAIL, "wehrau_gabarit.svg")
GABARIT = os.path.join(os.path.dirname(carte.DATA), "wehrau_gabarit2.svg")

# 🔴 LA MARGE EST L'ESPACE DE DESSIN DU DÉCOR, en mètres autour du rectangle
# jouable. 1800 m : au-delà, `export_godot/paysage.py` ne fabriquait déjà que
# du fond lointain, et l'artboard dépasserait la limite d'Illustrator.
MARGE = 1800.0
# Une unité SVG = un mètre. Aucun facteur à retenir, aucune échelle à régler.
# 🔴 CE QUI DEVIENT DU SOL JOUABLE, et la liste de `02_qualifier.py` que ce
# calque remplace. Le reste — forêt, massifs — est du décor et va en `paysage`.
# L'eau a rejoint le sol le 2026-09-15 : l'Ilse redessinée doit remplacer les
# îlots `riviere`, sinon l'ancien tracé reste sous le neuf et se voit.
CALQUES_SOL = {"champs": "CHAMPS", "eau": "RIVIERE"}
# 🔴 LE CALQUE DIT CE QU'EST LE SOL, et c'est écrit sur l'îlot (`sol`) au lieu
# d'une liste de fid dans `02`. Le 2026-09-15 les champs neufs sont tombés sur
# 73 et 74, déjà pavillonnaires : `02` s'arrêtait sur « îlot 73 affecté deux
# fois ». Le vocabulaire est celui des `sous_type` de `02`.
SOL_SOUS_TYPE = {"champs": "champ", "eau": "riviere"}
# Le sol dessiné se numérote À PART, au-dessus de la ville : une reprise du
# gabarit renumérote la campagne, jamais un îlot que les listes de `02` nomment.
FID_SOL = 1000
GENRES_CALQUES = {"relief": "relief", "bois": "bois"}
CALQUES_DESSIN = ["coupes", "champs", "domaines", "emprise"] + list(GENRES_CALQUES)

# 🔴 C'EST LE DESSIN ENTIER QUI REMPLACE UN ÎLOT-CHAMP, pas le seul damier :
# l'auteur redonne une partie de ses anciens champs à la forêt et à l'eau
# (îlot 6 entièrement, îlot 8 aux deux tiers — 2026-09-15). Juger sur le seul
# damier faisait voir des trous là où il y a des bois. En dessous du seuil
# l'îlot est gardé, et ce que le dessin y mord est annoncé.
# 0.95 et non 1.00 : la maille de mesure perd un liseré sur le contour.
COUVERTURE_REMPLACE = 0.95
PAS_MESURE = 2.0
# = `GRILLE` de `03_adjacences.py`. En dessous, deux sommets sont le même, et
# c'est à cette condition que deux champs voisins se savent voisins : sans la
# soudure, Illustrator laisse 1,8 % du linéaire hors adjacence (2026-09-15).
SOUDURE_M = 0.25

# 🔴 LE NOM DU CALQUE EST CELUI QUE L'AUTEUR TAPE dans Illustrator, pas celui
# du gabarit : il renomme, duplique (`champs 2`), accentue. La clé se compare
# sans casse, sans accent, sans chiffre ni suffixe final, et cette table dit
# quel mot mène où. Un calque absent d'ici est ANNONCÉ, jamais ignoré en
# silence — c'est comme ça qu'on voit qu'un dessin n'a pas été repris.
ALIAS_CALQUES = {
    "coupes": "coupes", "coupe": "coupes",
    "champs": "champs", "champ": "champs", "parcelle": "champs",
    "domaines": "domaines", "domaine": "domaines", "ferme": "domaines",
    "emprise": "emprise", "cadre": "emprise", "monde": "emprise",
    "eau": "eau", "ilse": "eau", "riviere": "eau",
    "relief": "relief", "montagne": "relief", "massif": "relief",
    "bois": "bois", "foret": "bois", "boisement": "bois",
}

# Un point tous les 2 m suffit : à l'écran un champ fait 200 m de large, et la
# chaîne ne relit jamais une courbe, seulement des segments.
PAS_COURBE = 2.0

NS = "http://www.w3.org/2000/svg"


# ==========================================================================
# --exporter
# ==========================================================================

def _couleurs():
    connus = atelier.listes_connues()
    de = {}
    for fid in connus.get("CHAMPS") or []:
        de[fid] = ("#96b26a", "#5a7846", "champ")
    for fid in connus.get("RIVIERE") or []:
        de[fid] = ("#68adb3", "#3c7882", "eau")
    return de, connus


def exporter():
    couches = carte.lire_source()
    de, connus = _couleurs()
    x0, y0, x1, y1 = carte._enveloppe(couches["ilots"])
    X0, Y0, X1, Y1 = x0 - MARGE, y0 - MARGE, x1 + MARGE, y1 + MARGE
    L, H = X1 - X0, Y1 - Y0

    def pt(p):
        return "%.2f,%.2f" % (p[0] - X0, Y1 - p[1])

    def chemin(parts, fermer=True):
        d = []
        for pts in parts:
            d.append("M" + " L".join(pt(p) for p in pts) + ("Z" if fermer else ""))
        return " ".join(d)

    corps = []
    corps.append('<g id="_reference-fond">'
                 '<rect x="0" y="0" width="%.2f" height="%.2f" fill="#eef4ef"/>'
                 '<rect id="cadre-geo" x="%.2f" y="%.2f" width="%.2f" height="%.2f" '
                 'fill="none" stroke="#c8b8a0" stroke-width="3" stroke-dasharray="18 12"/>'
                 '</g>' % (L, H, MARGE, MARGE, x1 - x0, y1 - y0))

    ilots, etiquettes = [], []
    for e in couches["ilots"]:
        fid = e["fid"]
        remp, trait, quoi = de.get(fid, ("#e8e2d4", "#8a8578", "bati"))
        ilots.append('<path id="ilot-%d" d="%s" fill="%s" stroke="%s" '
                     'stroke-width="1.2"/>' % (fid, chemin(e["parts"]), remp, trait))
        if quoi == "champ":
            xs = [p[0] for p in e["parts"][0]]
            ys = [p[1] for p in e["parts"][0]]
            cx, cy = sum(xs) / len(xs), sum(ys) / len(ys)
            etiquettes.append('<text x="%.2f" y="%.2f" font-family="Helvetica" '
                              'font-size="34" fill="#33502c" text-anchor="middle">%d</text>'
                              % (cx - X0, Y1 - cy, fid))
    corps.append('<g id="_reference-ilots">%s</g>' % "".join(ilots))
    corps.append('<g id="_reference-rues">%s</g>'
                 % "".join('<path d="%s" fill="none" stroke="#c8503c" '
                           'stroke-width="2.4"/>' % chemin(e["parts"], False)
                           for e in couches["routes"]))
    corps.append('<g id="_reference-numeros">%s</g>' % "".join(etiquettes))

    for nom in CALQUES_DESSIN:
        corps.append('<g id="%s"></g>' % nom)

    svg = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<svg xmlns="%s" version="1.1" width="%.2fpt" height="%.2fpt" '
           'viewBox="0 0 %.2f %.2f">\n'
           '<title>Wehrau — gabarit de dessin</title>\n'
           '<desc>geo:EPSG:25832 cadre=%r,%r,%r,%r marge=%r</desc>\n'
           '%s\n</svg>\n'
           % (NS, L, H, L, H, x0, y0, x1, y1, MARGE, "\n".join(corps)))
    os.makedirs(carte.TRAVAIL, exist_ok=True)
    with open(GABARIT_NEUF, "w", encoding="utf-8", newline="\n") as f:
        f.write(svg)

    print("\nGABARIT PRÊT")
    print("   %s" % GABARIT_NEUF)
    print("   %.0f × %.0f m — 1 unité = 1 mètre" % (L, H))
    print("\n   calques à dessiner")
    print("     coupes   des TRAITS OUVERTS en travers d'un champ → il se coupe en deux")
    print("     eau      des formes fermées : l'Ilse au-delà des bords")
    print("     relief   des formes fermées : les massifs")
    print("     bois     des formes fermées : les boisements")
    print("\n   🔴 ne pas toucher aux calques `_reference-*` ni au rectangle `cadre-geo`")
    print("   reprendre : python QGIS/scripts/atelier_svg.py --reprendre --blanc")


# ==========================================================================
# Lire un SVG : transformations, chemins, courbes
# ==========================================================================

def _matmul(m, n):
    a, b, c, d, e, f = m
    A, B, C, D, E, F = n
    return (a*A + c*B, b*A + d*B, a*C + c*D, b*C + d*D,
            a*E + c*F + e, b*E + d*F + f)


def _lire_transform(txt):
    m = (1, 0, 0, 1, 0, 0)
    for nom, args in re.findall(r"(\w+)\s*\(([^)]*)\)", txt or ""):
        v = [float(x) for x in re.split(r"[\s,]+", args.strip()) if x]
        if nom == "matrix" and len(v) == 6:
            n = tuple(v)
        elif nom == "translate":
            n = (1, 0, 0, 1, v[0], v[1] if len(v) > 1 else 0)
        elif nom == "scale":
            n = (v[0], 0, 0, v[1] if len(v) > 1 else v[0], 0, 0)
        elif nom == "rotate" and len(v) == 1:
            r = math.radians(v[0])
            n = (math.cos(r), math.sin(r), -math.sin(r), math.cos(r), 0, 0)
        else:
            continue
        m = _matmul(m, n)
    return m


def _applique(m, p):
    a, b, c, d, e, f = m
    return (a * p[0] + c * p[1] + e, b * p[0] + d * p[1] + f)


_NOMBRE = re.compile(r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")


def _cubique(p0, p1, p2, p3):
    lg = (math.dist(p0, p1) + math.dist(p1, p2) + math.dist(p2, p3))
    n = max(2, min(64, int(lg / PAS_COURBE) + 1))
    out = []
    for k in range(1, n + 1):
        t = k / n
        u = 1 - t
        out.append((u*u*u*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t*t*t*p3[0],
                    u*u*u*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t*t*t*p3[1]))
    return out


def _lire_d(d):
    """-> liste de (points, fermé). Les courbes sont aplaties, les arcs comptés."""
    jetons = re.findall(r"[MmLlHhVvCcSsQqTtAaZz]|%s" % _NOMBRE.pattern, d)
    i, cur, depart = 0, (0.0, 0.0), (0.0, 0.0)
    trace, sorties, cmd, ctrl, arcs = [], [], None, None, 0
    def nb():
        nonlocal i
        v = float(jetons[i]); i += 1; return v
    while i < len(jetons):
        if re.match(r"[A-Za-z]", jetons[i]):
            cmd = jetons[i]; i += 1
        elif cmd in ("M", "m"):
            cmd = "L" if cmd == "M" else "l"
        if cmd is None:
            i += 1; continue
        rel = cmd.islower()
        c = cmd.upper()
        if c == "Z":
            if trace:
                sorties.append((trace, True)); trace = []
            cur = depart
            continue
        if c == "M":
            if trace:
                sorties.append((trace, False))
            x, y = nb(), nb()
            cur = (cur[0] + x, cur[1] + y) if rel else (x, y)
            depart = cur; trace = [cur]; ctrl = None
        elif c in ("L", "T"):
            x, y = nb(), nb()
            cur = (cur[0] + x, cur[1] + y) if rel else (x, y)
            trace.append(cur); ctrl = None
        elif c == "H":
            x = nb(); cur = (cur[0] + x, cur[1]) if rel else (x, cur[1])
            trace.append(cur); ctrl = None
        elif c == "V":
            y = nb(); cur = (cur[0], cur[1] + y) if rel else (cur[0], y)
            trace.append(cur); ctrl = None
        elif c in ("C", "S"):
            if c == "C":
                p1 = (nb(), nb())
                if rel: p1 = (cur[0] + p1[0], cur[1] + p1[1])
            else:
                p1 = (2*cur[0] - ctrl[0], 2*cur[1] - ctrl[1]) if ctrl else cur
            p2 = (nb(), nb())
            if rel: p2 = (cur[0] + p2[0], cur[1] + p2[1])
            p3 = (nb(), nb())
            if rel: p3 = (cur[0] + p3[0], cur[1] + p3[1])
            trace.extend(_cubique(cur, p1, p2, p3))
            cur, ctrl = p3, p2
        elif c == "Q":
            q = (nb(), nb())
            if rel: q = (cur[0] + q[0], cur[1] + q[1])
            p3 = (nb(), nb())
            if rel: p3 = (cur[0] + p3[0], cur[1] + p3[1])
            trace.extend(_cubique(cur, (cur[0] + 2/3*(q[0]-cur[0]), cur[1] + 2/3*(q[1]-cur[1])),
                                  (p3[0] + 2/3*(q[0]-p3[0]), p3[1] + 2/3*(q[1]-p3[1])), p3))
            cur, ctrl = p3, q
        elif c == "A":
            for _ in range(5): nb()
            p3 = (nb(), nb())
            if rel: p3 = (cur[0] + p3[0], cur[1] + p3[1])
            trace.append(p3); cur, ctrl = p3, None
            arcs += 1
        else:
            i += 1
    if trace:
        sorties.append((trace, False))
    return sorties, arcs


def _formes(noeud, m):
    """-> liste de (points, fermé) en unités SVG racine. Récursif."""
    m = _matmul(m, _lire_transform(noeud.get("transform")))
    out, arcs = [], 0
    tag = noeud.tag.split("}")[-1]
    if tag == "path" and noeud.get("d"):
        brins, a = _lire_d(noeud.get("d")); arcs += a
        out += brins
    elif tag in ("polygon", "polyline"):
        v = [float(x) for x in re.split(r"[\s,]+", noeud.get("points", "").strip()) if x]
        pts = list(zip(v[::2], v[1::2]))
        if pts:
            out.append((pts, tag == "polygon"))
    elif tag == "rect":
        x, y = float(noeud.get("x", 0)), float(noeud.get("y", 0))
        w, h = float(noeud.get("width", 0)), float(noeud.get("height", 0))
        out.append(([(x, y), (x+w, y), (x+w, y+h), (x, y+h)], True))
    elif tag == "line":
        out.append(([(float(noeud.get("x1", 0)), float(noeud.get("y1", 0))),
                     (float(noeud.get("x2", 0)), float(noeud.get("y2", 0)))], False))
    for enfant in noeud:
        sous, a = _formes(enfant, m)
        out += sous; arcs += a
    return [([_applique(m, p) for p in pts], f) for pts, f in out], arcs


_ACCENTS = str.maketrans("àâäéèêëîïôöùûüç", "aaaeeeeiioouuuc")


def _clef(nom):
    """`Forêts 2` → `foret`. Ce qui reste est le mot, seul."""
    n = (nom or "").lower().translate(_ACCENTS)
    n = re.sub(r"[^a-z]+$", "", n)
    return re.sub(r"[^a-z]", "", n)


def _hors_calque(racine, vers_epsg):
    """Les tracés posés à la racine du SVG, hors de tout calque. Illustrator y
    laisse ce qu'on dessine sans avoir choisi de calque — et l'auteur y a mis
    l'emprise du monde le 2026-09-15. Les ignorer, c'est perdre son dessin
    sans un mot."""
    out = []
    for e in racine:
        if e.tag.split("}")[-1] in ("g", "defs", "title", "desc", "style"):
            continue
        for pts, ferme in _formes(e, (1, 0, 0, 1, 0, 0))[0]:
            out.append(([vers_epsg(p) for p in pts], ferme))
    return out


def _cible(nom):
    """-> le calque du gabarit visé par ce nom, ou None. Le pluriel se tente
    en second : `Forêts` mène à `foret`, mais `bois` ne devient pas `boi`."""
    k = _clef(nom)
    return ALIAS_CALQUES.get(k) or (
        ALIAS_CALQUES.get(k[:-1]) if k.endswith("s") else None)


def _groupes(racine, m=(1, 0, 0, 1, 0, 0)):
    """-> [(id, noeud, matrice des ANCÊTRES)] pour tout `<g>` nommé."""
    out = []

    def marche(noeud, mat):
        avant = mat
        mat = _matmul(mat, _lire_transform(noeud.get("transform")))
        ident = noeud.get("id")
        if ident and noeud.tag.split("}")[-1] == "g":
            out.append((ident, noeud, avant))
        for e in noeud:
            marche(e, mat)

    marche(racine, m)
    return out


def _trouver(racine, ident, m=(1, 0, 0, 1, 0, 0)):
    """Le calque ou l'objet portant cet id, où qu'il soit, avec la matrice de
    ses ANCÊTRES seulement — `_formes` applique ensuite la sienne."""
    def marche(noeud, mat):
        avant = mat
        mat = _matmul(mat, _lire_transform(noeud.get("transform")))
        if noeud.get("id") == ident:
            return noeud, avant
        for e in noeud:
            r = marche(e, mat)
            if r:
                return r
        return None
    return marche(racine, m)


# ==========================================================================
# --reprendre
# ==========================================================================

def _repere(racine, couches):
    """-> la fonction SVG → EPSG. Les îlots de référence d'abord, `cadre-geo`
    ensuite. Échoue si aucun des deux ne tient.

    🔴 ILLUSTRATOR JETTE `<desc>` ET LE RECTANGLE `cadre-geo` à l'export : le
    pont refusait alors tout dessin de l'auteur. Les `ilot-N`, eux, survivent
    — ce sont des tracés visibles —, ils portent la même information et se
    contrôlent tout seuls : on sait de combien ils retombent à côté."""
    sur_ilots = _repere_sur_ilots(racine, couches)
    if sur_ilots:
        return sur_ilots
    return _repere_sur_cadre(racine)


def _repere_sur_ilots(racine, couches):
    """Recale le dessin sur les îlots de référence appariés par leur `id`."""
    paires = []
    for e in couches["ilots"]:
        trouve = _trouver(racine, "ilot-%d" % e["fid"])
        if not trouve:
            continue
        formes, _ = _formes(trouve[0], trouve[1])
        pts = [p for f, _c in formes for p in f]
        if pts:
            paires.append((pts, e["parts"][0]))
    # 🔴 Illustrator ne garde l'`id` que des tracés qu'il n'a pas reconvertis :
    # 39 des 71 îlots le 2026-09-15. Trois suffisent à poser le repère, mais
    # sous dix on préfère `cadre-geo` s'il est là.
    if len(paires) < 10:
        return None
    svg = [p for a, _b in paires for p in a]
    geo = [p for _a, b in paires for p in b]
    sx0, sx1 = min(p[0] for p in svg), max(p[0] for p in svg)
    sy0, sy1 = min(p[1] for p in svg), max(p[1] for p in svg)
    gx0, gx1 = min(p[0] for p in geo), max(p[0] for p in geo)
    gy0, gy1 = min(p[1] for p in geo), max(p[1] for p in geo)
    if sx1 - sx0 < 1 or sy1 - sy0 < 1:
        return None

    def vers_epsg(p):
        return (gx0 + (p[0] - sx0) / (sx1 - sx0) * (gx1 - gx0),
                gy1 - (p[1] - sy0) / (sy1 - sy0) * (gy1 - gy0))

    ecart = 0.0
    for pts, ref in paires:
        for p in (vers_epsg(q) for q in pts):
            ecart = max(ecart, min(math.dist(p, r) for r in ref))
    print("repère sur %d îlots de référence — ils retombent à %.2f m près"
          % (len(paires), ecart))
    if ecart > 5.0:
        raise SystemExit(
            "❌ les îlots de référence ont été déplacés ou déformés (%.1f m).\n"
            "   sans eux le dessin ne sait plus où il tombe : relance\n"
            "   `--exporter` et recolle ton dessin dans le gabarit neuf." % ecart)
    return vers_epsg


def _repere_sur_cadre(racine):
    """-> la fonction SVG → EPSG, lue sur `cadre-geo`. Échoue si le repère a bougé."""
    desc = None
    for e in racine.iter():
        if e.tag.split("}")[-1] == "desc" and (e.text or "").startswith("geo:"):
            desc = e.text
    if not desc:
        raise SystemExit("❌ ce SVG ne vient pas du gabarit : ni îlots de référence\n"
                         "   reconnaissables, ni repère `geo:`.\n"
                         "   relance `--exporter` et redessine dedans.")
    x0, y0, x1, y1 = [float(v) for v in
                      re.search(r"cadre=([-\d.,e+]+)", desc).group(1).split(",")]
    trouve = _trouver(racine, "cadre-geo")
    if not trouve:
        raise SystemExit("❌ le rectangle `cadre-geo` a disparu du SVG.\n"
                         "   sans lui, impossible de savoir où tombe ton dessin.")
    noeud, mat = trouve
    formes, _ = _formes(noeud, mat)
    pts = [p for f, _ in formes for p in f]
    sx0, sy0 = min(p[0] for p in pts), min(p[1] for p in pts)
    sx1, sy1 = max(p[0] for p in pts), max(p[1] for p in pts)
    if sx1 - sx0 < 1 or sy1 - sy0 < 1:
        raise SystemExit("❌ `cadre-geo` est aplati — repère inutilisable.")
    ratio = ((sx1 - sx0) / (sy1 - sy0)) / ((x1 - x0) / (y1 - y0))
    if not 0.98 < ratio < 1.02:
        print("⚠️  `cadre-geo` a été déformé de %.1f %% : ton dessin sera étiré "
              "d'autant." % (abs(ratio - 1) * 100))

    def vers_epsg(p):
        return (x0 + (p[0] - sx0) / (sx1 - sx0) * (x1 - x0),
                y1 - (p[1] - sy0) / (sy1 - sy0) * (y1 - y0))
    return vers_epsg


def _calques(racine, vers_epsg):
    """-> {calque: [(points EPSG, fermé)]}, le compte d'arcs, et les calques
    dessinés que la table d'alias ne sait pas placer."""
    parents = {id(e): id(n) for n in racine.iter() for e in n}
    pris, reconnus, inconnus, arcs = set(), {}, [], 0

    def sous_un_pris(noeud):
        k = parents.get(id(noeud))
        while k is not None:
            if k in pris:
                return True
            k = parents.get(k)
        return False

    for nom, noeud, mat in _groupes(racine):
        if nom.startswith("_reference") or sous_un_pris(noeud):
            continue
        cible = _cible(nom)
        formes, a = _formes(noeud, mat)
        if cible is None:
            if formes:
                inconnus.append((nom, len(formes)))
            continue
        pris.add(id(noeud))
        arcs += a
        propres = []
        for pts, ferme in formes:
            geo = [vers_epsg(p) for p in pts]
            geo = [p for k, p in enumerate(geo)
                   if k == 0 or math.dist(p, geo[k-1]) > 0.05]
            if len(geo) >= (3 if ferme else 2):
                propres.append((geo, ferme))
        if propres:
            reconnus.setdefault(cible, []).extend(propres)
    return reconnus, arcs, inconnus


def _emprise(candidats, source):
    """-> l'anneau de l'emprise, ou None. C'est le plus grand tracé fermé qui
    contient toute la ville : un cadre, pas un objet du paysage."""
    x0, y0, x1, y1 = carte._enveloppe(source["ilots"])
    tenables = []
    for pts, ferme in candidats:
        if not ferme or len(pts) > 12:
            continue
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        if min(xs) <= x0 and max(xs) >= x1 and min(ys) <= y0 and max(ys) >= y1:
            tenables.append(((max(xs) - min(xs)) * (max(ys) - min(ys)), pts))
    if not tenables:
        return None
    return max(tenables)[1]


def _souder(anneaux):
    """Recolle ce qu'Illustrator laisse à côté : les sommets distants de moins
    de `SOUDURE_M` deviennent UN sommet, et un sommet posé au milieu de
    l'arête du voisin y est inséré. Sans ça, deux champs mitoyens ne partagent
    pas leur arête et `03` ne les déclare pas voisins."""
    ancres = {}

    def ancrer(p):
        cx, cy = int(p[0] // SOUDURE_M), int(p[1] // SOUDURE_M)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for q in ancres.get((cx + dx, cy + dy), ()):
                    if math.dist(p, q) <= SOUDURE_M:
                        return q
        ancres.setdefault((cx, cy), []).append(p)
        return p

    colles = []
    for a in anneaux:
        r = [ancrer(p) for p in a]
        r = [q for k, q in enumerate(r) if q != r[k - 1]]
        colles.append(r)

    tous = [q for lst in ancres.values() for q in lst]
    grille = {}
    for q in tous:
        grille.setdefault((int(q[0] // SOUDURE_M), int(q[1] // SOUDURE_M)), []).append(q)

    sortie, ajouts = [], 0
    for r in colles:
        neuf = []
        for k in range(len(r)):
            a, b = r[k], r[(k + 1) % len(r)]
            neuf.append(a)
            L2 = (b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2
            if L2 < 1e-9:
                continue
            vus = []
            x0, x1 = sorted((a[0], b[0]))
            y0, y1 = sorted((a[1], b[1]))
            for cx in range(int(x0 // SOUDURE_M) - 1, int(x1 // SOUDURE_M) + 2):
                for cy in range(int(y0 // SOUDURE_M) - 1, int(y1 // SOUDURE_M) + 2):
                    for q in grille.get((cx, cy), ()):
                        if q is a or q is b:
                            continue
                        t = ((q[0] - a[0]) * (b[0] - a[0])
                             + (q[1] - a[1]) * (b[1] - a[1])) / L2
                        if not 1e-6 < t < 1 - 1e-6:
                            continue
                        pr = (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]))
                        if math.dist(q, pr) <= SOUDURE_M:
                            vus.append((t, q))
            for _t, q in sorted(vus):
                if q != neuf[-1]:
                    neuf.append(q)
                    ajouts += 1
        sortie.append(neuf)
    return sortie, ajouts


def _ferme(anneau):
    """🔴 `decouper.dedans` parcourt `len - 1` arêtes : un anneau OUVERT — la
    convention de la source — y perd sa dernière arête et le test se trompe.
    Mesuré le 2026-09-15 : 68 ha de champs lus comme 47."""
    return anneau if anneau[0] == anneau[-1] else anneau + [anneau[0]]


def _maille(poly):
    """Le semis de points de `poly`, à `PAS_MESURE`. Sert à mesurer un
    recouvrement sans bibliothèque géométrique."""
    poly = _ferme(poly)
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    out = set()
    x = min(xs)
    while x < max(xs):
        y = min(ys)
        while y < max(ys):
            if decouper.dedans(poly, (x, y)):
                out.add((round(x / PAS_MESURE), round(y / PAS_MESURE)))
            y += PAS_MESURE
        x += PAS_MESURE
    return out


def _ha(n):
    return n * PAS_MESURE * PAS_MESURE / 10000.0


def _sans_lifere(cases):
    """🔴 LA MAILLE INVENTE UN TROU LE LONG DE CHAQUE CONTOUR : un liseré d'une
    case, soit 0,42 ha sur les sept anciens champs, qui fond de moitié quand la
    maille est deux fois plus fine (mesuré le 2026-09-15). Une case entourée de
    vide est du bruit ; un vrai trou a de l'épaisseur."""
    return {c for c in cases
            if all((c[0] + dx, c[1] + dy) in cases
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}


# Le mot qui nomme chaque sol dans les comptes rendus.
NOM_SOL = {"champs": "champs", "eau": "rivière"}


def _sol_dessine(source, sols, domaines, decor):
    """Le dessin DEVIENT le sol (décision de l'auteur, 2026-09-15) : chaque
    calque de `CALQUES_SOL` remplace les îlots de sa liste, la forêt et les
    massifs reprennent le reste. -> (îlots, rapport, {calque: fids neufs},
    entités `domaines`)."""
    par_fid = {e["fid"]: e for e in source["ilots"]}
    connues = atelier.listes_connues()
    rapport = []

    # 🔴 LE SOL DÉJÀ DESSINÉ S'EFFACE D'ABORD. `sol` marque les îlots qu'une
    # reprise précédente a posés : sans ce retrait, une deuxième passe EMPILE
    # une seconde campagne sur la première (93 îlots de plus, fid 1093 et
    # suivants) au lieu de la remplacer, et la chaîne n'est plus rejouable.
    ancien = [f for f, e in par_fid.items() if e.get("sol")]
    for f in ancien:
        del par_fid[f]
    if ancien:
        rapport.append("%d îlots de la reprise précédente effacés (fid %d à %d)"
                       % (len(ancien), min(ancien), max(ancien)))

    # --- souder chaque sol, puis mesurer TOUT ce que le dessin couvre
    anneaux, mailles = {}, {}
    for calque, brins in sols.items():
        soudes, ajouts = _souder(brins)
        anneaux[calque] = soudes
        m = set()
        for a in soudes:
            m |= _maille(a)
        mailles[calque] = m
        rapport.append("%-8s %d formes, %.1f ha — soudure : %d sommets insérés"
                       % (NOM_SOL.get(calque, calque), len(soudes), _ha(len(m)), ajouts))
    sol = set()
    for m in mailles.values():
        sol |= m
    mailles_decor = {}
    for genre, formes in decor.items():
        m = set()
        for a in formes:
            m |= _maille(a)
        mailles_decor[genre] = m - sol
    couvert = set(sol)
    for m in mailles_decor.values():
        couvert |= m
    # ce dans quoi se répartit un ancien îlot, sous son nom d'affichage
    morceaux = {NOM_SOL.get(k, k): v for k, v in mailles.items()}
    morceaux.update(mailles_decor)

    # --- quels îlots le dessin remplace, et par quoi
    a_effacer, gardes, trous = [], [], 0.0
    for calque, liste in sorted(CALQUES_SOL.items()):
        for fid in sorted(connues.get(liste) or []):
            if fid not in par_fid:
                continue
            m = _maille(par_fid[fid]["parts"][0])
            if not m:
                continue
            if len(m & couvert) / len(m) >= COUVERTURE_REMPLACE:
                a_effacer.append(fid)
                parts = sorted(morceaux.items(), key=lambda t: -len(m & t[1]))
                rendus = ["%.2f ha en %s" % (_ha(len(m & g)), nom)
                          for nom, g in parts if _ha(len(m & g)) >= 0.05]
                rapport.append("îlot %d (%.2f ha, %s) → %s"
                               % (fid, _ha(len(m)), NOM_SOL.get(calque, calque),
                                  ", ".join(rendus) or "rien"))
                trous += _ha(len(_sans_lifere(m - couvert)))
            else:
                gardes.append((fid, len(m & couvert) / len(m), _ha(len(m & sol))))

    for fid in a_effacer:
        del par_fid[fid]
    libre = max(FID_SOL, max(par_fid) + 1)
    neufs = {}
    for calque in sorted(anneaux):
        neufs[calque] = []
        for a in anneaux[calque]:
            par_fid[libre] = {"fid": libre, "parts": [a], "multi": False,
                              "sol": SOL_SOUS_TYPE[calque]}
            neufs[calque].append(libre)
            libre += 1

    if trous > 0.02:
        rapport.append("🔴 %.2f ha d'ancien sol que le dessin ne reprend NI en sol "
                       "NI en décor — ce sera un trou dans la carte" % trous)
    for fid, part, mord in gardes:
        if mord > 0.05:
            rapport.append("🔴 îlot %d n'est couvert qu'à %.0f %% : il est GARDÉ, et "
                           "%.2f ha de dessin le recouvrent — sol compté deux fois"
                           % (fid, part * 100, mord))
        else:
            rapport.append("îlot %d gardé tel quel (le dessin ne le touche pas)" % fid)

    # --- les fermes
    ents, sans = [], 0
    for i, a in enumerate(domaines, 1):
        ents.append({"fid": i, "parts": [a], "multi": False, "nom": "D%d" % i})
    if ents:
        for a in anneaux.get("champs", []):
            c = (sum(p[0] for p in a) / len(a), sum(p[1] for p in a) / len(a))
            if not any(decouper.dedans(_ferme(d["parts"][0]), c) for d in ents):
                sans += 1
        rapport.append("fermes : %d domaines, %d champs sans ferme" % (len(ents), sans))

    return [par_fid[k] for k in sorted(par_fid)], rapport, neufs, ents


def reprendre(chemin_svg, blanc):
    if not os.path.exists(chemin_svg):
        raise SystemExit("SVG introuvable : %s" % chemin_svg)
    racine = ET.parse(chemin_svg).getroot()
    source = carte.lire_source()
    print("\n" + "=" * 74)
    print("CE QUE LE DESSIN APPORTE")
    print("=" * 74)
    vers_epsg = _repere(racine, source)
    calques, arcs, inconnus = _calques(racine, vers_epsg)
    libres = _hors_calque(racine, vers_epsg)

    # --- l'emprise du monde, sur son calque ou posée à la racine
    cadre = _emprise(calques.get("emprise", []) or libres, source)
    if cadre:
        xs = [p[0] for p in cadre]
        ys = [p[1] for p in cadre]
        x0, y0, x1, y1 = carte._enveloppe(source["ilots"])
        print("\nEMPRISE  %.0f × %.0f m  =  %.0f ha"
              % (max(xs) - min(xs), max(ys) - min(ys),
                 (max(xs) - min(xs)) * (max(ys) - min(ys)) / 10000))
        print("   la ville en occupe %.0f ha — il reste %.0f m à l'ouest, %.0f à "
              "l'est,\n   %.0f au sud et %.0f au nord pour la campagne"
              % ((x1 - x0) * (y1 - y0) / 10000, x0 - min(xs), max(xs) - x1,
                 y0 - min(ys), max(ys) - y1))
    elif libres:
        print("\n⚠️  %d tracés hors de tout calque, LAISSÉS DE CÔTÉ — aucun "
              "n'entoure la ville." % len(libres))

    if inconnus:
        print("\n⚠️  %d calque(s) dessiné(s) que je ne sais pas placer, LAISSÉS DE CÔTÉ :"
              % len(inconnus))
        for nom, n in inconnus:
            print("      `%s` — %d tracés" % (nom, n))
        print("    soit le calque est renommé dans Illustrator (`%s`),"
              % "` `".join(CALQUES_DESSIN))
        print("    soit son mot rejoint la table `ALIAS_CALQUES` du script.")
    if not calques:
        print("\n   rien de repris — aucun calque `%s`."
              % "` `".join(CALQUES_DESSIN))
        return
    if arcs:
        print("⚠️  %d arcs elliptiques approximés par une corde. Dans Illustrator,"
              % arcs)
        print("    Objet > Tracé > Ajouter des points d'ancrage les convertit.")

    source.setdefault("paysage", [])
    nouvelles = {n: list(e) for n, e in source.items()}

    # --- les formes fermées du décor
    # 🔴 MÊME PIÈGE QUE POUR LE SOL : sans ce retrait la deuxième reprise
    # empilait 8 formes de plus sur les 8 premières. La note dit d'où elles
    # viennent, donc ce qui a été tracé dans QGIS (`atelier.py`) survit.
    avant = len(nouvelles["paysage"])
    nouvelles["paysage"] = [e for e in nouvelles["paysage"]
                            if not (e.get("note") or "").startswith("dessiné dans ")]
    if avant - len(nouvelles["paysage"]):
        print("\n%d forme(s) de décor de la reprise précédente effacées"
              % (avant - len(nouvelles["paysage"])))
    fid = max([e["fid"] for e in nouvelles["paysage"]] or [0])
    for calque, genre in GENRES_CALQUES.items():
        formes = [f for f in calques.get(calque, []) if f[1]]
        ouvertes = len(calques.get(calque, [])) - len(formes)
        if ouvertes:
            print("⚠️  calque `%s` : %d tracés NON FERMÉS, ignorés." % (calque, ouvertes))
        for pts, _ in formes:
            fid += 1
            nouvelles["paysage"].append(
                {"fid": fid, "parts": [pts], "multi": False, "genre": genre,
                 "altitude_m": None, "note": "dessiné dans %s" % calque})
        if formes:
            print("\n%-8s %d formes  →  paysage genre `%s`"
                  % (calque.upper(), len(formes), genre))

    # --- le sol dessiné : les champs, l'Ilse, et les fermes qui les coiffent
    sols = {}
    for calque in sorted(CALQUES_SOL):
        fermes_ = [pts for pts, f in calques.get(calque, []) if f]
        ouverts = len(calques.get(calque, [])) - len(fermes_)
        if ouverts:
            print("⚠️  calque `%s` : %d tracés NON FERMÉS, ignorés." % (calque, ouverts))
        if fermes_:
            sols[calque] = fermes_
    fids_neufs = {}
    if sols:
        decor = {"forêt": [p for p, f in calques.get("bois", []) if f],
                 "massif": [p for p, f in calques.get("relief", []) if f]}
        nouvelles["ilots"], rapport, fids_neufs, ents = _sol_dessine(
            source, sols, [p for p, f in calques.get("domaines", []) if f], decor)
        if ents:
            nouvelles["domaines"] = ents
        print("\nLE SOL DESSINÉ  →  îlots")
        for l in rapport:
            print("   " + l)

    # --- les coupes
    coupes = [pts for pts, _ in calques.get("coupes", [])]
    if coupes:
        nouvelles["ilots"], rapport = _appliquer_coupes(nouvelles["ilots"], coupes)
        print("\nCOUPES  %d traits" % len(coupes))
        for l in rapport:
            print("   " + l)

    if fids_neufs:
        # 🔄 Ce bloc imprimait les listes de fid à recoller dans `02` : la
        # campagne porte son `sol` depuis le 2026-09-15, il n'y a plus rien à
        # recopier. Ce qui reste à l'auteur, ce sont les îlots de la VILLE.
        print("\n LE CALQUE FAIT LE SOL — rien à recopier dans `02_qualifier.py` :")
        for calque, neufs in sorted(fids_neufs.items()):
            print("   %-8s %3d îlots, fid %d à %d, `sol = %s`"
                  % (calque, len(neufs), neufs[0], neufs[-1],
                     SOL_SOUS_TYPE[calque]))
        vivants = {e["fid"] for e in nouvelles["ilots"]}
        restes = {l: [f for f in (atelier.listes_connues().get(l) or [])
                      if f in vivants and f < FID_SOL]
                  for l in sorted(set(CALQUES_SOL.values()))}
        if any(restes.values()):
            print("   ⚠️  encore nommés par leur numéro dans `02`, donc comptés "
                  "deux fois si le dessin les recouvre :")
            for liste, fids in sorted(restes.items()):
                if fids:
                    print("      %s = %s" % (liste, fids))

    manquants = [e["fid"] for e in nouvelles["paysage"] if e["genre"] == "relief"]
    if manquants:
        print("\n⚠️  %d massifs sans altitude_m — hauteur par défaut à l’export Godot."
              % len(manquants))

    if cadre:
        nouvelles["emprise"] = [{"fid": 1, "parts": [cadre], "multi": False}]

    if blanc:
        print("\n--blanc : rien n'a été écrit.")
        return
    atelier.exiger_arbre_propre()
    ecrits = carte.ecrire_source(nouvelles)
    print("\nSOURCE ÉCRITE")
    for nom, n in sorted(ecrits.items()):
        print("   %-9s %4d entités" % (nom, n))
    print("\n   annuler  : git checkout QGIS/data/source")
    print("   relancer : python QGIS/scripts/chaine.py --godot")


def _croisements(ligne, anneau):
    """Les points où `ligne` traverse `anneau`, rangés le long de la ligne.
    -> [(rang, point)]. C'est ce qui remplace l'accrochage : l'auteur trace
    en travers, à la louche, et les deux bouts exacts sont calculés ici."""
    out = []
    for k in range(len(ligne) - 1):
        p, q = ligne[k], ligne[k + 1]
        dx, dy = q[0] - p[0], q[1] - p[1]
        for m in range(len(anneau) - 1):
            a, b = anneau[m], anneau[m + 1]
            ex, ey = b[0] - a[0], b[1] - a[1]
            den = dx * ey - dy * ex
            if abs(den) < 1e-12:
                continue
            t = ((a[0] - p[0]) * ey - (a[1] - p[1]) * ex) / den
            u = ((a[0] - p[0]) * dy - (a[1] - p[1]) * dx) / den
            if 0 <= t <= 1 and 0 <= u <= 1:
                out.append((k + t, (p[0] + t * dx, p[1] + t * dy)))
    out.sort(key=lambda r: r[0])
    net = []
    for rang, pt in out:
        if not net or math.dist(pt, net[-1][1]) > 0.05:
            net.append((rang, pt))
    return net


def _brins_dedans(ligne, anneaux):
    """Les morceaux de `ligne` qui traversent le polygone de bord à bord, chacun
    commençant et finissant EXACTEMENT sur le bord."""
    croix = _croisements(ligne, anneaux[0])
    brins = []
    for (r0, p0), (r1, p1) in zip(croix, croix[1:]):
        milieu = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
        entre = [ligne[k] for k in range(len(ligne))
                 if r0 < k < r1]
        temoin = entre[len(entre) // 2] if entre else milieu
        if not decouper.dedans(anneaux[0], temoin):
            continue
        brins.append([p0] + entre + [p1])
    return brins


def _appliquer_coupes(ilots, coupes):
    """Réutilise la machinerie de `00_decouper_ilots` : c'est elle qui garantit
    la topologie, et c'est pour ça que l'auteur dessine des TRAITS."""
    par_fid = {e["fid"]: e for e in ilots}
    champs = set(atelier.listes_connues().get("CHAMPS") or [])
    rapport = []
    for ligne in coupes:
        # 🔴 UN TRAIT PEUT TRAVERSER PLUSIEURS ÎLOTS : chaque morceau coupe le
        # sien. Le parcours se refait à chaque fois, la table ayant changé.
        morceaux = []
        for fid in sorted(par_fid):
            if fid in decouper.NE_PAS_COUPER:
                continue
            for brin in _brins_dedans(ligne, par_fid[fid]["parts"]):
                morceaux.append((fid, brin))
        if not morceaux:
            rapport.append("⚠️  un trait ne traverse aucun îlot de bord à bord — ignoré")
            continue
        for fid, brin in morceaux:
            _couper_un(par_fid, fid, brin, champs, rapport)
        continue
    return [par_fid[k] for k in sorted(par_fid)], rapport


# 🔴 UN ÉCLAT SOUS CE SEUIL EST UN ACCIDENT DE TRACÉ, pas un champ : il
# traverserait toute la chaîne et ressortirait en parcelle absurde dans la 3D.
ECLAT_HA = 0.15


def _couper_un(par_fid, fid, brin, champs, rapport):
        e = par_fid[fid]
        libre = max(par_fid) + 1
        try:
            a, b = decouper.couper(e["parts"][0], brin)
        except Exception as err:
            rapport.append("⚠️  îlot %d : coupe refusée (%s)" % (fid, err))
            return
        grand, petit = (a, b) if abs(decouper.aire(a)) >= abs(decouper.aire(b)) else (b, a)
        ha = abs(decouper.aire(petit)) / 10000
        if ha < ECLAT_HA:
            rapport.append("⚠️  îlot %d : coupe REFUSÉE, elle ne détache que %.2f ha "
                           "— le trait effleure le bord" % (fid, ha))
            return
        if fid not in champs:
            rapport.append("🔴 îlot %d N'EST PAS UN CHAMP et vient d'être coupé. "
                           "C'est du level design : à confirmer." % fid)
        par_fid[fid] = dict(e, parts=[grand])
        par_fid[libre] = {"fid": libre, "parts": [petit], "multi": False}
        rapport.append("îlot %d coupé  →  %d garde %.2f ha, %d prend %.2f ha"
                       % (fid, fid, abs(decouper.aire(grand)) / 10000,
                          libre, abs(decouper.aire(petit)) / 10000))


# ==========================================================================

def main():
    a = sys.argv[1:]
    if "--exporter" in a:
        exporter()
    elif "--reprendre" in a:
        svg = next((x for x in a if x.endswith(".svg")), GABARIT)
        reprendre(svg, "--blanc" in a)
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
