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

GABARIT = os.path.join(carte.TRAVAIL, "wehrau_gabarit.svg")

# 🔴 LA MARGE EST L'ESPACE DE DESSIN DU DÉCOR, en mètres autour du rectangle
# jouable. 1800 m : au-delà, `export_godot/paysage.py` ne fabriquait déjà que
# du fond lointain, et l'artboard dépasserait la limite d'Illustrator.
MARGE = 1800.0
# Une unité SVG = un mètre. Aucun facteur à retenir, aucune échelle à régler.
GENRES_CALQUES = {"eau": "eau", "relief": "relief", "bois": "bois"}
CALQUES_DESSIN = ["coupes"] + list(GENRES_CALQUES)

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
    with open(GABARIT, "w", encoding="utf-8", newline="\n") as f:
        f.write(svg)

    print("\nGABARIT PRÊT")
    print("   %s" % GABARIT)
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

def _repere(racine):
    """-> la fonction SVG → EPSG, lue sur `cadre-geo`. Échoue si le repère a bougé."""
    desc = None
    for e in racine.iter():
        if e.tag.split("}")[-1] == "desc" and (e.text or "").startswith("geo:"):
            desc = e.text
    if not desc:
        raise SystemExit("❌ ce SVG ne vient pas du gabarit : pas de repère `geo:`.\n"
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
    """-> {nom de calque: [(points EPSG, fermé)]}, et le compte d'arcs."""
    out, arcs = {}, 0
    for nom in CALQUES_DESSIN:
        trouve = _trouver(racine, nom)
        if not trouve:
            continue
        noeud, mat = trouve
        formes, a = _formes(noeud, mat)
        arcs += a
        propres = []
        for pts, ferme in formes:
            geo = [vers_epsg(p) for p in pts]
            geo = [p for k, p in enumerate(geo)
                   if k == 0 or math.dist(p, geo[k-1]) > 0.05]
            if len(geo) >= (3 if ferme else 2):
                propres.append((geo, ferme))
        if propres:
            out[nom] = propres
    return out, arcs


def reprendre(chemin_svg, blanc):
    if not os.path.exists(chemin_svg):
        raise SystemExit("SVG introuvable : %s" % chemin_svg)
    racine = ET.parse(chemin_svg).getroot()
    vers_epsg = _repere(racine)
    calques, arcs = _calques(racine, vers_epsg)

    print("\n" + "=" * 74)
    print("CE QUE LE DESSIN APPORTE")
    print("=" * 74)
    if not calques:
        print("   rien — aucun des calques `%s` ne porte de tracé."
              % "` `".join(CALQUES_DESSIN))
        return
    if arcs:
        print("⚠️  %d arcs elliptiques approximés par une corde. Dans Illustrator,"
              % arcs)
        print("    Objet > Tracé > Ajouter des points d'ancrage les convertit.")

    source = carte.lire_source()
    source.setdefault("paysage", [])
    nouvelles = {n: list(e) for n, e in source.items()}

    # --- les formes fermées du décor
    fid = max([e["fid"] for e in source["paysage"]] or [0])
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

    # --- les coupes
    coupes = [pts for pts, _ in calques.get("coupes", [])]
    if coupes:
        nouvelles["ilots"], rapport = _appliquer_coupes(nouvelles["ilots"], coupes)
        print("\nCOUPES  %d traits" % len(coupes))
        for l in rapport:
            print("   " + l)

    manquants = [e["fid"] for e in nouvelles["paysage"] if e["genre"] == "relief"]
    if manquants:
        print("\n⚠️  %d massifs sans altitude_m — plats tant que tu ne la donnes pas."
              % len(manquants))

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
