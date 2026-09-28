"""Les fermes des domaines : une cour, des bâtiments, un chemin jusqu'à la route la plus proche.

Le chemin suit les limites des champs, comme les sorties : il ne coupe aucune culture.
Tout est dérivé de la carte, sauf `FERMES`, qui est du level design.
"""
import heapq
import math
import random
from collections import defaultdict

import palette as PAL
from .batiments import _masse
from .camps import _dedans
from .decor import _d_point_seg
from .geometrie import Maillage, _densifier, _ruban, aire_signee
from .reglages import FACADE_AVEUGLE, FACADE_LOGEMENT, FACADE_PORTE
from .sorties import LimitesChamps, portes

# 🚜 LEVEL DESIGN : le champ qui porte la cour de chaque domaine (proposé le
# 2026-09-26, à corriger à la main). D11 n'en a pas : ce sont les champs du camp
# de l'ouverture.
FERMES = {
    "D1": 1001, "D2": 1012, "D3": 1006, "D4": 1027, "D5": 1032,
    "D6": 1054, "D7": 1059, "D8": 1069, "D9": 1063, "D10": 1080,
}

CHEMIN_LARGEUR = 4.0
RECUL = 1.5                # entre le bord du chemin et la cour
CHEMIN_CIBLE_M = 200.0     # la longueur de chemin préférée quand un champ hésite

# Cinq formes, chacune deux fois sur les dix domaines ; les mesures sont tirées
# du nom du domaine (retour de l'auteur, 2026-09-28 : « plus petites, plus variées »).
FORMES = ["cour", "equerre", "longere", "paralleles", "hangar"]


def _plan(dom):
    """(largeur, profondeur, centre de la cour, bâtiments) d'un domaine.

    u court le long du chemin, a entre dans le champ ; la cour s'ouvre sur le chemin.
    Un bâtiment : (sorte, u0, u1, a0, a1, niveaux, pente, faîtage le long de u ?).
    """
    r = random.Random(dom)

    def t(lo, hi):
        return round(r.uniform(lo, hi) * 2) / 2
    forme = FORMES[(int(dom[1:]) - 1) % len(FORMES)]
    gd = t(10.0, 12.0)
    if forme == "cour":
        lu, ln = t(28, 34), t(26, 32)
        mw, ml = t(9, 11), min(t(10, 12), ln - gd - 4)
        hw, hl = t(9, 12), min(t(9, 13), ln - gd - 4)
        bat = [("maison", 0, mw, 2, 2 + ml, 2, 0.90, False),
               ("grange", 0, lu - t(0, 5), ln - gd, ln, 2, 0.75, True),
               ("hangar", lu - hw, lu, 3, 3 + hl, r.choice((1, 2)), 0.30, False)]
        centre = (lu / 2, (ln - gd) / 2)
    elif forme == "equerre":
        lu, ln = t(24, 30), t(22, 28)
        mw, ml = t(9, 11), min(t(10, 13), ln - gd - 3)
        bat = [("maison", 0, mw, 1, 1 + ml, r.choice((1, 2)), 0.90, False),
               ("grange", 0, lu, ln - gd, ln, 2, 0.75, True)]
        centre = ((lu + mw) / 2, (ln - gd) / 2)
    elif forme == "longere":
        # Maison et grange sous deux toits accolés, au fond d'une cour peu profonde.
        mw, gl, ln = t(10, 13), t(14, 20), t(18, 22)
        lu = mw + gl + t(0, 4)
        hw, hl = t(7, 9), min(t(6, 8), ln - gd - 2)
        bat = [("maison", 0, mw, ln - 9, ln, 2, 0.90, True),
               ("grange", mw, mw + gl, ln - gd, ln, 2, 0.75, True),
               ("hangar", lu - hw, lu, 0, hl, 1, 0.30, True)]
        centre = (lu / 2, (ln - gd) / 2)
    elif forme == "paralleles":
        lu, ln = t(26, 32), t(26, 30)
        mw = min(t(11, 13), lu / 2 - 3)
        gl = t(18, lu)
        bat = [("maison", 0, mw, 0, 8.5, 2, 0.90, True),
               ("grange", lu - gl, lu, ln - gd, ln, 2, 0.75, True)]
        if r.random() < 0.5:
            bat.append(("hangar", lu - t(7, 9), lu, 0, min(t(7, 9), ln - gd - 3), 1, 0.30, False))
        centre = (lu / 2, (8.5 + ln - gd) / 2)
    else:
        # La ferme d'après-guerre : une maison, un grand hangar à faible pente.
        lu, ln = t(26, 32), t(24, 28)
        mw, ml = t(9, 10), t(8, 10)
        hw, hd = t(16, 22), t(12, 14)
        bat = [("maison", 0, mw, 2, 2 + ml, 2, 0.60, False),
               ("hangar", lu - hw, lu, ln - hd, ln, 2, 0.25, True)]
        centre = (lu / 2, (ln - hd) / 2)
    if r.random() < 0.5:
        bat = [(s, lu - u1, lu - u0, a0, a1, niv, pe, lg) for s, u0, u1, a0, a1, niv, pe, lg in bat]
        centre = (lu - centre[0], centre[1])
    return forme, lu, ln, centre, bat


def _cle(p):
    return (round(p[0], 2), round(p[1], 2))


class Reseau:
    """Les limites de champs praticables, et leur distance à une route.

    `toutes` : n'importe quelle route circulable ; sinon les seules grandes routes.
    """

    def __init__(self, ilots, routes, toutes=False):
        self.pos, proprio = {}, defaultdict(set)
        for fid, d in ilots.items():
            if d["sous_type"] != "champ":
                continue
            an = d["brut"]
            for a, b in zip(an, an[1:] + an[:1]):
                ka, kb = _cle(a), _cle(b)
                if ka != kb:
                    self.pos[ka], self.pos[kb] = tuple(a), tuple(b)
                    proprio[tuple(sorted((ka, kb)))].add(fid)
        # Les grandes routes sont celles qui sortent de la ville, avec leur prolongement.
        grandes = {r["fid"] for r, *_ in portes(routes)}
        self.grandes = grandes
        limites = LimitesChamps(ilots)
        cibles = [(a, b, r["largeur_m"] / 2 + 3.0, r["fid"]) for r in routes
                  if (r["hierarchie"] != "rive" and (r["largeur_m"] or 0) > 0
                      if toutes else r["fid"] in grandes)
                  for part in r["parts"] for a, b in zip(part, part[1:])]
        for r, a, b, _ in portes(routes):
            ligne = limites.tracer(a, b, r["largeur_m"])
            cibles += [(p, q, 6.0, r["fid"]) for p, q in zip(ligne, ligne[1:])]
        rues = [(a, b, (r["largeur_m"] or 0) / 2 + 4.0) for r in routes
                for part in r["parts"] for a, b in zip(part, part[1:])]
        autres = [(a, b, 25.0 if d["sous_type"] == "riviere" else 3.0)
                  for d in ilots.values() if d["sous_type"] != "champ"
                  for a, b in zip(d["brut"], d["brut"][1:] + d["brut"][:1])]

        def pres(p, segs):
            return next((s for s in segs if _d_point_seg(p, s[0], s[1]) < s[2]), None)

        self.voisins = defaultdict(list)
        for (ka, kb), fids in proprio.items():
            a, b = self.pos[ka], self.pos[kb]
            mi = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
            # Ni le long d'une rue, ni contre la ville, ni sur la berge.
            if pres(mi, rues) or pres(mi, autres):
                continue
            poids = math.dist(a, b) * (1.0 if len(fids) == 2 else 1.25)
            self.voisins[ka].append((kb, poids))
            self.voisins[kb].append((ka, poids))
        self.route = {}
        for k, p in self.pos.items():
            s = pres(p, cibles)
            if s:
                self.route[k] = s[3]
        self.dist, self.suite = {k: 0.0 for k in self.route}, {}
        tas = [(0.0, k) for k in self.route]
        while tas:
            dk, k = heapq.heappop(tas)
            if dk > self.dist[k]:
                continue
            for v, w in self.voisins[k]:
                if dk + w < self.dist.get(v, math.inf):
                    self.dist[v], self.suite[v] = dk + w, k
                    heapq.heappush(tas, (dk + w, v))

    def chemin(self, k):
        out = [self.pos[k]]
        while k in self.suite:
            k = self.suite[k]
            out.append(self.pos[k])
        return out, self.route.get(k)


def _cour(ring, a, b, s0, relief_z, lu, ln):
    """Le repère de la cour sur l'arête a→b, ou None si elle ne tient pas dans le champ."""
    L = math.dist(a, b)
    u = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
    n = (-u[1], u[0])
    m = (a[0] + u[0] * L / 2 + n[0] * 3, a[1] + u[1] * L / 2 + n[1] * 3)
    if not _dedans(ring, m):
        n = (-n[0], -n[1])
    o = (a[0] + u[0] * s0, a[1] + u[1] * s0)

    def P(du, dn):
        return (o[0] + u[0] * du + n[0] * dn, o[1] + u[1] * du + n[1] * dn)
    n0 = CHEMIN_LARGEUR / 2 + RECUL
    bord = [P(du, dn) for du in range(-4, int(lu) + 5, 4) for dn in (n0, n0 + ln + 4)] \
        + [P(du, dn) for du in (-4, lu + 4) for dn in range(int(n0), int(n0 + ln) + 5, 4)]
    if not all(_dedans(ring, q) for q in bord):
        return None
    z = [relief_z(*q) for q in bord]
    if max(z) - min(z) > 0.25:
        return None
    return P, n0


def placer(ilots, routes, domaines, relief_z):
    """Une ferme par domaine de `FERMES` : sa cour, ses bâtiments, son chemin."""
    # La cour se place encore d'après les grandes routes (placement vu par l'auteur
    # le 2026-09-28) ; son chemin, lui, rejoint la route la plus proche.
    reseau = Reseau(ilots, routes)
    proche = Reseau(ilots, routes, toutes=True)
    noms = dict(domaines)
    out = []
    for dom, fid in sorted(FERMES.items(), key=lambda kv: int(kv[0][1:])):
        if fid not in ilots or dom not in noms:
            print("    🔴 ferme %s : champ %s introuvable" % (dom, fid))
            continue
        ring = ilots[fid]["brut"]
        forme, lu, ln, centre, plan = _plan(dom)
        meilleur = None
        for i in range(len(ring)):
            for j in (i - 1, (i + 1) % len(ring)):
                ka, kb = _cle(ring[i]), _cle(ring[j])
                # La cour se pose près de `ka`, le chemin part vers `kb` sans revenir.
                if kb not in reseau.dist or ka in reseau.route or \
                        not any(v == kb for v, _ in reseau.voisins[ka]) or \
                        reseau.pos[ka] in reseau.chemin(kb)[0]:
                    continue
                a, b = reseau.pos[ka], reseau.pos[kb]
                L = math.dist(a, b)
                for s0 in range(4, int(L - lu - 4) + 1, 4):
                    cour = _cour(ring, a, b, s0, relief_z, lu, ln)
                    if cour is None:
                        continue
                    longueur = L - s0 - lu / 2 + reseau.dist[kb]
                    note = abs(longueur - CHEMIN_CIBLE_M)
                    if meilleur is None or note < meilleur[0]:
                        meilleur = (note, cour, ka, kb)
                    break
        if meilleur is None:
            print("    🔴 ferme %s : aucune arête du champ %d ne porte la cour et ne mène à une grande route"
                  % (dom, fid))
            continue
        _note, (P, n0), ka, kb = meilleur
        entree = P(lu / 2, 0.0)
        # Depuis l'entrée, par l'un ou l'autre bout de l'arête qui porte la cour.
        issues = [(math.dist(entree, proche.pos[k]) + proche.dist[k], k)
                  for k in (ka, kb) if k in proche.dist]
        if not issues:
            print("    🔴 ferme %s : aucune route atteignable depuis le champ %d" % (dom, fid))
            continue
        longueur, k = min(issues)
        suite, route = proche.chemin(k)
        out.append({
            "domaine": dom, "champ": fid, "route": route, "longueur": longueur,
            "forme": forme, "chemin": [entree] + suite, "profondeur": ln,
            "cour": [P(0, n0), P(lu, n0), P(lu, n0 + ln), P(0, n0 + ln)],
            "batiments": [(sorte, [P(u0, n0 + a0), P(u1, n0 + a0), P(u1, n0 + a1), P(u0, n0 + a1)],
                           niv, pente, P(1, 0) if long_u else P(0, 1), P(0, 0),
                           P(centre[0], n0 + centre[1]))
                          for sorte, u0, u1, a0, a1, niv, pente, long_u in plan],
        })
    return out


def gene(fermes, p, marge=4.0):
    """Vrai si un container posé en `p` tomberait dans une cour."""
    for f in fermes:
        c = f["cour"]
        if _dedans(c, p) or min(_d_point_seg(p, a, b) for a, b in zip(c, c[1:] + c[:1])) < marge:
            return True
    return False


def a_deboiser(fermes):
    """Chemins et cours au format des axes de `hors_routes`."""
    out = [{"points": f["chemin"], "largeur_m": CHEMIN_LARGEUR} for f in fermes]
    for f in fermes:
        c = f["cour"]
        m0 = ((c[0][0] + c[3][0]) / 2, (c[0][1] + c[3][1]) / 2)
        m1 = ((c[1][0] + c[2][0]) / 2, (c[1][1] + c[2][1]) / 2)
        out.append({"points": [m0, m1], "largeur_m": max(4.0, f["profondeur"] - 12.0)})
    return out


def maillages(fermes, G, surface):
    """Le sol (chemins, cours) et le bâti des fermes, posés sur le champ rendu."""
    sol, bati = Maillage(), Maillage()
    # Un asphalte usé, plus clair que la grande route : le gris du sol nu ne se
    # lisait pas sur les chaumes.
    c_chemin = PAL.vers_lineaire(PAL.melanger(PAL.MINERAL, PAL.MINERAL_CLAIR, 0.4))
    c_cour = PAL.vers_lineaire(PAL.melanger(PAL.MINERAL_CLAIR, PAL.LIMON, 0.55))

    def pose(dy):
        def proj(x, y, h):
            p = G(x, y, 0.0)
            return (p[0], surface.hauteur(p[0], p[2], p[1]) + dy + h, p[2])
        return proj
    ok = tot = 0
    for f in fermes:
        # Débité tous les 4 m : sinon le dernier tronçon, qui finit au niveau de
        # la chaussée, plongeait sous le champ sur toute sa longueur.
        _ruban(sol, _densifier(f["chemin"], 4.0), CHEMIN_LARGEUR, c_chemin, pose(0.035),
               0.0, bouts=False)
        c = f["cour"] if aire_signee(f["cour"]) > 0 else f["cour"][::-1]
        pr = pose(0.02)
        sol.triangle(pr(*c[0], 0), pr(*c[1], 0), pr(*c[2], 0), c_cour)
        sol.triangle(pr(*c[0], 0), pr(*c[2], 0), pr(*c[3], 0), c_cour)
        base = min(pose(0.0)(p[0], p[1], 0.0)[1] for p in f["cour"])

        def Gf(x, y, h):
            p = G(x, y, 0.0)
            return (p[0], base + h, p[2])
        for sorte, an, niv, pente, pu, p0, centre_cour in f["batiments"]:
            ax = (pu[0] - p0[0], pu[1] - p0[1])
            if aire_signee(an) < 0:
                an = an[::-1]
            gr = int(abs(an[0][0] * 100)) ^ int(abs(an[0][1] * 100))
            tissu = {"maison": "coeur_ancien", "grange": "ilot_compact",
                     "hangar": "friche_industrielle"}[sorte]
            mur = PAL.vers_lineaire(PAL.couleur_mur(tissu, gr))
            toit = PAL.vers_lineaire(PAL.couleur_toit(
                "friche_industrielle" if sorte == "hangar" else "coeur_ancien", gr))
            # La façade qui regarde la cour porte la porte ; la grange et le hangar
            # n'ouvrent que sur elle.
            genres = []
            for a, b in zip(an, an[1:] + an[:1]):
                m = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
                dehors = (b[1] - a[1], a[0] - b[0])
                vers_cour = (centre_cour[0] - m[0]) * dehors[0] + (centre_cour[1] - m[1]) * dehors[1] > 0
                if sorte == "maison":
                    genres.append(FACADE_PORTE if vers_cour else FACADE_LOGEMENT)
                else:
                    genres.append(FACADE_LOGEMENT if vers_cour else FACADE_AVEUGLE)
            a, b, _h, _t = _masse(bati, an, {}, mur, Gf, niv, pente, ax, toit, genres,
                                  random.Random(gr).random(), 1.0,
                                  1 if sorte == "maison" else 5)
            ok += a
            tot += b
    # Le centre de chaque cour, pour numéroter les aperçus.
    reperes = [[round(v, 1) for v in G(sum(p[0] for p in f["cour"]) / 4,
                                       sum(p[1] for p in f["cour"]) / 4, 0.0)] + [f["domaine"]]
               for f in fermes]
    return {"sol": sol.json(), "bati": bati.json(), "reperes": reperes}, ok, tot
