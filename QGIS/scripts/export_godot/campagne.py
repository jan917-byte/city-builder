"""Parcelles continues sur les supports urbain et extérieur, sans changer la simulation."""
import math
import random

import palette as PAL
from .geometrie import Maillage, aire_signee, dedans


def couper(poly, a, b, marge=0):
    """Demi-plan gauche, avec interpolation de l'altitude du support."""
    out = []
    def cote(p):
        return (b[0]-a[0])*(p[2]-a[1]) - (b[1]-a[1])*(p[0]-a[0]) - marge*math.dist(a, b)
    for p, q in zip(poly, poly[1:] + poly[:1]):
        dp, dq = cote(p), cote(q)
        if dp >= 0:
            out.append(p)
        if (dp >= 0) != (dq >= 0):
            t = dp / (dp-dq)
            out.append(tuple(p[j] + t*(q[j]-p[j]) for j in range(3)))
    return out


def intersection(poly, anneau, marge=0):
    for a, b in zip(anneau, anneau[1:] + anneau[:1]):
        poly = couper(poly, a, b, marge)
        if len(poly) < 3:
            return []
    return poly


def soustraire(poly, anneau):
    dehors = []
    for a, b in zip(anneau, anneau[1:] + anneau[:1]):
        mo = couper(poly, b, a)
        if len(mo) >= 3:
            dehors.append(mo)
        poly = couper(poly, a, b)
        if len(poly) < 3:
            break
    return dehors


def boite(poly):
    return min(p[0] for p in poly), min(p[1] for p in poly), max(p[0] for p in poly), max(p[1] for p in poly)


def croise(a, b):
    return a[0] <= b[2] and a[2] >= b[0] and a[1] <= b[3] and a[3] >= b[1]


def emettre(m, poly, couleur, axe=None):
    if aire_signee([(p[0], p[2]) for p in poly]) < 0:
        poly = list(reversed(poly))
    for k in range(1, len(poly)-1):
        if abs(aire_signee([(p[0], p[2]) for p in [poly[0], poly[k], poly[k+1]]])) < 1e-7:
            continue
        m.triangle(poly[0], poly[k+1], poly[k], couleur, axe_toit=axe,
                   genre=(-1, 0) if axe else None)


def ruban(m, points, largeur, couleur, altitude):
    couloirs = []
    rails = []
    dense = []
    for a, b in zip(points, points[1:]):
        n = max(1, math.ceil(math.dist(a,b)/8))
        dense.extend([(a[0]+(b[0]-a[0])*k/n,a[1]+(b[1]-a[1])*k/n) for k in range(n)])
    points = dense + points[-1:]
    for k, p in enumerate(points):
        a, b = points[max(0, k-1)], points[min(len(points)-1, k+1)]
        lg = math.dist(a, b)
        nx, nz = -(b[1]-a[1])/lg*largeur/2, (b[0]-a[0])/lg*largeur/2
        rails.append([(p[0]+nx, p[1]+nz), (p[0]-nx, p[1]-nz)])
    for (a, b), (c, d) in zip(rails, rails[1:]):
        poly = [a, b, d, c]
        if aire_signee(poly) < 0:
            poly.reverse()
        emettre(m, [(x, altitude(x, z)+.16, z) for x, z in poly], couleur)
        couloirs.append(poly)
    return couloirs


def campagne(exterieur, sols, ilots, routes, altitude, bord_eau, lisiere, hx, hz, cx, cy):
    rng = random.Random(190917)
    altitude_relief = altitude
    terrain = {}
    for k in range(0, len(exterieur.i), 3):
        tri = [exterieur.v[exterieur.i[k+n]] for n in range(3)]
        bb = boite([(p[0],p[2]) for p in tri])
        for iz in range(math.floor(bb[1]/65), math.floor(bb[3]/65)+1):
            for ix in range(math.floor(bb[0]/65), math.floor(bb[2]/65)+1):
                terrain.setdefault((ix,iz), []).append(tri)
    def altitude(x,z):
        for a,b,c in terrain.get((math.floor(x/65),math.floor(z/65)), ()):
            det = (b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
            if abs(det)<1e-9:
                continue
            u = ((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/det
            v = ((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/det
            if min(u,v,1-u-v)>=-1e-6:
                return u*a[1]+v*b[1]+(1-u-v)*c[1]
        return altitude_relief(x,z)
    voirie = Maillage()
    axes = []
    sorties = []
    bouts = {}
    for r in routes:
        if r["largeur_m"] <= 0:
            continue
        for part in r["parts"]:
            for p in (part[0], part[-1]):
                cle = (round(p[0], 1), round(p[1], 1))
                bouts[cle] = bouts.get(cle, 0) + 1
    for r in routes:
        if r["largeur_m"] <= 0 or r.get("hierarchie") == "rive":
            continue
        for part in r["parts"]:
            for bout in (part, list(reversed(part))):
                p, q = bout[-1], bout[-2]
                if bouts[(round(p[0], 1), round(p[1], 1))] != 1:
                    continue
                x, z = p[0]-cx, cy-p[1]
                dx, dz = p[0]-q[0], q[1]-p[1]
                lg = math.hypot(dx, dz)
                if lg < .01 or math.hypot(x/hx, z/hz) < .65 or dx*x+dz*z < 0:
                    continue
                angle = math.atan2(dz, dx)
                points = [(x, z)]
                for k in range(76):
                    # Après les champs, chercher la pente douce parmi les directions voisines.
                    candidats = []
                    h = altitude(x, z)
                    for da in (-.22, -.11, 0, .11, .22):
                        an = angle + da
                        px, pz = x+32*math.cos(an), z+32*math.sin(an)
                        pente = abs(altitude(px, pz)-h)/32
                        score = max(0, pente-.12)*50 + abs(da)*.35
                        score += max(0, 32-bord_eau(px, pz))*3
                        score += max(0, math.hypot(x, z)-math.hypot(px, pz))*.2
                        candidats.append((score, an, px, pz))
                    _, angle, x, z = min(candidats)
                    points.append((x, z))
                axes.append(points)
                sorties.append({"rue": r["fid"], "depart": list(points[0]), "fin": list(points[-1])})
    couloirs = []
    for points in axes:
        ruban(voirie, points, 9.5, PAL.vers_lineaire("#9b9878"), altitude)
        couloirs.extend(ruban(voirie, points, 6.2, PAL.vers_lineaire("#626662"), lambda x,z: altitude(x,z)+.02))

    def pres_route(x, z):
        meilleur = 1e9
        for axe in axes:
            for a, b in zip(axe, axe[1:]):
                vx, vz = b[0]-a[0], b[1]-a[1]
                t = max(0, min(1, ((x-a[0])*vx+(z-a[1])*vz)/(vx*vx+vz*vz)))
                meilleur = min(meilleur, math.hypot(x-a[0]-t*vx, z-a[1]-t*vz))
        return meilleur

    # Sommets partagés : des quadrilatères allongés, sans damier ni trous entre voisins.
    noeuds = {}
    for j in range(-11, 12):
        for i in range(-9, 10):
            u = i*175 + 55*math.sin(i*1.9) + rng.uniform(-15, 15) + 70*math.sin(j*.65)
            v = j*115 + 35*math.sin(j*1.3) + rng.uniform(-12, 12) + 40*math.sin(i*.8)
            noeuds[i,j] = (.955*u-.296*v, .296*u+.955*v)
    cellules = []
    index = {}
    for j in range(-11, 11):
        for i in range(-9, 9):
            an = [noeuds[i,j], noeuds[i+1,j], noeuds[i+1,j+1], noeuds[i,j+1]]
            centre = tuple(sum(p[k] for p in an)/4 for k in (0,1))
            if lisiere(*centre) > 60:
                continue
            cell = {"fid": (j+11)*18+i+10, "anneau": an, "pieces": [], "centre": centre,
                    "boite": boite(an), "ferme": False, "culture": rng.randrange(5)}
            cellules.append(cell)
            bb = cell["boite"]
            for iz in range(math.floor(bb[1]/150), math.floor(bb[3]/150)+1):
                for ix in range(math.floor(bb[0]/150), math.floor(bb[2]/150)+1):
                    index.setdefault((ix,iz), []).append(cell)
    champs = {f for f,d in ilots.items() if d["sous_type"] == "champ"}
    sols.fermer()
    supports = []
    for f, debut, nb in sols.groupes:
        if f in champs:
            supports.extend([[sols.v[sols.i[k+n]] for n in range(3)] for k in range(debut, debut+nb, 3)])
    for k in range(0, len(exterieur.i), 3):
        tri = [exterieur.v[exterieur.i[k+n]] for n in range(3)]
        if any(abs(p[0]) < 1250 and abs(p[2]) < 1400 for p in tri):
            supports.append(tri)
    routes_boites = [(boite(c), c) for c in couloirs]
    for tri in supports:
        bb = boite([(p[0],p[2]) for p in tri])
        candidats = {}
        for iz in range(math.floor(bb[1]/150), math.floor(bb[3]/150)+1):
            for ix in range(math.floor(bb[0]/150), math.floor(bb[2]/150)+1):
                for cell in index.get((ix,iz), ()):
                    candidats[cell["fid"]] = cell
        for cell in candidats.values():
            if not croise(bb, cell["boite"]):
                continue
            mo = intersection(tri, cell["anneau"], .9)
            if len(mo) < 3:
                continue
            pieces = [mo]
            for rb, route in routes_boites:
                if croise(bb, rb):
                    pieces = [p for piece in pieces for p in soustraire(piece, route)]
            cell["pieces"].extend(pieces)

    cultures = [("Blé", "#b0ab7b"), ("Orge", "#a1a579"), ("Prairie", "#82915e"),
                ("Colza", "#b5b178"), ("Labour", "#938672")]
    maillage, objets = Maillage(), {}
    chemins = Maillage()
    for cell in cellules:
        pieces = cell["pieces"]
        surface = sum(abs(aire_signee([(p[0],p[2]) for p in mo])) for mo in pieces)
        if surface < 90:
            continue
        fid, an = cell["fid"], cell["anneau"]
        maillage.marque(fid)
        culture, couleur = cultures[cell["culture"]]
        dx, dz = an[1][0]-an[0][0], an[1][1]-an[0][1]
        lg = math.hypot(dx, dz)
        axe = (dx/lg, dz/lg)
        coul = tuple(c*rng.uniform(.97, 1.03) for c in PAL.vers_lineaire(couleur))
        for mo in pieces:
            emettre(maillage, [(p[0],p[1]+.045,p[2]) for p in mo], coul, axe)
        # Chemins de desserte sur les limites extérieures, à l'écart du bâti et des berges.
        for a, b in zip(an[:2], an[1:3]):
            pts = [(a[0]+(b[0]-a[0])*k/12, a[1]+(b[1]-a[1])*k/12) for k in range(13)]
            for p, q in zip(pts, pts[1:]):
                if all((abs(t[0])>hx+6 or abs(t[1])>hz+6) and bord_eau(*t)>16 for t in (p,q)):
                    ruban(chemins, [p,q], 2.4, PAL.vers_lineaire("#a9a389"), altitude)
        # Une cour près d'un chemin, trois volumes : logis, grange, remise.
        x, z = .38*an[0][0]+.62*cell["centre"][0], .38*an[0][1]+.62*cell["centre"][1]
        dehors = abs(x)>hx+35 or abs(z)>hz+35
        if fid % 7 == 0 and dehors and bord_eau(x,z)>65 and pres_route(x,z)>35:
            cour = [(x-19,z-17),(x+19,z-17),(x+19,z+17),(x-19,z+17)]
            if all(dedans(an+[an[0]], p) for p in cour):
                h = max(altitude(*p) for p in cour)+.1
                if h-min(altitude(*p) for p in cour) < 4.0:
                    cell["ferme"] = True
                    emettre(maillage, [(px,h,pz) for px,pz in cour], PAL.vers_lineaire("#b6ad91"))
                    ferme(maillage, x-11,z,8,15,h,5.5)
                    ferme(maillage, x+3,z-10,20,9,h,6.5)
                    ferme(maillage, x+12,z+5,7,13,h,4)
                    ruban(chemins, [(x,z+12),an[0]], 3, PAL.vers_lineaire("#a9a389"), altitude)
        # Point de contrôle garanti DANS un morceau, même sur les parcelles découpées par l'eau.
        principal = max(pieces, key=lambda mo: abs(aire_signee([(p[0],p[2]) for p in mo])))
        point = [sum(p[k] for p in principal)/len(principal) for k in range(3)]
        point[1] += .045
        objets[str(fid)] = {"nom": "%s · parcelle %d" % ("Ferme" if cell["ferme"] else culture, fid),
                            "surface_m2": round(surface,1), "culture": culture, "ferme": cell["ferme"],
                            "point": point}
    print("  campagne : %d parcelles cliquables, %d fermes, %d routes prolongées" %
          (len(objets), sum(o["ferme"] for o in objets.values()), len(sorties)))
    def dans_champ(x,z):
        return any(str(c["fid"]) in objets and dedans(c["anneau"]+[c["anneau"][0]], (x,z))
                   for c in index.get((math.floor(x/150),math.floor(z/150)), ()))
    return {"sols": maillage.json(), "objets": objets, "anciens_champs": sorted(champs),
            "routes": voirie.json(), "chemins": chemins.json(), "sorties": sorties,
            "pres_route": pres_route, "dans_champ": dans_champ}


def ferme(m, x, z, largeur, profondeur, y, h):
    murs, toit = PAL.vers_lineaire("#dfd2b6"), PAL.vers_lineaire("#935b40")
    bas = [(x-largeur/2,y,z-profondeur/2), (x+largeur/2,y,z-profondeur/2),
           (x+largeur/2,y,z+profondeur/2), (x-largeur/2,y,z+profondeur/2)]
    haut = [(p[0],y+h,p[2]) for p in bas]
    for k in range(4):
        j = (k+1)%4
        m.triangle(bas[k],haut[k],haut[j],murs)
        m.triangle(bas[k],haut[j],bas[j],murs)
    a, b = (x,y+h+3,z-profondeur/2), (x,y+h+3,z+profondeur/2)
    m.triangle(haut[0],a,haut[1],murs)
    m.triangle(haut[3],haut[2],b,murs)
    for p,q,r,s in [(haut[0],haut[3],b,a),(a,b,haut[2],haut[1])]:
        m.triangle(p,q,r,toit)
        m.triangle(p,r,s,toit)
