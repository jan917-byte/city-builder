# -*- coding: utf-8 -*-
"""Contrôles du dépôt partagé et de la portée des ponts : aucune règle de jeu."""

import unittest
from importlib import import_module

ChampCrue = import_module("04e_crue").ChampCrue
from export_godot.boue import carte_boue
from export_godot.geometrie import Chenal, Maillage
from export_godot.ponts import _cadre, _pont_neuf, _pont_ruine, _acces_pont
from export_godot.voirie import DecoupeChaussees, D4C
from export_godot.geometrie import _aire_xy, _chenal_eau
from export_godot.berges import _emettre_quai
from export_godot.reglages import Y_CHAUSSEE, Y_TROTTOIR, JEU_CHAUSSEE


class CrueVisuelle(unittest.TestCase):
    def test_depot_coupe_un_ilot_et_ignore_la_hauteur_maximale(self):
        c = Chenal([[(20, -20), (50, -20), (50, 100), (20, 100)]])
        champ = ChampCrue(c.rivieres, contour=((80, 0), (80, 60)))
        ilots = {1: {"brut": [(0, 0), (110, 0), (110, 90), (0, 90)],
                     "hauteur_eau_max": 6.0, "sous_type": "champ"}}
        b = carte_boue(ilots, [], c, 0, 0, champ=champ)
        nx, ny = b["taille"]
        self.assertEqual(len(b["pixels"]), nx * ny * 2)

        def depth(x, y):
            x0, z0, largeur, hauteur = b["repere"]
            i = round((x - x0) / largeur * (nx - 1))
            j = round((-y - z0) / hauteur * (ny - 1))
            return b["pixels"][(j * nx + i) * 2]

        self.assertGreater(depth(60, 30), depth(75, 30))
        self.assertGreater(depth(75, 30), 0)
        for p in ((90, 30), (10, 30), (35, 30), (60, 75)):
            self.assertEqual(depth(*p), 0, "Est, ouest, eau et nord restent propres")
        ilots[1]["hauteur_eau_max"] = 0.0
        self.assertEqual(b, carte_boue(ilots, [], c, 0, 0, champ=champ))

    def test_une_route_ou_un_pont_ne_deplace_pas_la_limite(self):
        c = Chenal([[(20, -20), (50, -20), (50, 100), (20, 100)]])
        champ = ChampCrue(c.rivieres, contour=((80, 0), (80, 60)))
        ilots = {1: {"brut": [(0, 0), (110, 0), (110, 90), (0, 90)]}}
        reference = carte_boue(ilots, [], c, 0, 0, champ=champ)
        for etat in ("coupe", "fragile", "envase", "intact"):
            route = {"parts": [[(10, 30), (100, 30)]], "largeur_m": 20,
                     "hauteur_eau": 3.8, "etat_crue": etat}
            self.assertEqual(reference, carte_boue(ilots, [route], c, 0, 0, champ=champ))

    def test_degats_et_depot_lisent_le_meme_point(self):
        c = Chenal([[(20, -20), (50, -20), (50, 100), (20, 100)]])
        champ = ChampCrue(c.rivieres, contour=((80, 0), (80, 60)))
        etat = import_module("04e_crue").etat
        self.assertEqual(etat(champ.ouverture((51, 30))), "ruine")
        self.assertEqual(etat(champ.ouverture((70, 30))), "sinistre")
        self.assertEqual(etat(champ.ouverture((90, 30))), "intact")

    def test_tablier_franchit_le_relief_sous_jacent(self):
        def G(x, y, h):
            return x, h + x * x / 100.0 + y * .4, -y
        longueur, poser = _cadre([(0, 0), (10, 0)], G)
        self.assertEqual(longueur, 10)
        self.assertAlmostEqual(poser(5, 0, 0)[1], .5)
        self.assertAlmostEqual(poser(5, 4, 0)[1], .5)
        self.assertAlmostEqual(poser(5, -4, 0)[1], .5)

    def test_ouvrage_epais_et_rupture_ouverte(self):
        axe = [(0, 0), (48, 0)]
        G = lambda x, y, h: (x, h, -y)
        neuf, ruine = Maillage(), Maillage()
        couleurs = ((.6, .6, .5), (.2, .2, .2), (.4, .4, .35))
        _pont_neuf(neuf, axe, 14, 8.5, *couleurs, G)
        self.assertTrue(any(n[1] < -.9 for n in neuf.n), "Sous-face absente")
        self.assertGreater(max(p[1] for p in neuf.v), 1.0)
        self.assertLess(min(p[1] for p in neuf.v), -2.6)
        self.assertEqual(_pont_ruine(ruine, axe, 14, 8.5, *couleurs, G), 2)
        self.assertFalse(any(12 < p[0] < 36 for p in ruine.v), "La travée détruite doit rester ouverte")
        bord = {round(p[0], 2) for p in ruine.v if 3 < p[0] < 8 and p[1] > -1}
        self.assertGreater(len(bord), 4, "Cassure trop droite")

    def test_acces_oblique_joint_le_niveau_de_la_rue_sur_toute_sa_largeur(self):
        G = lambda x, y, h: (x, h + max(-1, min(1, 1 - (x + y * .6) / 20)), -y)
        longueur, poser = _cadre([(0, 0), (48, 0)], G, raccord=8)
        for s in (0, longueur):
            for w in (-10, -7.9, 0, 7.9, 10):
                self.assertAlmostEqual(poser(s, w, Y_CHAUSSEE)[1], G(s, w, Y_CHAUSSEE)[1])
        self.assertAlmostEqual(poser(24, -8, 0)[1], poser(24, 8, 0)[1])

    def test_chaussee_du_pont_retrouve_la_largeur_des_acces(self):
        m = Maillage()
        asphalte = (.2, .2, .2)
        _pont_neuf(m, [(0, 0), (48, 0)], 20, 10.5, (.6, .6, .5),
                   asphalte, (.4, .4, .35), lambda x, y, h: (x, h, -y), bord=7.9)
        for s in (0, 48):
            bord = [abs(p[2]) for p, c in zip(m.v, m.c)
                    if abs(p[0] - s) < 1e-5 and tuple(c[:3]) == asphalte]
            self.assertAlmostEqual(max(bord), 7.9 + JEU_CHAUSSEE)

    def test_trottoirs_dacces_ne_recouvrent_pas_le_carrefour(self):
        decoupe = DecoupeChaussees([], {})
        chaussee = [(-12, -3), (0, -3), (0, 3), (-12, 3)]
        decoupe.ajouter(1, chaussee)
        m = Maillage()
        _acces_pont(m, [(-12, 0), (48, 0)], [(0, 0), (48, 0)],
                    12, 4.25, (.6, .6, .5), lambda x, y, h: (x, h, -y), decoupe)
        self.assertTrue(m.i)
        for k in range(0, len(m.i), 3):
            pts = [m.v[j] for j in m.i[k:k + 3]]
            if not all(abs(p[1] - Y_TROTTOIR) < 1e-5 for p in pts):
                continue
            poly = [(p[0], -p[2]) for p in pts]
            intersection = D4C._soustraire_convexe(poly, decoupe.plans(chaussee))[1]
            self.assertLess(sum(abs(_aire_xy(p)) for p in intersection), 1e-6)

    def test_berge_oblique_decoupe_le_revetement_du_pont(self):
        chenal = Chenal([[(0, 0), (30, 0), (30, 100), (0, 100)]])
        G = lambda x, y, h: (x, h + chenal.niveau_voirie(x, y), -y)
        m = Maillage()
        asphalte = (.2, .2, .2)
        _pont_neuf(m, [(-3, 30), (33, 60)], 20, 10.5, (.6, .6, .5),
                   asphalte, (.4, .4, .35), G, bord=7.9, chenal=chenal)
        for k in range(0, len(m.i), 3):
            ids = m.i[k:k + 3]
            if not all(tuple(m.c[j][:3]) == asphalte for j in ids):
                continue
            xs = [m.v[j][0] for j in ids]
            for x in (0, 30):
                self.assertFalse(min(xs) < x - 1e-5 and max(xs) > x + 1e-5,
                                 "Une face de chaussée chevauche la cassure de la rive")

    def test_muret_interrompu_a_la_largeur_reelle_du_pont(self):
        decoupe = DecoupeChaussees([], {})
        decoupe.ajouter(1, [(-10, -5), (10, -5), (10, 5), (-10, 5)])
        ext = [(-20, 0), (0, 0), (20, 0)]
        inte = [(x, .4) for x, y in ext]
        m = Maillage()
        _emettre_quai(m, [(ext, inte, [(x, -2) for x, y in ext],
                          (0, 0, 1), [], [(0, 2)])],
                     (.4, .4, .35), (.6, .6, .5), lambda x, y, h: (x, h, -y),
                     None, decoupe)
        hauts = [p for p in m.v if p[1] > Y_CHAUSSEE]
        self.assertTrue(hauts)
        self.assertFalse(any(abs(p[0]) < 10 - 1e-5 for p in hauts))

    def test_mur_de_rive_sarrete_sous_la_dalle(self):
        anneau = [(0, 0), (30, 0), (30, 100), (0, 100)]
        chenal = Chenal([anneau])
        passages = DecoupeChaussees([], {})
        passages.ajouter(1, [(-10, 40), (40, 40), (40, 60), (-10, 60)])
        m, eau = Maillage(), Maillage()
        _chenal_eau(eau, m, anneau, chenal, (.2, .4, .5), (.4, .4, .35),
                    lambda x, y, h: (x, h, -y), passages=passages)
        testes = 0
        for k in range(0, len(m.i), 3):
            ids = m.i[k:k + 3]
            if abs(m.n[ids[0]][1]) > .1:
                continue
            pts = [m.v[j] for j in ids]
            if 40 < -sum(p[2] for p in pts) / 3 < 60:
                self.assertLessEqual(max(p[1] for p in pts), Y_CHAUSSEE - .8 + 1e-6)
                testes += 1
        self.assertEqual(testes, 4)


if __name__ == "__main__":
    unittest.main()
