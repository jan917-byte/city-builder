"""Repère des rives et contour de la crue dessiné par l'auteur."""

# Limite orientale relevée sur l'annotation du 2026-09-16, en EPSG:25832.
# Le dépôt peut couper un îlot ; les limites cadastrales ne le commandent pas.
LIMITE_DEPOT_EST = (
    (500827.0, 5600040.0), (500805.0, 5600135.0),
    (500775.0, 5600200.0), (500746.0, 5600250.0),
    (500729.0, 5600300.0), (500724.0, 5600350.0),
    (500725.0, 5600400.0), (500727.0, 5600430.0),
    (500705.0, 5600470.0), (500674.0, 5600510.0),
    (500655.0, 5600550.0), (500659.0, 5600590.0),
    (500651.0, 5600620.0), (500674.0, 5600670.0),
    (500674.0, 5600710.0), (500687.0, 5600755.0),
    (500682.0, 5600775.0),
)


class Rives:
    def __init__(self, anneaux):
        self.anneaux = [list(a) + [a[0]] for a in anneaux]
        self.coupes = {}

    def coupe(self, y):
        if y not in self.coupes:
            xs = []
            for anneau in self.anneaux:
                for a, b in zip(anneau, anneau[1:]):
                    if (a[1] <= y < b[1]) or (b[1] <= y < a[1]):
                        xs.append(a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]))
            self.coupes[y] = (min(xs), max(xs)) if xs else None
        return self.coupes[y]

    def rive(self, p):
        coupe = self.coupe(p[1])
        if coupe is None:
            return "droite"
        return "gauche" if p[0] > sum(coupe) / 2 else "droite"


def limite_est(y, contour=LIMITE_DEPOT_EST):
    for a, b in zip(contour, contour[1:]):
        if a[1] <= y <= b[1]:
            return a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1])
    return None
