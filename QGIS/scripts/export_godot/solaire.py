# -*- coding: utf-8 -*-
"""☀️ Les panneaux, toit par toit (auteur, 2026-09-26).

Un toit se découpe en UNITÉS — un versant, ou un toit plat. Chacune reçoit UN
tableau de modules entiers, marges tenues, et l'îlot range ses unités de la plus
rentable à la moins rentable. Rien n'est dessiné ici : tout part en attribut de
sommet (`pv` → CUSTOM1), et le shader pose les modules dans cet ordre, rangée
par rangée depuis la gouttière."""

import math
import random

from .geometrie import _dans_triangle, _graine_lieu, aire_signee

# Un module de 400 W d'aujourd'hui : portrait sur un versant, paysage sur le plat.
MODULE_LONG = 1.72
MODULE_LARGE = 1.13
JOINT = 0.02
A_MODULE = MODULE_LONG * MODULE_LARGE
# 0,5 m de la gouttière, du faîtage et des rives ; 1 m du bord d'un toit plat
# (zone de rive au vent, acrotère).
MARGE_PENTE = 0.5
MARGE_PLAT = 1.0
# Sur le plat, des rangées à 15° tournées vers le sud, assez espacées pour ne
# pas s'ombrer l'hiver. ⚠️ Le shader porte les mêmes cotes (materiaux.gd).
INCLINAISON_PLAT = math.radians(15.0)
PROFONDEUR_PLAT = MODULE_LARGE * math.cos(INCLINAISON_PLAT)
RANGEE_PLAT = 1.9
# En dessous, personne ne monte poser : l'unité reste nue.
MODULES_MIN = 4
# Les frais fixes d'un chantier (échafaudage, raccordement), en m² de module :
# c'est ce qui fait passer un petit toit après un grand.
A_FIXE_M2 = 12.0


def rendement(pente, cos_sud):
    """Part du productible d'un pan plein sud à 35°, Allemagne du Sud.
    Ajusté sur PVGIS : 1,00 au sud à 30°, 0,80 est-ouest, 0,60 au nord,
    0,87 à plat."""
    return (0.87 + 0.38 * math.sin(pente) * cos_sud
            - 0.5 * (1.0 - math.cos(pente)))


def _perte_ombre(c, hauts):
    """Ce que les voisins plus hauts, dans le secteur sud ±60°, prennent."""
    e = 0.0
    for x, y, z in hauts:
        dy = y - c[1]
        if dy <= 0.5:
            continue
        dx, dz = x - c[0], z - c[2]
        d = math.hypot(dx, dz)
        if d < 1.0 or dz < 0.5 * d:          # le sud est +Z dans Godot
            continue
        e = max(e, math.atan2(dy, d))
    # Horizon à 20° : −7 % ; 30° : −21 % ; 45° : −47 %.
    x = (math.degrees(e) - 12.0) / 40.0
    return 0.6 * min(1.0, max(0.0, x)) ** 1.3


def _aire3(p, q, r):
    ux, uy, uz = q[0] - p[0], q[1] - p[1], q[2] - p[2]
    vx, vy, vz = r[0] - p[0], r[1] - p[1], r[2] - p[2]
    return 0.5 * math.sqrt((uy * vz - uz * vy) ** 2 + (uz * vx - ux * vz) ** 2
                           + (ux * vy - uy * vx) ** 2)


def _faces_de_toit(m, debut, fin):
    """Les triangles de toit d'un bâtiment : UV porte l'axe UNITAIRE du toit
    (07), une façade y porte (u, L) avec L ≥ 2 m, le reste (0, 0)."""
    for b in range(debut, fin, 3):
        ux, uz = m.uv[b]
        if abs(ux * ux + uz * uz - 1.0) > 0.02 or m.n[b][1] < 0.55:
            continue
        yield b


def _unites(m, debut, fin):
    """Les faces de toit groupées par plan : un versant, un toit plat."""
    groupes = []
    cos_seuil = math.cos(math.radians(10.0))
    for b in _faces_de_toit(m, debut, fin):
        n = m.n[b]
        plat = n[1] >= 0.995
        y = m.v[b][1]
        a = _aire3(m.v[b], m.v[b + 1], m.v[b + 2])
        if a < 1e-6:
            continue
        for g in groupes:
            if g["plat"] != plat:
                continue
            if plat and abs(g["y"] - y) < 0.3:
                break
            if not plat:
                s = g["ns"]
                L = math.sqrt(s[0] ** 2 + s[1] ** 2 + s[2] ** 2)
                if (s[0] * n[0] + s[1] * n[1] + s[2] * n[2]) / L > cos_seuil:
                    break
        else:
            g = {"plat": plat, "y": y, "ns": [0.0, 0.0, 0.0], "tris": [],
                 "axe": tuple(m.uv[b]), "aire": 0.0}
            groupes.append(g)
        g["tris"].append(b)
        g["aire"] += a
        for k in range(3):
            g["ns"][k] += n[k] * a
    return groupes


def _cadre(g):
    """(projection 3D → (t, s) en mètres, cos de l'écart au sud, pente).
    `s` monte vers le faîtage sur un versant, vers le nord sur le plat : la
    rangée 0 est toujours celle qu'on pose en premier."""
    if g["plat"]:
        ax, az = g["axe"]
        # La rangée regarde celui des quatre côtés du bâtiment le plus au sud.
        fx, fz = max(((ax, az), (-ax, -az), (-az, ax), (az, -ax)),
                     key=lambda f: f[1])
        return ((lambda p: (-p[0] * fz + p[2] * fx,
                            -(p[0] * fx + p[2] * fz))),
                fz, INCLINAISON_PLAT)
    s = g["ns"]
    L = math.sqrt(s[0] ** 2 + s[1] ** 2 + s[2] ** 2)
    ny = min(1.0, s[1] / L)
    pente = math.acos(ny)
    h = math.hypot(s[0], s[2])
    dx, dz = s[0] / h, s[2] / h                # vers la gouttière
    return ((lambda p: (-p[0] * dz + p[2] * dx,
                        -(p[0] * dx + p[2] * dz) / ny)),
            dz, pente)


def _enveloppe(pts):
    pts = sorted(set((round(p[0], 4), round(p[1], 4)) for p in pts))
    if len(pts) < 3:
        return pts

    def cr(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    bas, haut = [], []
    for p in pts:
        while len(bas) >= 2 and cr(bas[-2], bas[-1], p) <= 0:
            bas.pop()
        bas.append(p)
    for p in reversed(pts):
        while len(haut) >= 2 and cr(haut[-2], haut[-1], p) <= 0:
            haut.pop()
        haut.append(p)
    return bas[:-1] + haut[:-1]


def _etendue(poly, s):
    """[tmin, tmax] du polygone CONVEXE à la hauteur s, ou None."""
    lo, hi = math.inf, -math.inf
    n = len(poly)
    for i in range(n):
        (t1, s1), (t2, s2) = poly[i], poly[(i + 1) % n]
        if (s1 - s) * (s2 - s) > 0.0:
            continue
        if abs(s2 - s1) < 1e-9:
            lo, hi = min(lo, t1, t2), max(hi, t1, t2)
            continue
        t = t1 + (s - s1) * (t2 - t1) / (s2 - s1)
        lo, hi = min(lo, t), max(hi, t)
    return None if lo > hi else (lo, hi)


def _gabarit(plat):
    """(pas en t, pas en s, largeur d'un module, hauteur de r rangées)."""
    if plat:
        return (MODULE_LONG + JOINT, RANGEE_PLAT, MODULE_LONG,
                lambda r: (r - 1) * RANGEE_PLAT + PROFONDEUR_PLAT)
    return (MODULE_LARGE + JOINT, MODULE_LONG + JOINT, MODULE_LARGE,
            lambda r: r * (MODULE_LONG + JOINT) - JOINT)


def _tableau_convexe(poly, plat):
    """Le plus grand tableau rectangulaire de modules qui tient, marges
    comprises. Sur un convexe, un rectangle est dedans dès que ses quatre
    coins le sont : deux étendues suffisent par bande."""
    cw, ch, _lm, hauteur = _gabarit(plat)
    marge = MARGE_PLAT if plat else MARGE_PENTE
    smin = min(p[1] for p in poly)
    smax = max(p[1] for p in poly)
    meilleur = None
    r = 1
    while r < 64:
        libre = smax - smin - 2.0 * marge - hauteur(r)
        if libre < 0.0:
            break
        pas = max(0.05, libre / 24.0)
        k = 0
        while k * pas <= libre + 1e-9:
            s0 = smin + marge + k * pas
            e1 = _etendue(poly, s0 - marge)
            e2 = _etendue(poly, s0 + hauteur(r) + marge)
            k += 1
            if e1 is None or e2 is None:
                continue
            lo = max(e1[0], e2[0]) + marge
            L = min(e1[1], e2[1]) - marge - lo
            c = int((L + JOINT) // cw)
            if c < 1:
                continue
            jeu = L - (c * cw - JOINT)
            cle = (r * c, round(jeu, 1), -abs(s0 - smin - marge - libre / 2.0))
            if meilleur is None or cle > meilleur[0]:
                meilleur = (cle, r, c, lo + jeu / 2.0, s0)
        r += 1
    return None if meilleur is None else meilleur[1:]


def _tableau_trame(tris, plat):
    """Même question sur une unité CONCAVE : on essaie neuf calages de trame,
    une case vaut si son module, marge comprise, tombe dans les triangles, et
    on garde le plus grand rectangle de cases valides."""
    cw, ch, lm, _h = _gabarit(plat)
    hm = PROFONDEUR_PLAT if plat else MODULE_LONG
    marge = MARGE_PLAT if plat else MARGE_PENTE
    ts = [p[0] for t in tris for p in t]
    ss = [p[1] for t in tris for p in t]
    boites = [(min(p[0] for p in t), max(p[0] for p in t),
               min(p[1] for p in t), max(p[1] for p in t)) for t in tris]

    def dedans(x, y):
        for (a, b, c), (x0, x1, y0, y1) in zip(tris, boites):
            if x0 - 1e-6 <= x <= x1 + 1e-6 and y0 - 1e-6 <= y <= y1 + 1e-6 \
                    and _dans_triangle((x, y), a, b, c):
                return True
        return False

    meilleur = None
    for ox in (0.0, cw / 3.0, 2.0 * cw / 3.0):
        for oy in (0.0, ch / 3.0, 2.0 * ch / 3.0):
            t0, s0 = min(ts) + marge + ox, min(ss) + marge + oy
            nx = int((max(ts) - t0) // cw) + 1
            ny = int((max(ss) - s0) // ch) + 1
            ok = []
            for j in range(ny):
                y0 = s0 + j * ch
                ok.append([all(dedans(x, y) for x, y in (
                    (t0 + i * cw - marge, y0 - marge),
                    (t0 + i * cw + lm + marge, y0 - marge),
                    (t0 + i * cw - marge, y0 + hm + marge),
                    (t0 + i * cw + lm + marge, y0 + hm + marge),
                    (t0 + i * cw + lm / 2.0, y0 + hm / 2.0)))
                    for i in range(nx)])
            # Le plus grand rectangle de cases valides, par histogrammes.
            hist = [0] * nx
            for j in range(ny):
                for i in range(nx):
                    hist[i] = hist[i] + 1 if ok[j][i] else 0
                pile = []
                for i in range(nx + 1):
                    h = hist[i] if i < nx else 0
                    debut = i
                    while pile and pile[-1][1] >= h:
                        debut, hh = pile.pop()
                        n = hh * (i - debut)
                        if n and (meilleur is None or n > meilleur[0]):
                            meilleur = (n, hh, i - debut,
                                        t0 + debut * cw, s0 + (j - hh + 1) * ch)
                    pile.append((debut, h))
    return None if meilleur is None else meilleur[1:]


def _poser_unite(m, g, hauts):
    """Mesure une unité : son tableau, son rendement, sa rentabilité."""
    proj, cos_sud, pente = _cadre(g)
    tris = [tuple(proj(m.v[b + k]) for k in range(3)) for b in g["tris"]]
    poly = _enveloppe([p for t in tris for p in t])
    aire_poly = abs(aire_signee(poly)) if len(poly) >= 3 else 0.0
    aire_tris = sum(abs(aire_signee(list(t))) for t in tris)
    convexe = aire_poly > 0.0 and aire_tris >= 0.97 * aire_poly
    tab = (_tableau_convexe(poly, g["plat"]) if convexe
           else _tableau_trame(tris, g["plat"]))
    if tab is None or tab[0] * tab[1] < MODULES_MIN:
        return None
    rangs, cols, t0, s0 = tab
    pts = [m.v[b + k] for b in g["tris"] for k in range(3)]
    centre = tuple(sum(p[k] for p in pts) / len(pts) for k in range(3))
    f = rendement(pente, cos_sud) * (0.97 if g["plat"] else 1.0)
    f *= 1.0 - _perte_ombre(centre, hauts)
    n = rangs * cols
    return {"g": g, "proj": proj, "rangs": rangs, "cols": cols, "t0": t0,
            "s0": s0, "m2": n * A_MODULE, "rendement": f, "plat": g["plat"],
            "sud": cos_sud, "centre": centre,
            "score": f / (1.0 + A_FIXE_M2 / (n * A_MODULE))}


def _hauts(m, debut, fin):
    """Les points hauts d'un bâtiment : ce qui peut ombrer ses voisins."""
    ys = [m.v[i][1] for i in range(debut, fin)]
    if not ys:
        return []
    seuil = max(ys) - 1.5
    return list({(round(m.v[i][0], 1), round(m.v[i][1], 1), round(m.v[i][2], 1))
                 for i in range(debut, fin) if m.v[i][1] >= seuil})


def poser(masses, plages_m, repare, plages_r, volumes, rangs_verts):
    """Range les unités d'un îlot et écrit leur tableau dans les sommets.

    Le bâti intact passe d'abord ; le bâti relevé après la crue (`repare`)
    prend la suite, puisqu'il n'existe qu'une fois reconstruit. Rend les
    unités dans l'ordre de pose."""
    hauts = [(k, _hauts(masses, a, b)) for a, b, k in plages_m]
    unites = []
    for m, plages, relevee in ((masses, plages_m, False),
                               (repare, plages_r, True)):
        if not hasattr(m, "pv"):
            m.pv = {}
        for a, b, k in plages:
            autour = [p for kk, h in hauts if kk != k for p in h]
            for g in _unites(m, a, b):
                u = _poser_unite(m, g, autour)
                if u is not None:
                    u.update(m=m, k=k, relevee=relevee)
                    unites.append(u)
    # Le plus rentable d'abord ; à égalité, le lieu départage (35).
    unites.sort(key=lambda u: (u["relevee"], -round(u["score"], 4),
                               round(u["centre"][0], 1), round(u["centre"][2], 1)))
    cumul = 0.0
    for u in unites:
        u["debut_m2"] = cumul
        cumul += u["m2"]
        # cols + rangs/64 : une valeur par unité, exacte en flottant.
        cr = u["cols"] + u["rangs"] / 64.0
        cw, ch, _lm, _h = _gabarit(u["plat"])
        for b in u["g"]["tris"]:
            for i in (b, b + 1, b + 2):
                t, s = u["proj"](u["m"].v[i])
                u["m"].pv[i] = ((t - u["t0"]) / cw, (s - u["s0"]) / ch,
                                u["debut_m2"], cr)
    _ranger_verts(masses, plages_m, volumes, rangs_verts, unites)
    return unites


def _ranger_verts(m, plages, volumes, rangs_verts, unites):
    """🌿 Le vert prend les toits plats DANS L'ORDRE INVERSE des panneaux : ceux
    qu'aucun module ne peut couvrir d'abord, puis les moins rentables. Un toit
    solaire ou vert, jamais les deux (2026-08-31) — et ainsi les deux curseurs
    ne se disputent un toit qu'en fin de course. Réécrit le rang que `_masse` a
    posé dans UV2.y ; le centre du segment d'aire, comme avant."""
    if not rangs_verts:
        return
    rang_solaire = {}
    for i, u in enumerate(unites):
        if u["plat"] and not u["relevee"]:
            rang_solaire.setdefault(u["k"], i)
    nus = sorted((k for k in rangs_verts if k not in rang_solaire),
                 key=lambda k: random.Random(
                     _graine_lieu(volumes[k][0]) ^ 0x5EDA).random())
    equipes = sorted((k for k in rangs_verts if k in rang_solaire),
                     key=lambda k: -rang_solaire[k])
    ordre = nus + equipes
    aires = {k: abs(aire_signee(volumes[k][0])) for k in ordre}
    total = sum(aires.values())
    if total <= 0.0:
        return
    cumul = 0.0
    rang = {}
    for k in ordre:
        rang[k] = (cumul + aires[k] / 2.0) / total
        cumul += aires[k]
    for a, b, k in plages:
        if k not in rang:
            continue
        for t in _faces_de_toit(m, a, b):
            if m.n[t][1] >= 0.995:
                for i in (t, t + 1, t + 2):
                    m.uv2[i] = (m.uv2[i][0], rang[k])


def avec_pv(m):
    """Le JSON du maillage, plus la colonne `pv` s'il porte un toit équipable :
    (x, y dans la trame en modules, m² posés avant cette unité, cols + rangs/64)."""
    d = m.json()
    pv = getattr(m, "pv", None)
    if pv:
        zero = [0, 0, 0, 0]
        d["pv"] = [zero if i not in pv else
                   [round(pv[i][0], 3), round(pv[i][1], 3),
                    round(pv[i][2], 1), round(pv[i][3], 6)]
                   for i in range(len(m.v))]
    return d
