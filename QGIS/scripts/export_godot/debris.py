# -*- coding: utf-8 -*-
"""🪵 Ce que la crue a laissé (2026-10-09, auteur) : troncs, bouts de mur,
gravats, poutres, pans de toit, haies arrachées. Tout sort avec `plafond` à −2,
que le shader efface à la remise en état de l'îlot ou de la rue qui le porte."""

import math
from importlib import import_module

import palette as PAL
from apercu_carte import dedans
from .geometrie import aire_signee, normale
from .reglages import (
    DEBRIS_EAU_M,
    DEBRIS_HAIE_PERTE,
    DEBRIS_M2,
    DEBRIS_PART,
    DEBRIS_RUE_PART,
    DEBRIS_RUE_PAS_M,
    DEBRIS_RUINE_M,
    HAIE_HAUTEUR,
    HAIE_LARGEUR,
    HAIE_SEGMENT_MIN,
    RUINE_FORCE_PLEINE_M,
    Y_SOL,
)

SEUIL_RUINE = import_module("04e_crue").SEUIL_RUINE

# (rang, seuil, plafond) du canal de 07 : −1 est la ruine, −2 le débris.
DEBRIS = (0.0, 1.0e9, -2.0)

C_FLOTTE = PAL.vers_lineaire(PAL.BOIS_FLOTTE)
C_ECORCE = PAL.vers_lineaire(PAL.ECORCE)
C_CASSE = PAL.vers_lineaire(PAL.BOIS_CASSE)
C_MOTTE = PAL.vers_lineaire(PAL.MOTTE)
C_POUTRE = PAL.vers_lineaire(PAL.POUTRE)
C_SOUS_TOIT = PAL.vers_lineaire(PAL.SOUS_TOIT)
C_GRAVATS = PAL.vers_lineaire(PAL.GRAVATS)
C_HAIE_MORTE = PAL.vers_lineaire(PAL.HAIE_MORTE)


def force_ruine(eau):
    """0 au seuil de la ruine, 1 au bord de l'eau : ce qui reste debout."""
    return max(0.0, min(1.0, (eau - SEUIL_RUINE)
                        / (RUINE_FORCE_PLEINE_M - SEUIL_RUINE)))


def densite(h):
    a, b = DEBRIS_EAU_M
    t = max(0.0, min(1.0, (h - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


# ------------------------------------------------------------------ formes

def _mix(a, b, t):
    return tuple(a[k] + (b[k] - a[k]) * t for k in range(3))


def _unit(v):
    L = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / L for c in v)


def _croix(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def _repere(e1):
    """Deux axes perpendiculaires à e1 ; le second monte quand e1 est couché."""
    ref = (0.0, 0.0, 1.0) if abs(e1[2]) < 0.9 else (1.0, 0.0, 0.0)
    e2 = _unit(_croix(ref, e1))
    return e2, _croix(e1, e2)


def _ao(h, y0):
    return 0.80 + 0.20 * min(1.0, max(0.0, (h - y0) / 1.6))


def _face(m, G, pts, coul, centre, y0):
    """Un polygone plan (carte x, y, h), tourné à l'opposé de `centre` (Godot).
    Toutes les formes d'ici sont convexes : c'est ce qui rend le test sûr."""
    g = [G(p[0], p[1], p[2]) for p in pts]
    ao = [_ao(p[2], y0) for p in pts]
    n = normale(g[0], g[1], g[2])
    c = [sum(q[k] for q in g) / len(g) for k in range(3)]
    if sum(n[k] * (c[k] - centre[k]) for k in range(3)) < 0.0:
        g.reverse()
        ao.reverse()
    for k in range(1, len(g) - 1):
        m.triangle(g[0], g[k], g[k + 1], coul, (ao[0], ao[k], ao[k + 1]))


def _prisme(m, G, centre, e1, profil, longueur, flancs, bouts, y0, fin=1.0):
    """`profil` (b, c) dans le plan (e2, e3), extrudé sur e1 et centré sur
    `centre`. `fin` rétrécit le bout +e1. `flancs` : une teinte, ou une liste
    (une par arête du profil) ; `bouts` : (−e1, +e1), None pour ne rien fermer."""
    e2, e3 = _repere(e1)
    demi = longueur / 2.0

    def pt(b, c, s, k):
        return tuple(centre[i] + e1[i] * s + (e2[i] * b + e3[i] * c) * k
                     for i in range(3))
    a = [pt(b, c, -demi, 1.0) for b, c in profil]
    z = [pt(b, c, demi, fin) for b, c in profil]
    cg = G(*centre)
    n = len(profil)
    for i in range(n):
        j = (i + 1) % n
        coul = flancs[i] if isinstance(flancs, list) else flancs
        _face(m, G, [a[i], a[j], z[j], z[i]], coul, cg, y0)
    if bouts[0] is not None:
        _face(m, G, a, bouts[0], cg, y0)
    if bouts[1] is not None:
        _face(m, G, z, bouts[1], cg, y0)


def _disque(r, n, rng, irr):
    return [(math.cos(2 * math.pi * k / n) * r * rng.uniform(1 - irr, 1 + irr),
             math.sin(2 * math.pi * k / n) * r * rng.uniform(1 - irr, 1 + irr))
            for k in range(n)]


def _rect(w, h, phi=0.0):
    """Arêtes dans l'ordre : dessous, +e2, dessus, −e2. `phi` le penche."""
    cs, sn = math.cos(phi), math.sin(phi)
    return [(b * cs - c * sn, b * sn + c * cs)
            for b, c in ((-w / 2, -h / 2), (w / 2, -h / 2),
                         (w / 2, h / 2), (-w / 2, h / 2))]


def _cap(angle):
    return (math.cos(angle), math.sin(angle))


# ------------------------------------------------------------------ pièces

def _tronc(m, G, x, y, y0, cap, rng, long_max=12.0):
    """Un arbre couché, le pied en (x, y), la cime vers `cap`. La motte
    arrachée relève le pied ; sans elle, le fût est cassé net, clair."""
    L = min(long_max, rng.uniform(6.0, 12.0))
    r = rng.uniform(0.22, 0.36)
    motte = rng.random() < 0.55
    R = r * rng.uniform(3.2, 4.4) if motte else 0.0
    h_pied = y0 + (R * 0.72 if motte else r * 0.7)
    p0 = (x, y, h_pied)
    p1 = (x + cap[0] * L, y + cap[1] * L, y0 + r * 0.6)
    e1 = _unit(tuple(p1[i] - p0[i] for i in range(3)))
    centre = tuple((p0[i] + p1[i]) / 2.0 for i in range(3))
    ecorce = C_FLOTTE if rng.random() < 0.7 else C_ECORCE
    _prisme(m, G, centre, e1, _disque(r, 6, rng, 0.08), L, ecorce,
            (None if motte else C_CASSE, C_CASSE), y0, fin=0.62)
    if motte:
        c = tuple(p0[i] - e1[i] * 0.15 for i in range(3))
        _prisme(m, G, c, e1, _disque(R, 7, rng, 0.25), 0.42, C_MOTTE,
                (C_MOTTE, _mix(C_MOTTE, ecorce, 0.3)), y0)
    for _ in range(rng.randint(1, 3)):
        s = rng.uniform(0.45, 0.88) * L
        cote = 1.0 if rng.random() < 0.5 else -1.0
        a = math.atan2(cap[1], cap[0]) + cote * rng.uniform(0.6, 1.0)
        lb = rng.uniform(1.0, 2.4)
        d = _unit((math.cos(a), math.sin(a), rng.uniform(0.05, 0.35)))
        base = tuple(p0[i] + e1[i] * s for i in range(3))
        cb = tuple(base[i] + d[i] * lb / 2.0 for i in range(3))
        _prisme(m, G, cb, d, _disque(r * 0.32, 4, rng, 0.1), lb, ecorce,
                (None, C_CASSE), y0, fin=0.5)
    return p1


def _chicot(m, G, x, y, y0, rng):
    """Un arbre cassé debout : un fût court, la cassure claire en haut."""
    h = rng.uniform(0.9, 2.3)
    r = rng.uniform(0.17, 0.30)
    a, t = rng.uniform(0.0, 2 * math.pi), rng.uniform(0.0, 0.2)
    e1 = _unit((math.cos(a) * math.sin(t), math.sin(a) * math.sin(t),
                math.cos(t)))
    centre = (x, y, y0 + h / 2.0 - 0.15)
    _prisme(m, G, centre, e1, _disque(r, 6, rng, 0.1), h, C_ECORCE,
            (None, C_CASSE), y0, fin=0.88)


def _bloc(m, G, x, y, y0, coul, rng):
    """Un pan de mur tombé à plat, une arête relevée sur les gravats."""
    L = rng.uniform(0.9, 2.2)
    larg = rng.uniform(0.6, 1.3)
    ep = rng.uniform(0.35, 0.6)
    a, t = rng.uniform(0.0, 2 * math.pi), rng.uniform(0.0, 0.42)
    e1 = (math.cos(a) * math.cos(t), math.sin(a) * math.cos(t), math.sin(t))
    centre = (x, y, y0 + ep / 2.0 + math.sin(t) * L / 2.0 - 0.10)
    tranche = _mix(coul, C_GRAVATS, 0.45)
    _prisme(m, G, centre, e1, _rect(larg, ep, rng.uniform(-0.2, 0.2)), L,
            [coul, tranche, coul, tranche], (tranche, tranche), y0)


def _pan_toit(m, G, x, y, y0, coul_toit, rng, taille=1.0, pente=None):
    """Un morceau de toiture : les tuiles dessus, salies ; le lattis dessous."""
    coul_toit = _mix(coul_toit, C_MOTTE, 0.25)
    L = rng.uniform(2.0, 3.6) * taille
    W = rng.uniform(1.5, 2.6) * taille
    a = rng.uniform(0.0, 2 * math.pi)
    t = rng.uniform(0.12, 0.45) if pente is None else pente
    e1 = (math.cos(a) * math.cos(t), math.sin(a) * math.cos(t), math.sin(t))
    centre = (x, y, y0 + 0.06 + math.sin(t) * L / 2.0)
    _prisme(m, G, centre, e1, _rect(W, 0.14, rng.uniform(-0.15, 0.15)), L,
            [C_SOUS_TOIT, C_SOUS_TOIT, coul_toit, C_SOUS_TOIT],
            (C_SOUS_TOIT, C_SOUS_TOIT), y0)


def _poutre(m, G, x, y, y0, rng, long_max=5.5):
    L = min(long_max, rng.uniform(2.5, 5.5))
    w = rng.uniform(0.16, 0.26)
    a, t = rng.uniform(0.0, 2 * math.pi), rng.uniform(0.0, 0.14)
    e1 = (math.cos(a) * math.cos(t), math.sin(a) * math.cos(t), math.sin(t))
    centre = (x, y, y0 + w * 0.3 + math.sin(t) * L / 2.0)
    bois = C_POUTRE if rng.random() < 0.6 else C_FLOTTE
    _prisme(m, G, centre, e1, _rect(w, w * 0.75, rng.uniform(-0.3, 0.3)), L,
            bois, (C_CASSE, C_CASSE), y0)


def _branchages(m, G, x, y, y0, rng):
    """Un fagot de branches que l'eau a déposé : quatre bois croisés."""
    for _ in range(rng.randint(3, 5)):
        L = rng.uniform(1.5, 3.4)
        r = rng.uniform(0.05, 0.09)
        a, t = rng.uniform(0.0, 2 * math.pi), rng.uniform(0.0, 0.25)
        e1 = (math.cos(a) * math.cos(t), math.sin(a) * math.cos(t),
              math.sin(t))
        c = (x + rng.uniform(-0.8, 0.8), y + rng.uniform(-0.8, 0.8),
             y0 + r + math.sin(t) * L / 2.0)
        _prisme(m, G, c, e1, _disque(r, 4, rng, 0.1), L,
                C_ECORCE if rng.random() < 0.5 else C_FLOTTE,
                (None, None), y0, fin=0.6)


def _embacle(m, G, emp, u, rng, libre):
    """Des troncs couchés en travers du courant, arrêtés contre le mur amont."""
    p = min(emp, key=lambda q: q[0] * u[0] + q[1] * u[1])
    a0 = math.atan2(u[1], u[0]) + math.pi / 2.0
    n = 0
    for k in range(rng.randint(2, 4)):
        d = 0.7 + k * 0.6 + rng.uniform(0.0, 0.3)
        c = (p[0] - u[0] * d, p[1] - u[1] * d)
        a = a0 + rng.uniform(-0.3, 0.3)
        L = rng.uniform(5.0, 9.0)
        pied = (c[0] - math.cos(a) * L / 2.0, c[1] - math.sin(a) * L / 2.0)
        if libre(c) and libre(pied):
            _tronc(m, G, pied[0], pied[1], Y_SOL, _cap(a), rng, long_max=L)
            n += 1
    return n


def _tas(m, G, x, y, y0, coul_mur, rng, rayon=None):
    """Un tas de gravats : sept pans de teintes voisines, et quelques blocs."""
    R = rayon or rng.uniform(0.9, 2.0)
    H = R * rng.uniform(0.28, 0.45)
    n = 7
    teintes = [coul_mur, _mix(coul_mur, C_GRAVATS, 0.5),
               _mix(C_GRAVATS, (1.0, 1.0, 1.0), 0.12),
               _mix(coul_mur, C_POUTRE, 0.35)]
    base, mi = [], []
    for k in range(n):
        a = 2 * math.pi * k / n + rng.uniform(-0.2, 0.2)
        rr = R * rng.uniform(0.8, 1.15)
        base.append((x + math.cos(a) * rr, y + math.sin(a) * rr, y0 - 0.05))
        mi.append((x + math.cos(a) * rr * 0.55, y + math.sin(a) * rr * 0.55,
                   y0 + H * 0.62))
    haut = (x + rng.uniform(-0.15, 0.15) * R, y + rng.uniform(-0.15, 0.15) * R,
            y0 + H)
    cg = G(x, y, y0 + H * 0.3)
    for k in range(n):
        j = (k + 1) % n
        _face(m, G, [base[k], base[j], mi[j], mi[k]], rng.choice(teintes), cg, y0)
        _face(m, G, [mi[k], mi[j], haut], rng.choice(teintes), cg, y0)
    for _ in range(rng.randint(2, 3)):
        s = rng.uniform(0.25, 0.55)
        a, d = rng.uniform(0.0, 2 * math.pi), rng.uniform(0.3, 1.0) * R
        cx, cy = x + math.cos(a) * d, y + math.sin(a) * d
        e1 = _unit((math.cos(a + 1.0), math.sin(a + 1.0), rng.uniform(-0.3, 0.3)))
        _prisme(m, G, (cx, cy, y0 + H * (1.0 - d / R) + s * 0.25), e1,
                _rect(s, s, rng.uniform(0.0, 0.8)), s * rng.uniform(1.0, 1.8),
                rng.choice(teintes), (teintes[1], teintes[1]), y0)


# --------------------------------------------------------------- placement

def _point_dans(ferme, rng, essais=12):
    xs = [p[0] for p in ferme]
    ys = [p[1] for p in ferme]
    for _ in range(essais):
        p = (rng.uniform(min(xs), max(xs)), rng.uniform(min(ys), max(ys)))
        if dedans(ferme, p):
            return p
    return None


def _nombre(x, rng):
    """Un arrondi tiré au sort : 1,4 donne 1 ou 2, jamais toujours 1."""
    return int(x + rng.random())


def autour_ruine(m, emp, force, coul_mur, coul_toit, G, rng, libre, aval):
    """Une ruine éventrée : gravats et toit effondré dedans ; pans de mur,
    tuiles et poutres dehors, poussés vers l'aval d'autant plus que l'eau
    était haute. Renvoie le nombre de pièces posées."""
    m.dense = DEBRIS
    ferme = list(emp) + [emp[0]]
    xs = [p[0] for p in emp]
    ys = [p[1] for p in emp]
    cote = min(max(xs) - min(xs), max(ys) - min(ys))
    tour = sum(math.dist(emp[i], emp[(i + 1) % len(emp)])
               for i in range(len(emp)))
    k = max(1.0, tour / DEBRIS_RUINE_M)
    sens = 1.0 if aire_signee(emp) > 0.0 else -1.0
    n = 0

    def dehors():
        for _ in range(12):
            i = rng.randrange(len(emp))
            a, b = emp[i], emp[(i + 1) % len(emp)]
            L = math.dist(a, b)
            if L < 0.5:
                continue
            t = rng.random()
            nx, ny = sens * (b[1] - a[1]) / L, -sens * (b[0] - a[0]) / L
            d = rng.uniform(0.6, 2.5 + 6.0 * force)
            p = (a[0] + (b[0] - a[0]) * t + nx * d,
                 a[1] + (b[1] - a[1]) * t + ny * d)
            u = aval(p)
            g = rng.uniform(0.0, 7.0 * force)
            p = (p[0] + u[0] * g, p[1] + u[1] * g)
            if libre(p) and not dedans(ferme, p):
                return p
        return None

    for _ in range(max(1, _nombre((1.0 + 1.5 * force) * k, rng))):
        p = _point_dans(ferme, rng)
        if p:
            _tas(m, G, p[0], p[1], Y_SOL, coul_mur, rng,
                 rayon=min(1.8, max(0.6, 0.3 * cote)) * rng.uniform(0.7, 1.0))
            n += 1
    # Loin de l'eau la toiture est tombée DANS la coque ; au bord, elle est partie.
    if cote > 3.0 and rng.random() < 0.85 - 0.6 * force:
        p = _point_dans(ferme, rng)
        if p:
            _pan_toit(m, G, p[0], p[1], Y_SOL, coul_toit, rng,
                      taille=min(1.3, cote / 6.0), pente=rng.uniform(0.35, 0.6))
            n += 1
    for _ in range(_nombre((0.5 + 1.5 * force) * k, rng)):
        p = dehors()
        if p:
            _bloc(m, G, p[0], p[1], Y_SOL, coul_mur, rng)
            n += 1
    for _ in range(_nombre((0.2 + 0.6 * force) * k, rng)):
        p = dehors()
        if p:
            _pan_toit(m, G, p[0], p[1], Y_SOL, coul_toit, rng)
            n += 1
    for _ in range(_nombre((0.8 + 1.2 * force) * k, rng)):
        p = dehors() if rng.random() < 0.7 else _point_dans(ferme, rng)
        if p:
            _poutre(m, G, p[0], p[1], Y_SOL, rng)
            n += 1
    # L'embâcle : ce que le courant poussait s'est arrêté contre le mur amont.
    if rng.random() < 0.6 * force:
        n += _embacle(m, G, emp, aval(emp[0]), rng, libre)
    m.dense = None
    return n


def _place(libre, x, y, cap):
    """La plus grande longueur de tronc qui tient sur le sol libre, ou 0."""
    for L in (12.0, 9.0, 6.0):
        if (libre((x + cap[0] * L, y + cap[1] * L))
                and libre((x + cap[0] * L / 2.0, y + cap[1] * L / 2.0))):
            return L
    return 0.0


def dans_ilot(m, anneau, arbres, libre, hauteur, aval, G, rng):
    """Les arbres des jardins noyés, couchés vers l'aval ou cassés debout, puis
    le bois que l'eau a charrié sur le sol libre. Renvoie (troncs, pièces)."""
    m.dense = DEBRIS
    troncs = pieces = 0
    for a in arbres:
        x, y = a[0], a[1]
        f = densite(hauteur((x, y)))
        if f <= 0.0:
            continue
        if rng.random() < 0.15 + 0.5 * (1.0 - f):
            _chicot(m, G, x, y, Y_SOL, rng)
            pieces += 1
            continue
        u = aval((x, y))
        cap = _cap(math.atan2(u[1], u[0]) + rng.uniform(-0.6, 0.6))
        L = _place(libre, x, y, cap)
        if L:
            _tronc(m, G, x, y, Y_SOL, cap, rng, long_max=L)
            troncs += 1
    ferme = list(anneau) + [anneau[0]]
    for _ in range(int(abs(aire_signee(anneau)) / DEBRIS_M2)):
        p = _point_dans(ferme, rng, 1)
        if p is None or not libre(p):
            continue
        if rng.random() > densite(hauteur(p)) * DEBRIS_PART:
            continue
        r = rng.random()
        if r < 0.55:
            u = aval(p)
            cap = _cap(math.atan2(u[1], u[0]) + rng.uniform(-0.7, 0.7))
            L = _place(libre, p[0], p[1], cap)
            if L:
                _tronc(m, G, p[0], p[1], Y_SOL, cap, rng, long_max=L)
                troncs += 1
        elif r < 0.72:
            for _ in range(rng.randint(1, 3)):
                _poutre(m, G, p[0] + rng.uniform(-1, 1), p[1] + rng.uniform(-1, 1),
                        Y_SOL, rng)
            pieces += 1
        else:
            _branchages(m, G, p[0], p[1], Y_SOL, rng)
            pieces += 1
    m.dense = None
    return troncs, pieces


def sur_rue(m, axes, chaussee, hauteur, libre, G, y0, rng):
    """Les obstacles d'une rue envasée : un tronc en travers, ou un tas de
    gravats et ses poutres. C'est ce que « déblayer » enlève."""
    m.dense = DEBRIS
    n = 0
    for axe in axes:
        # ⚠️ Une marche le long de TOUT l'axe : arête par arête, les axes de
        # quelques mètres ne tiraient jamais rien.
        s = rng.uniform(4.0, DEBRIS_RUE_PAS_M)
        fait = 0.0
        for a, b in zip(axe, axe[1:]):
            L = math.dist(a, b)
            if L < 1e-6:
                continue
            tx, ty = (b[0] - a[0]) / L, (b[1] - a[1]) / L
            while s < fait + L:
                p = (a[0] + tx * (s - fait), a[1] + ty * (s - fait))
                s += DEBRIS_RUE_PAS_M * rng.uniform(0.7, 1.3)
                if rng.random() > densite(hauteur(p)) * DEBRIS_RUE_PART:
                    continue
                off = rng.uniform(-0.3, 0.3) * chaussee
                q = (p[0] - ty * off, p[1] + tx * off)
                if not libre(q):
                    continue
                if rng.random() < 0.6:
                    cap = _cap(math.atan2(ty, tx) + math.pi / 2.0
                               + rng.uniform(-0.6, 0.6))
                    lg = chaussee * rng.uniform(0.7, 1.1)
                    pied = (q[0] - cap[0] * lg / 2.0, q[1] - cap[1] * lg / 2.0)
                    _tronc(m, G, pied[0], pied[1], y0, cap, rng, long_max=lg)
                else:
                    _tas(m, G, q[0], q[1], y0, C_FLOTTE, rng,
                         rayon=rng.uniform(0.8, 1.3))
                    _poutre(m, G, q[0], q[1], y0, rng, long_max=chaussee * 0.8)
                n += 1
            fait += L
    m.dense = None
    return n


def haie_arrachee(m, a, b, coul, G, rng, force):
    """Une haie noyée : des morceaux arrachés, le reste couché par le courant
    et bruni. Renvoie la longueur restée debout."""
    L = math.dist(a, b)
    if L < HAIE_SEGMENT_MIN:
        return 0.0
    ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    perte = DEBRIS_HAIE_PERTE[0] + (DEBRIS_HAIE_PERTE[1]
                                    - DEBRIS_HAIE_PERTE[0]) * force
    teinte = _mix(coul, C_HAIE_MORTE, 0.35 + 0.55 * force)
    m.dense = DEBRIS
    reste = 0.0
    n = max(1, int(L / 2.0 + 0.5))
    for k in range(n):
        if rng.random() < perte:
            continue
        t0 = (k + rng.uniform(0.05, 0.2)) / n
        t1 = (k + 1 - rng.uniform(0.05, 0.2)) / n
        haut = HAIE_HAUTEUR * rng.uniform(0.35, 0.8)
        t = (t0 + t1) / 2.0
        c = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t,
             Y_SOL + haut / 2.0 - 0.04)
        _prisme(m, G, c, (ux, uy, 0.0),
                _rect(HAIE_LARGEUR, haut, rng.uniform(-0.45, 0.45)),
                (t1 - t0) * L, teinte, (teinte, teinte), Y_SOL)
        reste += (t1 - t0) * L
    m.dense = None
    return reste
