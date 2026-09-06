# -*- coding: utf-8 -*-
"""Chenal, quais, franchissements et rives transformées."""


import math
from apercu_carte import dedans
from importlib import import_module
from .ponts import _pont_neuf, _pont_ruine
from .geometrie import (
    _axe_ruban,
    _bande3d,
    _boite,
    _cle,
    _cumul,
    _densifier,
    _onglets,
    _parapet,
    _ruban,
    _tronquer,
    _unite,
)
from .reglages import (
    BANDE_QUAI,
    BERGE_BANDE_M,
    BERGE_ENFOUIE,
    BERGE_LISSE_M,
    BERGE_LISSE_PENTE,
    BERGE_MIN_M,
    BERGE_Y,
    FOND_ILSE,
    NAPPE_ILSE,
    PARAPET_EP,
    PARAPET_H,
    PENTE_OMBRE,
    PENTE_OND,
    PENTE_RIVE_M,
    PILE_COTE,
    PILE_RETRAIT,
    PONT_COUPE_MARGE,
    PONT_CULEE,
    PONT_MIN,
    QUAI_DEBORD_MAX,
    QUAI_LONGE_SIN,
    QUAI_PAS,
    QUAI_PENTE,
    QUAI_PORTEE,
    QUAI_SONDE,
    RIVE_GAUCHE_Y,
    SEMIS_BUISSON,
    SEMIS_BUISSON_LARGE,
    SEMIS_BUISSON_PAS,
    SEMIS_ROSEAU,
    SEMIS_ROSEAU_PAS,
    TABLIER_TRAVEE,
    Y_CHAUSSEE,
    Y_QUAI,
    Y_SOL,
    Y_TABLIER,
    Y_TROTTOIR,
)
from .voirie import (
    _axe_arrondi,
    _combler,
    _etendre,
    _longueur,
    _plages,
    _stations_eau,
    _dessus_trottoir,
)

D4 = import_module("04_deriver_attributs")
D4C = import_module("04c_parcelles")


def _arrondir_rives(ilots):
    """Arrondi d'affichage partagé par l'eau, le sol et le quai ; source intacte."""
    rivieres = [d for d in ilots.values() if d["sous_type"] == "riviere"]
    champs = {_cle(p) for d in ilots.values() if d["sous_type"] == "champ"
              for p in d["brut"]}
    compte = {}
    def cle(a, b):
        return tuple(sorted((_cle(a), _cle(b))))
    for d in rivieres:
        an = d["brut"]
        for a, b in zip(an, an[1:] + an[:1]):
            c = cle(a, b)
            compte[c] = compte.get(c, 0) + 1
    for d in rivieres:
        an, lisse = d["brut"], []
        for i, p in enumerate(an):
            a, b = an[i - 1], an[(i + 1) % len(an)]
            # Les limites entre biefs restent identiques dans les deux polygones.
            if _cle(p) in champs or compte[cle(a, p)] != 1 or compte[cle(p, b)] != 1:
                lisse.append(p)
                continue
            u, v = _unite(a, p), _unite(p, b)
            if u is None or v is None or u[0] * v[0] + u[1] * v[1] > .999:
                lisse.append(p)
                continue
            recul = min(4.0, math.dist(a, p) * .25, math.dist(p, b) * .25)
            debut = (p[0] - u[0] * recul, p[1] - u[1] * recul)
            fin = (p[0] + v[0] * recul, p[1] + v[1] * recul)
            for k in range(7):
                t = k / 6.0
                lisse.append(tuple((1 - t) ** 2 * debut[j]
                                   + 2 * t * (1 - t) * p[j] + t * t * fin[j]
                                   for j in (0, 1)))
        d["brut"] = lisse


def _axe_ampute(axe, chenal, marge=PONT_COUPE_MARGE):
    """L'axe d'un pont EMPORTÉ (04e) : ce qu'il en reste de part et d'autre.

    On retire le trajet au-dessus de l'eau, plus `marge` de chaque côté, et on
    rend les morceaux. Un axe amputé n'a plus ses deux bords mouillés en même
    temps, donc `_plages_pont` n'y voit plus d'ouvrage : ni tablier, ni parapet,
    ni pile ne sortent — le vide est celui du tablier, pas seulement de
    l'asphalte. C'est ce qui économise toute chirurgie dans `_bord_eau`.

    ⚠️ Rend une liste, pas un axe : appelé partout où l'axe entier l'était,
    donc TOUJOURS dans une boucle. Un morceau de moins de deux points est jeté.
    """
    dense = _densifier(list(axe), 1.0)
    mouille = [chenal.dans_eau(p) for p in dense]
    if not any(mouille):
        return [list(axe)]
    cum = _cumul(dense)
    s0 = min(cum[k] for k in range(len(dense)) if mouille[k]) - marge
    s1 = max(cum[k] for k in range(len(dense)) if mouille[k]) + marge
    out = []
    for a, b in ((0.0, s0), (s1, cum[-1])):
        if b - a < 1.0:
            continue
        bout = _tronquer(dense, cum, max(0.0, a), min(cum[-1], b))
        if len(bout) >= 2:
            out.append(bout)
    return out


def _axe_manque(axe, chenal, marge=PONT_COUPE_MARGE):
    """Le morceau que `_axe_ampute` a retiré — donc exactement ce qu'il faudra
    rebâtir. Les deux lisent la MÊME marge : sinon le tablier neuf ne
    retomberait pas sur les deux bouts de chaussée qui l'attendent."""
    dense = _densifier(list(axe), 1.0)
    mouille = [chenal.dans_eau(p) for p in dense]
    if not any(mouille):
        return []
    cum = _cumul(dense)
    s0 = min(cum[k] for k in range(len(dense)) if mouille[k]) - marge
    s1 = max(cum[k] for k in range(len(dense)) if mouille[k]) + marge
    bout = _tronquer(dense, cum, max(0.0, s0), min(cum[-1], s1))
    return bout if len(bout) >= 2 else []


def _plages_pont(net, st):
    """Les plages [a, b, i0, i1] où la chaussée TRAVERSE vraiment : les deux
    bords au-dessus de l'eau, sur au moins `PONT_MIN`, étendues des culées.

    🔴 SORTIE DE `_bord_eau` LE 2026-08-19, et ce n'est pas du rangement : le
    quai a besoin de savoir où sont les tabliers AVANT que la boucle des routes
    ne commence à émettre, pour ne pas bâtir un muret sous un pont. Deux copies
    de cette décision auraient dérivé dès le premier réglage."""
    pont = _combler([c["cotes"][1]["mouille"] and c["cotes"][-1]["mouille"]
                     for c in st])
    plages = []
    for i0, i1 in _plages(pont):
        if _longueur(net, i0, i1) < PONT_MIN:
            continue                    # une amorce de rue, pas un ouvrage
        a, b = _etendre(net, i0, i1, PONT_CULEE)
        plages.append((a, b, i0, i1))
    return plages


def _tabliers(axe, ch, chenal, relief):
    """Les emprises des tabliers de cette part de tronçon, sans rien émettre.

    Mêmes polygones que ceux que `_bord_eau` rangera dans `plateformes` — c'est
    la même recette lue deux fois, pas deux recettes."""
    h = ch / 2.0
    net = _densifier(_axe_ruban(axe, h, True), QUAI_PAS)
    if len(net) < 2:
        return []
    dec = _onglets(net)
    st = _stations_eau(net, dec, h, chenal, relief)
    out = []
    for a, b, _i0, _i1 in _plages_pont(net, st):
        cotes = {}
        for cote in (1, -1):
            cotes[cote] = [(net[k][0] + dec[k][0] * cote * (h + BANDE_QUAI),
                            net[k][1] + dec[k][1] * cote * (h + BANDE_QUAI))
                           for k in range(a, b + 1)]
        out.append(list(cotes[1]) + list(reversed(cotes[-1])) + [cotes[1][0]])
    return out


def _chaines_berge(chenal):
    """Les arêtes de berge recousues en polylignes continues, dans le sens de
    l'anneau d'îlot dont elles sortent — donc **l'eau est toujours à gauche**.

    C'est la seule chose que `Chenal` ne savait pas faire : il donne un SAC
    d'arêtes, indexé pour la recherche par boîte, et un sac ne se longe pas.
    Sans ce recousage, un mur de quai ne peut être que le décalé d'autre chose
    — et c'est exactement le défaut qu'on répare.

    ⚠️ LE SENS EST HÉRITÉ, PAS DEVINÉ. `_chenal_eau` prouve déjà que la normale
    à gauche du parcours regarde l'eau (contrôle « murs de quai, tous tournés
    vers l'eau »). On ne le recalcule donc pas ici : on garde l'ordre des
    arêtes tel que l'anneau les a produites."""
    par_debut = {}
    for k, (a, _b) in enumerate(chenal.berges):
        par_debut.setdefault(_cle(a), []).append(k)
    # Un sommet où AUCUNE arête n'arrive est un vrai début de chaîne : la rive
    # y bute sur le bord de la carte, ou sur une arête interne à l'eau qui a
    # été écartée. Les prendre d'abord évite de couper une rive en deux au
    # milieu, ce qui remettrait un bout franc là où il n'y a rien.
    fins = {_cle(b) for (_a, b) in chenal.berges}
    depart = [k for k, (a, _b) in enumerate(chenal.berges)
              if _cle(a) not in fins]
    libre = set(range(len(chenal.berges)))
    chaines = []
    for k0 in depart + list(range(len(chenal.berges))):
        if k0 not in libre:
            continue
        libre.discard(k0)
        a, b = chenal.berges[k0]
        chaine = [a, b]
        while True:
            suite = [k for k in par_debut.get(_cle(chaine[-1]), ())
                     if k in libre]
            if not suite:
                break
            libre.discard(suite[0])
            chaine.append(chenal.berges[suite[0]][1])
        chaines.append(chaine)
    return chaines


class GrilleChaussee(object):
    """Les segments de chaussée rangés en cases de 8 m, pour répondre vite à
    « y a-t-il de l'asphalte ici, et à quel tronçon ».

    `_dans_chaussee` balaie les 430 rubans à chaque appel : la sonde du mur de
    quai en fait ~75 000, et sans grille l'export y passerait plus de temps
    qu'à tout le reste."""

    PAS = 8.0

    def __init__(self, index, emprises=None):
        self.emprises = emprises
        self.seg = []
        self.idx = {}
        for fid, demi, axe in index:
            for a, b in zip(axe, axe[1:]):
                k = len(self.seg)
                self.seg.append((fid, demi, a, b))
                for cx in range(int((min(a[0], b[0]) - demi) // self.PAS),
                                int((max(a[0], b[0]) + demi) // self.PAS) + 1):
                    for cy in range(int((min(a[1], b[1]) - demi) // self.PAS),
                                    int((max(a[1], b[1]) + demi) // self.PAS) + 1):
                        self.idx.setdefault((cx, cy), []).append(k)

    def dessus(self, p, long_de=None):
        """Le `fid` de la chaussée sous `p`, ou None.

        🔴 `long_de` EST TOUT L'INTÉRÊT DE CETTE MÉTHODE, et c'est lui qui
        empêche le quai de festonner. Au carrefour, la chaussée d'une rue
        PERPENDICULAIRE se rallonge d'une demi-largeur pour remplir le
        croisement, et ce carré d'asphalte de 7 m passe au-dessus de l'eau. Sans
        ce filtre, la sonde le trouve, le mur s'avance pour le porter, et le
        quai part en festons dans la rivière — vu à l'écran le 2026-08-19, en
        pire que le défaut qu'on réparait. Une rue qui TRAVERSE n'a pas à
        déplacer le bord de l'eau : son amorce reste derrière le parapet du
        quai, comme avant, et le contrôle de l'asphalte en l'air le dit."""
        presents = None
        if self.emprises is not None:
            ids = self.emprises.grille.get((int(p[0] // 16), int(p[1] // 16)), ())
            presents = {self.emprises.polys[k][0] for k in ids
                        if dedans(self.emprises.polys[k][1], p)}
            if not presents:
                return None
            if long_de is None:
                return min(presents)
        for k in self.idx.get((int(p[0] // self.PAS), int(p[1] // self.PAS)), ()):
            fid, demi, a, b = self.seg[k]
            if presents is not None and fid not in presents:
                continue
            if D4C.dist_pt_seg(p, a, b) > demi:
                continue
            if long_de is not None:
                u = _unite(a, b)
                if u is None or abs(u[0] * long_de[1]
                                    - u[1] * long_de[0]) > QUAI_LONGE_SIN:
                    continue
            return fid
        return None


def _debord_asphalte(p, w, t, grille):
    """(débord, tronçon) à cette station de berge — le débord compté DEPUIS LA
    BERGE, positif vers l'eau.

    Trois réponses possibles, et ce sont elles qui décident de tout :
      · un nombre POSITIF — l'asphalte déborde sur l'eau. Le mur devra s'avancer
        d'autant pour le porter ;
      · un nombre NÉGATIF — la chaussée s'arrête en deçà de la berge. Le mur se
        pose sur la berge, et il n'y a rien à porter ;
      · None — aucune chaussée à `QUAI_PORTEE` de là. Ce n'est pas un quai :
        c'est une rive de campagne, et elle n'a que faire d'un muret.

    ⚠️ ON SONDE CÔTÉ EAU D'ABORD, ET ON S'ARRÊTE AU PREMIER TROU. Prendre le
    point le plus loin sans exiger la continuité ferait mordre le quai sur la
    chaussée d'en face, à travers la rivière."""
    d, debord, fid = 0.0, None, None
    while d <= QUAI_DEBORD_MAX:
        f = grille.dessus((p[0] + w[0] * d, p[1] + w[1] * d), t)
        if f is None:
            break
        debord, fid = d, f
        d += QUAI_SONDE
    if debord is not None:
        return debord, fid
    # 🔴 LE REPLI ACCEPTE N'IMPORTE QUELLE RUE, et il le faut. Au débouché
    # d'une perpendiculaire, la rue de quai s'arrête et c'est l'amorce de
    # l'autre qui touche l'eau : avec le filtre « longe » ici aussi, le mur se
    # coupait à chaque carrefour — un trou de parapet tous les 60 m, et
    # l'asphalte de l'amorce par-dessus. Ce qui décide de l'AVANCÉE du mur doit
    # longer ; ce qui décide qu'il y a un QUAI ici, non.
    d = 0.0
    while d <= QUAI_PORTEE:
        f = grille.dessus((p[0] - w[0] * d, p[1] - w[1] * d))
        if f is not None:
            lo, hi = max(0.0, d - QUAI_SONDE), d
            for _ in range(8):
                mi = (lo + hi) * 0.5
                if grille.dessus((p[0] - w[0] * mi, p[1] - w[1] * mi)) is None:
                    lo = mi
                else:
                    hi = mi
            return -hi, f
        d += QUAI_SONDE
    return None, None


def _boites(polys):
    """Chaque polygone avec sa boîte englobante. Le test d'appartenance sert
    deux fois (le quai cherche les tabliers, le pont cherche les quais) et
    `dedans` coûte un parcours complet de l'anneau : la boîte élimine 99 % des
    candidats en quatre comparaisons."""
    return [(min(q[0] for q in poly), min(q[1] for q in poly),
             max(q[0] for q in poly), max(q[1] for q in poly), poly)
            for poly in polys]


def _dans_boites(p, boites):
    return any(x0 <= p[0] <= x1 and y0 <= p[1] <= y1 and dedans(poly, p)
               for x0, y0, x1, y1, poly in boites)


def _bascule(pa, pb, test, tours=6):
    """La fraction de [pa, pb] où `test` cesse d'être vrai — `test(pa)` vrai,
    `test(pb)` faux. Six dichotomies ramènent l'erreur à 1/64 du pas.

    ⚠️ SANS ELLE, LE BOUT DU PARAPET D'UN PONT TOMBE À LA STATION, donc à 2 m
    près : ou bien il s'arrête 2 m avant le nu du quai et il reste un trou au
    coin, ou bien il le dépasse de 2 m et il remonte sur la voie de berge —
    c'est-à-dire exactement le défaut qu'on répare."""
    lo, hi = 0.0, 1.0
    for _ in range(tours):
        mi = (lo + hi) / 2.0
        if test((pa[0] + (pb[0] - pa[0]) * mi, pa[1] + (pb[1] - pa[1]) * mi)):
            lo = mi
        else:
            hi = mi
    return lo


def _entre(pa, pb, t):
    return (pa[0] + (pb[0] - pa[0]) * t, pa[1] + (pb[1] - pa[1]) * t)


def _quais(chenal, relief, grille, tabliers, franchis=None):
    """LE QUAI, TENU PAR LA BERGE — le PLAN, pas l'émission.

    Renvoie (plan, compte, plateformes, murs), où `plan` est
    `{fid: [morceau, ...]}`. Une passe unique, lancée AVANT la boucle des
    routes : une berge ne sait pas à quel tronçon elle appartient, et le
    morceau qui la borde doit tomber dans le GROUPE de ce tronçon — sans quoi
    la rue aurait deux nœuds dans Godot, et les calques thématiques n'en
    repeindraient qu'un.

    L'ordre : on recoud les berges, on demande à chaque station ce que
    l'asphalte fait par ici, on lisse le nu du mur, on découpe par tronçon."""
    st = {"quai_m": 0.0, "avance_m": 0.0, "parapet_m": 0.0, "talus": 0,
          "campagne": 0, "tablier": 0, "morceaux": 0, "runs": 0,
          "berges": 0, "rattachees": 0, "traverses": 0}
    plan, murs, plateformes, berges = {}, [], [], []
    boites = _boites(tabliers)
    # Les franchissements de la CARTE : ce qui coupe les berges. Par défaut ce
    # sont les tabliers bâtis — donc rien, le jour où la crue les a tous pris.
    boites_franchis = _boites(tabliers if franchis is None else franchis)

    def sous_tablier(p):
        return _dans_boites(p, boites)

    def sous_franchissement(p):
        return _dans_boites(p, boites_franchis)

    for ic, chaine in enumerate(_chaines_berge(chenal)):
        net = _densifier(chaine, QUAI_PAS)
        n = len(net)
        if n < 3:
            continue
        # La normale EAU de chaque station. Pas d'onglet ici : la berge n'est
        # pas un ruban à décaler d'une largeur constante, et un onglet
        # s'envolerait au premier angle droit de la rive.
        eau = []
        for i in range(n):
            u = _unite(net[max(0, i - 1)], net[min(n - 1, i + 1)]) or (1.0, 0.0)
            eau.append((-u[1], u[0]))
        prendre = [False] * n
        bord = [0.0] * n
        off = [0.0] * n
        fids = [None] * n
        sous = [False] * n
        for i, p in enumerate(net):
            if sous_tablier(p):
                sous[i] = True
                st["tablier"] += 1
                continue
            # 🌾 Une berge de champ descend à 22 % jusqu'à l'eau : un muret
            # planté au milieu de cette pente ne serait ni une barrière ni un
            # quai. La ville tient la rive avec un mur, la campagne avec un
            # talus — c'est déjà la règle du creusement.
            if relief is not None and relief.z(p[0], p[1]) < -0.20:
                st["talus"] += 1
                continue
            d, f = _debord_asphalte(p, eau[i], (-eau[i][1], eau[i][0]),
                                    grille)
            if d is None:
                st["campagne"] += 1
                continue
            prendre[i] = True
            bord[i] = d
            fids[i] = f
            # Le nu du mur : le débord de l'asphalte, plus la bande. Négatif,
            # il retombe à zéro — le mur se pose alors sur la berge elle-même,
            # et c'est le mur du chenal qui fait la paroi.
            off[i] = max(0.0, d + BANDE_QUAI)
        # 🌊 LA COUPE DE LA BERGE, et elle ne coupe qu'aux TABLIERS. `fids`
        # portait le tronçon qui longe ; il porte désormais la BERGE, donc
        # `_decouper_quai` taille le mur par bief et non plus par rue — cliquer
        # un parapet ouvre la berge. Les rues sont gardées pour la fiche.
        rues = list(fids)
        fids[:] = [None] * n
        # 🔴 LA DEUXIÈME COUPE, ET SANS ELLE LES BERGES SE REJOIGNENT PAR LE
        # BOUT. Les six îlots d'eau forment UN anneau : la rive gauche descend,
        # traverse l'Ilse au bout de la carte et remonte en rive droite. Le
        # bord où l'anneau traverse est la seule arête qui change de rive — on
        # y coupe, et chaque berge appartient alors à une rive et une seule.
        rives = [chenal.niveau_rive(p[0], p[1], False) for p in net]
        coupe = [sous_franchissement(p) for p in net]
        for i in range(1, n):
            if rives[i] != rives[i - 1]:
                coupe[i] = True
        st["traverses"] += sum(1 for i in range(1, n)
                               if rives[i] != rives[i - 1])
        runs = _plages([not c for c in coupe])
        longs = [j for j, (a, b) in enumerate(runs)
                 if _longueur(net, a, b) >= BERGE_MIN_M]
        # 🌉 Un bout de moins de 15 m entre deux tabliers n'est pas une berge :
        # il rejoint la voisine, sinon son mur de quai disparaîtrait avec lui.
        for j, (a, b) in enumerate(runs):
            if not longs:
                break
            jj = min(longs, key=lambda k: abs(k - j))
            if jj != j:
                st["rattachees"] += 1
            for i in range(a, b + 1):
                fids[i] = (ic, jj)
        # Au carrefour, la route s'écarte brièvement de la sonde du quai.
        # Raccorder ces deux rives urbaines sans traverser un champ ni un ouvrage.
        for a, z in _plages([not v for v in prendre]):
            if a == 0 or z == n - 1 or fids[a - 1] is None \
                    or fids[a - 1] != fids[z + 1]:
                continue
            longueur = _longueur(net, a - 1, z + 1)
            if longueur > 2 * QUAI_PORTEE or any(
                    coupe[i] or sous[i] or (relief is not None and relief.z(*net[i]) < -.20)
                    for i in range(a, z + 1)):
                continue
            for i in range(a, z + 1):
                t = _longueur(net, a - 1, i) / longueur
                prendre[i] = True
                bord[i] = bord[a - 1] * (1 - t) + bord[z + 1] * t
                off[i] = off[a - 1] * (1 - t) + off[z + 1] * t
                rues[i] = rues[a - 1] if t < .5 else rues[z + 1]
        for j in longs:
            a, b = runs[j]
            mil = net[(a + b) // 2]
            berges.append({
                "cle": (ic, j), "i0": a, "i1": b,
                # Les tableaux sont pris PAR RÉFÉRENCE : `prendre` et `off` sont
                # encore retouchés plus bas, et c'est leur état final qui dit où
                # un mur tient la berge et où il faut poser la bande.
                "net": net, "eau": eau, "prendre": prendre, "sous": sous,
                "bord": bord, "off": off,
                "longueur_m": _longueur(net, a, b),
                "rues": sorted({f for f in rues[a:b + 1] if f is not None}),
                "rive": "gauche" if rives[(a + b) // 2] == RIVE_GAUCHE_Y
                        else "droite",
                "amont": max(p[1] for p in net[a:b + 1]),
                # 🌊 LE BIEF QU'ELLE BORDE, en fil d'eau. Élargir la section
                # abaisse la crue sur toute la traversée, LES DEUX RIVES : c'est
                # ce couple, et pas la liste des rues, qui dit qui en profite.
                "fil_amont": chenal.fil(max(p[1] for p in net[a:b + 1])),
                "fil_aval": chenal.fil(min(p[1] for p in net[a:b + 1])),
            })
        _combler(prendre)
        # ⚠️ LA CORDE PEND. Entre deux stations de berge (2 m), le mur est une
        # droite alors que le bord de l'asphalte, lui, tourne : quatre quais en
        # courbe laissaient ainsi 16 m² d'asphalte dépasser d'un mètre. Chaque
        # station prend donc le débord de ses voisines — c'est la corde qui se
        # place sur la flèche, et non l'inverse.
        large = list(off)
        for i in range(n):
            if prendre[i]:
                off[i] = max(large[max(0, i - 1)], large[i],
                             large[min(n - 1, i + 1)])
        # 🌉 LE QUAI GLISSE SOUS LE TABLIER, de deux stations. Sans ça il
        # s'arrête au ras du pont et il reste, entre son bout et la culée, un
        # coin d'asphalte qui dépasse le parapet de 1,5 m — mesuré sur les
        # tronçons 97, 101, 128 et 146. On ne prolonge QUE sous un tablier :
        # prolonger dans un talus de champ y planterait un muret.
        for i0, i1 in _plages(prendre):
            for pas_, bout in ((-1, i0), (1, i1)):
                k = bout
                for _ in range(2):
                    j = k + pas_
                    if not (0 <= j < n) or prendre[j] or not sous[j]:
                        break
                    prendre[j] = True
                    bord[j] = bord[k]
                    off[j] = off[k]
                    fids[j] = fids[k]
                    k = j
        for i0, i1 in _plages(prendre):
            if _longueur(net, i0, i1) < 4.0:
                continue
            st["runs"] += 1
            # L'ÉPAULEMENT : le nu ne peut pas sauter d'une station à l'autre.
            for i in range(i0 + 1, i1 + 1):
                off[i] = max(off[i], off[i - 1] - QUAI_PENTE)
            for i in range(i1 - 1, i0 - 1, -1):
                off[i] = max(off[i], off[i + 1] - QUAI_PENTE)
            _decouper_quai(net, eau, off, bord, fids, sous, i0, i1,
                           plan, st, murs, plateformes)
    # 🔢 LE NUMÉRO D'UNE BERGE SE LIT : rive gauche d'abord, puis de l'amont
    # vers l'aval. L'Ilse coule vers le sud, donc l'amont est le grand y. Un
    # numéro tiré de l'ordre de recousage des arêtes n'aurait rien voulu dire.
    berges.sort(key=lambda b: (b["rive"] != "gauche", -b["amont"]))
    renum = {}
    for k, b in enumerate(berges):
        b["fid"] = k + 1
        renum[b["cle"]] = k + 1
    plan = {renum[c]: v for c, v in plan.items() if c in renum}
    st["berges"] = len(berges)
    for b in berges:
        # Mesuré sur la ligne, pas compté en stations : le mur glisse sous
        # les tabliers, et un comptage donnait 316 m de mur sur 302 m de berge.
        b["mur_m"] = sum(
            _longueur(b["net"], b["i0"] + j0, b["i0"] + j1)
            for j0, j1 in _plages(b["prendre"][b["i0"]:b["i1"] + 1]))
        pris = [i for i in range(b["i0"], b["i1"] + 1) if b["prendre"][i]]
        b["debord_max_m"] = round(max([b["bord"][i] for i in pris] or [0.0]), 2)
        b["debord_m2"] = round(sum(max(0.0, b["bord"][i]) for i in pris)
                               * QUAI_PAS, 1)
        # 🌊 CE QU'ELLE A ENCORE À RENDRE : la rive entre la chaussée et l'eau,
        # depuis que le corridor se colle aux façades. La médiane, parce
        # qu'elle passe d'une voie `rive` (1,9 m) à un boulevard de quai
        # (9,9 m) le long d'une même berge.
        libres = sorted(-b["bord"][i] for i in pris if b["bord"][i] < 0.0)
        b["rive_m"] = round(libres[len(libres) // 2], 2) if libres else 0.0
    return plan, st, plateformes, murs, berges


def _decouper_quai(net, eau, off, bord, fids, sous, i0, i1, plan, st, murs,
                   plateformes):
    """Une longueur de quai découpée en morceaux à `fid` constant.

    🔴 LE DÉCOUPAGE NE COUPE QUE LE MAILLAGE, JAMAIS LA LIGNE. Les morceaux
    sont taillés dans les mêmes tableaux, en partageant leur station de
    frontière : deux voisins ont donc les mêmes sommets au millimètre, et le
    joint ne se voit pas. C'est ce qui permet de garder un parapet cliquable —
    cliquer un muret ouvre la fiche de la rue — sans revenir aux 21 bouts de
    mur qu'on vient de supprimer."""
    ext = [(net[i][0] + eau[i][0] * off[i], net[i][1] + eau[i][1] * off[i])
           for i in range(i0, i1 + 1)]
    inte = [(net[i][0] + eau[i][0] * (off[i] - PARAPET_EP),
             net[i][1] + eau[i][1] * (off[i] - PARAPET_EP))
            for i in range(i0, i1 + 1)]
    # Le couronnement ne commence qu'où le sol s'arrête : sous l'asphalte il
    # n'y a rien à couvrir, et par-dessus la plaque de sol deux surfaces au même
    # millimètre se battraient en duel.
    interieur = [(net[i][0] + eau[i][0] * max(0.0, min(bord[i], off[i])),
                  net[i][1] + eau[i][1] * max(0.0, min(bord[i], off[i])))
                 for i in range(i0, i1 + 1)]
    # La plateforme sert au contrôle de l'asphalte en l'air : ce qu'elle couvre
    # est porté. Côté terre elle mord 2 m au-delà de la berge, ce qui ne coûte
    # rien — l'asphalte de ce côté-là n'est pas au-dessus de l'eau.
    arriere = [(net[i][0] - eau[i][0] * 2.0, net[i][1] - eau[i][1] * 2.0)
               for i in range(i0, i1 + 1)]
    plateformes.append(list(arriere) + list(reversed(ext)) + [arriere[0]])
    for j in range(i1 - i0 + 1):
        murs.append((ext[j], eau[i0 + j]))
    st["quai_m"] += _longueur(net, i0, i1)

    coupes = [0]
    for j in range(1, i1 - i0 + 1):
        if fids[i0 + j] != fids[i0 + j - 1]:
            coupes.append(j)
    coupes.append(i1 - i0)
    for a, b in zip(coupes, coupes[1:]):
        if b <= a:
            continue
        st["morceaux"] += 1
        avance = []
        for j0, j1 in _plages([off[i0 + k] > 0.05 for k in range(a, b + 1)]):
            if j1 > j0:
                avance.append((j0, j1))
                st["avance_m"] += _longueur(net, i0 + a + j0, i0 + a + j1)
        # 🚧 PAS DE PARAPET SOUS UN TABLIER. Le quai glisse sous le pont pour
        # que rien ne dépasse entre les deux ; son MURET, lui, monte de 1 m et le
        # tablier n'est qu'à 1 cm au-dessus du couronnement — il traverserait la
        # chaussée du pont et poserait un crochet en travers, vu à l'écran le
        # 2026-08-19. Le couronnement et la paroi, eux, restent : ils sont
        # dessous, invisibles, et ce sont eux qui portent l'asphalte.
        garde_fou = [(j0, j1) for j0, j1
                     in _plages([not sous[i0 + k] for k in range(a, b + 1)])
                     if j1 > j0]
        st["parapet_m"] += sum(_longueur(net, i0 + a + j0, i0 + a + j1)
                               for j0, j1 in garde_fou)
        plan.setdefault(fids[i0 + a], []).append(
            (ext[a:b + 1], inte[a:b + 1], interieur[a:b + 1],
             (eau[i0 + a][0], 0.0, -eau[i0 + a][1]), avance, garde_fou))


def _cale_rive(chenal, x, y):
    """G remet l'eau à zéro ; un quai avancé garde le niveau de sa terrasse."""
    return chenal.niveau_rive(x, y, False) - chenal.niveau_rive(x, y)


def _rive_haut(chenal, p):
    """Le haut du talus d'une rive rendue, à cette station — la lèvre de la
    bande de berge, dont le talus et les roseaux partent."""
    return Y_TROTTOIR + BERGE_Y + chenal.niveau_rive(p[0], p[1], False)


def _emettre_quai(m, morceaux, coul_mur, coul_chap, G, chenal, passages=None):
    """Les trois surfaces d'un morceau de quai : couronnement, paroi, parapet.
    Le groupe est ouvert par l'appelant, d'où le fait qu'il ne marque rien.
    🔴 C'est le corps que la rive rendue EFFACE — d'où son maillage à part.
    `G` est celui de la RIVE (`_cale_rive`) : le quai est posé dessus."""
    tri = 0
    for ext, inte, interieur, dehors, avance, garde_fou in morceaux:
        if passages is None:
            tri += _bande3d(m, [(p[0], p[1], Y_QUAI) for p in interieur],
                            [(p[0], p[1], Y_QUAI) for p in ext],
                            coul_mur, G, (0.0, 1.0, 0.0))
        else:
            for j in range(len(ext) - 1):
                poly = [interieur[j], interieur[j + 1], ext[j + 1], ext[j]]
                tri += _dessus_trottoir(m, poly, coul_mur, G,
                                       Y_QUAI - Y_TROTTOIR, passages)
        # La paroi ne descend au fond QUE là où le mur s'est avancé sur l'eau.
        # Là où il est posé sur la berge, le mur de quai du chenal est déjà là,
        # à la même place : deux parois coplanaires, c'est du z-fighting sur
        # toute la longueur de l'Ilse.
        for j0, j1 in avance:
            tri += _bande3d(
                m, [(p[0], p[1], Y_QUAI) for p in ext[j0:j1 + 1]],
                # Le pied est le seul sommet du quai qui appartienne à l'EAU :
                # on lui reprend le mètre que `G` vient de donner à la rive,
                # sinon la paroi s'arrête au-dessus de la nappe.
                [(p[0], p[1], FOND_ILSE - _cale_rive(chenal, p[0], p[1]))
                 for p in ext[j0:j1 + 1]],
                coul_mur, G, dehors)
        for j0, j1 in garde_fou:
            if passages is None:
                tri += _parapet(m, ext[j0:j1 + 1], inte[j0:j1 + 1], dehors,
                                coul_mur, coul_chap, G, Y_QUAI)
                continue
            # Réserver aussi l'ouvrage à reconstruire : aucun muret dans ses accès.
            troncons = []
            for j in range(j0, j1):
                a, b = ext[j:j + 2]
                longueur = math.dist(a, b)
                if longueur < 1e-6:
                    continue
                for p, q in passages.segments(a, b):
                    interieur = []
                    for v in (p, q):
                        t = math.dist(a, v) / longueur
                        interieur.append(tuple(inte[j][k] * (1 - t) + inte[j + 1][k] * t
                                               for k in (0, 1)))
                    if troncons and math.dist(troncons[-1][0][-1], p) < 1e-5:
                        troncons[-1][0].append(q)
                        troncons[-1][1].append(interieur[1])
                    else:
                        troncons.append(([p, q], interieur))
            for bord, dedans in troncons:
                tri += _parapet(m, bord, dedans, dehors, coul_mur, coul_chap, G, Y_QUAI)
    return tri


def _bande_berge(m, b, coul, G, relief, passages=None):
    """La BANDE de rive : le corps de la berge là où aucun mur ne la tient.

    Sur un quai, le mur et son parapet SONT la berge — il y a de quoi cliquer.
    En campagne il n'y a qu'un talus d'herbe, et une berge sans corps ne serait
    ni cliquable ni transformable. La bande suit le talus (`relief`) : posée à
    plat elle flotterait au-dessus de la pente à 22 % des champs riverains."""
    net, eau, i0, i1 = b["net"], b["eau"], b["i0"], b["i1"]
    tri = 0
    # Un tablier coupe la bande : elle ne passe pas sous un pont. Le reste se
    # découpe selon qu'un mur tient la rive — c'est ce qui dit sur QUOI la
    # bande se pose, donc à quelle hauteur et de quelle couleur.
    for d0, d1 in _plages([not b["sous"][i] for i in range(i0, i1 + 1)]):
        k = i0 + d0
        drapeaux = [b["prendre"][i] for i in range(i0 + d0, i0 + d1 + 1)]
        for a, z in _tranches(drapeaux):
            if z - a < 1:
                continue
            quai = drapeaux[a]
            A, B = [], []
            for i in range(k + a, k + z + 1):
                p = net[i]
                large = _large_berge(b, i)
                # Côté TERRE, donc à l'opposé de la normale eau.
                q = (p[0] - eau[i][0] * large,
                     p[1] - eau[i][1] * large)
                # 🔴 EN CAMPAGNE, LA BANDE PASSE SOUS LE TALUS. Posée dessus
                # elle y traçait un ruban vert à dents de scie le long des deux
                # rives — un décor que personne n'a demandé, sur des berges
                # déjà naturelles. Le terrain n'a AUCUN corps de collision
                # (`maquette._fusionne`) : cachée, elle reste cliquable.
                d = BERGE_Y if quai else -BERGE_ENFOUIE
                ya = Y_TROTTOIR if quai else Y_SOL + relief.z(p[0], p[1])
                yb = Y_TROTTOIR if quai else Y_SOL + relief.z(q[0], q[1])
                # Le talus part du nu avancé du quai : fermer aussi son dessus.
                o = b["off"][i] if quai else 0.0
                A.append((p[0] + eau[i][0] * o, p[1] + eau[i][1] * o, ya + d))
                B.append((q[0], q[1], yb + d))
            if quai and passages is not None:
                for i in range(len(A) - 1):
                    poly = [(p[0], p[1]) for p in (A[i], A[i + 1], B[i + 1], B[i])]
                    tri += _dessus_trottoir(m, poly, coul[0], G, BERGE_Y, passages)
            else:
                tri += _bande3d(m, A, B, coul[0] if quai else coul[1], G,
                                (0.0, 1.0, 0.0))
    return tri


def _pente_berge(m, b, coul_haut, coul_lit, G, chenal):
    """🌿 LE TALUS D'UNE RIVE RENDUE — ce qu'on montre À LA PLACE du mur.

    Deux quads par station, coupés À LA LIGNE D'EAU : la limite mouillée est
    une arête, pas une teinte devinée par le shader. Le haut part du bord de la
    bande (même altitude, sinon une lèvre de 9 cm reste ouverte quand le
    parapet disparaît) et le pied descend au lit.

    Rien sous un tablier, rien en campagne : là, le talus est déjà le terrain."""
    net, eau, i0, i1 = b["net"], b["eau"], b["i0"], b["i1"]
    debut = len(m.v)
    tri = 0
    for a, z in _plages([b["prendre"][i] and not b["sous"][i]
                         for i in range(i0, i1 + 1)]):
        if z - a < 1:
            continue
        haut, ligne, pied = [], [], []
        for i in range(i0 + a, i0 + z + 1):
            p, e, o = net[i], eau[i], b["off"][i]
            large = _larges_pente(b)[i - i0]
            direction = b["directions_pente"][i - i0]
            # Altitudes absolues : G ne doit plus ajouter le niveau de rive.
            yh = _rive_haut(chenal, p)
            part_eau = (yh - NAPPE_ILSE) / (yh - FOND_ILSE)
            for dist, y, out in ((0.0, yh, haut),
                                 (large * part_eau, NAPPE_ILSE, ligne),
                                 (large, FOND_ILSE, pied)):
                out.append((p[0] + e[0] * o + direction[0] * dist,
                            p[1] + e[1] * o + direction[1] * dist, y))
        # 🔴 LE DÉGRADÉ EST CE QUI FAIT LIRE LA PENTE. Vue de 34° au-dessus,
        # une bande verte inclinée de 31° a la même valeur qu'une bande à plat :
        # sans cette ombre qui descend vers l'eau, le talus reste un aplat.
        tri += _bande3d(m, haut, ligne, coul_haut, G, (0.0, 1.0, 0.0),
                        (1.0, PENTE_OMBRE))
        tri += _bande3d(m, ligne, pied, coul_lit, G, (0.0, 1.0, 0.0),
                        (PENTE_OMBRE, 0.55 * PENTE_OMBRE))
    # Lisser l'éclairage entre stations, sans arrondir la cassure côté promenade.
    normales = {}
    for p, n in zip(m.v[debut:], m.n[debut:]):
        cle = tuple(round(c, 6) for c in p)
        somme = normales.setdefault(cle, [0.0, 0.0, 0.0])
        for axe in range(3):
            somme[axe] += n[axe]
    for i in range(debut, len(m.v)):
        n = normales[tuple(round(c, 6) for c in m.v[i])]
        longueur = math.sqrt(sum(c * c for c in n))
        if longueur > 1e-9:
            m.n[i] = tuple(c / longueur for c in n)
    return tri


def _promenade_berge(m, b, coul, G, decoupe=None):
    """La promenade partage le bord de la bande ; son autre bord joint la rue."""
    tri = 0
    for a, z in _plages([b["prendre"][i] and not b["sous"][i]
                         for i in range(b["i0"], b["i1"] + 1)]):
        A, B = [], []
        for i in range(b["i0"] + a, b["i0"] + z + 1):
            p, e = b["net"][i], b["eau"][i]
            large = _large_berge(b, i)
            bord = max(large, -b["bord"][i])
            A.append((p[0] - e[0] * large, p[1] - e[1] * large,
                      Y_TROTTOIR + BERGE_Y))
            B.append((p[0] - e[0] * bord, p[1] - e[1] * bord, Y_TROTTOIR))
        if decoupe is None:
            tri += _bande3d(m, A, B, coul, G, (0.0, 1.0, 0.0))
        else:
            for k in range(len(A) - 1):
                poly = [(p[0], p[1]) for p in (A[k], A[k + 1], B[k + 1], B[k])]
                tri += _dessus_trottoir(m, poly, coul, G, BERGE_Y, decoupe)
    return tri


def _arc_berge(b):
    """L'abscisse curviligne de chaque station, en mètres depuis le début de la
    berge. Calculée une fois : la bande et le semis doivent lire la MÊME."""
    if "arc" not in b:
        net, s, out = b["net"], 0.0, [0.0]
        for i in range(b["i0"], b["i1"]):
            s += math.hypot(net[i + 1][0] - net[i][0],
                            net[i + 1][1] - net[i][1])
            out.append(s)
        b["arc"] = out
    return b["arc"]


def _ond_berge(b, i):
    """L'ondulation du TALUS à cette station, 0,86 à 1,14.

    🔄 RETOUR EN ARRIÈRE SIGNALÉ, 2026-09-02 : elle allait de 0,72 à 1,28 sur
    deux sinusoïdes de 23 et 9 m, et la bande la partageait. Une période de 9 m
    échantillonnée tous les 2 m ne fait pas une rive, elle fait une scie —
    l'auteur devant l'image : « je veux que ce soit plus smooth, moins
    dentelé ». Deux périodes longues (29 et 61 m), quinze stations par vague,
    et la bande n'y touche plus : son bord côté terre est une LIGNE."""
    t = _arc_berge(b)[i - b["i0"]] + b["fid"] * 3.7
    return 1.0 + PENTE_OND * (0.72 * math.sin(t / 4.6)
                              + 0.28 * math.sin(t / 9.7 + 2.1))


def _larges_pente(b):
    """Rétrécir le talus dans un coude rentrant où ses pieds se croiseraient."""
    if "larges_pente" in b:
        return b["larges_pente"]
    indices = list(range(b["i0"], b["i1"] + 1))
    larges = [PENTE_RIVE_M * _ond_berge(b, i) for i in indices]
    hauts = [(b["net"][i][0] + b["eau"][i][0] * b["off"][i],
              b["net"][i][1] + b["eau"][i][1] * b["off"][i]) for i in indices]
    directions = []
    # Une normale prise sur 8 m répartit le virage au lieu de pincer deux stations.
    for j in range(len(hauts)):
        u = _unite(hauts[max(0, j - 2)], hauts[min(len(hauts) - 1, j + 2)])
        directions.append((-u[1], u[0]))
    b["directions_pente"] = directions
    def aire(a, p, q):
        return (p[0] - a[0]) * (q[1] - a[1]) - (p[1] - a[1]) * (q[0] - a[0])
    for _ in range(40):
        corrige = False
        for j, i in enumerate(indices[:-1]):
            if not (b["prendre"][i] and b["prendre"][i + 1]):
                continue
            pieds = [(hauts[k][0] + directions[k][0] * larges[k],
                      hauts[k][1] + directions[k][1] * larges[k])
                     for k in (j, j + 1)]
            if (aire(hauts[j], hauts[j + 1], pieds[1]) <= 1e-7
                    or aire(hauts[j], pieds[1], pieds[0]) <= 1e-7):
                larges[j] *= 0.8
                larges[j + 1] *= 0.8
                corrige = True
        for j in range(1, len(larges)):
            larges[j] = min(larges[j], larges[j - 1] + 0.35)
        for j in range(len(larges) - 2, -1, -1):
            larges[j] = min(larges[j], larges[j + 1] + 0.35)
        if not corrige:
            break
    b["larges_pente"] = larges
    return larges


def _larges_berge(b):
    """🌿 LA LARGEUR DE LA BANDE, station par station — calculée une fois.

    `BERGE_BANDE_M` partout, sauf là où la chaussée est plus près que ça :
    `bord` est la distance de la berge à l'asphalte, et rien ne monte sur la
    rue. 🔴 CE RABOTAGE EST CE QUI DENTELAIT LE BORD — la sonde du quai répond
    par pas de 0,35 m, donc le bord sautait d'une station à l'autre. Il est
    moyenné sur `BERGE_LISSE_M`, puis interdit de MONTER de plus de
    `BERGE_LISSE_PENTE` par station : la bande s'amincit en biseau au droit
    d'une rue qui serre la rive, et redevient droite après."""
    if "large" not in b:
        brut = []
        for i in range(b["i0"], b["i1"] + 1):
            large = BERGE_BANDE_M
            if b["prendre"][i]:
                large = min(large, max(0.0, -b["bord"][i] - 0.10))
            brut.append(large)
        k = max(1, int(round(BERGE_LISSE_M / QUAI_PAS)))
        n = len(brut)
        lisse = [sum(brut[max(0, j - k):j + k + 1])
                 / len(brut[max(0, j - k):j + k + 1]) for j in range(n)]
        lisse = [min(l, b) for l, b in zip(lisse, brut)]
        # Le biseau, dans les deux sens : ce qui reste après ces deux passes ne
        # remonte jamais plus vite que la pente, donc aucun angle rentrant.
        for j in range(1, n):
            lisse[j] = min(lisse[j], lisse[j - 1] + BERGE_LISSE_PENTE)
        for j in range(n - 2, -1, -1):
            lisse[j] = min(lisse[j], lisse[j + 1] + BERGE_LISSE_PENTE)
        b["large"] = lisse
    return b["large"]


def _large_berge(b, i):
    return _larges_berge(b)[i - b["i0"]]


def _semis_berge(b, rng, relief, chenal):
    """Ce qui pousse sur une rive rendue au fleuve : roseaux au fil de l'eau,
    buissons en retrait. Sortie : [x, y, alt, échelle, lacet, genre].

    🔴 SEMÉ SUR LA BANDE, JAMAIS AU-DELÀ. La largeur est celle que
    `_bande_berge` donne à la station — 3,5 m en campagne, ce que la chaussée
    laisse en ville —, donc rien ne pousse sur l'asphalte. Rien sous un tablier
    non plus : la bande n'y passe pas.

    🌊 EN VILLE, LES ROSEAUX SONT DANS L'EAU : ils se plantent sur le TALUS
    (`_pente_berge`), au ras de la ligne d'eau. Sur la bande, ils poussaient
    trois mètres au-dessus du fleuve, sur le nez du quai."""
    net, eau, i0, i1 = b["net"], b["eau"], b["i0"], b["i1"]
    out = []
    # Décalés au tirage : deux berges qui se suivent ne doivent pas commencer
    # leur file de roseaux au même mètre.
    dr = rng.uniform(0.0, SEMIS_ROSEAU_PAS)
    db = rng.uniform(0.0, SEMIS_BUISSON_PAS)
    for i in range(i0, i1):
        if b["sous"][i] or b["sous"][i + 1]:
            continue
        p, q = net[i], net[i + 1]
        pas_m = math.hypot(q[0] - p[0], q[1] - p[1])
        if pas_m < 1e-6:
            continue
        large = _large_berge(b, i)
        dr += pas_m
        db += pas_m
        while dr >= SEMIS_ROSEAU_PAS:
            dr -= SEMIS_ROSEAU_PAS
            if b["prendre"][i]:
                large_pente = _larges_pente(b)[i - i0]
                haut = (p[0] + eau[i][0] * b["off"][i],
                        p[1] + eau[i][1] * b["off"][i])
                _poser_roseau(out, haut, b["directions_pente"][i - i0], 0.0,
                              large_pente, rng,
                              _rive_haut(chenal, p))
                # L'export ajoute G : retirer ici le niveau au pied du roseau.
                out[-1][2] -= chenal.niveau_rive(out[-1][0], out[-1][1])
            else:
                _poser_plante(out, p, eau[i],
                              rng.uniform(0.15, 0.30 + 0.30 * large),
                              SEMIS_ROSEAU, rng, relief)
        while db >= SEMIS_BUISSON_PAS:
            db -= SEMIS_BUISSON_PAS
            if large < SEMIS_BUISSON_LARGE:
                continue
            _poser_plante(out, p, eau[i],
                          rng.uniform(0.55 * large, 0.90 * large),
                          SEMIS_BUISSON, rng, relief)
    return out


def _poser_plante(out, p, e, recul, genre, rng, relief):
    """Posée à `recul` mètres de la ligne de berge, CÔTÉ TERRE — donc à
    l'opposé de la normale eau, comme la bande elle-même. Le pied suit le
    talus : sans ça un roseau de champ flotterait au-dessus de la pente."""
    x, y = p[0] - e[0] * recul, p[1] - e[1] * recul
    out.append([x, y, relief.z(x, y),
                rng.uniform(0.75, 1.30), rng.uniform(0.0, 6.2832), genre])


def _poser_roseau(out, p, e, nu, large, rng, y_haut):
    """Un roseau planté DANS le talus de la rive rendue, à quelques centimètres
    d'eau : sa hauteur suit la pente, sinon il flotterait ou serait noyé.
    `y_haut` est la lèvre de SA rive — les deux ne sont pas au même niveau."""
    # De la lèvre mouillée à 25 cm de fond : la frange où poussent les roseaux.
    f = (y_haut - NAPPE_ILSE + rng.uniform(-0.10, 0.25)) / (y_haut - FOND_ILSE)
    d = nu + large * f
    out.append([p[0] + e[0] * d, p[1] + e[1] * d,
                y_haut + (FOND_ILSE - y_haut) * f,
                rng.uniform(0.75, 1.30), rng.uniform(0.0, 6.2832),
                SEMIS_ROSEAU])


def _tranches(drapeaux):
    """Les plages [a, b] où le drapeau ne change pas — `_plages` ne rend que
    les vraies, et ici les deux valeurs portent chacune une bande.

    ⚠️ CHAQUE PLAGE MORD SUR LA STATION SUIVANTE, sans quoi le quad qui
    enjambe le changement n'est émis par personne : la bande s'ouvrait sur 2 m
    à chaque passage du quai au talus de campagne."""
    out, i, n = [], 0, len(drapeaux)
    while i < n:
        j = i
        while j + 1 < n and drapeaux[j + 1] == drapeaux[i]:
            j += 1
        out.append((i, min(j + 1, n - 1)))
        i = j + 1
    return out


def _bord_eau(m, axe, ch, chenal, relief, coul_mur, coul_chap, G, quais=()):
    """Le quai porté et le pont, sur une part de tronçon. Renvoie un compte.

    L'ordre est celui du raisonnement : on relève ce que chaque station voit de
    l'eau, on décide QUI traverse et qui longe, et seulement ensuite on émet.
    Rien ici ne connaît le nom d'une rue ni le numéro d'un franchissement.

    `quais` : les plateformes de quai déjà planifiées, en boîtes. Elles ne
    servent qu'à savoir où le parapet du pont doit s'arrêter — voir plus bas."""
    st_out = {"pont": 0, "pont_m": 0.0, "pile": 0, "quai_m": 0.0,
              "parapet_m": 0.0, "parapet_coupe_m": 0.0, "sur_quai": 0.0,
              "bouts": 0, "tri": 0}
    ponts = []                  # (longueur, milieu) — pour le point de vue
    # (point du nu extérieur, normale sortante) : le contrôle s'en sert pour
    # dire de quel côté du mur tombe le peu d'asphalte qui reste en l'air.
    murs = []
    h = ch / 2.0
    # Le MÊME axe rallongé que la chaussée : le mur doit couvrir aussi les deux
    # bouts qui remplissent les carrefours, sinon il s'arrête avant l'asphalte.
    net = _densifier(_axe_ruban(axe, h, True), QUAI_PAS)
    if len(net) < 2:
        return st_out, [], ponts, murs
    dec = _onglets(net)
    st = _stations_eau(net, dec, h, chenal, relief)

    # ① QUI TRAVERSE : les deux bords au-dessus de l'eau, sur au moins PONT_MIN.
    plages = _plages_pont(net, st)
    garde = [False] * len(st)
    for a, b, _i0, _i1 in plages:
        for k in range(a, b + 1):
            garde[k] = True
    plateformes = []

    for a, b, i0, i1 in plages:
        st_out["pont"] += 1
        st_out["pont_m"] += _longueur(net, a, b)
        mil = net[(i0 + i1) // 2]
        ponts.append((_longueur(net, i0, i1), mil))
        cotes = {}
        for cote in (1, -1):
            cotes[cote] = [(net[k][0] + st[k]["dec"][0] * cote * (h + BANDE_QUAI),
                            net[k][1] + st[k]["dec"][1] * cote * (h + BANDE_QUAI))
                           for k in range(a, b + 1)]
        # la sous-face du tablier — la seule surface du projet qui regarde en bas
        st_out["tri"] += _bande3d(
            m, [(p[0], p[1], Y_TABLIER) for p in cotes[1]],
            [(p[0], p[1], Y_TABLIER) for p in cotes[-1]],
            coul_mur, G, (0.0, -1.0, 0.0))
        for cote in (1, -1):
            ligne = cotes[cote]
            u = st[a]["dec"]
            dehors = (u[0] * cote, 0.0, -u[1] * cote)
            # la joue du tablier : c'est elle qu'on voit depuis la rivière, et
            # c'est son ombre qui fait qu'un pont est un pont et non un ruban.
            st_out["tri"] += _bande3d(
                m, [(p[0], p[1], Y_SOL) for p in ligne],
                [(p[0], p[1], Y_TABLIER) for p in ligne], coul_mur, G, dehors)
            inte = [(net[k][0] + st[k]["dec"][0] * cote * (h + BANDE_QUAI - PARAPET_EP),
                     net[k][1] + st[k]["dec"][1] * cote * (h + BANDE_QUAI - PARAPET_EP))
                    for k in range(a, b + 1)]
            # la bande de tablier entre l'asphalte et le parapet : le trottoir
            # du pont, sans bordure — sur 70 cm elle ne mérite pas de marche.
            bord = [(net[k][0] + st[k]["dec"][0] * cote * h,
                     net[k][1] + st[k]["dec"][1] * cote * h)
                    for k in range(a, b + 1)]
            st_out["tri"] += _bande3d(
                m, [(p[0], p[1], Y_SOL) for p in bord],
                [(p[0], p[1], Y_SOL) for p in ligne], coul_mur, G, (0.0, 1.0, 0.0))
            # 🌉 LE PARAPET DU PONT S'ARRÊTE AU BORD DE L'EAU — demandé le
            # 2026-08-19 sur capture : « les murs des ponts sont encore dans
            # les routes des berges, ils doivent s'arrêter aux berges. »
            #
            # Il courait sur toute la plage, culées comprises, donc 2,5 m
            # au-delà de la berge GÉOMÉTRIQUE — et le bord de l'eau qu'on VOIT
            # est encore ~5 m plus loin dans la rivière, au nu du quai, parce
            # que la voie de berge y déborde son asphalte et que le mur s'est
            # avancé pour le porter. Le muret du pont finissait donc 7 m après
            # la rive apparente, en travers de la chaussée qui longe.
            #
            # La règle ne mesure plus rien : le parapet ne couvre que l'EAU
            # LIBRE — ni la terre, ni ce que le quai porte déjà. Là où le quai
            # s'arrête (une berge de campagne), c'est la rive qui le borne, et
            # le pont garde son retour de culée.
            libre = (lambda p: chenal.dans_eau(p)
                     and not _dans_boites(p, quais))
            garde_p = [libre(p) for p in ligne]
            st_out["parapet_coupe_m"] += _longueur(net, a, b)
            # Le partage des mètres coupés, pour le contrôle : ce qui montait
            # sur la TERRE (le retour de culée) et ce qui montait sur le QUAI —
            # c'est le second que l'auteur voit en travers de la voie de berge.
            st_out["sur_quai"] += sum(QUAI_PAS for k, p in enumerate(ligne)
                                      if not garde_p[k] and chenal.dans_eau(p))
            for j0, j1 in _plages(garde_p):
                if j1 <= j0:
                    continue
                ext_p, int_p = list(ligne[j0:j1 + 1]), list(inte[j0:j1 + 1])
                # Les deux bouts au millimètre, pas à la station : sinon un
                # trou de 2 m au coin du quai, ou 2 m de muret par-dessus.
                if j0 > 0:
                    t = _bascule(ligne[j0], ligne[j0 - 1], libre)
                    ext_p[0] = _entre(ligne[j0], ligne[j0 - 1], t)
                    int_p[0] = _entre(inte[j0], inte[j0 - 1], t)
                if j1 < len(ligne) - 1:
                    t = _bascule(ligne[j1], ligne[j1 + 1], libre)
                    ext_p[-1] = _entre(ligne[j1], ligne[j1 + 1], t)
                    int_p[-1] = _entre(inte[j1], inte[j1 + 1], t)
                st_out["tri"] += _parapet(m, ext_p, int_p, dehors,
                                          coul_mur, coul_chap, G)
                st_out["bouts"] += 1
                L_p = _cumul(ext_p)[-1]
                st_out["parapet_m"] += L_p
                st_out["parapet_coupe_m"] -= L_p
        plateformes.append(list(cotes[1]) + list(reversed(cotes[-1]))
                           + [cotes[1][0]])
        for cote in (1, -1):
            for j, k in enumerate(range(a, b + 1)):
                u = st[k]["dec"]
                Lu = math.hypot(u[0], u[1]) or 1.0
                murs.append((cotes[cote][j],
                             (u[0] * cote / Lu, u[1] * cote / Lu)))
        # ② LES PILES — une travée de 40 m d'un seul jet n'existe pas dans une
        # petite ville. Elles sont posées sur la partie MOUILLÉE, pas sur le
        # tablier entier : une pile sous une culée serait dans la terre.
        L = _longueur(net, i0, i1)
        k = max(0, int(math.ceil(L / TABLIER_TRAVEE)) - 1)
        for j in range(1, k + 1):
            s = L * j / (k + 1.0)
            d = 0.0
            idx = i0
            while idx < i1 and d + math.hypot(net[idx + 1][0] - net[idx][0],
                                              net[idx + 1][1] - net[idx][1]) < s:
                d += math.hypot(net[idx + 1][0] - net[idx][0],
                                net[idx + 1][1] - net[idx][1])
                idx += 1
            u = _unite(net[idx], net[min(idx + 1, len(net) - 1)]) or (1.0, 0.0)
            st_out["tri"] += _boite(
                m, net[idx], u, PILE_COTE,
                ch + 2.0 * BANDE_QUAI - 2.0 * PILE_RETRAIT,
                FOND_ILSE, Y_TABLIER, coul_mur, G)
            st_out["pile"] += 1

    # ⏸️ « ③ QUI LONGE » A QUITTÉ CETTE FONCTION LE 2026-08-19, et la remettre
    # ici serait revenir en arrière. Le mur de quai était construit ici même,
    # station par station le long de la chaussée, symétrique du pont : d'où un
    # mur qui suivait les évasements de carrefour et se coupait à chaque bout de
    # tronçon. Il se fait maintenant en une seule passe, à partir des berges
    # recousues, après toutes les routes — voir `_quais`.
    return st_out, plateformes, ponts, murs


def _asphalte_en_lair(routes, coudes, chenal, plateformes, murs,
                      morceaux=None, pas=0.75):
    """LE CONTRÔLE : combien d'asphalte reste au-dessus du vide, et s'il se voit.

    Il échantillonne toute la chaussée affichée, garde les points qui tombent
    dans le polygone de l'Ilse, et les range en trois familles :

      · PORTÉ      — posé sur un tablier ou sur un quai ;
      · DERRIÈRE   — en l'air, mais en deçà du nu du mur, donc masqué par le
                     parapet qui passe devant. Ce sont les ~35 amorces de rue
                     au débouché d'un quai : elles traversent, elles ne longent
                     pas, donc la règle ne leur donne pas de mur — et elles
                     finissent derrière celui du quai qu'elles rejoignent ;
      · AU-DELÀ    — en l'air ET au-delà du mur. Le seul chiffre qui se verrait
                     à l'écran, avec son dépassement maximal.

    7 212 m² volaient avant ce lot, sans distinction. Séparer les trois est ce
    qui permet de dire « ✅ » sans mentir : ce qui reste doit être AU-DELÀ, et
    négligeable.

    🔴 `morceaux` N'EST PAS UNE COMMODITÉ : sans lui, ce contrôle rebâtit l'axe
    depuis `routes` et mesure une chaussée QUI N'EST PLUS ÉMISE. Un pont emporté
    (04e) lui faisait alors annoncer 296 m² d'asphalte au-dessus du vide là où il
    n'y a plus rien du tout. Un contrôle qui mesure autre chose que ce qu'on
    affiche est pire qu'absent.
    """
    boites = []
    for poly in plateformes:
        xs = [q[0] for q in poly]
        ys = [q[1] for q in poly]
        boites.append((min(xs), min(ys), max(xs), max(ys), poly))
    # Une grille sur les stations de mur : sans elle, chaque échantillon les
    # compare une à une — 1 500 murs contre 15 000 points.
    GR = 8.0
    idx = {}
    for k, (q, n) in enumerate(murs):
        idx.setdefault((int(q[0] // GR), int(q[1] // GR)), []).append(k)

    total = cache = dela = depasse = 0.0
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        h = ch / 2.0
        for ip, part in enumerate(d["parts"]):
            # 🌊 Les morceaux RÉELLEMENT émis, pont emporté compris.
            for axe in (morceaux[d["fid"]][ip] if morceaux
                        else [_axe_arrondi(part, d["fid"], ip, coudes)]):
                net = _axe_ruban(axe, h, bouts=False)
                if len(net) < 2:
                    continue
                dec = _onglets(net)
                for i in range(len(net) - 1):
                    seg = math.hypot(net[i + 1][0] - net[i][0],
                                     net[i + 1][1] - net[i][1])
                    if seg < 1e-9:
                        continue
                    nk = max(1, int(math.ceil(seg / pas)))
                    nw = max(2, int(math.ceil(ch / pas)))
                    aire = (seg / nk) * (ch / nw)
                    for a in range(nk):
                        f = (a + 0.5) / nk
                        px = net[i][0] + (net[i + 1][0] - net[i][0]) * f
                        py = net[i][1] + (net[i + 1][1] - net[i][1]) * f
                        ux = dec[i][0] + (dec[i + 1][0] - dec[i][0]) * f
                        uy = dec[i][1] + (dec[i + 1][1] - dec[i][1]) * f
                        for b in range(nw):
                            w = -h + ch * (b + 0.5) / nw
                            q = (px + ux * w, py + uy * w)
                            if not chenal.dans_eau(q):
                                continue
                            total += aire
                            if any(x0 <= q[0] <= x1 and y0 <= q[1] <= y1
                                   and dedans(poly, q)
                                   for x0, y0, x1, y1, poly in boites):
                                continue
                            best = None
                            cx, cy = int(q[0] // GR), int(q[1] // GR)
                            for jx in (cx - 1, cx, cx + 1):
                                for jy in (cy - 1, cy, cy + 1):
                                    for k in idx.get((jx, jy), ()):
                                        mp = murs[k][0]
                                        dd = math.hypot(q[0] - mp[0], q[1] - mp[1])
                                        if best is None or dd < best[0]:
                                            best = (dd, k)
                            if best is None:
                                dela += aire
                                continue
                            mp, mn = murs[best[1]]
                            proj = (q[0] - mp[0]) * mn[0] + (q[1] - mp[1]) * mn[1]
                            if proj > 0.02:
                                dela += aire
                                depasse = max(depasse, proj)
                            else:
                                cache += aire
    return total, cache, dela, depasse
