"""Relief extérieur et campagne sélectionnable, sans modifier les données urbaines."""
import math
import random
from functools import lru_cache

import palette as PAL
from .geometrie import Maillage


PORTEE = 3600.0
PAS = 65.0
GRAINE = 917


def fondu(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def paysage(largeur, profondeur, chenal, cx, cy, routes, sols, ilots):
    hx, hz = largeur / 2, profondeur / 2
    rng = random.Random(GRAINE)
    # Les sorties sont les deux bouchons du chenal sur le bord de la carte.
    canaux = []
    for a, b in chenal.berges:
        p, q = (a[0] - cx, cy - a[1]), (b[0] - cx, cy - b[1])
        if not ((p[0] > hx - 3 and q[0] > hx - 3) or
                (p[1] < -hz + 3 and q[1] < -hz + 3)):
            continue
        mx, mz = (p[0] + q[0]) / 2, (p[1] + q[1]) / 2
        largeur_eau = math.dist(p, q)
        if largeur_eau < 12:
            continue
        est = mx > hx - 3
        rails = []
        for k in range(131):
            t = k * 30.0
            virage = (145 * math.sin(t / 350) + 65 * math.sin(t / 790)) * fondu(0, 220, t)
            x = hx + t if est else mx + virage
            z = mz + virage if est else -hz - t
            demi = largeur_eau / 2 * (1 + .23 * math.sin(t / 145) * fondu(0, 130, t))
            rails.append(((x, z - demi), (x, z + demi)) if est
                         else ((x - demi, z), (x + demi, z)))
        for (a, b), (c, d) in zip(rails, rails[1:]):
            canaux.append([a, b, d, c])

    def distance(x, z):
        return math.hypot(max(abs(x) - hx, 0), max(abs(z) - hz, 0))

    segments = []
    for a, b, c, d in canaux:
        px, pz = (a[0]+b[0])/2, (a[1]+b[1])/2
        qx, qz = (c[0]+d[0])/2, (c[1]+d[1])/2
        vx, vz = qx-px, qz-pz
        segments.append((px,pz,vx,vz,vx*vx+vz*vz,math.dist(a,b)/2,
                         min(px,qx),min(pz,qz),max(px,qx),max(pz,qz)))

    @lru_cache(maxsize=250000)
    def bord_riviere(x, z):
        dist = 1e9
        for px,pz,vx,vz,lg,demi,x0,z0,x1,z1 in segments:
            if max(x0-x,x-x1,z0-z,z-z1) > dist+demi:
                continue
            t = max(0, min(1, ((x-px)*vx + (z-pz)*vz) / lg))
            dist = min(dist, math.hypot(x-px-t*vx, z-pz-t*vz) - demi)
        return dist

    @lru_cache(maxsize=250000)
    def altitude(x, z):
        d = distance(x, z)
        rive = chenal.niveau_rive(cx + x, cy - z)
        cote = fondu(220, 780, abs(x - 65 * math.sin(z / 520)))
        collines = 0.70 + 0.19 * math.sin(z / 285 + x / 730) + 0.11 * math.cos(z / 131 - x / 270)
        cretes = 420 * math.exp(-((abs(x) - hx - 740 - 160 * math.sin(z / 430)) / 480) ** 2)
        arriere = 270 * fondu(1050, 2100, d)
        relief = (cretes * collines + arriere) * cote * fondu(130, 580, d)
        relief += 13 * fondu(0, 250, d) * (1 + math.sin(x / 155 + z / 210)) * cote
        berge = bord_riviere(x, z)
        fond = rive + 0.03 + relief * fondu(0, 190, berge)
        return -2.4 + (fond + 2.4) * fondu(0, 12, berge)

    def lisiere(x, z):
        return math.hypot(x, z * .82) - (820 + 85 * math.sin(z / 180) + 55 * math.cos(x / 160))

    sol, eau = Maillage(), Maillage()
    vert = PAL.vers_lineaire("#687e49")

    def axe(a, b):
        n = math.ceil((b - a) / PAS)
        return [a + (b - a) * k / n for k in range(n + 1)]

    def point(x, z):
        return (x, altitude(x, z), z)

    def bande(x0, x1, z0, z1):
        from .geometrie import D4C, dedans, _coupe_boite
        zs, xs = axe(z0, z1), axe(x0, x1)
        for za, zb in zip(zs, zs[1:]):
            for xa, xb in zip(xs, xs[1:]):
                proches = [c for c in canaux if min(p[0] for p in c) <= xb
                           and max(p[0] for p in c) >= xa and min(p[1] for p in c) <= zb
                           and max(p[1] for p in c) >= za]
                pieces = [[(xa, za), (xb, za), (xb, zb), (xa, zb)]]
                for canal in proches:
                    for a, b in zip(canal, canal[1:] + canal[:1]):
                        if _coupe_boite((a, b), xa, za, xb, zb):
                            pieces = [p for mo in pieces for p in D4C.couper(mo, a, (b[1]-a[1], a[0]-b[0]))]
                for mo in pieces:
                    centre = (sum(p[0] for p in mo)/len(mo), sum(p[1] for p in mo)/len(mo))
                    if any(dedans(c + c[:1], centre) for c in proches):
                        continue
                    for k in range(1, len(mo)-1):
                        sol.triangle(point(*mo[0]), point(*mo[k+1]), point(*mo[k]), vert)

    bande(-PORTEE, -hx, -PORTEE, PORTEE)
    bande(hx, PORTEE, -PORTEE, PORTEE)
    bande(-hx, hx, -PORTEE, -hz)
    bande(-hx, hx, hz, PORTEE)
    from .geometrie import aire_signee
    for canal in canaux:
        if aire_signee(canal) < 0:
            canal = list(reversed(canal))
        for k in (1, 2):
            eau.triangle((canal[0][0], -2, canal[0][1]),
                         (canal[k+1][0], -2, canal[k+1][1]),
                         (canal[k][0], -2, canal[k][1]), PAL.vers_lineaire("#68adb3"))
    # Normales continues : le relief doit lire des versants, pas des facettes.
    for k, (x, _, z) in enumerate(sol.v):
        nx = altitude(x - 1, z) - altitude(x + 1, z)
        nz = altitude(x, z - 1) - altitude(x, z + 1)
        norme = math.sqrt(nx * nx + 4 + nz * nz)
        sol.n[k] = (nx / norme, 2 / norme, nz / norme)

    from .campagne import campagne
    rural = campagne(sol, sols, ilots, routes, altitude, bord_riviere, lisiere, hx, hz, cx, cy)
    arbres = [[], []]
    for z0 in range(-1950, 1950, 25):
        for x0 in range(-1950, 1950, 25):
            x, z = x0 + rng.uniform(-12, 12), z0 + rng.uniform(-12, 12)
            d = distance(x, z)
            if d < 30 or lisiere(x, z) < 20 or rng.random() > 0.92 - 0.68 * fondu(600, 1600, d):
                continue
            if bord_riviere(x, z) < 22 or rural["pres_route"](x, z) < 13 or rural["dans_champ"](x,z):
                continue
            espece = int(rng.random() < 0.35 + 0.4 * fondu(200, 650, d))
            arbres[espece].append([round(x, 2), round(altitude(x, z), 2), round(z, 2),
                                  round(rng.uniform(1.15, 1.95), 3), round(rng.uniform(0, math.tau), 3)])

    nuages = []
    for cote in (-1, 1):
        for k in range(12):
            x = cote * (hx + rng.uniform(570, 1450))
            z = -2350 + k * 425 + rng.uniform(-120, 120)
            nuages.append([x, altitude(x, z) + rng.uniform(50, 125), z,
                           rng.uniform(430, 760), rng.uniform(110, 180), rng.random()])
    quad = Maillage()
    quad.triangle((-0.5, -0.5, 0), (0.5, -0.5, 0), (0.5, 0.5, 0), (1, 1, 1))
    quad.triangle((-0.5, -0.5, 0), (0.5, 0.5, 0), (-0.5, 0.5, 0), (1, 1, 1))
    print("  vallée : %d triangles de sol, %d arbres extérieurs, %d bancs de nuages"
          % (len(sol), sum(map(len, arbres)), len(nuages)))
    rural.pop("pres_route")
    rural.pop("dans_champ")
    return {"demi_emprise": [hx, hz], "sol": sol.json(), "eau": eau.json(), "campagne": rural,
            "arbres": arbres, "modeles": [_arbre(False), _arbre(True)],
            "nuages": nuages, "quad": quad.json()}


def _arbre(sapin):
    m = Maillage()
    # Silhouettes de fond : 30/40 triangles, sans branches ni ombres projetées.
    anneaux = [(1.5, 1.0), (3.0, 4.5), (8.0, 5.2), (12.5, 0.0)]
    if sapin:
        anneaux = [(0, 0.5), (2, 0.5), (2.1, 4.5), (8, 2.8), (17, 0)]
    for (ya, ra), (yb, rb) in zip(anneaux, anneaux[1:]):
        for k in range(5):
            a, b = k * math.tau / 5, (k + 1) * math.tau / 5
            p, q = (ra * math.cos(a), ya, ra * math.sin(a)), (ra * math.cos(b), ya, ra * math.sin(b))
            r, s = (rb * math.cos(b), yb, rb * math.sin(b)), (rb * math.cos(a), yb, rb * math.sin(a))
            m.triangle(p, s, r, (1, 1, 1))
            m.triangle(p, r, q, (1, 1, 1))
    return m.json()
