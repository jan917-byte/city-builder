# -*- coding: utf-8 -*-
"""Repères civiques dans les empreintes existantes, sans asset ni nœud ajouté."""

import math
import palette as PAL
from .geometrie import normale


ROLES = {16: "eglise", 20: "mairie", 36: "universite"}
PENTES = {"eglise": .95, "mairie": .95, "universite": .60}


class Edifice:
    def __init__(self, m, emp, G, cible):
        if len(emp) != 4:
            raise ValueError("Un repère civique exige une empreinte rectangulaire.")
        self.m, self.G = m, G
        # La façade regarde l'adresse civique ou la cour du campus.
        def vers_cible(i):
            a, b = emp[i], emp[(i + 1) % 4]
            dx, dy = b[0] - a[0], b[1] - a[1]
            L = math.hypot(dx, dy)
            vx, vy = cible[0] - (a[0] + b[0]) / 2, cible[1] - (a[1] + b[1]) / 2
            return (dy * vx - dx * vy) / (L * max(math.hypot(vx, vy), 0.01))
        i = max(range(4), key=vers_cible)
        a, b = emp[i], emp[(i + 1) % 4]
        self.w = math.dist(a, b)
        self.u = ((b[0] - a[0]) / self.w, (b[1] - a[1]) / self.w)
        self.v = (-self.u[1], self.u[0])
        self.o = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        self.l = max((p[0] - self.o[0]) * self.v[0] + (p[1] - self.o[1]) * self.v[1] for p in emp)
        self.toit = 0.0
        self.faces = 0

    def point(self, p):
        x, y, z = p
        return self.G(self.o[0] + x * self.u[0] + y * self.v[0],
                      self.o[1] + x * self.u[1] + y * self.v[1], z)

    def face(self, points, couleur, dehors, toit=False, fenetres=False):
        pts = [self.point(p) for p in points]
        dx, dy, dz = dehors
        attendu = (dx * self.u[0] + dy * self.v[0], dz,
                   -dx * self.u[1] - dy * self.v[1])
        largeur = math.dist(points[0][:2], points[1][:2])
        uv = [(0, largeur), (largeur, largeur), (largeur, largeur), (0, largeur)]
        for i in range(1, len(pts) - 1):
            ids = [0, i, i + 1]
            n = normale(*(pts[k] for k in ids))
            if sum(a * b for a, b in zip(n, attendu)) < 0:
                ids.reverse()
            tri = [pts[k] for k in ids]
            self.m.triangle(*tri, couleur,
                            ao=tuple(0.78 + 0.22 * min(1, max(0, points[k][2]) / 3) for k in ids),
                            axe_toit=(self.v[0], -self.v[1]) if toit else None,
                            facade=tuple(uv[k] for k in ids) if fenetres else None,
                            genre=(1.0, 0.45) if fenetres else None)
            self.faces += 1
            if toit:
                a, b, c = tri
                ab = [b[k] - a[k] for k in range(3)]
                ac = [c[k] - a[k] for k in range(3)]
                self.toit += math.sqrt(sum((ab[(k+1)%3] * ac[(k+2)%3] - ab[(k+2)%3] * ac[(k+1)%3]) ** 2 for k in range(3))) / 2

    def boite(self, x0, x1, y0, y1, z0, z1, couleur, fenetres=False, cap=True):
        ring = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
        for i, n in enumerate([(0,-1,0), (1,0,0), (0,1,0), (-1,0,0)]):
            a, b = ring[i], ring[(i+1)%4]
            self.face([(*a,z0), (*b,z0), (*b,z1), (*a,z1)], couleur, n, fenetres=fenetres)
        if cap:
            self.face([(x,y,z1) for x,y in ring], couleur, (0,0,1))

    def comble(self, x0, x1, y0, y1, h, pente, mur, couverture, trou=None):
        milieu = (x0+x1)/2
        def z(x):
            return h + pente * min(x-x0, x1-x)
        for y, ny in [(y0,-1), (y1,1)]:
            self.face([(x0,y,h),(x1,y,h),(milieu,y,z(milieu))], mur, (0,ny,0))
        coupes = sorted(set([x0, milieu, x1] + ([] if trou is None else [trou[0], trou[1]])))
        for a,b in zip(coupes,coupes[1:]):
            debut = trou[2] if trou and trou[0] <= (a+b)/2 <= trou[1] else y0
            self.face([(a,debut,z(a)), (b,debut,z(b)), (b,y1,z(b)), (a,y1,z(a))],
                      couverture, (-1 if b <= milieu else 1,0,1), toit=True)
        for x in [x0,x1]:
            self.boite(x-.12,x+.12,y0-.12,y1+.12,h-.16,h+.05,tuple(c*.7 for c in couverture))

    def fleche(self, x, y, cote, bas, haut, couleur):
        r = cote/2
        ring = [(x-r,y-r),(x+r,y-r),(x+r,y+r),(x-r,y+r)]
        for i,n in enumerate([(0,-1,1),(1,0,1),(0,1,1),(-1,0,1)]):
            self.face([(*ring[i],bas),(*ring[(i+1)%4],bas),(x,y,haut)],couleur,n,toit=True)

    def ouverture(self, x, y, bas, largeur, haut, couleur, cote="front", ogive=False):
        r = largeur/2
        epaule = haut - (r*1.5 if ogive else r)
        points = [(-r,bas),(r,bas),(r,epaule)]
        if ogive:
            points += [(r*.65,epaule+r*.85),(0,haut),(-r*.65,epaule+r*.85)]
        else:
            points += [(math.cos(a*math.pi/6)*r,epaule+math.sin(a*math.pi/6)*r) for a in range(1,6)]
        points += [(-r,epaule)]
        if cote == "front":
            pts, n = [(x+t,y,z) for t,z in points], (0,-1,0)
        elif cote == "droite":
            pts, n = [(x,y+t,z) for t,z in points], (1,0,0)
        else:
            pts, n = [(x,y-t,z) for t,z in points], (-1,0,0)
        self.face(pts,couleur,n)

    def horloge(self, y, h, r, pierre, sombre, sens=-1):
        for rayon,coul,delta in [(r+.16,pierre,0),(r,sombre,-.02)]:
            self.face([(math.sin(k*math.tau/24)*rayon,y-delta*sens,h+math.cos(k*math.tau/24)*rayon) for k in range(24)],coul,(0,sens,0))
        for k in range(12):
            a = k*math.tau/12
            x,z = math.sin(a)*r*.8,h+math.cos(a)*r*.8
            self.face([(x-.045,y+.04*sens,z-.08),(x+.045,y+.04*sens,z-.08),(x+.045,y+.04*sens,z+.08),(x-.045,y+.04*sens,z+.08)],pierre,(0,sens,0))
        for x,z in [(0,h+r*.66),(r*.46,h-r*.22)]:
            self.face([(-.06,y+.05*sens,h),(.06,y+.05*sens,h),(x+.06,y+.05*sens,z),(x-.06,y+.05*sens,z)],pierre,(0,sens,0))


def equipement(m, emp, G, role, niveaux, cible, principal=False, eau=0.0):
    e = Edifice(m,emp,G,cible)
    m.sol = G(emp[0][0], emp[0][1], 0.0)[1]   # le shader compte les étages depuis lui
    def couleur(hexa):
        return PAL.vers_lineaire(PAL.salir(hexa,eau) if eau > 0 else hexa)
    pierre, vitrage = couleur("D6C9AC"), couleur("394F56")
    ardoise, tuile = couleur("596370"), couleur("A96850")
    w,l = e.w,e.l
    if role == "eglise":
        mur = couleur("BEB7A0")
        t = min(w*.43,4.8)
        h = 8.1
        e.boite(-w/2,w/2,t,l,-.3,h,mur,cap=False)
        e.comble(-w/2,w/2,t,l,h,.95,mur,ardoise)
        for a,b in [(-w/2,-t/2),(t/2,w/2)]:
            e.boite(a,b,0,t,-.3,4.2,mur,cap=False)
            e.comble(a,b,0,t,4.2,.7,mur,ardoise)
        e.boite(-t/2,t/2,0,t,-.3,17.5,mur)
        e.boite(-t/2-.16,t/2+.16,-.12,t+.12,16.9,17.35,pierre)
        e.fleche(0,t/2,t+.25,17.5,26.0,ardoise)
        e.boite(-.1,.1,t/2-.1,t/2+.1,25.6,27.5,pierre)
        e.boite(-.65,.65,t/2-.1,t/2+.1,26.7,26.88,pierre)
        e.ouverture(0,-.035,.1,2.4,4.2,pierre,ogive=True)
        e.ouverture(0,-.06,.1,1.8,3.65,vitrage,ogive=True)
        for cote,x,y in [("front",0,-.04),("droite",t/2+.04,t/2),("gauche",-t/2-.04,t/2)]:
            e.ouverture(x,y,13.3,1.6,16.1,vitrage,cote,True)
        for signe,cote in [(-1,"gauche"),(1,"droite")]:
            for k in range(3):
                y = t+(l-t)*(k+.5)/3
                e.ouverture(signe*(w/2+.025),y,2.3,1.7,6.9,pierre,cote,True)
                e.ouverture(signe*(w/2+.05),y,2.5,1.15,6.5,vitrage,cote,True)
            for k in range(4):
                y = t+(l-t)*k/3
                e.boite(signe*w/2-.32,signe*w/2+.32,y-.25,y+.25,-.2,6.0,pierre)
    else:
        mairie = role == "mairie"
        h = niveaux*2.7
        mur = couleur("D3BC9A" if mairie else "C9BEA8")
        pente = PENTES[role]
        couverture = tuile if mairie else ardoise
        e.boite(-w/2,w/2,0,l,-.3,h,mur,fenetres=True,cap=False)
        t = 3.2
        trou = (-t/2,t/2,t) if mairie else None
        e.comble(-w/2,w/2,0,l,h,pente,mur,couverture,trou)
        # Les fenêtres existantes suivent le zéro monde, rive comprise.
        pied_monde = e.point((0,0,0))[1]
        corniches = [2.45 + k*2.7 - pied_monde for k in range(int(niveaux)+1)]
        for z in [z for z in corniches if .2 < z < h-.3]:
            e.boite(-w/2-.1,w/2+.1,-.12,l+.12,z,z+.20,pierre)
        for x in [-w/2+.2,w/2-.2]:
            for y in [0,l-.3]:
                e.boite(x-.25,x+.25,y-.2,y+.5,.4,h,pierre)
        if mairie:
            # Un pignon à redents sur toute la façade, plus un beffroi court.
            for y in [0,l]:
                for k in range(5):
                    demi = w/2*(1-k/5)
                    z = h+pente*w/2*k/5
                    e.boite(-demi,demi,y-.22,y+.22,z,z+pente*w/10,mur)
                    e.boite(-demi-.08,demi+.08,y-.28,y+.28,z+pente*w/10-.14,z+pente*w/10+.06,pierre)
            sommet = h+pente*w/2+1.8
            e.boite(-t/2,t/2,0,t,h,sommet,mur)
            e.horloge(-.31,h+3.3,1.08,pierre,vitrage)
            e.horloge(l+.31,h+3.3,1.08,pierre,vitrage,1)
            e.boite(-t/2-.15,t/2+.15,-.15,t+.15,sommet-.25,sommet,pierre)
            e.fleche(0,t/2,t+.2,sommet,sommet+3.3,ardoise)
            for x in [-w*.31,0,w*.31]:
                e.ouverture(x,-.30,.10,2.7,3.0,pierre)
                e.ouverture(x,-.33,.1,2.15,2.7,vitrage)
        else:
            # Même ordonnance sur les pavillons ; l'Aula porte le grand portique.
            largeur = min(w*.62,12.0) if principal else 5.4
            haut = h if principal else 4.0
            e.boite(-largeur/2,largeur/2,-.22,.12,0,haut,mur)
            for x in [-largeur*.28,0,largeur*.28]:
                e.ouverture(x,-.25,.25,1.8,3.25,vitrage)
                if principal:
                    e.ouverture(x,-.25,3.65,1.5,h-.25,vitrage)
            for k in range(4 if principal else 2):
                x = -largeur/2 + (largeur*k/(3 if principal else 1))
                e.boite(x-.22,x+.22,-1.1,-.55,.3,haut,pierre)
                e.boite(x-.36,x+.36,-1.23,-.42,haut-.25,haut+.1,pierre)
            e.boite(-largeur/2-.5,largeur/2+.5,-1.35,.2,haut,haut+.42,pierre)
            e.face([(-largeur/2-.5,-1.38,haut+.42),(largeur/2+.5,-1.38,haut+.42),(0,-1.38,haut+largeur*.27)],pierre,(0,-1,0))
            e.face([(-largeur*.36,-1.40,haut+.63),(largeur*.36,-1.40,haut+.63),(0,-1.40,haut+largeur*.23)],mur,(0,-1,0))
            for k in range(3):
                e.boite(-largeur/2-.6,largeur/2+.6,-1.8+k*.4,.1,0,.12*(k+1),pierre)
            # Deux bannières de faculté encadrent l'entrée, dans la palette du jeu.
            for x in [-largeur/2-.75,largeur/2+.75]:
                e.boite(x-.38,x+.38,-.28,-.20,1.7,min(h-.3,4.6),couleur("456E68"))
    m.sol = None
    return (e.faces,e.faces,0,0), e.toit
