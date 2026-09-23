"""Prolonge les sorties uniquement sur les limites communes des champs SVG."""
import math
from collections import Counter, defaultdict

import palette as PAL
from .decor import _d_point_seg
from .geometrie import Maillage, _cumul, _densifier, _le_long, _ruban, _tronquer
from .reglages import AXE_TRAIT, LARGEUR_LIGNE, Y_SOL

# Auteur, 2026-09-15 : ces deux dessertes s'arrêtent avec les îlots.
ARRETS_LISIERE = {177, 178}

# La rue ne tombe jamais pile sur la limite des champs : sur ces premiers mètres,
# la sortie part du bout de la rue, dans son axe, et rejoint la limite en courbe.
RACCORD_M = 30.0
AXE_VIDE_CAMPAGNE = 10.0   # hors agglomération : 3 m de trait, 10 m de vide


def raccorder(ligne, a, b):
    """Remplace le début de la ligne par une courbe tangente à la rue et à la limite."""
    cum = _cumul(ligne)
    if cum[-1] < RACCORD_M + 1.0:
        return ligne
    q, tq = _le_long(ligne, cum, RACCORD_M)
    L = math.dist(a, b)
    ta = ((a[0] - b[0]) / L, (a[1] - b[1]) / L)
    p1 = (a[0] + ta[0] * RACCORD_M / 3, a[1] + ta[1] * RACCORD_M / 3)
    p2 = (q[0] - tq[0] * RACCORD_M / 3, q[1] - tq[1] * RACCORD_M / 3)
    courbe = []
    for k in range(8):
        t = k / 8
        u = 1 - t
        courbe.append(tuple(u ** 3 * a[i] + 3 * u * u * t * p1[i] + 3 * u * t * t * p2[i] + t ** 3 * q[i]
                            for i in (0, 1)))
    return courbe + _tronquer(ligne, cum, RACCORD_M, cum[-1])


def tirets(ligne):
    cum = _cumul(ligne)
    s, out = AXE_VIDE_CAMPAGNE / 2, []
    while s + AXE_TRAIT < cum[-1] - RACCORD_M / 2:
        if s > RACCORD_M / 2:
            out.append(_tronquer(ligne, cum, s, s + AXE_TRAIT))
        s += AXE_TRAIT + AXE_VIDE_CAMPAGNE
    return out


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


class LimitesChamps:
    """La source est soudée par atelier_svg : aucun arrondi ni nouveau tracé ici."""
    def __init__(self, ilots):
        proprietaires = defaultdict(set)
        for fid, d in ilots.items():
            if d["sous_type"] != "champ":
                continue
            an = d["brut"]
            for a, b in zip(an, an[1:] + an[:1]):
                if math.dist(a, b) > 1e-6:
                    proprietaires[tuple(sorted((tuple(a), tuple(b))))].add(fid)
        self.segments = [ab for ab, fids in proprietaires.items() if len(fids) == 2]
        self.voisins = defaultdict(list)
        self.bords = {p for ab, fids in proprietaires.items() if len(fids) == 1 for p in ab}
        for a, b in self.segments:
            self.voisins[a].append(b)
            self.voisins[b].append(a)

    def tracer(self, a, b, largeur):
        if not self.segments:
            return []
        sommet = min(self.voisins, key=lambda p: math.dist(p, a))
        if math.dist(sommet, a) < .5:
            depart = sommet
            candidats = self.voisins[sommet]
        else:
            c, d = min(self.segments, key=lambda cd: _d_point_seg(a, *cd))
            vx, vy = d[0] - c[0], d[1] - c[1]
            t = max(0, min(1, ((a[0] - c[0]) * vx + (a[1] - c[1]) * vy) / (vx * vx + vy * vy)))
            depart = (c[0] + t * vx, c[1] + t * vy)
            if math.dist(depart, a) > largeur / 2:
                return []
            candidats = [c, d]
        ligne, vus = [depart], {depart}
        direction = (a[0] - b[0], a[1] - b[1])
        initiale = direction
        while candidats:
            p = ligne[-1]
            possibles = [q for q in candidats if q not in vus and
                         (q[0] - p[0]) * initiale[0] + (q[1] - p[1]) * initiale[1] > 0]
            if not possibles:
                break
            q = max(possibles, key=lambda q: ((q[0] - p[0]) * direction[0] +
                                             (q[1] - p[1]) * direction[1]) / math.dist(p, q))
            ligne.append(q)
            vus.add(q)
            if q in self.bords:
                break
            direction = (q[0] - p[0], q[1] - p[1])
            candidats = self.voisins[q]
        # Garder chaque angle du SVG : arrondir la route la ferait quitter la limite.
        return _densifier(ligne, 4.0) if len(ligne) > 1 else []


def sorties(routes, ilots, massifs, relief, G, largeurs, surface):
    limites = LimitesChamps(ilots)
    m, accotements, marquage, axes = Maillage(), Maillage(), Maillage(), []
    for r, a, b, cote in portes(routes):
        largeur = min(largeurs.get(r["hierarchie"], 8.5), r["largeur_m"])
        ligne = limites.tracer(a, b, largeur)
        if not ligne:
            print("    sortie %d : aucune limite commune de champs à prolonger" % r["fid"])
            continue
        ecart = math.dist(ligne[0], a)
        ligne = raccorder(ligne, a, b)
        def proj(x, y, h):
            # 🔄 Elle partait de la cote de la rue, 7 cm sous le champ : ses
            # premiers mètres étaient enterrés et la sortie semblait décollée de la rue.
            raccord = min(1.0, math.dist((x, y), a) / 24.0)
            p = G(x, y, Y_SOL + relief.z(x, y) + massifs.hauteur(x, y))
            haut = surface.hauteur(p[0], p[2], p[1]) + .05 + .11 * raccord
            return (p[0], haut + h, p[2])
        for cote_acc in (-1, 1):
            _ruban(accotements, ligne, .75, PAL.vers_lineaire("#899571"), proj, -.025,
                   decal=cote_acc * (largeur / 2 + .375), bouts=False)
        for bande in range(4):
            _ruban(m, ligne, largeur / 4, PAL.vers_lineaire(PAL.MINERAL), proj, 0.0,
                   decal=-largeur / 2 + largeur / 4 * (bande + .5), bouts=False)
        for trait in tirets(ligne):
            _ruban(marquage, trait, LARGEUR_LIGNE, PAL.vers_lineaire(PAL.MARQUAGE), proj, .01,
                   bouts=False)
        print("    sortie %d : départ recollé au bout de la rue (%.1f m d'écart)" % (r["fid"], ecart))
        axes.append({"fid": r["fid"], "largeur_m": largeur,
                     "points": [list(p) for p in ligne]})
    print("  sorties de ville : %d routes prolongées, %.0f m exactement entre les champs"
          % (len(axes), sum(math.dist(a, b) for axe in axes for a, b in zip(axe["points"], axe["points"][1:]))))
    return {"sol": m.json(), "accotements": accotements.json(),
            "marquage": marquage.json(), "axes": axes}


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
