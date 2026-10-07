# -*- coding: utf-8 -*-
"""Volumes, façades et toitures à partir des empreintes mesurées."""


import math
import random
from apercu_carte import dedans
from importlib import import_module
from .geometrie import (
    _boite,
    _convexe,
    _decaler,
    _degenere,
    _graine_lieu,
    _point_proche,
    aire_signee,
    normale,
    trianguler,
)
from .reglages import (
    ACCES_OUVERTURE,
    ACROTERE,
    AIRE_JARDIN_MIN,
    ANGLE_MIN_DEG,
    AO_HAUTEUR,
    AO_MIN,
    BANDE_CHAMP,
    BANDE_ECART,
    BATI,
    BATI_DEFAUT,
    CHEMINEE_AIRE_MIN,
    CHEMINEE_COTE,
    CHEMINEE_HAUT,
    COMPLEXITE_PLAT,
    COS_EGOUT,
    COUL_CHEMINEE,
    DEBORD_TOIT,
    DENSE_INTERDIT,
    ENFOUISSEMENT,
    EPAISSEUR_TOIT,
    ETAGE_M,
    FACADE_AVEUGLE,
    FACADE_LOGEMENT,
    FACADE_MIN,
    FACADE_PORTE,
    FACADE_TISSU,
    FACADE_TISSU_DEFAUT,
    FAITAGE_MAX,
    HAIE_HAUTEUR,
    HAIE_LARGEUR,
    HAIE_SEGMENT_MIN,
    LARGEUR_MIN_BATI,
    MITOYEN_JEU,
    MITOYEN_SINUS,
    PAN_COUPE_M,
    PART_CHEMINEES,
    PAN_MIN_M2,
    PART_COTE_MAX,
    RECTANGULAIRE,
    RETRAIT_MAX,
    RUE_DERRIERE,
    RUE_SINUS,
    RUINE_DALLE_Y,
    RUINE_PANS,
    RUINE_PAN_ARETES,
    RUINE_RETRAIT,
    TOL_RUE,
    Y_SOL,
    cheminees,
    facades,
    facades_m,
    minces,
    pointes,
    rectangles,
    retournes,
)

D4B = import_module("04b_emprises_baties")
D4C = import_module("04c_parcelles")


def _acces_pavillonnaire(parcelle, emprises, rues):
    """Le plus court trajet maison→rue contraint à l'angle droit.

    Pour chaque limite sur rue, on exprime chaque arête du bâtiment dans le
    repère de cette limite : `t` le long de la rue, `n` en profondeur. Les
    deux bouts qui partagent le même `t` forment donc, par construction, un
    chemin perpendiculaire. Parmi tous ces chemins possibles, on garde le plus
    court ; une égalité se départage vers le milieu de la façade pour éviter
    qu'un long mur parallèle reçoive systématiquement son accès dans un coin.
    """
    meilleur = None
    marge = ACCES_OUVERTURE / 2.0 + HAIE_LARGEUR
    for k, sur_rue in enumerate(rues):
        if not sur_rue:
            continue
        a, b = parcelle[k], parcelle[(k + 1) % len(parcelle)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        longueur = math.hypot(dx, dy)
        if longueur < ACCES_OUVERTURE + 2.0 * HAIE_LARGEUR:
            continue
        ux, uy = dx / longueur, dy / longueur
        nx, ny = -uy, ux
        tmin, tmax = marge, longueur - marge
        for emp in emprises:
            for i in range(len(emp)):
                p, q = emp[i], emp[(i + 1) % len(emp)]
                px, py = p[0] - a[0], p[1] - a[1]
                qx, qy = q[0] - a[0], q[1] - a[1]
                t0, t1 = px * ux + py * uy, qx * ux + qy * uy
                n0, n1 = px * nx + py * ny, qx * nx + qy * ny
                dt = t1 - t0
                if abs(dt) < 1e-9:
                    if t0 < tmin or t0 > tmax:
                        continue
                    lo, hi = 0.0, 1.0
                else:
                    z0, z1 = (tmin - t0) / dt, (tmax - t0) / dt
                    lo, hi = max(0.0, min(z0, z1)), min(1.0, max(z0, z1))
                    if lo > hi:
                        continue
                essais = [lo, hi, (lo + hi) / 2.0]
                dn = n1 - n0
                if abs(dn) > 1e-9:
                    racine = -n0 / dn
                    if lo <= racine <= hi:
                        essais.append(racine)
                for lam in essais:
                    t = t0 + dt * lam
                    n = n0 + dn * lam
                    maison = (p[0] + (q[0] - p[0]) * lam,
                               p[1] + (q[1] - p[1]) * lam)
                    route = (a[0] + ux * t, a[1] + uy * t)
                    distance = abs(n)
                    if distance < 0.25:
                        continue
                    cle = (round(distance, 9), abs(t - longueur / 2.0))
                    if meilleur is None or cle < meilleur[0]:
                        vx, vy = route[0] - maison[0], route[1] - maison[1]
                        lv = math.hypot(vx, vy)
                        # `asin(dot)` mesure l'écart à 90°, pas l'angle
                        # lui-même. Il doit rester nul à l'arrondi près.
                        ecart = math.degrees(math.asin(min(
                            1.0, abs((vx * ux + vy * uy) / lv))))
                        meilleur = (cle, {"arete": k, "maison": maison,
                                          "route": route,
                                          "longueur": distance,
                                          "ecart_angle": ecart})
    return None if meilleur is None else meilleur[1]


def _ouvrir_segment(a, b, centre, largeur):
    """Les deux morceaux d'une limite après l'ouverture du chemin."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    longueur = math.hypot(dx, dy)
    if longueur < 1e-9:
        return []
    ux, uy = dx / longueur, dy / longueur
    t = max(0.0, min(longueur,
                     (centre[0] - a[0]) * ux + (centre[1] - a[1]) * uy))
    demi = largeur / 2.0
    avant = (a[0] + ux * max(0.0, t - demi),
             a[1] + uy * max(0.0, t - demi))
    apres = (a[0] + ux * min(longueur, t + demi),
             a[1] + uy * min(longueur, t + demi))
    return [(a, avant), (apres, b)]


def _haie(m, a, b, coul, G):
    """Un petit prisme le long d'une limite de parcelle.

    Le segment est raccourci d'une demi-largeur à chaque bout : deux limites
    qui se rencontrent au coin peuvent se toucher, jamais se dépasser. Renvoie
    la longueur visible pour que le contrôle imprimé mesure ce qui est dessiné.
    """
    dx, dy = b[0] - a[0], b[1] - a[1]
    longueur = math.hypot(dx, dy)
    if longueur < HAIE_SEGMENT_MIN:
        return 0.0
    ux, uy = dx / longueur, dy / longueur
    vx, vy = -uy, ux
    demi = HAIE_LARGEUR / 2.0
    a = (a[0] + ux * demi, a[1] + uy * demi)
    b = (b[0] - ux * demi, b[1] - uy * demi)
    anneau = [
        (a[0] + vx * demi, a[1] + vy * demi),
        (a[0] - vx * demi, a[1] - vy * demi),
        (b[0] - vx * demi, b[1] - vy * demi),
        (b[0] + vx * demi, b[1] + vy * demi),
    ]
    y0, y1 = Y_SOL, Y_SOL + HAIE_HAUTEUR
    for k in range(4):
        p, q = anneau[k], anneau[(k + 1) % 4]
        m.triangle(G(p[0], p[1], y0), G(q[0], q[1], y0),
                   G(q[0], q[1], y1), coul, (0.76, 0.76, 1.0))
        m.triangle(G(p[0], p[1], y0), G(q[0], q[1], y1),
                   G(p[0], p[1], y1), coul, (0.76, 1.0, 1.0))
    for ia, ib, ic in trianguler(anneau):
        p, q, r = anneau[ia], anneau[ib], anneau[ic]
        m.triangle(G(p[0], p[1], y1), G(q[0], q[1], y1),
                   G(r[0], r[1], y1), tuple(c * 1.06 for c in coul))
    return longueur - HAIE_LARGEUR


def _index_bord(anneaux, grille=1.0):
    """Index de grille des arêtes devant lesquelles une parcelle est « sur
    rue ». Sans lui, tester « cette arête donne-t-elle sur la rue » serait
    quadratique — 968 parcelles contre 53 emprises, ça se sent.

    🚶 Prend une LISTE d'anneaux depuis le 2026-08-14, et c'est ce qui fait
    tenir le chemin de bout en bout. Le bord de l'emprise ne suffit plus :
    les deux parois de la venelle sont aussi une adresse. `04c` le sait déjà
    — il peigne chaque morceau d'emprise pour son compte, donc pour lui la
    paroi EST du bord. Si `07` ne l'apprend pas, toutes les parcelles qui
    donnent sur la venelle sortent enclavées et repartent au jardin : mesuré
    avant correction, 879 volumes bâtis sans chemin contre 855 avec, alors
    que la découpe en annonçait soixante de plus."""
    idx = {}
    for anneau in anneaux:
        n = len(anneau)
        for i in range(n):
            a, b = anneau[i], anneau[(i + 1) % n]
            x0 = int(min(a[0], b[0]) // grille)
            x1 = int(max(a[0], b[0]) // grille)
            y0 = int(min(a[1], b[1]) // grille)
            y1 = int(max(a[1], b[1]) // grille)
            for cx in range(x0, x1 + 1):
                for cy in range(y0, y1 + 1):
                    idx.setdefault((cx, cy), []).append((a, b))
    return idx


def _rive(m, anneau, y_haut, epaisseur, coul, G):
    """La tranche verticale du débord de toit. C'est elle qu'on voit d'en
    haut comme un liseré sombre autour de chaque maison, et c'est elle qui
    reçoit l'ombre portée du toit sur la façade."""
    for i in range(len(anneau)):
        a, b = anneau[i], anneau[(i + 1) % len(anneau)]
        pa_b = G(a[0], a[1], y_haut)
        pb_b = G(b[0], b[1], y_haut)
        pa_h = G(a[0], a[1], y_haut + epaisseur)
        pb_h = G(b[0], b[1], y_haut + epaisseur)
        m.triangle(pa_b, pb_b, pb_h, coul)
        m.triangle(pa_b, pb_h, pa_h, coul)


def _acrotere(m, anneau, y_haut, coul, G):
    """Le muret d'un toit plat, ÉMIS EN DOUBLE FACE — deux quads opposés par
    arête, donc visible du dedans comme du dehors sans épaisseur réelle. Le
    dessus du toit reste à `y_haut` : c'est le retrait de 45 cm qui fait lire
    « toiture » et non « tranche de boîte »."""
    for i in range(len(anneau)):
        a, b = anneau[i], anneau[(i + 1) % len(anneau)]
        pa_b = G(a[0], a[1], y_haut)
        pb_b = G(b[0], b[1], y_haut)
        pa_h = G(a[0], a[1], y_haut + ACROTERE)
        pb_h = G(b[0], b[1], y_haut + ACROTERE)
        m.triangle(pa_b, pb_b, pb_h, coul)
        m.triangle(pa_b, pb_h, pa_h, coul)
        m.triangle(pb_b, pa_b, pa_h, coul)
        m.triangle(pb_b, pa_h, pb_h, coul)


def _cheminee(m, x, y, y_bas, y_haut, u, coul, G):
    """Une souche : quatre murs et un chapeau, alignés sur le faîtage `u`.

    Elle part de `y_bas` (sous la couverture) et non du faîtage : à mi-pente,
    une souche posée sur le plan du toit flotterait au-dessus du versant.

    🔄 Le 2026-08-18, la boîte orientée est sortie d'ici dans `_boite` : la pile
    d'un pont est la même forme, à la taille près."""
    return _boite(m, (x, y), u, CHEMINEE_COTE, CHEMINEE_COTE,
                  y_bas, y_haut, coul, G)


def _bandes_de_fauche(anneau, coul):
    """Les bandes suivent le grand côté du champ, sans changer son contour."""
    a, b = max(zip(anneau, anneau[1:] + anneau[:1]),
               key=lambda ab: math.dist(*ab))
    ang = math.atan2(b[1] - a[1], b[0] - a[0]) + math.pi / 2
    nx, ny = math.cos(ang), math.sin(ang)
    proj = [p[0] * nx + p[1] * ny for p in anneau]
    s0, s1 = min(proj), max(proj)
    if s1 - s0 < BANDE_CHAMP * 1.6:
        return [(anneau, coul)]

    out, reste = [], [anneau]
    rang = 0
    s = s0 + BANDE_CHAMP
    # Le plafond de rangs borne le cas pathologique d'un champ démesuré ; à
    # 15 m de bande, 80 rangs couvrent 1,2 km, soit plus que Wehrau entière.
    while s < s1 - 0.5 and rang < 80 and reste:
        suivant = []
        for mo in reste:
            for piece in D4C.couper(mo, (nx * s, ny * s), (nx, ny)):
                cx = sum(p[0] for p in piece) / len(piece)
                cy = sum(p[1] for p in piece) / len(piece)
                # `couper` rend les morceaux des DEUX côtés sans dire lequel :
                # le centroïde tranche, et il est fiable ici parce que chaque
                # morceau est entièrement d'un côté de la droite.
                if cx * nx + cy * ny < s:
                    out.append((piece, rang))
                else:
                    suivant.append(piece)
        reste = suivant
        rang += 1
        s += BANDE_CHAMP
    out.extend((mo, rang) for mo in reste)
    return [(mo, tuple(c * (1.0 + (BANDE_ECART if k % 2 else -BANDE_ECART))
                       for c in coul)) for mo, k in out]


def _index_murs(empreintes, grille=2.0):
    """Index de grille des murs de TOUS les bâtiments d'un îlot.

    Chaque arête y entre avec le rang de son bâtiment : c'est ce rang qui
    permet ensuite d'ignorer le bâtiment lui-même. Sans index, chercher le
    voisin de chaque mur serait quadratique — jusqu'à 40 volumes par îlot.

    ⚠️ L'arête est semée LE LONG DU SEGMENT, pas dans sa boîte
    englobante — la même différence qu'entre un trait et le rectangle qui
    le contient. Une arête de barre de 100 m en diagonale occupe 50 cases
    le long de sa ligne, contre 2 500 dans sa boîte : autant de faux
    voisins à écarter pour chaque mur. La passe entière (index +
    mitoyenneté + façades sur rue) coûte 0,2 s sur les 11 s de l'export,
    mesuré le 2026-08-18.

    ⚠️ `_index_bord`, plus haut, a gardé la boîte englobante : ses
    anneaux d'îlot n'ont que des arêtes courtes, et rien n'a montré que
    ça le gênait. Ne pas « uniformiser » sans mesurer d'abord."""
    idx = {}
    for k, emp in enumerate(empreintes):
        n = len(emp)
        for i in range(n):
            a, b = emp[i], emp[(i + 1) % n]
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            # Un pas de demi-case : aucune case traversée ne peut être sautée.
            pas = max(1, int(L / (grille * 0.5)) + 1)
            vues = set()
            for j in range(pas + 1):
                t = float(j) / pas
                c = (int((a[0] + t * (b[0] - a[0])) // grille),
                     int((a[1] + t * (b[1] - a[1])) // grille))
                if c in vues:
                    continue
                vues.add(c)
                idx.setdefault(c, []).append((k, a, b))
    return idx


def _mitoyen(k, a, b, idx, grille=2.0):
    """Ce mur du bâtiment `k` est-il collé à un autre bâtiment ?"""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    if L < 1e-9:
        return False
    ux, uy = dx / L, dy / L
    # Trois points de contrôle plutôt qu'un : un mur n'est mitoyen que s'il
    # l'est sur toute sa longueur. Effleurer le coin du voisin ne compte pas.
    for t in (0.25, 0.5, 0.75):
        p = (a[0] + ux * L * t, a[1] + uy * L * t)
        cx, cy = int(p[0] // grille), int(p[1] // grille)
        touche = False
        for ddx in (-1, 0, 1):
            for ddy in (-1, 0, 1):
                for (j, c, e) in idx.get((cx + ddx, cy + ddy), ()):
                    if j == k:
                        continue
                    vx, vy = e[0] - c[0], e[1] - c[1]
                    M = math.hypot(vx, vy)
                    if M < 1e-9:
                        continue
                    if abs(ux * vy - uy * vx) / M > MITOYEN_SINUS:
                        continue
                    if D4C.dist_pt_seg(p, c, e) <= MITOYEN_JEU:
                        touche = True
                        break
                if touche:
                    break
            if touche:
                break
        if not touche:
            return False
    return True


def _segments_rue(parcelle, idx_bord):
    """Les arêtes de la parcelle qui donnent sur la rue, en segments."""
    n = len(parcelle)
    return [(parcelle[i], parcelle[(i + 1) % n])
            for i, r in enumerate(_sur_rue(parcelle, idx_bord)) if r]


def _devant_rue(a, b, segs):
    """Ce mur regarde-t-il une limite sur rue de sa propre parcelle ?"""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    if L < 1e-9:
        return False
    ux, uy = dx / L, dy / L
    # Anneau TRIGONOMÉTRIQUE (forcé par `anneau_ouvert`) ⇒ l'intérieur est à
    # gauche du parcours, donc le dehors est (dy, −dx). Le même raisonnement
    # que le contrôle de sens des murs dans `_masse`, à un repère près.
    mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
    nx, ny = uy, -ux
    for (c, e) in segs:
        vx, vy = e[0] - c[0], e[1] - c[1]
        M = math.hypot(vx, vy)
        if M < 1e-9:
            continue
        if abs(ux * vy - uy * vx) / M > RUE_SINUS:
            continue
        q = _point_proche((mx, my), c, e)
        if math.hypot(q[0] - mx, q[1] - my) > RETRAIT_MAX:
            continue
        # La rue est-elle DEVANT ce mur ? C'est ce test-là, et lui seul, qui
        # écarte la façade arrière — elle est parallèle à la rue et, sur une
        # parcelle courte, presque aussi près.
        if (q[0] - mx) * nx + (q[1] - my) * ny >= -RUE_DERRIERE:
            return True
    return False


def _facades(k, emp, parcelle, idx_bord, idx_murs, st):
    """Le genre de percement de CHAQUE mur de l'empreinte, arête par arête.

    Trois questions dans cet ordre, et c'est tout :
      · le mur est-il mitoyen ? alors il est aveugle ;
      · donne-t-il sur la rue ? alors il porte le rez qui s'ouvre — vitrine
        pour le front commerçant, porte ailleurs ;
      · sinon c'est une façade arrière : des fenêtres, pas d'entrée.
    """
    sur_rue, ailleurs = FACADE_TISSU.get(st, FACADE_TISSU_DEFAUT)
    segs = _segments_rue(parcelle, idx_bord)
    n = len(emp)

    def longueur(i):
        a, b = emp[i], emp[(i + 1) % n]
        return math.hypot(b[0] - a[0], b[1] - a[1])

    out = []
    for i in range(n):
        a, b = emp[i], emp[(i + 1) % n]
        if longueur(i) < FACADE_MIN or _mitoyen(k, a, b, idx_murs):
            out.append(FACADE_AVEUGLE)
        elif _devant_rue(a, b, segs):
            out.append(sur_rue)
        else:
            out.append(ailleurs)

    # ⚠️ UNE SEULE PORTE PAR BÂTIMENT, sur sa plus longue façade sur rue. Un
    # pavillon d'angle a deux façades sur rue et n'a pas deux entrées.
    if sur_rue == FACADE_PORTE:
        candidats = [i for i, g in enumerate(out) if g == FACADE_PORTE]
        if candidats:
            garde = max(candidats, key=longueur)
            for i in candidats:
                if i != garde:
                    out[i] = FACADE_LOGEMENT

    for i, g in enumerate(out):
        facades[g] += 1
        facades_m[g] += longueur(i)
    return out


def _toit_plat(pente, faite, emp):
    """Le toit de CE volume est-il plat ? Le tissu donne une pente, la
    géométrie la refuse : même test qu'à l'émission, appelé aux deux endroits
    pour qu'ils ne puissent pas diverger."""
    if not (pente > 0.0 and faite is not None):
        return True
    c = _complexite(emp, faite)
    return c is None or c >= COMPLEXITE_PLAT


def _rangs_verts(volumes, pente):
    """k_vol -> la place de ce toit sur [0,1[ dans l'aire PLATE de l'îlot.

    🌿 UN TOIT EST SOLAIRE OU VERT, JAMAIS LES DEUX (2026-08-31) : le partage
    ne peut donc plus se jouer au mètre carré, il se joue volume par volume.
    Le shader verdit un toit ENTIER dès que son rang passe sous le curseur ;
    le rang est pris au MILIEU du segment d'aire du volume, donc la surface
    verdie à l'écran retombe sur celle que l'îlot annonce, à un toit près.
    L'ordre est tiré du LIEU (35) : la même ville verdit les mêmes toits.
    ⚠️ Versants et ruines n'y sont pas — `toit_plat_m2` ne les compte pas non
    plus, et c'est lui qui plafonne le curseur."""
    plats = []
    for k, (emp, _niv, faite, _parc, crue, _eau) in enumerate(volumes):
        if crue == "ruine" or not _toit_plat(pente, faite, emp):
            continue
        plats.append((random.Random(_graine_lieu(emp) ^ 0x5EDA).random(), k,
                      abs(D4C.aire_signee(emp))))
    total = sum(a for _t, _k, a in plats)
    if total <= 0.0:
        return {}
    plats.sort()
    rangs = {}
    cumul = 0.0
    for _t, k, a in plats:
        rangs[k] = (cumul + a / 2.0) / total
        cumul += a
    return rangs


def _rangs_denses(volumes, st, loge):
    """k_vol -> la place de ce bâtiment sur [0,1[ dans l'ordre de montée.

    🏢 DU PLUS BAS AU PLUS HAUT (auteur, 2026-09-03) : un îlot qu'on
    densifie monte bâtiment par bâtiment, en commençant par celui qui a le
    moins d'étages. Le shader lève un bâtiment ENTIER dès que son rang passe
    sous le curseur — même mécanique que les toits verts, sur les sommets
    cette fois-ci.
    ⚠️ Trois exclusions, et elles ne disent pas la même chose : le patrimoine
    (DENSE_INTERDIT, level design), les ruines — une ruine se relève avant de
    grandir —, et les îlots que la donnée ne LOGE PAS. Sans la dernière, une
    halle et l'université gagnaient des appartements : `logements` dit qui loge
    (04), le plancher dit combien (04d), et on n'ajoute que là où il y a déjà.
    Rend aussi l'emprise réunie de ceux qui montent, dont sortent les logements
    qu'un étage ajoute.
    """
    if st in DENSE_INTERDIT or loge <= 0:
        return {}, 0.0, []
    ordre = sorted((niv, abs(D4C.aire_signee(emp)), k)
                   for k, (emp, niv, _f, _p, crue, _e) in enumerate(volumes)
                   if crue != "ruine")
    n = len(ordre)
    if n == 0:
        return {}, 0.0, []
    total = sum(a for _niv, a, _k in ordre)
    # 🪜 LE PROFIL DES PALIERS : ce que les k premiers bâtiments pèsent dans
    # l'emprise qui monte. Le curseur de Godot compte des BÂTIMENTS, les
    # logements sortent des EMPRISES, et les deux ne vont pas au même rythme —
    # sans ce profil, monter le plus petit bâtiment logerait autant que le
    # plus grand.
    cumul = []
    c = 0.0
    for _niv, a, _k in ordre:
        c += a
        cumul.append(c / total if total > 0.0 else 0.0)
    return ({k: i / float(n) for i, (_niv, _a, k) in enumerate(ordre)},
            total, cumul)


def _masse(m, anneau, d, coul, G, niveaux=None, pente=0.0, faitage=None,
           coul_toit=None, genres=None, alea=0.0, rang_vert=1.0, famille=0):
    """Un prisme à deux plans horizontaux, base enterrée.

    🔄 `y_haut` ajoutait `altitude_relative` — le bâtiment se posait sur le
    relief que les données annonçaient. La carte est plate depuis le
    2026-08-12 : tout part de 0, et un bâtiment ne fait plus que sa hauteur.
    `y_bas` plonge sous le sol pour qu'aucun volume ne flotte. Aucune jupe,
    aucune face inférieure : elles ne sont jamais vues.

    `niveaux` permet de donner à CHAQUE parcelle sa propre hauteur, tirée de
    sa graine (35). Sans lui, mille bâtiments arasés au même plan ne valent
    pas mieux qu'un pâté plein.
    """
    if niveaux is None:
        niveaux = d["hauteur"] or 0.0
    y_haut = niveaux * ETAGE_M
    y_bas = -ENFOUISSEMENT
    # Le pied en Y monde : le shader compte les étages depuis lui.
    m.sol = G(anneau[0][0], anneau[0][1], 0.0)[1]

    def ao(y):
        return AO_MIN + (1.0 - AO_MIN) * min(1.0, max(0.0, (y - y_bas) / AO_HAUTEUR))

    n = len(anneau)
    ok = 0
    for i in range(n):
        a = anneau[i]
        b = anneau[(i + 1) % n]
        pa_b = G(a[0], a[1], y_bas)
        pb_b = G(b[0], b[1], y_bas)
        pa_h = G(a[0], a[1], y_haut)
        pb_h = G(b[0], b[1], y_haut)
        fb, fh = ao(y_bas), ao(y_haut)
        # 🪟 LES COORDONNÉES DE FAÇADE. `u` court de 0 au coin `a` jusqu'à
        # `L` au coin `b`, et `L` est répété sur les quatre sommets : c'est
        # lui qui permet au shader de centrer les travées sur CE mur-là.
        # Un mur aveugle n'en porte aucune — il sort comme avant le
        # 2026-08-18, donc en enduit plein.
        g = FACADE_AVEUGLE if genres is None else genres[i]
        genre = None
        pied = tete = None
        if g != FACADE_AVEUGLE:
            Lm = math.hypot(b[0] - a[0], b[1] - a[1])
            pied, tete = (0.0, Lm), (Lm, Lm)
            # Famille en partie entière, tirage en partie décimale : le
            # tirage est borné sous 0,998 pour que l'arrondi du JSON ne
            # le fasse pas passer à la famille suivante.
            genre = (float(g), famille + min(alea, 0.998))
        m.triangle(pa_b, pb_b, pb_h, coul, (fb, fb, fh),
                   facade=None if genre is None else (pied, tete, tete),
                   genre=genre)
        m.triangle(pa_b, pb_h, pa_h, coul, (fb, fh, fh),
                   facade=None if genre is None else (pied, tete, pied),
                   genre=genre)
        # Contrôle du sens des faces. On ne parie pas sur la chiralité après
        # l'inversion de Z, on la mesure — mais avec le bon test : sur un
        # polygone CONCAVE (43 des 69 le sont), « la normale s'éloigne du
        # centroïde » est faux aux sommets réflexes.
        #
        # Anneau trigonométrique ⇒ l'intérieur est à gauche du parcours, donc
        # la normale extérieure en source vaut (dy, −dx). Le passage en
        # repère Godot envoie un vecteur horizontal (vx, vy) sur (vx, −vy),
        # d'où l'attendu en XZ : (dy, dx).
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        nn = normale(pa_b, pb_b, pb_h)
        if L > 1e-9 and (nn[0] * dy + nn[2] * dx) / L > 0.9:
            ok += 1

    # 🔄 `coul` ne peint plus que les MURS depuis le 2026-08-18. Le toit a son
    # propre matériau ; `coul_toit` absent veut dire « l'ancien rendu », où les
    # deux étaient la même teinte.
    if coul_toit is None:
        coul_toit = coul

    # La direction de rue commande déjà le faîtage. Les rares volumes sans
    # adresse reprennent leur plus longue arête : même dans ce repli, les
    # panneaux suivent donc le bâtiment et jamais une grille mondiale.
    # 🏭 Sauf la halle : ses verrières suivent sa charpente, pas la rue — sur
    # une rue en biais, elles traversaient le toit en diagonale.
    axe_toit = None if famille == 5 else faitage
    if axe_toit is None:
        a, b = max(((anneau[i], anneau[(i + 1) % len(anneau)])
                    for i in range(len(anneau))),
                   key=lambda e: math.hypot(e[1][0] - e[0][0],
                                            e[1][1] - e[0][1]))
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        axe_toit = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
    # Un vecteur source (x, y) devient (x, -y) dans le plan XZ de Godot.
    axe_uv = (axe_toit[0], -axe_toit[1])

    # ⚠️ TOIT PENTU si l'empreinte se découpe en morceaux convexes (un L, un
    # T…) : même test que `_toit_plat`, appelé en amont pour mettre la pente à 0.
    morceaux = (_morceaux_convexes(anneau)
                if pente and pente > 0.0 and faitage is not None else None)
    if morceaux:
        bord = _decaler(anneau, DEBORD_TOIT)
        if len(morceaux) > 1:
            # Découpé APRÈS le débord ; si le bord ne se découpe pas, on garde
            # les morceaux du mur, sans débord.
            morceaux = _morceaux_convexes(bord) or morceaux
        else:
            morceaux = [bord]
        # La rive est la MÊME couverture, franchement assombrie : c'est une
        # tranche, elle ne reçoit jamais le soleil de face. C'est ce contraste
        # qui dessine le contour de chaque maison vue d'en haut.
        _rive(m, bord, y_haut, EPAISSEUR_TOIT,
              tuple(c * 0.70 for c in coul_toit), G)
        h = t = 0
        for poly, fait in _toits_croises(morceaux, axe_toit):
            a, b = _toit(m, poly, y_haut + EPAISSEUR_TOIT, pente, fait,
                         coul_toit, G, y_haut)
            h += a
            t += b
        m.sol = None
        return ok, n, h, t

    haut_ok = 0
    tris = trianguler(anneau)
    for ia, ib, ic in tris:
        a, b, c = anneau[ia], anneau[ib], anneau[ic]
        pa = G(a[0], a[1], y_haut)
        pb = G(b[0], b[1], y_haut)
        pc = G(c[0], c[1], y_haut)
        # 🌿 UV2 = (−famille, rang) sur un toit : ≤ 0 n'est pas une façade,
        # donc les fenêtres ne s'y percent pas ; la famille y pose les
        # verrières des halles ; `rang` dit au shader si CE toit-ci verdit en
        # entier. Les versants gardent (0, 0) : ils ne verdissent jamais.
        m.triangle(pa, pb, pc, coul_toit, axe_toit=axe_uv,
                   genre=(-float(famille), rang_vert))
        if normale(pa, pb, pc)[1] > 0.0:
            haut_ok += 1
    # L'acrotère est posé sur TOUS les toits plats : un dessus rasé se lit
    # comme une boîte coupée.
    if abs(aire_signee(anneau)) >= 20.0:
        _acrotere(m, anneau, y_haut, tuple(c * 0.88 for c in coul), G)
    m.sol = None
    return ok, n, haut_ok, len(tris)


def _ruine(m, anneau, coul_mur, coul_gravats, G, rng):
    """Un bâtiment que la crue a emporté : des pans de mur cassés à des
    hauteurs différentes, et le plancher du rez à nu entre eux.

    🔴 LA CRÊTE FAIT LA RUINE, PAS LA COULEUR. Arasés au même plan, cent
    bâtiments sortent en lotissement de toits plats. Chaque arête porte donc sa
    hauteur, tirée par PAQUETS de une à trois arêtes : arête par arête on
    obtient une dentelure régulière, qui se lit comme un motif et non comme une
    casse.

    Aucune couverture, aucun acrotère, aucun percement : le dessus est OUVERT.
    Les murs étant à face unique, ceux du fond sont cullés et on voit le sol
    sombre entre ceux de devant — c'est le seul trou noir de la ville.
    """
    anneau = _decaler(anneau, -RUINE_RETRAIT)
    n = len(anneau)
    y_bas = -ENFOUISSEMENT
    hauteurs = []
    while len(hauteurs) < n:
        h = rng.choice(RUINE_PANS) * ETAGE_M
        hauteurs += [h] * rng.randint(*RUINE_PAN_ARETES)

    def ao(y):
        return AO_MIN + (1.0 - AO_MIN) * min(1.0, max(0.0, (y - y_bas) / AO_HAUTEUR))

    ok = 0
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        y_haut = hauteurs[i]
        pa_b = G(a[0], a[1], y_bas)
        pb_b = G(b[0], b[1], y_bas)
        pa_h = G(a[0], a[1], y_haut)
        pb_h = G(b[0], b[1], y_haut)
        fb, fh = ao(y_bas), ao(y_haut)
        m.triangle(pa_b, pb_b, pb_h, coul_mur, (fb, fb, fh))
        m.triangle(pa_b, pb_h, pa_h, coul_mur, (fb, fh, fh))
        # Le même contrôle de chiralité que `_masse` : on ne parie pas sur le
        # sens des faces après l'inversion de Z, on le mesure.
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        nn = normale(pa_b, pb_b, pb_h)
        if L > 1e-9 and (nn[0] * dy + nn[2] * dx) / L > 0.9:
            ok += 1

    tris = trianguler(anneau)
    f = ao(RUINE_DALLE_Y)
    for ia, ib, ic in tris:
        pa = G(anneau[ia][0], anneau[ia][1], RUINE_DALLE_Y)
        pb = G(anneau[ib][0], anneau[ib][1], RUINE_DALLE_Y)
        pc = G(anneau[ic][0], anneau[ic][1], RUINE_DALLE_Y)
        m.triangle(pa, pb, pc, coul_gravats, (f, f, f))
    return ok, n, len(tris), len(tris)


def _pans(anneau, faitage):
    """Les versants d'une empreinte convexe : (lignes, égouts, pans, dist).
    Un pan = la part de l'empreinte dont l'égout i est le plus proche."""
    ux, uy = faitage
    n = len(anneau)
    sens = 1.0 if aire_signee(anneau) > 0.0 else -1.0
    lignes = []                    # (origine, normale intérieure, égout ?)
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L < 1e-6:
            lignes.append(None)
            continue
        ex, ey = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        lignes.append((a, (-ey * sens, ex * sens),
                       abs(ex * ux + ey * uy) >= COS_EGOUT))
    egouts = [i for i, l in enumerate(lignes) if l and l[2]]
    if not egouts:                 # aucun égout : croupe sur tout le tour
        egouts = [i for i, l in enumerate(lignes) if l]

    def dist(i, p):
        a, (nx, ny), _e = lignes[i]
        return (p[0] - a[0]) * nx + (p[1] - a[1]) * ny

    # Le pan de l'égout i : là où i est l'égout le plus proche. Empreinte
    # convexe ⇒ chaque pan est un polygone convexe, coupé demi-plan par
    # demi-plan. Égalité parfaite (arêtes alignées) : le premier garde le pan.
    pans = {}
    for i in egouts:
        poly = list(anneau)
        for j in egouts:
            if j != i and len(poly) >= 3:
                poly = _couper(poly, lambda p, j=j: dist(j, p) - dist(i, p),
                               -1e-9 if j > i else 1e-9)
        if len(poly) >= 3 and abs(aire_signee(poly)) > 1e-4:
            pans[i] = poly
    return lignes, egouts, pans, dist


def _complexite(emp, faite):
    """Versants de plus de PAN_MIN_M2 que porterait ce toit, plus l'écart
    moyen de ses angles à l'équerre (0 à 1). Rectangle ≈ 2, L ≈ 4. None si
    l'empreinte ne se découpe pas."""
    morceaux = _morceaux_convexes(emp)
    if morceaux is None:
        return None
    pans = sum(1 for poly, f in _toits_croises(morceaux, faite)
               for pan in _pans(poly, f)[2].values()
               if abs(aire_signee(pan)) >= PAN_MIN_M2)
    n = len(emp)
    ecart = 0.0
    for i in range(n):
        a, b, c = emp[i - 1], emp[i], emp[(i + 1) % n]
        u, v = (a[0] - b[0], a[1] - b[1]), (c[0] - b[0], c[1] - b[1])
        ang = math.degrees(math.atan2(abs(u[0] * v[1] - u[1] * v[0]),
                                      u[0] * v[0] + u[1] * v[1]))
        ecart += min(abs(ang - 90.0) if ang < 135.0 else 180.0 - ang, 45.0)
    return pans + ecart / 45.0 / n


def _toit(m, anneau, y_egout, pente, faitage, coul, G, y_mur=None):
    """Un toit pentu sur une empreinte CONVEXE, sans un seul asset.

    Chaque arête de l'égout est un ÉGOUT (elle porte un versant) si elle court
    à moins de ANGLE_EGOUT_DEG du faîtage, un PIGNON (mur vertical) sinon. La
    hauteur d'un point est `pente × distance à l'égout le plus proche` : chaque
    versant est donc un PLAN, quelle que soit la forme. Rectangle → deux pentes
    et deux pignons ; trapèze → faîtage en biais, versants plans ; pan coupé →
    une petite croupe.

    🔄 Remplace (2026-10-07) « chaque sommet relié à sa projection sur une
    droite de faîtage » : hors rectangle, les pans sortaient vrillés et de
    pentes différentes — les toits cassés vus par l'auteur.
    ⚠️ Le faîtage est parallèle à la RUE, pas à l'axe long de l'empreinte.
    """
    ux, uy = faitage
    axe_uv = (ux, -uy)
    n = len(anneau)
    lignes, egouts, pans, dist = _pans(anneau, faitage)
    d_max = max((dist(i, p) for i, poly in pans.items() for p in poly),
                default=0.0)
    s = min(pente, FAITAGE_MAX / d_max) if d_max > 1e-6 else 0.0

    def haut(p):
        return y_egout + s * max(0.0, min(dist(i, p) for i in egouts))

    cx = sum(p[0] for p in anneau) / n
    cy = sum(p[1] for p in anneau) / n
    coeur = G(cx, cy, y_egout + s * d_max / 2.0)

    ok = tot = 0
    for i, poly in pans.items():
        pts = [G(p[0], p[1], y_egout + s * max(0.0, dist(i, p))) for p in poly]
        for k in range(1, len(pts) - 1):
            tri = (pts[0], pts[k], pts[k + 1])
            if _degenere(tri):
                continue
            if normale(*tri)[1] < 0.0:
                tri = (tri[0], tri[2], tri[1])
                retournes[0] += 1
            m.triangle(tri[0], tri[1], tri[2], coul, axe_toit=axe_uv)
            tot += 1
            ok += 1

    # Les pignons : un mur vertical sous le profil du toit, pris aux points où
    # l'égout le plus proche change le long de l'arête.
    for k, l in enumerate(lignes):
        if l is None or k in pans or k in egouts:
            continue
        a, b = anneau[k], anneau[(k + 1) % n]
        ts = {0.0, 1.0}
        for x in range(len(egouts)):
            for y in range(x + 1, len(egouts)):
                fa = dist(egouts[x], a) - dist(egouts[y], a)
                fb = dist(egouts[x], b) - dist(egouts[y], b)
                if (fa > 0.0) != (fb > 0.0) and abs(fa - fb) > 1e-12:
                    ts.add(fa / (fa - fb))
        profil = []
        for t in sorted(ts, reverse=True):
            p = (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]))
            profil.append(G(p[0], p[1], haut(p)))
        bas_a, bas_b = G(a[0], a[1], y_egout), G(b[0], b[1], y_egout)
        contour = [bas_a, bas_b] + profil
        for j in range(1, len(contour) - 1):
            tri = (contour[0], contour[j], contour[j + 1])
            if _degenere(tri):
                continue
            if not _vers_dehors(tri, coeur):
                tri = (tri[0], tri[2], tri[1])
            m.triangle(tri[0], tri[1], tri[2], coul, axe_toit=axe_uv)
            tot += 1
            ok += 1

    # 🔥 LA SOUCHE, sur la ligne médiane de l'empreinte. Position et existence
    # tirées du LIEU (35) : mêmes cheminées aux mêmes endroits.
    if y_mur is not None and abs(aire_signee(anneau)) >= CHEMINEE_AIRE_MIN:
        r = random.Random(_graine_lieu(anneau) ^ 0xC17E)
        if r.random() <= PART_CHEMINEES:
            vx, vy = -uy, ux
            vs = [(p[0] - cx) * vx + (p[1] - cy) * vy for p in anneau]
            mv = (max(vs) + min(vs)) / 2.0
            ox, oy = cx + vx * mv, cy + vy * mv
            ts = [(p[0] - ox) * ux + (p[1] - oy) * uy for p in anneau]
            t = min(ts) + r.uniform(0.22, 0.78) * (max(ts) - min(ts))
            x, y = ox + ux * t, oy + uy * t
            if min(dist(i, (x, y)) for i, l in enumerate(lignes) if l) > 0.5:
                cheminees[0] += 1
                _cheminee(m, x, y, y_mur, haut((x, y)) + CHEMINEE_HAUT,
                          (ux, uy), COUL_CHEMINEE, G)
    return ok, tot


def _couper(poly, f, seuil):
    """Sutherland–Hodgman : la part de `poly` où f(p) ≥ seuil, f affine."""
    out = []
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        fa, fb = f(a) - seuil, f(b) - seuil
        if fa >= 0.0:
            out.append(a)
        if (fa >= 0.0) != (fb >= 0.0):
            t = fa / (fa - fb)
            out.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])))
    return out


def _morceaux_convexes(anneau, prof=0):
    """L'empreinte en morceaux convexes, ou None si elle ne se découpe pas.

    On coupe depuis un sommet RENTRANT, dans le prolongement d'une de ses deux
    arêtes, jusqu'au bord d'en face : un L donne deux rectangles. Des coupes
    possibles, on garde celle dont le morceau le plus mince est le plus épais.
    Mesuré le 2026-10-07 : 134 empreintes à un sommet rentrant, 17 à deux.
    """
    if _convexe(anneau):
        return [list(anneau)]
    n = len(anneau)
    if prof > 3 or n < 4:
        return None
    sens = 1.0 if aire_signee(anneau) > 0.0 else -1.0
    meilleur = None
    for i in range(n):
        p, r, q = anneau[i - 1], anneau[i], anneau[(i + 1) % n]
        cr = (r[0] - p[0]) * (q[1] - r[1]) - (r[1] - p[1]) * (q[0] - r[0])
        if cr * sens >= -1e-6:
            continue
        for o in (p, q):
            L = math.hypot(r[0] - o[0], r[1] - o[1])
            if L < 1e-6:
                continue
            coupe = _rayon(anneau, i, (r[0] - o[0]) / L, (r[1] - o[1]) / L)
            if coupe is None:
                continue
            j, h = coupe
            m1 = [r] + [anneau[(i + 1 + k) % n]
                        for k in range((j - i) % n)] + [h]
            m2 = [h] + [anneau[(j + 1 + k) % n]
                        for k in range((i - j - 1) % n)] + [r]
            m1, m2 = _sans_doublons(m1), _sans_doublons(m2)
            if len(m1) < 3 or len(m2) < 3:
                continue
            note = (_convexe(m1) + _convexe(m2),
                    min(_epaisseur(m1), _epaisseur(m2)))
            if meilleur is None or note > meilleur[0]:
                meilleur = (note, m1, m2)
    if meilleur is None:
        return None
    a = _morceaux_convexes(meilleur[1], prof + 1)
    b = _morceaux_convexes(meilleur[2], prof + 1)
    return a + b if a and b else None


def _rayon(anneau, i, dx, dy):
    """Premier bord touché par le rayon parti du sommet i : (arête, point)."""
    n = len(anneau)
    r = anneau[i]
    best = None
    for j in range(n):
        if j == i or j == (i - 1) % n:
            continue
        a, b = anneau[j], anneau[(j + 1) % n]
        ex, ey = b[0] - a[0], b[1] - a[1]
        den = dx * ey - dy * ex
        if abs(den) < 1e-12:
            continue
        wx, wy = a[0] - r[0], a[1] - r[1]
        t = (wx * ey - wy * ex) / den
        u = (wx * dy - wy * dx) / den
        if t > 1e-6 and -1e-9 <= u <= 1.0 + 1e-9 \
                and (best is None or t < best[0]):
            best = (t, j, (r[0] + t * dx, r[1] + t * dy))
    return None if best is None else (best[1], best[2])


def _sans_doublons(poly):
    out = []
    for p in poly:
        if not out or math.hypot(p[0] - out[-1][0], p[1] - out[-1][1]) > 1e-4:
            out.append(p)
    if len(out) > 1 and math.hypot(out[0][0] - out[-1][0],
                                   out[0][1] - out[-1][1]) <= 1e-4:
        out.pop()
    return out


def _epaisseur(poly):
    """La plus petite largeur d'un polygone, mesurée arête par arête."""
    n = len(poly)
    best = float("inf")
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L < 1e-6:
            continue
        nx, ny = -(b[1] - a[1]) / L, (b[0] - a[0]) / L
        best = min(best, max(abs((p[0] - a[0]) * nx + (p[1] - a[1]) * ny)
                             for p in poly))
    return best


def _toits_croises(morceaux, faitage):
    """[(polygone, faîtage)] : un toit par morceau, qui se croisent au joint.

    Un morceau prend le faîtage de la rue, ou sa perpendiculaire s'il est
    nettement plus long dans l'autre sens (une aile de L). Quand la coupe est
    un BOUT de ce morceau (pignon), il est prolongé dans son voisin jusqu'à
    mi-profondeur : son pignon finit sous le toit voisin, et la noue se fait
    toute seule à l'intersection des deux toits.
    """
    if len(morceaux) == 1:
        return [(morceaux[0], faitage)]
    ux, uy = faitage
    faites = []
    for poly in morceaux:
        su = [p[0] * ux + p[1] * uy for p in poly]
        sv = [-p[0] * uy + p[1] * ux for p in poly]
        long_u, long_v = max(su) - min(su), max(sv) - min(sv)
        faites.append((ux, uy) if long_u >= 0.8 * long_v else (-uy, ux))

    def voisin(k, a, b):
        mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
        for j, autre in enumerate(morceaux):
            if j == k:
                continue
            for i in range(len(autre)):
                c, d = autre[i], autre[(i + 1) % len(autre)]
                if D4C.dist_pt_seg((mx, my), c, d) < 1e-3:
                    return j
        return None

    out = []
    for k, poly in enumerate(morceaux):
        fx, fy = faites[k]
        i = 0
        while i < len(poly):
            a, b = poly[i], poly[(i + 1) % len(poly)]
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            j = voisin(k, a, b) if L > 1e-6 else None
            if j is None or \
                    abs((b[0] - a[0]) * fx + (b[1] - a[1]) * fy) / L >= COS_EGOUT:
                i += 1
                continue
            plus = _prolonger(poly, i, morceaux[j])
            if plus is None:
                i += 1
                continue
            poly = plus
            i += 3
        out.append((poly, faites[k]))
    return out


def _prolonger(poly, i, voisin):
    """`poly` prolongé au-delà de son arête i, dans `voisin`, jusqu'à
    mi-profondeur de celui-ci. None si le prolongement sort du voisin."""
    n = len(poly)
    a, b = poly[i], poly[(i + 1) % n]
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    sens = 1.0 if aire_signee(poly) > 0.0 else -1.0
    ox, oy = (b[1] - a[1]) / L * sens, -(b[0] - a[0]) / L * sens  # vers dehors
    w = max((p[0] - a[0]) * ox + (p[1] - a[1]) * oy for p in voisin) / 2.0

    def direction(c, d):
        l = math.hypot(c[0] - d[0], c[1] - d[1])
        u = ((c[0] - d[0]) / l, (c[1] - d[1]) / l) if l > 1e-6 else (ox, oy)
        return u if u[0] * ox + u[1] * oy > 0.3 else (ox, oy)

    da = direction(a, poly[i - 1])
    db = direction(b, poly[(i + 2) % n])
    ka = 1.0 / (da[0] * ox + da[1] * oy)
    kb = 1.0 / (db[0] * ox + db[1] * oy)
    for _essai in range(4):
        a2 = (a[0] + da[0] * w * ka, a[1] + da[1] * w * ka)
        b2 = (b[0] + db[0] * w * kb, b[1] + db[1] * w * kb)
        neuf = poly[:i + 1] + [a2, b2] + poly[i + 1:]
        if _dans_convexe(voisin, a2) and _dans_convexe(voisin, b2) \
                and _convexe(neuf):
            return neuf
        w /= 2.0
    return None


def _dans_convexe(poly, q, tol=0.05):
    sens = 1.0 if aire_signee(poly) > 0.0 else -1.0
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L < 1e-9:
            continue
        cr = ((b[0] - a[0]) * (q[1] - a[1])
              - (b[1] - a[1]) * (q[0] - a[0])) / L
        if cr * sens < -tol:
            return False
    return True


def _vers_dehors(tri, coeur):
    nn = normale(tri[0], tri[1], tri[2])
    gx = (tri[0][0] + tri[1][0] + tri[2][0]) / 3.0 - coeur[0]
    gy = (tri[0][1] + tri[1][1] + tri[2][1]) / 3.0 - coeur[1]
    gz = (tri[0][2] + tri[1][2] + tri[2][2]) / 3.0 - coeur[2]
    return nn[0] * gx + nn[1] * gy + nn[2] * gz > 0.0


def _decouper_quad(pa, pb, qb, qa, coeur):
    """Un pan de toit en triangles, sans jamais en retourner un.

    🔴 Le cas qui a coûté la soirée : un pignon dont l'arête n'est pas
    EXACTEMENT perpendiculaire au faîtage donne un quadrilatère VRILLÉ — ses
    quatre sommets ne sont pas dans un plan. Coupé en diagonale, une de ses
    deux moitiés bascule vers le bas et disparaît au culling. Mesuré : 992
    triangles sur 7 500, et les rectangles n'étaient gauchis que de treize
    centimètres.

    La sortie : on coupe la diagonale seulement si les deux moitiés tiennent.
    Sinon on éclate le quadrilatère en quatre triangles autour de son centre —
    plus cher d'un triangle, mais un éventail autour d'un point ne peut pas se
    retourner tout seul."""
    diag = [t for t in ((pa, pb, qb), (pa, qb, qa)) if not _degenere(t)]
    # Deux moitiés qui ne regardent pas du même côté = le quadrilatère est
    # VRILLÉ, ses quatre sommets ne sont pas dans un plan. La diagonale
    # trancherait alors dans le pli ; l'éventail autour du centre, non.
    if len(diag) == 2 and _vers_dehors(diag[0], coeur) == _vers_dehors(diag[1], coeur):
        return diag
    c = tuple(sum(p[k] for p in (pa, pb, qb, qa)) / 4.0 for k in range(3))
    return [t for t in ((pa, pb, c), (pb, qb, c), (qb, qa, c), (qa, pa, c))
            if not _degenere(t)]


def _debordement(emprise, parcelle):
    """De combien le bâtiment sort-il de la parcelle qui le porte ?

    🔴 LE DÉFAUT CONNU DU 2026-08-12, et il faut le voir plutôt que le
    deviner. `retracter` décale chaque arête vers l'intérieur ; sur un angle
    RENTRANT les deux droites décalées divergent, la limite de mitre remplace
    le pic par un biseau, et ce biseau peut ressortir du côté de la rue. Le
    dépassement est borné par le recul du tissu — 5 m en pavillonnaire, 6 m
    sur la barre — donc sans commune mesure avec les 258 m de la session 9,
    mais un bâtiment qui mord sur la chaussée reste un bâtiment qui ment.

    Depuis que 07 lit `batiments`, l'association à la parcelle d'origine est
    explicite. L'anneau doit être fermé pour `dedans` : l'ancien contrôle
    oubliait sa dernière arête et annonçait encore 38 faux débordements."""
    parcelles = [parcelle]
    parcelle_fermee = dict(parcelle)
    parcelle_fermee["anneau"] = list(parcelle["anneau"]) + [parcelle["anneau"][0]]
    pire = 0.0
    for q in emprise:
        d = min((min(D4C.dist_pt_seg(q, p["anneau"][i],
                                     p["anneau"][(i + 1) % len(p["anneau"])])
                     for i in range(len(p["anneau"]))))
                for p in parcelles) if parcelles else 0.0
        if d > pire and not dedans(parcelle_fermee["anneau"], q):
            pire = d
    return pire


def _sur_rue(parcelle, idx_bord):
    """Pour chaque arête de la parcelle : donne-t-elle sur la rue ?

    Une parcelle est un morceau de l'emprise ; ses arêtes sont donc soit sur
    le bord de l'emprise (la rue), soit issues d'une coupe et partagées avec
    une voisine. Ce test décide lesquelles reculent et lesquelles restent
    collées — c'est lui qui produit le mitoyen."""
    out = []
    n = len(parcelle)
    for i in range(n):
        a, b = parcelle[i], parcelle[(i + 1) % n]
        mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
        cx, cy = int(mx // 1.0), int(my // 1.0)
        rue = False
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for (p, q) in idx_bord.get((cx + dx, cy + dy), ()):
                    if D4C.dist_pt_seg((mx, my), p, q) <= TOL_RUE:
                        rue = True
                        break
                if rue:
                    break
            if rue:
                break
        out.append(rue)
    return out


def _direction_faitage(parcelle, idx_bord):
    """La plus longue façade sur rue, même règle R2 que 04d.

    04d produit l'empreinte ; 07 ne choisit plus sa forme. Cette direction ne
    sert qu'à plier son toit, parallèlement à la rue qui l'adresse. Les boîtes
    ont un toit plat, donc leur direction de plan-masse n'entre pas ici.
    """
    rues = _sur_rue(parcelle, idx_bord)
    meilleur = None
    longueur = 0.0
    for i, rue in enumerate(rues):
        if not rue:
            continue
        a, b = parcelle[i], parcelle[(i + 1) % len(parcelle)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L > longueur:
            longueur = L
            meilleur = (dx / L, dy / L)
    return meilleur


def _ecorner(anneau):
    """Couper les pointes : `\\_/` au lieu de `\\/`.

    Un sommet CONVEXE dont l'angle intérieur passe sous ANGLE_MIN_DEG est
    remplacé par deux sommets et une petite arête franche. Ces pointes ne
    viennent pas du parcellaire mais du rétrécissement : sur un angle rentrant
    de l'emprise, deux arêtes décalées se rejoignent très loin et fabriquent
    une lame de couteau — un mur de trois centimètres vu de face.

    Ce que ça ne casse pas : chanfreiner un sommet convexe laisse une
    empreinte convexe convexe, donc les toits à deux pentes ne se perdent pas
    en route. Et un sommet concave n'est jamais touché."""
    n = len(anneau)
    if n < 3:
        return anneau
    cos_seuil = math.cos(math.radians(ANGLE_MIN_DEG))
    out = []
    coupes = 0
    for i in range(n):
        p0 = anneau[(i - 1) % n]
        p = anneau[i]
        p1 = anneau[(i + 1) % n]
        ax, ay = p0[0] - p[0], p0[1] - p[1]
        bx, by = p1[0] - p[0], p1[1] - p[1]
        la = math.hypot(ax, ay)
        lb = math.hypot(bx, by)
        if la < 1e-9 or lb < 1e-9:
            out.append(p)
            continue
        # Anneau trigonométrique : le sommet est CONVEXE quand le produit
        # vectoriel des deux arêtes est positif.
        cr = ((p[0] - p0[0]) * (p1[1] - p[1])
              - (p[1] - p0[1]) * (p1[0] - p[0]))
        cosang = (ax * bx + ay * by) / (la * lb)   # cos de l'angle intérieur
        if cr <= 0.0 or cosang < cos_seuil:
            out.append(p)
            continue
        # Le pan coupé mesure 2·d·sin(θ/2) : on inverse pour viser PAN_COUPE_M.
        demi = math.acos(max(-1.0, min(1.0, cosang))) / 2.0
        vise = PAN_COUPE_M / (2.0 * max(math.sin(demi), 1e-3))
        d = min(vise, PART_COTE_MAX * la, PART_COTE_MAX * lb)
        if d < 0.15:
            out.append(p)
            continue
        out.append((p[0] + ax / la * d, p[1] + ay / la * d))
        out.append((p[0] + bx / lb * d, p[1] + by / lb * d))
        coupes += 1
    if not coupes:
        return anneau
    net = D4C.nettoyer(out)
    if len(net) < 3 or abs(D4C.aire_signee(net)) < 6.0:
        return anneau                 # la coupe mangeait tout : on renonce
    pointes[0] += coupes
    pointes[1] += 1
    return net


def _largeur_min(anneau):
    """La plus petite largeur de l'empreinte : la distance entre les deux
    droites parallèles les plus serrées qui l'enferment.

    Un bâtiment n'est pas jugé sur son aire — un coin de 40 m de long et 2 m de
    large en fait 40, ce qui passe tous les seuils d'aire, et se voit comme une
    lame posée à plat. C'est la LARGEUR qui dit si on croirait y habiter."""
    n = len(anneau)
    best = None
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < 1e-9:
            continue
        nx, ny = -dy / L, dx / L
        ds = [(p[0] - a[0]) * nx + (p[1] - a[1]) * ny for p in anneau]
        w = max(ds) - min(ds)
        if best is None or w < best:
            best = w
    return best if best is not None else 0.0


def _garder(volumes, parcelle):
    """Le filtre des lames. Ce qui ne survit pas rend sa parcelle au jardin —
    un cœur d'îlot un peu plus grand vaut mieux qu'un bâtiment qui ment."""
    out = []
    for emp, faite in volumes:
        if len(emp) >= 3 and _largeur_min(emp) >= LARGEUR_MIN_BATI:
            out.append((emp, faite))
        else:
            minces[0] += 1
    if not out:
        return [], [D4C.ouvrir(parcelle)]
    return out, None


def _rectangle(emp, u, w, w_max):
    """L'empreinte ramenée à une BOÎTE alignée sur la rue.

    Une barre de 1974, un hangar, une halle : ce sont des rectangles, et les
    faire suivre le découpage parcellaire leur donne des biais qu'ils n'ont
    jamais eus.

    🔴 LE PIÈGE, mesuré et corrigé le 2026-08-12 : prendre le RECTANGLE
    ENGLOBANT de l'empreinte est immédiat à écrire et faux. Une parcelle en L
    ou en biais a un englobant qui déborde très loin d'elle — 44,5 m mesurés,
    contre 4,8 m de débordement maximal avant. On cherche donc le plus grand
    rectangle qui TIENT DEDANS : on rastérise l'empreinte par balayage de
    lignes, puis on prend le plus grand rectangle de cellules pleines. C'est
    l'emprise au sol, pas une taille inventée, et ça ne peut pas sortir de la
    parcelle."""
    ux, uy = u
    wx, wy = w
    pts = [(p[0] * ux + p[1] * uy, p[0] * wx + p[1] * wy) for p in emp]
    u0 = min(p[0] for p in pts)
    u1 = max(p[0] for p in pts)
    v0 = min(p[1] for p in pts)
    v1 = min(max(p[1] for p in pts), w_max)
    if u1 - u0 < 2.0 or v1 - v0 < 2.0:
        return None

    pas = max(0.5, min(u1 - u0, v1 - v0) / 60.0)
    nu = max(1, int((u1 - u0) / pas))
    nv = max(1, int((v1 - v0) / pas))
    du = (u1 - u0) / nu
    dv = (v1 - v0) / nv

    # Rastérisation par balayage : pour chaque ligne, les abscisses où le bord
    # est traversé, deux à deux, donnent les segments pleins.
    n = len(pts)
    grille = []
    for j in range(nv):
        yc = v0 + (j + 0.5) * dv
        xs = []
        for i in range(n):
            a, b = pts[i], pts[(i + 1) % n]
            if (a[1] <= yc) != (b[1] <= yc):
                t = (yc - a[1]) / (b[1] - a[1])
                xs.append(a[0] + t * (b[0] - a[0]))
        xs.sort()
        ligne = [False] * nu
        for k in range(0, len(xs) - 1, 2):
            ka = max(0, int(math.ceil((xs[k] - u0) / du - 0.5)))
            kb = min(nu - 1, int(math.floor((xs[k + 1] - u0) / du - 0.5)))
            for c in range(ka, kb + 1):
                ligne[c] = True
        grille.append(ligne)

    # Le plus grand rectangle de cellules pleines — méthode de l'histogramme,
    # une pile par ligne.
    haut = [0] * nu
    best = (0, 0, -1, 0, -1)          # cellules, i0, i1, j0, j1
    for j in range(nv):
        for i in range(nu):
            haut[i] = haut[i] + 1 if grille[j][i] else 0
        pile = []
        for i in range(nu + 1):
            h = haut[i] if i < nu else 0
            debut = i
            while pile and pile[-1][1] >= h:
                d0, h0 = pile.pop()
                if h0 * (i - d0) > best[0]:
                    best = (h0 * (i - d0), d0, i - 1, j - h0 + 1, j)
                debut = d0
            pile.append((debut, h))
    if best[0] <= 0:
        return None

    a0 = u0 + best[1] * du
    a1 = u0 + (best[2] + 1) * du
    b0 = v0 + best[3] * dv
    b1 = v0 + (best[4] + 1) * dv
    if a1 - a0 < 2.0 or b1 - b0 < 2.0:
        return None

    def pt(a, b):
        return (a * ux + b * wx, a * uy + b * wy)

    rect = D4C.ouvrir([pt(a0, b0), pt(a1, b0), pt(a1, b1), pt(a0, b1)])
    rectangles[0] += 1
    return rect


def _empreinte_batie(parcelle, st, idx_bord):
    """La parcelle devient une empreinte de bâtiment ET un fond de parcelle.

    Trois gestes, dans cet ordre, et chacun répond à un des trois nombres de
    `BATI` : on recule de la rue, on s'écarte (ou pas) de la voisine, puis on
    coupe ce qui dépasse en profondeur.

    Renvoie DEUX listes : les volumes, et ce qui reste derrière eux — la cour
    ou le jardin. C'est ce deuxième retour qui est neuf : le fond de parcelle
    était calculé puis jeté, donc les cœurs d'îlot étaient du terrain nu. Une
    parcelle enclavée, sans aucune arête sur rue, n'est pas bâtie du tout : elle
    part entière au jardin."""
    recul, jeu, prof, _pente = BATI.get(st, BATI_DEFAUT)
    rues = _sur_rue(parcelle, idx_bord)
    if not any(rues):
        # enclavée : cour ou jardin, pas de maison. Elle était déjà creusée,
        # elle est maintenant DESSINÉE.
        return [], [D4C.ouvrir(parcelle)]

    retraits = [recul if r else jeu for r in rues]
    emp = D4B.retracter(parcelle, retraits)
    # `reparer` retire les boucles que tout offset à distance variable finit
    # par fabriquer sur un angle rentrant. Il renvoie (anneau, réparations,
    # plafond) — seul le premier nous intéresse ici.
    emp = D4B.reparer(emp)[0] if len(emp) >= 3 else []
    if len(emp) < 3 or abs(D4C.aire_signee(emp)) < 6.0:
        return [], [D4C.ouvrir(parcelle)]
    emp = D4C.ouvrir(emp)
    emp = D4C.nettoyer(emp)
    if len(emp) < 3:
        return [], [D4C.ouvrir(parcelle)]

    # La coupe en profondeur, depuis la plus longue arête sur rue. Sans elle,
    # deux rangées dos à dos donnent un bloc plein de 32 m et le cœur d'îlot
    # n'existe pas.
    n = len(parcelle)
    meilleur, best_L = None, 0.0
    for i in range(n):
        if not rues[i]:
            continue
        a, b = parcelle[i], parcelle[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L > best_L:
            best_L, meilleur = L, (a, b)
    if meilleur is None:
        v, j = _garder([(_ecorner(emp), None)], parcelle)
        return v, (j if j is not None else [])
    a, b = meilleur
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    if L < 1e-9:
        v, j = _garder([(_ecorner(emp), None)], parcelle)
        return v, (j if j is not None else [])
    rue_dir = (dx / L, dy / L)         # la direction du faîtage
    # Anneau trigonométrique : l'intérieur est à GAUCHE du parcours, donc la
    # normale rentrante vaut (−dy, dx). On garde le côté rue, c'est-à-dire le
    # côté négatif de cette normale.
    nx, ny = -dy / L, dx / L
    # `recul + prof` et pas `prof` : la façade est déjà en retrait de `recul`,
    # donc c'est de là qu'il faut compter la profondeur du bâtiment.
    fond = recul + prof
    p0 = (a[0] + nx * fond, a[1] + ny * fond)

    # Ce qui est DERRIÈRE la ligne de profondeur, découpé dans la parcelle
    # elle-même et non dans l'emprise rétrécie : les bandes latérales du jeu au
    # voisin y restent, et la partition (61) tient toujours — deux jardins
    # voisins partagent l'arête exacte de leur coupe commune.
    jardins = []
    for m in D4C.couper(parcelle, p0, (nx, ny)):
        if len(m) < 3:
            continue
        cx = sum(p[0] for p in m) / len(m)
        cy = sum(p[1] for p in m) / len(m)
        if (cx - p0[0]) * nx + (cy - p0[1]) * ny > 0.01 \
                and abs(D4C.aire_signee(m)) > AIRE_JARDIN_MIN:
            jardins.append(D4C.ouvrir(m))

    # Les boîtes : barre, hangar, halle. Elles sautent la coupe polygonale et
    # l'écornage — un rectangle n'a pas de pointe.
    if st in RECTANGULAIRE:
        rect = _rectangle(emp, rue_dir, (nx, ny),
                          (p0[0] * nx + p0[1] * ny))
        if rect is not None:
            v, j = _garder([(rect, rue_dir)], parcelle)
            return v, (j if j is not None else jardins)

    morceaux = D4C.couper(emp, p0, (-nx, -ny))
    garde = []
    for m in morceaux:
        if len(m) < 3:
            continue
        cx = sum(p[0] for p in m) / len(m)
        cy = sum(p[1] for p in m) / len(m)
        if (cx - p0[0]) * (-nx) + (cy - p0[1]) * (-ny) > -0.01 \
                and abs(D4C.aire_signee(m)) > 6.0:
            garde.append((_ecorner(D4C.ouvrir(m)), rue_dir))
    if not garde:
        garde = [(_ecorner(emp), rue_dir)]
    v, j = _garder(garde, parcelle)
    return v, (j if j is not None else jardins)
