"""Prolonge les portes de l'ancien cadre jusqu'au bord du dessin, hors simulation."""
import heapq
import math
from collections import Counter, defaultdict

import palette as PAL
from .decor import _d_point_seg
from .geometrie import Maillage, dedans, _densifier, _ruban
from .reglages import Y_CHAUSSEE, Y_SOL

PAS = 12.0
# Auteur, 2026-09-15 : ces deux dessertes s'arrêtent avec les îlots.
ARRETS_LISIERE = {177, 178}


class Surface:
    """Altitude des triangles réellement rendus, y compris leurs diagonales."""
    def __init__(self, maillages):
        self.cases = defaultdict(list)
        for m in maillages:
            for k in range(0, len(m.i), 3):
                a, b, c = [m.v[j] for j in m.i[k:k + 3]]
                det = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2])
                if abs(det) < 1e-9:
                    continue
                for x in range(math.floor(min(a[0], b[0], c[0]) / 16), math.floor(max(a[0], b[0], c[0]) / 16) + 1):
                    for z in range(math.floor(min(a[2], b[2], c[2]) / 16), math.floor(max(a[2], b[2], c[2]) / 16) + 1):
                        self.cases[x, z].append((a, b, c, det))

    def hauteur(self, x, z, defaut):
        haut = -math.inf
        for a, b, c, det in self.cases.get((math.floor(x / 16), math.floor(z / 16)), ()):
            u = ((b[2] - c[2]) * (x - c[0]) + (c[0] - b[0]) * (z - c[2])) / det
            v = ((c[2] - a[2]) * (x - c[0]) + (a[0] - c[0]) * (z - c[2])) / det
            if min(u, v, 1 - u - v) >= -1e-7:
                haut = max(haut, u * a[1] + v * b[1] + (1 - u - v) * c[1])
        return defaut if haut == -math.inf else haut


def portes(routes):
    circulables = [r for r in routes if r["hierarchie"] != "rive" and r["largeur_m"] > 0]
    points = [p for r in circulables for part in r["parts"] for p in part]
    cadre = (min(p[0] for p in points), min(p[1] for p in points),
             max(p[0] for p in points), max(p[1] for p in points))
    cle = lambda p: tuple(round(v, 1) for v in p)
    degre = Counter(cle(p) for r in circulables for part in r["parts"]
                    for a, b in zip(part, part[1:]) if math.dist(a, b) > .1 for p in (a, b))
    out = []
    for r in circulables:
        if r["fid"] in ARRETS_LISIERE:
            continue
        for part in r["parts"]:
            for k, voisin in ((0, 1), (-1, -2)):
                a, b = part[k], part[voisin]
                if degre[cle(a)] != 1 or math.dist(a, b) < .1:
                    continue
                ecarts = [abs(a[0] - cadre[0]), abs(a[1] - cadre[1]),
                          abs(a[0] - cadre[2]), abs(a[1] - cadre[3])]
                # Les impasses dans la ville ne deviennent pas des sorties.
                if min(ecarts) > 2.0:
                    continue
                out.append((r, a, b, ecarts.index(min(ecarts))))
    return out


def tracer(a, b, cote, cadre, libre, hauteur):
    """Cherche une continuation sur terre ferme, puis enlève les angles de grille."""
    x0, y0, x1, y1 = cadre
    nx, ny = math.ceil((x1 - x0) / PAS), math.ceil((y1 - y0) / PAS)
    dx, dy = (x1 - x0) / nx, (y1 - y0) / ny
    point = lambda ij: (x0 + ij[0] * dx, y0 + ij[1] * dy)
    depart = (round((a[0] - x0) / dx), round((a[1] - y0) / dy))
    vx, vy = a[0] - b[0], a[1] - b[1]
    norme = math.hypot(vx, vy)
    vx, vy = vx / norme, vy / norme
    def restant(ij):
        return (ij[0] * dx, ij[1] * dy, (nx - ij[0]) * dx, (ny - ij[1]) * dy)[cote]
    def segment(p, q):
        return all(libre(t) for t in _densifier([p, q], 3.0))
    couts, avant = {depart: 0.0}, {}
    tas = [(restant(depart), 0.0, depart)]
    while tas:
        _, cout, ij = heapq.heappop(tas)
        if cout != couts[ij]:
            continue
        p = point(ij)
        if restant(ij) < .01:
            chemin = [p]
            while ij in avant:
                ij = avant[ij]
                chemin.append(point(ij))
            chemin.reverse()
            chemin[0] = a
            # Simplification bornée : pas de raccourci au travers de l'Ilse.
            simple = [a]
            k = 0
            while k < len(chemin) - 1:
                j = min(k + 12, len(chemin) - 1)
                while j > k + 1 and not segment(simple[-1], chemin[j]):
                    j -= 1
                simple.append(chemin[j])
                k = j
            for _ in range(3):
                doux = [simple[0]]
                for p, q in zip(simple, simple[1:]):
                    doux.extend([(p[0] * .75 + q[0] * .25, p[1] * .75 + q[1] * .25),
                                 (p[0] * .25 + q[0] * .75, p[1] * .25 + q[1] * .75)])
                doux.append(simple[-1])
                if all(segment(p, q) for p, q in zip(doux, doux[1:])):
                    simple = doux
            ligne = _densifier(simple, 4.0)
            if not all(segment(p, q) for p, q in zip(ligne, ligne[1:])):
                raise ValueError("Le raccord de sortie traverse un obstacle")
            return ligne
        for di, dj in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
            voisin = (ij[0] + di, ij[1] + dj)
            if not (0 <= voisin[0] <= nx and 0 <= voisin[1] <= ny):
                continue
            q = point(voisin)
            if not libre(q) or not segment(p, q):
                continue
            if (q[0] - a[0]) * vx + (q[1] - a[1]) * vy < -PAS:
                continue
            ecart = abs((q[0] - a[0]) * vy - (q[1] - a[1]) * vx)
            nouveau = cout + math.dist(p, q) * (1 + (ecart / 180.0) ** 2)
            nouveau += abs(hauteur(*q) - hauteur(*p)) * 8
            if nouveau < couts.get(voisin, math.inf):
                couts[voisin], avant[voisin] = nouveau, ij
                heapq.heappush(tas, (nouveau + restant(voisin), nouveau, voisin))
    raise ValueError("Aucun passage sur terre ferme vers le bord de la carte")


def sorties(routes, ilots, cadre, massifs, relief, G, largeurs, surface):
    obstacles = []
    for d in ilots.values():
        if d["sous_type"] == "champ":
            continue
        an = d["brut"]
        obstacles.append((min(p[0] for p in an), min(p[1] for p in an),
                          max(p[0] for p in an), max(p[1] for p in an), an + an[:1]))
    m, accotements, axes = Maillage(), Maillage(), []
    for r, a, b, cote in portes(routes):
        largeur = min(largeurs.get(r["hierarchie"], 8.5), r["largeur_m"])
        marge = largeur / 2 + 2.0
        cache = {}
        def libre(p):
            if p in cache:
                return cache[p]
            ok = True
            for x0, y0, x1, y1, an in obstacles:
                if not (x0 - marge <= p[0] <= x1 + marge and y0 - marge <= p[1] <= y1 + marge):
                    continue
                if dedans(an, p) or min(_d_point_seg(p, c, d) for c, d in zip(an, an[1:])) < marge:
                    ok = False
                    break
            cache[p] = ok
            return ok
        ligne = tracer(a, b, cote, cadre, libre, massifs.hauteur)
        def proj(x, y, h):
            raccord = min(1.0, math.dist((x, y), a) / 24.0)
            p = G(x, y, Y_SOL + relief.z(x, y) + massifs.hauteur(x, y))
            haut = surface.hauteur(p[0], p[2], p[1]) + .16
            origine = G(x, y, Y_CHAUSSEE)[1]
            return (p[0], origine * (1 - raccord) + haut * raccord + h, p[2])
        for cote_acc in (-1, 1):
            _ruban(accotements, ligne, .75, PAL.vers_lineaire("#899571"), proj, -.025,
                   decal=cote_acc * (largeur / 2 + .375), bouts=False)
        for bande in range(4):
            _ruban(m, ligne, largeur / 4, PAL.vers_lineaire(PAL.MINERAL), proj, 0.0,
                   decal=-largeur / 2 + largeur / 4 * (bande + .5), bouts=False)
        axes.append({"fid": r["fid"], "largeur_m": largeur, "cote": cote,
                     "points": [list(p) for p in ligne]})
    print("  sorties de ville : %d routes prolongées jusqu'au cadre, %.0f m sur terre ferme"
          % (len(axes), sum(math.dist(a, b) for axe in axes for a, b in zip(axe["points"], axe["points"][1:]))))
    return {"sol": m.json(), "accotements": accotements.json(), "axes": axes}


def hors_routes(arbres, axes):
    cases = defaultdict(list)
    for axe in axes:
        marge = axe["largeur_m"] / 2 + 7
        for a, b in zip(axe["points"], axe["points"][1:]):
            for x in range(math.floor((min(a[0], b[0]) - marge) / 64), math.floor((max(a[0], b[0]) + marge) / 64) + 1):
                for z in range(math.floor((min(a[1], b[1]) - marge) / 64), math.floor((max(a[1], b[1]) + marge) / 64) + 1):
                    cases[x, z].append((a, b, marge))
    return [[arbre for arbre in essence if not any(
        min(a[0], b[0]) - marge <= arbre[0] <= max(a[0], b[0]) + marge
        and min(a[1], b[1]) - marge <= arbre[2] <= max(a[1], b[1]) + marge
        and _d_point_seg((arbre[0], arbre[2]), a, b) < marge
        for a, b, marge in cases.get((math.floor(arbre[0] / 64), math.floor(arbre[2] / 64)), ()))] for essence in arbres]
