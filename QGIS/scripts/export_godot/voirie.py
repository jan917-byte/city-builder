# -*- coding: utf-8 -*-
"""Chaussées, trottoirs, carrefours et places peintes."""


import math
from apercu_carte import dedans
from importlib import import_module
from .geometrie import (
    _aire_xy,
    _axe_ruban,
    _complement,
    _croiser,
    _cumul,
    _densifier,
    _fusionner,
    _le_long,
    _onglets,
    _ruban,
    _tronquer,
    _unite,
    aire_signee,
    Maillage,
    trianguler,
)
from .reglages import (
    ACCES_PARKING,
    ALLEE_PARKING,
    AXE_MIN_CHAUSSEE,
    AXE_TRAIT,
    AXE_VIDE,
    BORD_PARKING,
    COLLE_EAU,
    COLLE_MIN,
    COLLE_PART,
    COLLE_PAS,
    COLLE_PORTEE,
    COLLE_SONDE,
    CONTINUE_ANGLE,
    CONTINUE_FENETRE,
    CONTINUE_PORTEE,
    COUDE_MIN_DEG,
    ELARGISSEMENT_MAX,
    ESPACEMENT_TRAVERSEE,
    GLISSEMENT_U,
    GLISSEMENT_V,
    GRILLE_VOIRIE,
    HIER_LIGNE_RIVE,
    JEU_CHAUSSEE,
    JEU_COUDE,
    JEU_MARQUAGE,
    LARGEUR_LIGNE,
    LARGEUR_TROTTOIR,
    LIMITE_MITRE_TROTTOIR,
    MODULE_PARKING,
    PASSAGE_BANDE,
    PASSAGE_ECART,
    PASSAGE_JEU_BORD,
    PASSAGE_PROFONDEUR,
    PASSAGE_RECUL,
    PAS_ARC_DEG,
    PLACE_LARGEUR,
    PLACE_LONGUEUR,
    PLACE_RECUL_PASSAGE,
    PLACE_RUE_LONGUEUR,
    RAYON_MAX,
    RAYON_MIN,
    RIVE_RETRAIT,
    TROTTOIR_MIN,
    Y_MARQUAGE,
    Y_TERRAIN,
    Y_TROTTOIR,
)

D4 = import_module("04_deriver_attributs")
D4B = import_module("04b_emprises_baties")
D4C = import_module("04c_parcelles")


def _index_voirie(routes):
    """Tous les segments de rue, plus une grille pour les retrouver.

    Chaque segment porte de quoi poser un trottoir — la largeur du corridor,
    l'emprise de circulation — ET SON IDENTITÉ (fid, part, rang). C'est
    l'identité qui dit, plus loin, si deux arêtes d'îlot consécutives longent
    LE MÊME coude d'une même rue (à arrondir) ou deux rues différentes (un
    carrefour : on n'y touche pas)."""
    segs, idx = [], {}
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue                            # les 4 tronçons `rive` à 0 m
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        for ip, part in enumerate(d["parts"]):
            for k in range(len(part) - 1):
                a, b = part[k], part[k + 1]
                if math.hypot(b[0] - a[0], b[1] - a[1]) < 1e-9:
                    continue
                j = len(segs)
                segs.append((a, b, larg, ch, d["fid"], ip, k))
                for cx in range(int(min(a[0], b[0]) // GRILLE_VOIRIE),
                                int(max(a[0], b[0]) // GRILLE_VOIRIE) + 1):
                    for cy in range(int(min(a[1], b[1]) // GRILLE_VOIRIE),
                                    int(max(a[1], b[1]) // GRILLE_VOIRIE) + 1):
                        idx.setdefault((cx, cy), []).append(j)
    return segs, idx


def _rue_le_long(a, b, nout, segs, idx):
    """La rue que longe cette arête d'emprise : (distance à l'axe, largeur,
    emprise de circulation, fid, part, rang) — ou None.

    ⚠️ ON NE RECALCULE PAS LE RETRAIT DE 04b, ON LE RETROUVE. L'arête d'une
    emprise a été reculée de la demi-largeur de sa rue — ou de la largeur
    ENTIÈRE au bord de l'eau, pour que le quai de 22 m tienne sur la terre.
    Recopier cette règle ici en ferait une seconde source de vérité, qui
    dériverait le jour où 04b changerait. On cherche donc, DANS LA DIRECTION
    DU DEHORS, un segment parallèle, et on MESURE la distance au lieu de la
    supposer. Ce qui ne retombe sur aucune rue — bord de carte, berge, arête
    biseautée par la limite de mitre — n'a pas de trottoir, et c'est juste."""
    mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
    u = _unite(a, b)
    if u is None:
        return None
    cx, cy = int(mx // GRILLE_VOIRIE), int(my // GRILLE_VOIRIE)
    best = None
    for ix in (cx - 1, cx, cx + 1):
        for iy in (cy - 1, cy, cy + 1):
            for j in idx.get((ix, iy), ()):
                sa, sb, larg, ch, fid, ip, k = segs[j]
                us = _unite(sa, sb)
                if us is None or abs(us[0] * u[0] + us[1] * u[1]) < 0.85:
                    continue                    # perpendiculaire : pas elle
                dd = abs((mx - sa[0]) * us[1] - (my - sa[1]) * us[0])
                if dd < ch / 2.0 or dd > larg + 0.75:
                    continue
                # Le test qui fait tout le travail : la rue doit être DEVANT,
                # du côté du dehors. Sans lui, une arête prend la rue qui
                # longe l'AUTRE bord de son îlot dès que l'îlot est mince.
                if D4B.dist_pt_seg((mx + nout[0] * dd, my + nout[1] * dd),
                                   sa, sb) > 0.60:
                    continue
                if best is None or dd < best[0]:
                    best = (dd, larg, ch, fid, ip, k)
    return best


def _largeur_trottoir(dd, ch):
    """Ce qui reste pour un trottoir entre la limite de parcelle et la
    chaussée. Le trottoir ne touche jamais l'asphalte : les derniers
    centimètres restent du sol nu, comme les mètres libres."""
    w = min(LARGEUR_TROTTOIR, dd - ch / 2.0 - JEU_CHAUSSEE)
    return w if w >= TROTTOIR_MIN else 0.0


def _rayon_coude(theta, demi, marge, L1, L2):
    """Le rayon que LE CORRIDOR accepte à ce coude, ou 0.

    ⚠️ Le rayon n'est pas un goût. Arrondir un tracé le pousse vers
    l'intérieur du virage : le trottoir extérieur gonfle d'autant, et le
    trottoir intérieur maigrit. Quatre plafonds, mesurés sur la géométrie du
    coude :

      ① le confort (RAYON_MAX) ;
      ② tenir dans les deux segments voisins — la tangente ne doit pas manger
         plus de la moitié du plus court, sinon deux coudes se chevauchent ;
      ③ l'élargissement du trottoir EXTÉRIEUR reste sous ELARGISSEMENT_MAX ;
      ④ il reste JEU_COUDE de trottoir INTÉRIEUR au sommet du coude.

    🔴 CONSÉQUENCE ASSUMÉE : les coudes très serrés — au-delà de ~70° dans une
    rue ordinaire — ne s'arrondissent PAS. Ce n'est pas un renoncement : dans
    une rue de 13 m bordée de façades, un virage à 90° est un angle DU TISSU.
    Les maisons y font l'angle ; la chaussée le fait aussi. L'adoucir
    demanderait de bouger les parcelles, donc de rouvrir l'étape 2."""
    t = math.tan(math.radians(theta) / 2.0)
    c = 1.0 / math.cos(math.radians(theta) / 2.0) - 1.0
    if t < 1e-6 or c < 1e-9:
        return 0.0
    R = min(RAYON_MAX,
            0.45 * min(L1, L2) / t,
            ELARGISSEMENT_MAX / c - demi,
            (marge - JEU_COUDE) / c + demi)
    return R if R >= RAYON_MIN else 0.0


def _grille_emprises(ilots):
    """Les emprises bâties rangées par maille : de quoi mesurer, en un point,
    à quelle distance commence le bâti."""
    g = {}
    for d in ilots.values():
        an = d.get("anneau") or []
        if d["sous_type"] == "riviere" or len(an) < 3:
            continue
        ferme = list(an) + [an[0]]
        xs = [p[0] for p in an]
        ys = [p[1] for p in an]
        for cx in range(int(min(xs) // GRILLE_VOIRIE),
                        int(max(xs) // GRILLE_VOIRIE) + 1):
            for cy in range(int(min(ys) // GRILLE_VOIRIE),
                            int(max(ys) // GRILLE_VOIRIE) + 1):
                g.setdefault((cx, cy), []).append(ferme)
    return g


def _recul_facade(grille, p, n, portee):
    """À quelle distance de `p`, dans la direction `n`, commence l'emprise
    bâtie — ou None si on n'en rencontre aucune."""
    d = COLLE_PAS
    while d <= portee:
        q = (p[0] + n[0] * d, p[1] + n[1] * d)
        for an in grille.get((int(q[0] // GRILLE_VOIRIE),
                              int(q[1] // GRILLE_VOIRIE)), ()):
            if dedans(an, q):
                return d
        d += COLLE_PAS
    return None


def _coller_aux_facades(routes, ilots, chenal):
    """🌊 LE CORRIDOR D'UNE RUE DE BERGE SE POSE ENTIER SUR LA TERRE.

    Une station de tronçon LONGE l'eau si la rivière est sous un bord de la
    chaussée et pas sous l'autre — la même règle que le quai et le pont, et
    elle ne nomme aucune rue. Un tronçon qui longe sur plus de la moitié de sa
    longueur se décale vers ses façades, d'un seul écart : celui qui met son
    trottoir au nu de l'emprise bâtie. Ce qui reste entre l'asphalte et l'eau
    est la berge.

        AVANT   façade │ trottoir │ 15 m de sol nu │ ███ chaussée ███ │ Ilse
        APRÈS   façade │ trottoir │ ███ chaussée ███ │ promenade │ berge │ Ilse

    ⚠️ Les tronçons qui TRAVERSENT ne bougent pas : sous leurs deux bords il y
    a de l'eau, aucune station ne longe, et un pont décalé serait un pont à
    côté de sa culée."""
    grille = _grille_emprises(ilots)
    jonctions = {}
    for d in routes:
        if (d["largeur_m"] or 0.0) <= 0.0:
            continue
        for ip, part in enumerate(d["parts"]):
            for bout in (0, -1):
                p = part[bout]
                cle = (round(p[0] / 0.25), round(p[1] / 0.25))
                jonctions.setdefault(cle, []).append((d, ip, bout))
    st = {"n": 0, "m": 0.0, "bouts": 0, "decals": [], "libres": []}
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        n_tot, cotes, reculs = 0, [], []
        for part in d["parts"]:
            net = _densifier(part, COLLE_SONDE)
            for i, p in enumerate(net):
                u = _unite(net[max(0, i - 1)], net[min(len(net) - 1, i + 1)])
                if u is None:
                    continue
                n_tot += 1
                nl = (-u[1], u[0])
                w = ch / 2.0 + COLLE_EAU
                gauche = chenal.dans_eau((p[0] + nl[0] * w, p[1] + nl[1] * w))
                droite = chenal.dans_eau((p[0] - nl[0] * w, p[1] - nl[1] * w))
                if gauche == droite:
                    continue                # on traverse, ou on est loin de l'eau
                cote = -1.0 if gauche else 1.0      # la TERRE, en signe d'onglet
                cotes.append(cote)
                r = _recul_facade(grille, p, (nl[0] * cote, nl[1] * cote),
                                  COLLE_PORTEE)
                if r is not None:
                    reculs.append((cote, r))
        if n_tot == 0 or len(cotes) < COLLE_PART * n_tot:
            continue
        cote = 1.0 if sum(cotes) > 0 else -1.0
        rs = sorted(r for c, r in reculs if c == cote)
        if not rs:
            continue
        recul = rs[len(rs) // 2]            # la médiane, pas le minimum : un
        # débouché de rue perpendiculaire ouvre l'emprise sur 12 m.
        ecart = recul - LARGEUR_TROTTOIR - JEU_CHAUSSEE - ch / 2.0
        if ecart < COLLE_MIN:
            continue
        parts = []
        for part in d["parts"]:
            dec = _onglets(part)
            parts.append([(p[0] + dec[i][0] * ecart * cote,
                           p[1] + dec[i][1] * ecart * cote)
                          for i, p in enumerate(part)])
        d["parts"] = parts
        d["decal_m"] = round(ecart, 2)
        # Le côté EAU, en signe d'onglet : c'est celui-là que la promenade et
        # la bande de berge attendent.
        d["berge_cote"] = -cote
        d["berge_libre_m"] = round(recul - LARGEUR_TROTTOIR - JEU_CHAUSSEE - ch,
                                   2)
        # Le couloir de sélection n'est plus l'emprise de la source : la moitié
        # côté eau n'appartient plus à la rue, elle appartient à la berge.
        d["corridor_m"] = round(ch + 2.0 * (LARGEUR_TROTTOIR + JEU_CHAUSSEE), 2)
        st["n"] += 1
        st["m"] += d["longueur_m"] or 0.0
        st["decals"].append(ecart)
        st["libres"].append(d["berge_libre_m"])
    _raccorder_quais(jonctions)
    # Seuls les bouts isolés peuvent encore finir sur la ligne d'eau.
    raccordes = {(d["fid"], ip, bout) for branches in jonctions.values()
                 if len(branches) > 1 and any("decal_m" in d for d, _, _ in branches)
                 for d, ip, bout in branches}
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0 or "decal_m" in d:
            continue
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        parts = [_bouts_hors_eau(part, ch, chenal, garder={
            bout for bout in (0, -1) if (d["fid"], ip, bout) in raccordes})
                 for ip, part in enumerate(d["parts"])]
        st["bouts"] += sum(1 for a, b in zip(d["parts"], parts) if a != b)
        d["parts"] = parts
    return st


def _raccorder_quais(jonctions):
    """Les branches d'un ancien nœud rejoignent le même carrefour déplacé."""
    for branches in jonctions.values():
        decalees = [(d, ip, bout) for d, ip, bout in branches if "decal_m" in d]
        if len(branches) < 2 or not decalees:
            continue
        points = [d["parts"][ip][bout] for d, ip, bout in decalees]
        centre = tuple(sum(p[k] for p in points) / len(points) for k in (0, 1))
        # Intersection au moindre écart ; l'ancrage résout les rues parallèles.
        aa = bb = 1e-6
        ab = rx = ry = 0.0
        for d, ip, bout in branches:
            part = d["parts"][ip]
            p, q = part[bout], part[1 if bout == 0 else -2]
            u = _unite(p, q)
            if u is None:
                continue
            nx, ny = -u[1], u[0]
            c = nx * (p[0] - centre[0]) + ny * (p[1] - centre[1])
            aa += nx * nx
            ab += nx * ny
            bb += ny * ny
            rx += nx * c
            ry += ny * c
        det = aa * bb - ab * ab
        dx, dy = (rx * bb - ry * ab) / det, (ry * aa - rx * ab) / det
        # Deux quais presque parallèles peuvent se croiser loin hors du nœud.
        portee = max(d["decal_m"] for d, _, _ in decalees)
        if math.hypot(dx, dy) > portee:
            dx = dy = 0.0
        commun = (centre[0] + dx, centre[1] + dy)
        for d, ip, bout in branches:
            d["parts"][ip][bout] = commun


def _sans_le_bout(axe, coupe):
    """La polyligne amputée de ses `coupe` derniers mètres."""
    L = sum(math.hypot(b[0] - a[0], b[1] - a[1])
            for a, b in zip(axe, axe[1:]))
    return _debut_axe(axe, L - coupe) if L > coupe + 1.0 else list(axe)


def _bouts_hors_eau(part, ch, chenal, garder=()):
    """🌊 UNE RUE QUI DÉBOUCHE DANS L'ILSE S'ARRÊTE À LA RIVE.

    Son axe finit SUR la ligne d'eau — c'était le carrefour avec la rue de
    quai, qui vient de reculer. Le ruban, lui, se rallonge d'une demi-largeur
    pour remplir les carrefours (`_ruban`, § `bouts`) : sans ce
    raccourcissement, 428 m² d'asphalte restaient en l'air au-dessus de l'eau,
    sans mur pour les porter."""
    for bout in (-1, 0):
        u = _unite(part[-2], part[-1]) if len(part) >= 2 else None
        if bout not in garder and u is not None and chenal.dans_eau(
                (part[-1][0] + u[0] * COLLE_EAU,
                 part[-1][1] + u[1] * COLLE_EAU)):
            part = _sans_le_bout(part, ch / 2.0)
        part = part[::-1]
    return part


def _debut_axe(axe, fin):
    """Le début de la polyligne, coupé à `fin` mètres."""
    out, reste = [axe[0]], fin
    for a, b in zip(axe, axe[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L <= 1e-9:
            continue
        if L >= reste:
            out.append((a[0] + (b[0] - a[0]) * reste / L,
                        a[1] + (b[1] - a[1]) * reste / L))
            return out
        out.append(b)
        reste -= L
    return out


def _stations_le_long(axe, pas):
    """(point, unité) tous les `pas` mètres le long de la polyligne."""
    out, reste = [], 0.0
    for a, b in zip(axe, axe[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L <= 1e-9:
            continue
        u = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
        while reste <= L:
            out.append(((a[0] + u[0] * reste, a[1] + u[1] * reste), u))
            reste += pas
        reste -= L
    return out


def _bord_libre(d, ch):
    """Le nu du trottoir, compté depuis l'axe : c'est là que s'arrête tout ce
    qui est roulable. Sur une rue de berge le corridor a été refait à la
    mesure du collage (`corridor_m`), donc la formule vaut des deux côtés."""
    emprise = d.get("corridor_m", d["largeur_m"] or 0.0)
    return max(ch / 2.0, emprise / 2.0 - LARGEUR_TROTTOIR - JEU_CHAUSSEE)


def _places_de_rue(m, d, axe, ip, ch, nd, chenal, coul, G, dy=0.0,
                   fentes=None, gardes=None):
    """🅿️ LES PLACES DE RUE, PEINTES — la file, sa ligne et ses tirets.

    🔄 `routes.stationnement` en comptait 3 310 qu'aucune ligne ne montrait :
    les voitures se garaient sur un asphalte nu, la bande entre le trottoir et
    la chaussée n'était rien, et retirer le stationnement ne changeait que les
    voitures. La file se prend DANS la chaussée — les mètres libres du corridor
    ne font que 0,2 m sur une rue de 13 m, mesuré : il n'y a pas la place
    dehors.

    🔴 LA FILE NE COMMENCE PLUS AU NŒUD. Elle partait du premier mètre du
    tronçon : à un carrefour à quatre branches, huit files s'ouvraient sur le
    même point et les voitures garées se croisaient en travers des passages
    piétons. Elle ne se pose plus que dans ce que `_zones_interdites` laisse —
    la même découpe que le marquage longitudinal.

    `fentes` reçoit chaque place posée (x, z de son milieu, et sa direction,
    en repère Godot) : `trafic.gd` y garde ses voitures au lieu de refaire le
    calcul de son côté."""
    n = int(d.get("stationnement") or 0)
    total = max(float(d.get("longueur_m") or 0.0), 1.0)
    if n <= 0 or ch < 2.0 * PLACE_LARGEUR + 2.0:
        return 0
    cum = _cumul(axe)
    L = cum[-1]
    if L < PLACE_RUE_LONGUEUR:
        return 0
    n = int(round(n * L / total))               # la part de ce morceau d'axe
    par_cote = int(math.ceil(n / 2.0))
    if par_cote <= 0:
        return 0

    r0, r1, tv, _st, _se = _zones_interdites(
        d, axe, cum, ip, ch, nd, chenal, gardes)
    bloques = [[0.0, r0 + PLACE_RECUL_PASSAGE],
               [L - r1 - PLACE_RECUL_PASSAGE, L]]
    for s in tv:
        bloques.append([s - PASSAGE_PROFONDEUR / 2.0 - PLACE_RECUL_PASSAGE,
                        s + PASSAGE_PROFONDEUR / 2.0 + PLACE_RECUL_PASSAGE])
    libres = _complement(L, _fusionner(bloques))

    bord = _bord_libre(d, ch) - PLACE_LARGEUR
    milieu = bord + PLACE_LARGEUR / 2.0
    y = Y_MARQUAGE + dy
    posees = 0
    for a, b in libres:
        if par_cote <= 0:
            break
        k = min(int((b - a) / PLACE_RUE_LONGUEUR), par_cote)
        if k <= 0:
            continue
        file = _tronquer(axe, cum, a, a + k * PLACE_RUE_LONGUEUR)
        if len(file) < 2:
            continue
        for cote in (-1.0, 1.0):
            # La ligne qui sépare la file de la voie roulée.
            _ruban(m, file, LARGEUR_LIGNE, coul, G, y=y,
                   decal=cote * bord, bouts=False)
            # Un tiret par place, en travers de la file.
            for p, u in _stations_le_long(file, PLACE_RUE_LONGUEUR):
                nl = (-u[1] * cote, u[0] * cote)
                q = (p[0] + nl[0] * bord, p[1] + nl[1] * bord)
                r = (p[0] + nl[0] * (bord + PLACE_LARGEUR),
                     p[1] + nl[1] * (bord + PLACE_LARGEUR))
                h = (u[0] * LARGEUR_LIGNE / 2.0, u[1] * LARGEUR_LIGNE / 2.0)
                m.triangle(G(q[0] - h[0], q[1] - h[1], y),
                           G(r[0] - h[0], r[1] - h[1], y),
                           G(r[0] + h[0], r[1] + h[1], y), coul)
                m.triangle(G(q[0] - h[0], q[1] - h[1], y),
                           G(r[0] + h[0], r[1] + h[1], y),
                           G(q[0] + h[0], q[1] + h[1], y), coul)
            if fentes is None:
                continue
            for j in range(k):
                p, u = _le_long(axe, cum, a + (j + 0.5) * PLACE_RUE_LONGUEUR)
                nl = (-u[1] * cote, u[0] * cote)
                c = (p[0] + nl[0] * milieu, p[1] + nl[1] * milieu)
                g0 = G(c[0], c[1], 0.0)
                g1 = G(c[0] + u[0], c[1] + u[1], 0.0)
                fentes.extend([round(g0[0], 2), round(g0[2], 2),
                               round(g1[0] - g0[0], 3),
                               round(g1[2] - g0[2], 3)])
        par_cote -= k
        posees += k
    return 2 * posees


def _coudes(routes):
    """Le rayon retenu à chaque coude INTERNE de la voirie.

    Clé : (fid, part, rang du sommet). Un coude interne est un sommet au
    milieu d'un tronçon ; les 110 nœuds à trois branches ou plus sont, eux,
    des CARREFOURS et gardent leur angle — c'est ce que l'auteur a demandé, et
    c'est aussi ce qui garde un carrefour lisible."""
    out = {}
    total = marques = arrondis = 0
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        demi = larg / 2.0
        libre = demi - ch / 2.0
        w = _largeur_trottoir(demi, ch)
        # Sans trottoir, c'est la CHAUSSÉE qui ne doit pas sortir du corridor :
        # la marge à préserver est alors tous les mètres libres.
        marge = w if w > 0.0 else libre
        for ip, part in enumerate(d["parts"]):
            for iv in range(1, len(part) - 1):
                A, V, B = part[iv - 1], part[iv], part[iv + 1]
                u1, u2 = _unite(A, V), _unite(V, B)
                if u1 is None or u2 is None:
                    continue
                total += 1
                pv = max(-1.0, min(1.0, u1[0] * u2[0] + u1[1] * u2[1]))
                theta = math.degrees(math.acos(pv))
                if theta < COUDE_MIN_DEG:
                    continue                    # l'œil ne voit pas la cassure
                marques += 1
                R = _rayon_coude(
                    theta, demi, marge,
                    math.hypot(V[0] - A[0], V[1] - A[1]),
                    math.hypot(B[0] - V[0], B[1] - V[1]))
                if R <= 0.0:
                    continue
                sens = 1.0 if (u1[0] * u2[1] - u1[1] * u2[0]) > 0 else -1.0
                # Normales tournées vers l'INTÉRIEUR du virage : c'est de ce
                # côté qu'est le centre de l'arc, et c'est le signe de `sens`
                # qui le dit — pas une supposition sur le sens de la rue.
                n1 = (-u1[1] * sens, u1[0] * sens)
                n2 = (-u2[1] * sens, u2[0] * sens)
                bx, by = n1[0] + n2[0], n1[1] + n2[1]
                bl = math.hypot(bx, by)
                dC = R / math.cos(math.radians(theta) / 2.0)
                out[(d["fid"], ip, iv)] = {
                    "R": R, "theta": theta, "sens": sens, "u1": u1, "u2": u2,
                    "n1": n1, "n2": n2,
                    "C": (V[0] + bx / bl * dC, V[1] + by / bl * dC)}
                arrondis += 1
    return out, (total, marques, arrondis)


def _arc(C, r, p1, p2):
    """Les points de l'arc de centre C et de rayon r, par le plus court chemin
    entre les deux directions. Bornes comprises."""
    a1 = math.atan2(p1[1] - C[1], p1[0] - C[0])
    a2 = math.atan2(p2[1] - C[1], p2[0] - C[0])
    da = a2 - a1
    while da > math.pi:
        da -= 2.0 * math.pi
    while da < -math.pi:
        da += 2.0 * math.pi
    n = max(2, int(math.ceil(abs(math.degrees(da)) / PAS_ARC_DEG)))
    return [(C[0] + r * math.cos(a1 + da * k / n),
             C[1] + r * math.sin(a1 + da * k / n)) for k in range(n + 1)]


def _axe_arrondi(part, fid, ip, coudes):
    """La polyligne d'un tronçon, ses coudes retenus remplacés par des arcs."""
    pts = [part[0]]
    for iv in range(1, len(part) - 1):
        cd = coudes.get((fid, ip, iv))
        if cd is None:
            pts.append(part[iv])
            continue
        C, R = cd["C"], cd["R"]
        pts.extend(_arc(C, R,
                        (C[0] - cd["n1"][0] * R, C[1] - cd["n1"][1] * R),
                        (C[0] - cd["n2"][0] * R, C[1] - cd["n2"][1] * R)))
    pts.append(part[-1])
    return pts


def _index_chaussees(routes, coudes):
    """Les axes affichés et leurs demi-largeurs, pour exclure les troncs."""
    axes, index = {}, []
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        morceaux = []
        for ip, part in enumerate(d["parts"]):
            axe = _axe_arrondi(part, d["fid"], ip, coudes)
            morceaux.append(axe)
            net = _axe_ruban(axe, ch / 2.0)
            if net:
                index.append((d["fid"], ch / 2.0, net))
        axes[d["fid"]] = morceaux
    return axes, index


def _dans_chaussee(p, index, marge=0.0):
    """Vrai si le point — marge comprise — tombe dans une chaussée."""
    for _, demi, axe in index:
        if any(D4C.dist_pt_seg(p, a, b) <= demi + marge
               for a, b in zip(axe, axe[1:])):
            return True
    return False


class DecoupeChaussees:
    """Emprises exactes des rubans : partager les carrefours et dégager les trottoirs."""

    def __init__(self, routes, morceaux):
        self.polys, self.grille = [], {}
        self.noeuds = {}
        jonctions = {}
        self.priorite = {d["fid"]: (d.get("longueur_m", 0.0), d["fid"])
                         for d in routes}
        for d in routes:
            if not (d["largeur_m"] or 0.0) > 0.0:
                continue
            ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), d["largeur_m"])
            libre = _bord_libre(d, ch) - ch / 2.0
            for parts in morceaux[d["fid"]]:
                for axe in parts:
                    for bout in (0, -1):
                        p, q = axe[bout], axe[1 if bout == 0 else -2]
                        u = _unite(p, q)
                        h = _bord_libre(d, ch)
                        cle = (round(p[0] / 0.25), round(p[1] / 0.25))
                        jonctions.setdefault(cle, []).append((d["fid"], [
                            (p[0] - u[1] * h * s, p[1] + u[0] * h * s)
                            for s in (-1, 1)]))
                    rubans = [(ch, 0.0)]
                    if libre > 0.05:
                        rubans += [(libre, s * (ch + libre) / 2.0) for s in (-1, 1)]
                    for large, decal in rubans:
                        for poly in self.ruban(axe, large, decal):
                            self.ajouter(d["fid"], poly)
        for branches in jonctions.values():
            if len(branches) < 2:
                continue
            fid = min((f for f, _ in branches), key=self.priorite.get)
            poly = D4C.enveloppe_convexe([p for _, points in branches for p in points])
            if len(poly) >= 3:
                self.noeuds.setdefault(fid, []).append(poly)
                self.ajouter(fid, poly)

    def ajouter(self, fid, poly):
        k = len(self.polys)
        self.polys.append((fid, poly, self.plans(poly)))
        for case in self.cases(poly):
            self.grille.setdefault(case, []).append(k)

    @staticmethod
    def ruban(axe, large, decal=0.0):
        m = Maillage()
        _ruban(m, axe, large, (0.0, 0.0, 0.0),
               lambda x, y, h: (x, h, -y), decal=decal, bouts=False)
        return [[(m.v[j][0], -m.v[j][2]) for j in m.i[k:k + 3]]
                for k in range(0, len(m.i), 3)]

    @staticmethod
    def plans(poly):
        if _aire_xy(poly) < 0.0:
            poly = poly[::-1]
        return [(a, (a[1] - b[1], b[0] - a[0]))
                for a, b in zip(poly, poly[1:] + poly[:1])]

    @staticmethod
    def cases(poly):
        return [(x, y) for x in range(int(min(p[0] for p in poly) // 16),
                                     int(max(p[0] for p in poly) // 16) + 1)
                for y in range(int(min(p[1] for p in poly) // 16),
                               int(max(p[1] for p in poly) // 16) + 1)]

    def proches(self, poly, avant=None):
        ids = {k for case in self.cases(poly) for k in self.grille.get(case, ())}
        return [self.polys[k][2] for k in sorted(ids)
                if avant is None or self.priorite[self.polys[k][0]] < self.priorite[avant]]

    def hors(self, poly, avant=None):
        restes = [poly]
        for plans in self.proches(poly, avant):
            suite = []
            for r in restes:
                dehors, dedans = D4C._soustraire_convexe(r, plans)
                # Un masque voisin sans recouvrement ne doit pas fragmenter la rue.
                if sum(abs(_aire_xy(p)) for p in dedans) <= 1e-6:
                    suite.append(r)
                else:
                    suite.extend(p for p in dehors if abs(_aire_xy(p)) > 1e-6)
            restes = suite
            if not restes:
                break
        return restes

    def segments(self, a, b):
        libres = [(0.0, 1.0)]
        for plans in self.proches([a, b]):
            lo, hi = 0.0, 1.0
            for p, n in plans:
                v = (a[0] - p[0]) * n[0] + (a[1] - p[1]) * n[1]
                dv = (b[0] - a[0]) * n[0] + (b[1] - a[1]) * n[1]
                if abs(dv) < 1e-9:
                    if v < -1e-6:
                        hi = -1.0
                        break
                elif dv > 0.0:
                    lo = max(lo, -v / dv)
                else:
                    hi = min(hi, -v / dv)
            if hi > lo:
                libres = [p for iv in libres for p in _decouper(iv, [(lo, hi)])]
        return [((a[0] + (b[0] - a[0]) * lo, a[1] + (b[1] - a[1]) * lo),
                 (a[0] + (b[0] - a[0]) * hi, a[1] + (b[1] - a[1]) * hi))
                for lo, hi in libres if hi - lo > 1e-6]

    def emettre(self, m, axe, large, coul, G, fid, y, decal=0.0):
        for triangle in self.ruban(axe, large, decal):
            for poly in self.hors(triangle, fid):
                if _aire_xy(poly) < 0.0:
                    poly = poly[::-1]
                for a, b, c in trianguler(poly):
                    m.triangle(G(*poly[a], y), G(*poly[b], y), G(*poly[c], y), coul)

    def emettre_noeuds(self, m, fid, coul, G, y):
        for forme in self.noeuds.get(fid, ()):
            for poly in self.hors(forme, fid):
                for a, b, c in trianguler(poly):
                    m.triangle(G(*poly[a], y), G(*poly[b], y), G(*poly[c], y), coul)


def _stations_eau(net, dec, h, chenal, relief=None):
    """Le bord de l'asphalte est-il au-dessus de l'eau, à gauche et à droite ?

    Une seule question, et elle suffit : c'est elle qui dit qui TRAVERSE. Sous
    les deux bords, la rue franchit et prend un pont ; sous un seul, elle longe
    — et ce cas-là ne se décide plus ici depuis le 2026-08-19, mais dans
    `_quais`, à partir de la berge.

    ⏸️ CETTE FONCTION FAISAIT SIX FOIS PLUS. Elle tirait un rayon vers la
    rivière (`_ray_berge`), cherchait la berge la plus proche du bon côté
    (`_berge_proche`), mesurait l'écart latéral à l'eau, l'angle de la rue à la
    berge (`QUAI_COS`), et comptait les rives vues mais non bordées
    (`QUAI_VUE`). Tout cela servait à poser un mur DEPUIS LA ROUTE ; le mur
    part maintenant de la berge, où aucune de ces approximations n'est
    nécessaire — la berge, elle, sait où elle est. `relief` reste dans la
    signature pour ne pas changer les deux appels ; il ne sert plus."""
    return [{"p": p, "dec": dec[i],
             "cotes": {cote: {"mouille": chenal.dans_eau(
                 (p[0] + dec[i][0] * cote * h, p[1] + dec[i][1] * cote * h))}
                 for cote in (1, -1)}}
            for i, p in enumerate(net)]


def _plages(drapeaux):
    """Les plages [i0, i1] où le drapeau est vrai, bornes comprises."""
    out, i, n = [], 0, len(drapeaux)
    while i < n:
        if not drapeaux[i]:
            i += 1
            continue
        j = i
        while j + 1 < n and drapeaux[j + 1]:
            j += 1
        out.append((i, j))
        i = j + 1
    return out


def _combler(drapeaux):
    """Rebouche les trous d'UNE seule station. Un rayon peut manquer la berge au
    sommet exact où deux arêtes se rejoignent : sans ce rebouchage, le mur se
    coupe en deux sur deux mètres et il faut aller chercher pourquoi à l'écran."""
    for i in range(1, len(drapeaux) - 1):
        if drapeaux[i - 1] and drapeaux[i + 1]:
            drapeaux[i] = True
    return drapeaux


def _longueur(net, i0, i1):
    return sum(math.hypot(net[i + 1][0] - net[i][0], net[i + 1][1] - net[i][1])
               for i in range(i0, i1))


def _etendre(net, i0, i1, marge):
    """La plage allongée de `marge` mètres de chaque côté, sans sortir."""
    a = i0
    while a > 0 and _longueur(net, a - 1, i0) <= marge:
        a -= 1
    b = i1
    while b < len(net) - 1 and _longueur(net, i1, b + 1) <= marge:
        b += 1
    return a, b


def _pointilles(s0, s1):
    """Les traits d'une ligne discontinue, CENTRÉS dans l'intervalle libre.

    🔴 Pourquoi centrer plutôt que dérouler la trame depuis le départ : un
    tronçon fait rarement un nombre entier de motifs, et le reste tombait en
    bout de rue — un trait de 40 cm juste avant le carrefour, qui se lit comme
    une salissure. On compte les traits entiers qui tiennent, et on répartit
    le reste dans les deux marges."""
    L = s1 - s0
    if L < AXE_TRAIT:
        return []                       # un bout de trait est pire que rien
    pas = AXE_TRAIT + AXE_VIDE
    n = max(1, int((L + AXE_VIDE) / pas))
    marge = (L - (n * AXE_TRAIT + (n - 1) * AXE_VIDE)) / 2.0
    return [(s0 + marge + k * pas, s0 + marge + k * pas + AXE_TRAIT)
            for k in range(n)]


def _virages(pts, cum):
    """Les portions d'axe à traiter en TRAIT PLEIN.

    La règle ne regarde ni les coudes de la source ni les arcs de `_coudes` :
    elle mesure la polyligne FINALE. À chaque sommet on cumule le changement
    de direction sur une fenêtre de CONTINUE_FENETRE mètres ; au-delà de
    CONTINUE_ANGLE, le virage masque la visibilité et la ligne devient pleine.

    Ça attrape les deux formes du même fait : un coude arrondi (une suite de
    petits angles d'arc) et un coude resté vif (un seul grand angle). Une
    seule règle, deux géométries."""
    n = len(pts)
    tourne = [0.0] * n
    for i in range(1, n - 1):
        u1, u2 = _unite(pts[i - 1], pts[i]), _unite(pts[i], pts[i + 1])
        if u1 is None or u2 is None:
            continue
        pv = max(-1.0, min(1.0, u1[0] * u2[0] + u1[1] * u2[1]))
        tourne[i] = math.degrees(math.acos(pv))
    pleins = []
    demi = CONTINUE_FENETRE / 2.0
    for i in range(1, n - 1):
        if tourne[i] <= 0.0:
            continue
        total = sum(tourne[j] for j in range(1, n - 1)
                    if abs(cum[j] - cum[i]) <= demi)
        if total >= CONTINUE_ANGLE:
            pleins.append([cum[i] - CONTINUE_PORTEE, cum[i] + CONTINUE_PORTEE])
    return _fusionner(pleins)


def _noeuds_voirie(routes):
    """Les extrémités de tronçon regroupées par position : combien de branches
    s'y rejoignent, et l'emprise de circulation de chacune.

    C'est ce qui distingue un CARREFOUR (trois branches ou plus — on y pose des
    passages piétons et on y coupe les lignes) d'une simple continuation entre
    deux tronçons (deux branches — le marquage passe au travers) et d'un
    cul-de-sac ou d'un bord de carte (une seule)."""
    nd = {}
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        for ip, part in enumerate(d["parts"]):
            for p in (part[0], part[-1]):
                k = (round(p[0] / 0.25), round(p[1] / 0.25))
                nd.setdefault(k, []).append((d["fid"], ip, ch))
    return nd


def _zone_echange(nd, p, fid, ip):
    """De combien le marquage d'un tronçon doit reculer devant ce nœud.

    ⚠️ C'est la demi-chaussée de la rue LA PLUS LARGE QUI Y PASSE, pas la
    sienne : c'est la surface que les autres branches balaient, et y peindre
    une ligne d'axe la ferait traverser le carrefour. Sur une continuation à
    deux branches, il n'y a rien à traverser : le recul est nul."""
    br = nd.get((round(p[0] / 0.25), round(p[1] / 0.25)), [])
    if len(br) < 3:
        return 0.0
    autres = [c for (f, i, c) in br if not (f == fid and i == ip)]
    return (max(autres) / 2.0) if autres else 0.0


def _est_carrefour(nd, p):
    return len(nd.get((round(p[0] / 0.25), round(p[1] / 0.25)), [])) >= 3


def _passage_pieton(m, pts, cum, s, ch, coul, G, dy=0.0):
    """La trame d'un passage piéton : des bandes de PASSAGE_BANDE, en travers.

    Chaque bande est un ruban court dans le sens de la marche — donc le même
    code que la chaussée, donc le même sens de faces. Le nombre de bandes se
    déduit de la largeur de chaussée, il n'est jamais choisi : c'est ce qui
    fait qu'un passage de boulevard en a onze et un passage de rue huit."""
    p, u = _le_long(pts, cum, s)
    nrm = (-u[1], u[0])
    demi = ch / 2.0 - PASSAGE_JEU_BORD
    pas = PASSAGE_BANDE + PASSAGE_ECART
    k = int((2.0 * demi + PASSAGE_ECART) / pas)
    if k < 2:
        return 0, 0
    total = k * PASSAGE_BANDE + (k - 1) * PASSAGE_ECART
    t0 = -total / 2.0 + PASSAGE_BANDE / 2.0
    hp = PASSAGE_PROFONDEUR / 2.0
    tri = 0
    for j in range(k):
        t = t0 + j * pas
        c = (p[0] + nrm[0] * t, p[1] + nrm[1] * t)
        a = (c[0] - u[0] * hp, c[1] - u[1] * hp)
        b = (c[0] + u[0] * hp, c[1] + u[1] * hp)
        tri += _ruban(m, [a, b], PASSAGE_BANDE, coul, G,
                      y=Y_MARQUAGE + dy, bouts=False)
    return k, tri


def _cle_passage(p):
    return (round(p[0] / 0.25), round(p[1] / 0.25))


def _ecart_segments(a0, a1, b0, b1):
    """La distance entre deux segments du plan. 0 s'ils se coupent."""
    def _pt_seg(p, q0, q1):
        vx, vy = q1[0] - q0[0], q1[1] - q0[1]
        L2 = vx * vx + vy * vy
        t = 0.0 if L2 < 1e-12 else max(0.0, min(
            1.0, ((p[0] - q0[0]) * vx + (p[1] - q0[1]) * vy) / L2))
        return math.hypot(p[0] - (q0[0] + vx * t), p[1] - (q0[1] + vy * t))
    d0 = (a1[0] - a0[0], a1[1] - a0[1])
    d1 = (b1[0] - b0[0], b1[1] - b0[1])
    den = d0[0] * d1[1] - d0[1] * d1[0]
    if abs(den) > 1e-12:
        w = (b0[0] - a0[0], b0[1] - a0[1])
        t = (w[0] * d1[1] - w[1] * d1[0]) / den
        u = (w[0] * d0[1] - w[1] * d0[0]) / den
        if -1e-9 <= t <= 1.0 + 1e-9 and -1e-9 <= u <= 1.0 + 1e-9:
            return 0.0
    return min(_pt_seg(a0, b0, b1), _pt_seg(a1, b0, b1),
               _pt_seg(b0, a0, a1), _pt_seg(b1, a0, a1))


def _trame_passage(p, u, ch):
    """Les deux bouts de la ligne que le passage suit en travers de la rue."""
    demi = ch / 2.0 - PASSAGE_JEU_BORD
    n = (-u[1], u[0])
    return ((p[0] - n[0] * demi, p[1] - n[1] * demi),
            (p[0] + n[0] * demi, p[1] + n[1] * demi))


def _passages_ville(routes, morceaux, nd, chenal):
    """🚶 QUELS PASSAGES PIÉTONS LA VILLE GARDE, une fois les branches
    confrontées entre elles.

    🔴 Les règles ⑤ ⑥ ⑦ regardent UN tronçon à la fois, et à un nœud où deux
    branches repartent sous un angle serré leurs deux passages se recouvrent :
    une croix de peinture au milieu du carrefour, vue à l'écran le 2026-09-01.
    On les trie de la rue la plus large à la plus étroite et on retire celui
    qui vient toucher un passage déjà retenu — la traversée du boulevard reste,
    celle de la contre-allée saute.

    Renvoie (les clés retenues, le nombre de retirés)."""
    cand = []
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        for ip, ms in enumerate(morceaux.get(d["fid"], ())):
            for axe in ms:
                cum = _cumul(axe)
                if cum[-1] < 1.0:
                    continue
                r0 = _zone_echange(nd, axe[0], d["fid"], ip)
                r1 = _zone_echange(nd, axe[-1], d["fid"], ip)
                tv, _sans, _eau = _candidats_passage(
                    d, axe, cum, ch, nd, r0, r1, chenal)
                for t in tv:
                    p, u = _le_long(axe, cum, t)
                    cand.append((ch, d["fid"], p, u))
    cand.sort(key=lambda c: (-c[0], c[1]))
    gardes, tenus, retires = set(), [], 0
    for ch, _fid, p, u in cand:
        a0, a1 = _trame_passage(p, u, ch)
        heurte = False
        for b0, b1 in tenus:
            if _ecart_segments(a0, a1, b0, b1) < PASSAGE_PROFONDEUR + JEU_MARQUAGE:
                heurte = True
                break
        if heurte:
            retires += 1
            continue
        tenus.append((a0, a1))
        gardes.add(_cle_passage(p))
    return gardes, retires


def _zones_interdites(d, axe, cum, ip, ch, nd, chenal, gardes=None):
    """Où la chaussée est prise : la zone d'échange à chaque bout, et les
    traversées. Renvoie (recul début, recul fin, abscisses des passages,
    sans trottoir, passages refusés au-dessus de l'eau).

    🅿️ Partagée avec `_places_de_rue` : une place peinte au carrefour mettait
    huit voitures garées en travers du même nœud, chaque branche ouvrant sa
    file sur le point de rencontre.

    `gardes` est le verdict de `_passages_ville` : sans lui, chaque branche
    garde le passage que ses seules règles lui donnent.
    """
    r0 = _zone_echange(nd, axe[0], d["fid"], ip)
    r1 = _zone_echange(nd, axe[-1], d["fid"], ip)
    tv, sans_trottoir, sur_eau = _candidats_passage(
        d, axe, cum, ch, nd, r0, r1, chenal)
    if gardes is not None:
        tv = [t for t in tv
              if _cle_passage(_le_long(axe, cum, t)[0]) in gardes]
    return r0, r1, tv, sans_trottoir, sur_eau


def _candidats_passage(d, axe, cum, ch, nd, r0, r1, chenal):
    """Les passages que les règles ⑤ ⑥ ⑦ posent sur cette part, avant qu'on
    regarde ce que font les branches voisines."""
    L = cum[-1]

    # ⑤ les passages piétons. Ils demandent un trottoir des DEUX côtés : on
    # applique le test de `_largeur_trottoir` à la demi-largeur du tronçon,
    # c'est-à-dire exactement ce que `_trottoirs` ira poser plus loin.
    if _largeur_trottoir((d["largeur_m"] or 0.0) / 2.0, ch) <= 0.0:
        return [], 1, 0
    tv = []
    marge = PASSAGE_RECUL + PASSAGE_PROFONDEUR / 2.0
    if _est_carrefour(nd, axe[0]):
        tv.append(r0 + marge)
    if _est_carrefour(nd, axe[-1]):
        tv.append(L - r1 - marge)
    # ⑥ un tronçon long sans traversée : on en pose au milieu, autant
    # qu'il en faut pour rester sous ESPACEMENT_TRAVERSEE.
    bornes = sorted(set([0.0] + tv + [L]))
    for i in range(len(bornes) - 1):
        trou = bornes[i + 1] - bornes[i]
        if trou <= ESPACEMENT_TRAVERSEE:
            continue
        k = int(trou / ESPACEMENT_TRAVERSEE)
        for j in range(1, k + 1):
            tv.append(bornes[i] + trou * j / (k + 1.0))
    # ⑦ et jamais sur un pont : le chenal passe dessous, la peinture non.
    garde, sur_eau = [], 0
    for s in tv:
        if s < PASSAGE_PROFONDEUR or s > L - PASSAGE_PROFONDEUR:
            continue
        pt, _ = _le_long(axe, cum, s)
        if chenal.dans_eau(pt):
            sur_eau += 1
            continue
        garde.append(s)
    return sorted(garde), 0, sur_eau


def _marquage(m, d, axe, ip, ch, nd, chenal, coul, G, dy=0.0, gardes=None):
    """Tout le marquage d'une part de tronçon. Renvoie un compte.

    L'ordre compte : on place d'abord les PASSAGES (ce sont eux qui décident
    où le reste n'a pas le droit d'aller), puis on retire du tracé les zones
    de carrefour et les passages, et on ne peint les lignes que dans ce qui
    reste. Une ligne ne peut donc jamais traverser un passage piéton — pas
    parce qu'on le vérifie, mais parce qu'il n'y a plus de place."""
    st = {"passages": 0, "bandes": 0, "traits": 0, "pleins": 0,
          "rives": 0, "tri": 0, "sur_eau": 0, "sans_trottoir": 0}
    cum = _cumul(axe)
    L = cum[-1]
    if L < 1.0:
        return st

    r0, r1, tv, sans_trottoir, sur_eau = _zones_interdites(
        d, axe, cum, ip, ch, nd, chenal, gardes)
    st["sur_eau"] += sur_eau
    st["sans_trottoir"] = sans_trottoir

    for s in tv:
        k, tri = _passage_pieton(m, axe, cum, s, ch, coul, G, dy)
        if k:
            st["passages"] += 1
            st["bandes"] += k
            st["tri"] += tri

    # ④ ce qui reste au marquage longitudinal
    bloques = [[0.0, r0 + JEU_MARQUAGE], [L - r1 - JEU_MARQUAGE, L]]
    for s in tv:
        bloques.append([s - PASSAGE_PROFONDEUR / 2.0 - JEU_MARQUAGE,
                        s + PASSAGE_PROFONDEUR / 2.0 + JEU_MARQUAGE])
    libres = _complement(L, _fusionner(bloques))
    if not libres:
        return st

    # ① et ② la ligne d'axe : pleine dans les virages, discontinue ailleurs
    if ch >= AXE_MIN_CHAUSSEE:
        pleins = _virages(axe, cum)
        for iv in libres:
            ici = _croiser(iv, pleins)
            for a, b in ici:
                st["tri"] += _ruban(m, _tronquer(axe, cum, a, b),
                                    LARGEUR_LIGNE, coul, G,
                                    y=Y_MARQUAGE + dy, bouts=False)
                st["pleins"] += 1
            for a, b in _decouper(iv, ici):
                for t0, t1 in _pointilles(a, b):
                    st["tri"] += _ruban(m, _tronquer(axe, cum, t0, t1),
                                        LARGEUR_LIGNE, coul, G,
                                        y=Y_MARQUAGE + dy, bouts=False)
                    st["traits"] += 1

    # ③ les lignes de rive, pleines, réservées aux voies rapides
    if d["hierarchie"] in HIER_LIGNE_RIVE:
        dec = ch / 2.0 - RIVE_RETRAIT - LARGEUR_LIGNE / 2.0
        for a, b in libres:
            sub = _tronquer(axe, cum, a, b)
            for cote in (-dec, dec):
                st["tri"] += _ruban(m, sub, LARGEUR_LIGNE, coul, G,
                                    y=Y_MARQUAGE + dy, decal=cote, bouts=False)
                st["rives"] += 1
    return st


def _suites(js):
    """Les files d'entiers consécutifs : [3,4,5,9,10] → [(3,5), (9,10)].

    C'est ce qui évite de peindre le dos d'une rangée en autant de bouts
    qu'elle a de places — un vrai parking le peint d'un seul trait."""
    out = []
    for j in js:
        if out and j == out[-1][1] + 1:
            out[-1][1] = j
        else:
            out.append([j, j])
    return [(a, b) for a, b in out]


def _places_de_parc(anneau):
    """La trame de stationnement d'une place-parking : combien de places elle
    range, le marquage qui les dessine, et l'aire qu'elle occupe.

    Sortie : (places, traits, trame) — le compte, les segments à peindre
    ((x0,y0), (x1,y1)), et l'anneau retiré du bord, qui sert deux fois : à
    ranger les places, et à en tenir les arbres dehors.

    Les sept règles sont commentées au § PLACE_LARGEUR. Ce qui n'y est pas et
    qui compte ici : le DOS des deux rangées est le même trait pour les deux.
    Peint une fois par rangée, il serait peint deux fois au même endroit, à la
    même altitude — deux quadrilatères coplanaires, donc du z-fighting sur
    toute la longueur de la place."""
    n = len(anneau)
    if n < 3:
        return 0, [], None
    inner = D4B.retracter(anneau, [BORD_PARKING] * n)
    if len(inner) < 3 or abs(aire_signee(inner)) < MODULE_PARKING * PLACE_LARGEUR:
        return 0, [], None
    ferme = list(inner) + [inner[0]]

    # ① la direction : la plus longue arête de l'emprise, donc la façade
    # principale sur rue. Mesuré sur l'îlot 19 : les neuf directions possibles
    # ne s'écartent que de 119 à 129 places — la direction ne se choisit donc
    # PAS sur le compte, qui ne les départage pas, mais sur ce qu'elle veut
    # dire. Un parking rangé de travers par rapport à sa façade se voit.
    i = max(range(n), key=lambda k: (anneau[(k + 1) % n][0] - anneau[k][0]) ** 2
                                    + (anneau[(k + 1) % n][1] - anneau[k][1]) ** 2)
    a, b = anneau[i], anneau[(i + 1) % n]
    theta = math.atan2(b[1] - a[1], b[0] - a[0])
    ux, uy = math.cos(theta), math.sin(theta)
    vx, vy = -uy, ux
    ox = sum(p[0] for p in inner) / len(inner)
    oy = sum(p[1] for p in inner) / len(inner)
    us = [(p[0] - ox) * ux + (p[1] - oy) * uy for p in inner]
    vs = [(p[0] - ox) * vx + (p[1] - oy) * vy for p in inner]

    def P(u, v):
        return (ox + ux * u + vx * v, oy + uy * u + vy * v)

    def cadre(u0, u1, va, vb):
        """Les QUATRE coins dedans, pas le centre. Un rectangle dont seul le
        centre est testé déborde de moitié sur un bord oblique — et tous les
        bords de cette place-ci sont obliques."""
        return all(dedans(ferme, P(u, v)) for u, v in
                   ((u0, va), (u1, va), (u1, vb), (u0, vb)))

    def trame(dv, du):
        cases = []
        k0 = int(math.floor((min(vs) - dv) / MODULE_PARKING)) - 1
        k1 = int(math.ceil((max(vs) - dv) / MODULE_PARKING)) + 1
        j0 = int(math.floor((min(us) - du) / PLACE_LARGEUR)) - 1
        j1 = int(math.ceil((max(us) - du) / PLACE_LARGEUR)) + 1
        for k in range(k0, k1 + 1):
            base = dv + k * MODULE_PARKING
            dos = base + ALLEE_PARKING + PLACE_LONGUEUR
            for r in (0, 1):
                # r = 0 : la rangée qui donne sur l'allée du module, en deçà.
                # r = 1 : celle qui lui tourne le dos et donne sur l'allée du
                # module SUIVANT. Les deux se touchent en `dos`.
                va = base + ALLEE_PARKING if r == 0 else dos
                vb = dos if r == 0 else base + MODULE_PARKING
                wa = va - ACCES_PARKING if r == 0 else vb
                wb = va if r == 0 else vb + ACCES_PARKING
                for j in range(j0, j1 + 1):
                    ua = du + j * PLACE_LARGEUR
                    ub = ua + PLACE_LARGEUR
                    if cadre(ua, ub, va, vb) and cadre(ua, ub, wa, wb):
                        cases.append((k, r, j))
        return cases

    # ③ le glissement. 80 essais à ~130 places : le coût est celui d'un
    # clignement d'œil, et il vaut 10 places de plus que la trame centrée.
    meilleur = ([], 0.0, 0.0)
    for s in range(GLISSEMENT_V):
        for t in range(GLISSEMENT_U):
            dv = s * MODULE_PARKING / GLISSEMENT_V
            du = t * PLACE_LARGEUR / GLISSEMENT_U
            cases = trame(dv, du)
            if len(cases) > len(meilleur[0]):
                meilleur = (cases, dv, du)
    cases, dv, du = meilleur
    if not cases:
        return 0, [], inner

    par_module = {}
    for k, r, j in cases:
        par_module.setdefault(k, (set(), set()))[r].add(j)

    traits = []
    for k in sorted(par_module):
        base = dv + k * MODULE_PARKING
        dos = base + ALLEE_PARKING + PLACE_LONGUEUR
        ra, rb = par_module[k]
        # ⑥ les séparations. Une par BORD de place, donc une de plus que de
        # places dans une file — et elle traverse les deux rangées d'un coup
        # quand les deux sont là, ce qui est le marquage réel d'un dos à dos.
        bords = set()
        for rangee in (ra, rb):
            for j in rangee:
                bords.add(j)
                bords.add(j + 1)
        for jb in sorted(bords):
            haut = (jb in ra) or (jb - 1 in ra)
            bas = (jb in rb) or (jb - 1 in rb)
            v0 = base + ALLEE_PARKING if haut else dos
            v1 = base + MODULE_PARKING if bas else dos
            u = du + jb * PLACE_LARGEUR
            traits.append((P(u, v0), P(u, v1)))
        # ⑦ le dos, d'un seul trait par file continue : c'est la butée des
        # deux rangées à la fois.
        for j0, j1 in _suites(sorted(ra | rb)):
            traits.append((P(du + j0 * PLACE_LARGEUR, dos),
                           P(du + (j1 + 1) * PLACE_LARGEUR, dos)))
    return len(cases), traits, inner


def _decouper(iv, retires):
    """L'intervalle privé des morceaux déjà traités."""
    out, s = [], iv[0]
    for a, b in sorted(retires):
        if a > s:
            out.append((s, min(a, iv[1])))
        s = max(s, b)
    if s < iv[1]:
        out.append((s, iv[1]))
    return [(a, b) for a, b in out if b - a > 1e-6]


def _dessus_trottoir(m, poly, coul, G, dy=0.0, decoupe=None):
    """Une face horizontale au niveau du trottoir. Le sens de parcours est
    MESURÉ, pas supposé : un coin extérieur de virage se parcourt à l'envers
    d'un coin intérieur, et une face à l'envers est cullée — donc invisible,
    et le trou ne se verrait qu'à l'écran."""
    if len(poly) < 3:
        return 0
    if decoupe is not None:
        return sum(_dessus_trottoir(m, p, coul, G, dy)
                   for p in decoupe.hors(poly))
    if _aire_xy(poly) < 0.0:
        poly = poly[::-1]
    n = 0
    for k in range(1, len(poly) - 1):
        a, b, c = poly[0], poly[k], poly[k + 1]
        if abs(_aire_xy([a, b, c])) < 1e-6:
            continue
        m.triangle(G(a[0], a[1], Y_TROTTOIR + dy),
                   G(b[0], b[1], Y_TROTTOIR + dy),
                   G(c[0], c[1], Y_TROTTOIR + dy), coul)
        n += 1
    return n


def _bordure(m, a, b, vers, coul, G, dy=0.0, decoupe=None):
    """LA BORDURE : la face verticale d'un trottoir, du dessus jusqu'à la
    plaque de sol. `vers` est la direction, à plat, vers laquelle elle doit
    regarder — la chaussée pour la bordure de rue, l'îlot pour son flanc.

    Elle descend jusqu'à la PLAQUE (−0,10) et non jusqu'à la chaussée : sous
    le trottoir il y a du sol nu d'un côté, du sol d'îlot de l'autre, et les
    deux sont plus bas. Ce qui dépasse est recouvert, jamais visible."""
    if decoupe is not None:
        return sum(_bordure(m, p, q, vers, coul, G, dy)
                   for p, q in decoupe.segments(a, b))
    n = (-(b[1] - a[1]), b[0] - a[0])
    if math.hypot(n[0], n[1]) < 1e-9:
        return 0
    if (n[0] * vers[0] + n[1] * vers[1]) < 0.0:
        a, b = b, a
    p = G(a[0], a[1], Y_TROTTOIR + dy)
    q = G(b[0], b[1], Y_TROTTOIR + dy)
    r = G(b[0], b[1], Y_TERRAIN + dy)
    s = G(a[0], a[1], Y_TERRAIN + dy)
    m.triangle(p, s, r, coul)
    m.triangle(p, r, q, coul)
    return 2


def _coin_vif(V, p, e):
    """Le coin de trottoir d'un carrefour : l'onglet des deux bords décalés,
    écrêté en biseau quand il part en pointe. C'est ce que l'auteur a demandé
    — le carrefour garde son angle."""
    a = (V[0] + p["n"][0] * p["w"], V[1] + p["n"][1] * p["w"])
    b = (V[0] + e["n"][0] * e["w"], V[1] + e["n"][1] * e["w"])
    den = p["u"][0] * e["u"][1] - p["u"][1] * e["u"][0]
    if abs(den) > 1e-9:
        t = ((b[0] - a[0]) * e["u"][1] - (b[1] - a[1]) * e["u"][0]) / den
        M = (a[0] + p["u"][0] * t, a[1] + p["u"][1] * t)
        if math.hypot(M[0] - V[0], M[1] - V[1]) <= \
                LIMITE_MITRE_TROTTOIR * max(p["w"], e["w"]):
            return (M, M)
    return (a, b)                               # biseau


def _coin_arrondi(V, p, e, coudes):
    """L'arc de bordure au sommet d'un coude, ou None si ce sommet n'en est
    pas un.

    🔴 LES DEUX ÎLOTS D'UN MÊME COUDE DOIVENT S'ACCORDER, sinon la rue change
    de largeur dans le virage. Ils ne se parlent pas : ils lisent tous les
    deux le MÊME rayon d'axe, calculé une fois pour toutes par `_coudes`, et
    en déduisent le leur — R moins leur distance à l'axe du côté intérieur du
    virage, R plus cette distance du côté extérieur. Deux arcs concentriques,
    donc un corridor de largeur constante."""
    if p["rue"][:2] != e["rue"][:2] or abs(p["rue"][2] - e["rue"][2]) != 1:
        return None                        # deux rues : c'est un carrefour
    cd = coudes.get((p["rue"][0], p["rue"][1], max(p["rue"][2], e["rue"][2])))
    if cd is None:
        return None
    pv = max(-1.0, min(1.0, p["u"][0] * e["u"][0] + p["u"][1] * e["u"][1]))
    if abs(math.degrees(math.acos(pv)) - cd["theta"]) > 8.0:
        return None              # l'anneau ne tourne pas comme l'axe : biseau
    c = ((p["d"] - p["w"]) + (e["d"] - e["w"])) / 2.0
    vers = (-p["n"][0], -p["n"][1])             # de l'axe vers l'îlot
    dedans = (cd["u1"][0] * vers[1] - cd["u1"][1] * vers[0]) * cd["sens"] > 0
    r = cd["R"] - c if dedans else cd["R"] + c
    if r < 1.0:
        return None
    # La tangente recule de T le long de CHAQUE arête : si elle dépasse
    # l'arête de l'anneau, le quadrilatère du trottoir se retourne.
    T = cd["R"] * math.tan(math.radians(cd["theta"]) / 2.0)
    if T > 0.90 * min(p["L"], e["L"]):
        return None
    C = cd["C"]
    A = (C[0] - cd["n1"][0] * r, C[1] - cd["n1"][1] * r)
    B = (C[0] - cd["n2"][0] * r, C[1] - cd["n2"][1] * r)
    # L'anneau de l'îlot extérieur parcourt le coude À REBOURS de l'axe : son
    # premier point d'arc est alors celui de la SECONDE branche.
    if p["u"][0] * cd["u1"][0] + p["u"][1] * cd["u1"][1] < 0.0:
        A, B = B, A
    return tuple(_arc(C, r, A, B))


def _trottoirs(ilots, routes, coudes):
    """Le trottoir de chaque îlot : un anneau posé le long de la limite de
    parcelle, surélevé, qui TOURNE LES COINS DE RUE tout seul.

    🔴 C'est le point important, et il ne se voit pas dans le code : AUCUNE
    LIGNE ICI NE PARLE DE CARREFOUR. Un carrefour est ce qui RESTE entre
    quatre anneaux d'îlot — exactement comme un pont est ce qui reste quand on
    creuse le chenal sous une voirie qui, elle, ne sait rien.

    🔄 Le trottoir était AVANT un quadrilatère plus large que la chaussée,
    glissé SOUS elle, à 3 cm : deux liserés dépassaient de part et d'autre de
    l'asphalte, le carrefour était noyé par le débordement des deux rubans, et
    il n'y avait ni bordure ni coin de rue. L'ordre transversal est maintenant
    celui d'une vraie rue :

        façade │ trottoir │ mètres libres │ chaussée │ …
               └ bordure

    Les mètres libres restent le sol nu de la plaque : c'est là que le
    stationnement DE RUE se dessinera. 🔄 Le commentaire disait « 4 587 places
    à Wehrau, aucune visible » ; les deux moitiés ont bougé. Le compte est de
    3 310 places de rue (`routes.stationnement`, mesuré le 2026-08-19), et
    depuis le même jour la place-parking, elle, est dessinée — 123 places
    peintes sur les 127 annoncées, § `_places_de_parc`. Les rues, non.

    Sortie : {fid de tronçon: [faces]}. Les faces sont rangées sous LA RUE que
    longe l'arête, pas sous l'îlot — cliquer un trottoir ouvre la fiche du
    tronçon. ⚠️ Les fid d'îlot et de tronçon se recouvrent (71 et 178) : mêlés
    dans le même maillage, ils rendraient la ville cliquable n'importe
    comment."""
    segs, idx = _index_voirie(routes)
    faces = {}
    stats = {"ilots": 0, "aretes": 0, "avec_rue": 0, "avec_trottoir": 0,
             "coins": 0, "arrondis": 0, "long": 0.0}
    # Un coude a DEUX bords, et les deux doivent s'arrondir pour que la rue
    # garde sa largeur dans le virage. Le compte le dit au lieu de le supposer.
    par_coude = {}
    for fid_i in sorted(ilots):
        d = ilots[fid_i]
        if d["sous_type"] == "riviere":
            continue
        ring = d["anneau"]
        n = len(ring)
        if n < 3:
            continue
        ar = []
        for i in range(n):
            a, b = ring[i], ring[(i + 1) % n]
            u = _unite(a, b)
            if u is None:
                ar.append(None)
                continue
            stats["aretes"] += 1
            # L'anneau est TRIGONOMÉTRIQUE (forcé par `anneau_ouvert`), donc
            # l'intérieur est à gauche et le dehors — la rue — est à droite.
            nout = (u[1], -u[0])
            rue = _rue_le_long(a, b, nout, segs, idx)
            if rue is None:
                ar.append(None)
                continue
            stats["avec_rue"] += 1
            w = _largeur_trottoir(rue[0], rue[2])
            if w <= 0.0:
                ar.append(None)
                continue
            stats["avec_trottoir"] += 1
            ar.append({"u": u, "n": nout, "w": w, "d": rue[0],
                       "L": math.hypot(b[0] - a[0], b[1] - a[1]),
                       "rue": (rue[3], rue[4], rue[5])})

        deb = [None] * n
        fin = [None] * n
        coins = [None] * n
        for i in range(n):
            e, p = ar[i], ar[(i - 1) % n]
            V = ring[i]
            if e is None and p is None:
                continue
            if e is None:                       # le trottoir s'arrête ici
                fin[(i - 1) % n] = (V[0] + p["n"][0] * p["w"],
                                    V[1] + p["n"][1] * p["w"])
                continue
            if p is None:                       # … et il commence ici
                deb[i] = (V[0] + e["n"][0] * e["w"], V[1] + e["n"][1] * e["w"])
                continue
            stats["coins"] += 1
            arc = _coin_arrondi(V, p, e, coudes)
            if arc is None:
                arc = _coin_vif(V, p, e)
            else:
                stats["arrondis"] += 1
                cle = (p["rue"][0], p["rue"][1],
                       max(p["rue"][2], e["rue"][2]))
                par_coude[cle] = par_coude.get(cle, 0) + 1
            fin[(i - 1) % n] = arc[0]
            deb[i] = arc[-1]
            coins[i] = arc

        for i in range(n):
            e = ar[i]
            if e is None or deb[i] is None or fin[i] is None:
                continue
            a, b = ring[i], ring[(i + 1) % n]
            # Deux coins arrondis qui se rejoignent au milieu de l'arête :
            # le quadrilatère se retournerait. On saute plutôt que de plier.
            if ((fin[i][0] - deb[i][0]) * e["u"][0]
                    + (fin[i][1] - deb[i][1]) * e["u"][1]) <= 0.05:
                continue
            f = faces.setdefault(e["rue"][0], [])
            f.append(("plat", [a, b, fin[i], deb[i]]))
            f.append(("mur", deb[i], fin[i], e["n"]))          # la bordure
            f.append(("mur", a, b, (-e["n"][0], -e["n"][1])))  # le flanc
            stats["long"] += math.hypot(b[0] - a[0], b[1] - a[1])
            c = coins[i]
            if c is not None and len(c) >= 2 and \
                    math.hypot(c[0][0] - c[-1][0], c[0][1] - c[-1][1]) > 1e-6:
                f.append(("plat", [ring[i]] + list(c)))
                for k in range(len(c) - 1):
                    # Le dehors d'un coin n'est PAS la normale d'une de ses
                    # deux arêtes : sur un coin extérieur de virage l'arc
                    # tourne de l'autre côté. La direction qui vaut toujours
                    # est celle qui part du sommet de l'anneau.
                    f.append(("mur", c[k], c[k + 1],
                              ((c[k][0] + c[k + 1][0]) / 2.0 - ring[i][0],
                               (c[k][1] + c[k + 1][1]) / 2.0 - ring[i][1])))
        stats["ilots"] += 1
    stats["coudes_entiers"] = sum(1 for v in par_coude.values() if v == 2)
    return faces, stats
