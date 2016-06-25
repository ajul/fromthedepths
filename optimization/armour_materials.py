import numpy
import matplotlib.pyplot as plt

class Material():
    def __init__(self, name, hp, rp, ac, color):
        self.name = name
        self.hp = hp
        self.rp = rp
        self.ac = ac
        self.color = color

    def damageMultiplierVsAP(self, ap):
        return numpy.minimum(0.05 + 0.45 * ap / self.ac, 1.0)

    def damageMultiplierVsExplosive(self):
        return 1.0 / numpy.sqrt(self.ac)

    def effectiveHPPerRPVsAP(self, ap):
        return self.hp / self.rp / self.damageMultiplierVsAP(ap)

    def effectiveHPPerRPVsExplosive(self):
        return self.hp / self.rp / self.damageMultiplierVsExplosive()

    def plot(self, ap_values):
        plt.plot(ap_values, 1.0 / self.effectiveHPPerRPVsAP(ap_values),
                 color = self.color)
        plt.plot(ap_values, numpy.ones_like(ap_values) / self.effectiveHPPerRPVsExplosive(),
                 color = self.color, linestyle = '--')

    def plotRelative(self, ap_values, baseline):
        plt.plot(ap_values,
                 self.effectiveHPPerRPVsAP(ap_values) /
                 baseline.effectiveHPPerRPVsAP(ap_values),
                 color = self.color)
        plt.plot(ap_values, numpy.ones_like(ap_values) *
                 self.effectiveHPPerRPVsExplosive() /
                 baseline.effectiveHPPerRPVsExplosive(),
                 color = self.color, linestyle = '--')

    def legend(self):
        return [self.name, self.name + ' vs. explosive']

wood = Material('Wood', 120.0, 10.0, 3.0, (1.0, 0.5, 0.0))
stone = Material('Stone', 220.0, 30.0, 5.0, (0.75, 0.75, 0.0))
metal = Material('Metal', 280.0, 65.0, 10.0, (0.0, 0.0, 0.0))
alloy = Material('Alloy', 140.0, 170.0, 5.0, (0.0, 1.0, 1.0))
heavy_armour = Material('Heavy armour', 1000.0, 2000.0, 40.0, (0.5, 0.0, 1.0))

ap_values = numpy.arange(0.0, 40 + 0.5/8, 1/8)

materials = [wood, stone, metal, heavy_armour]

fig = plt.figure(figsize=(16, 9))

for material in materials: material.plotRelative(ap_values, metal)

legend = sum([material.legend() for material in materials], [])

plt.legend(legend, loc = 'upper left')
plt.xlabel('AP')
plt.ylabel('EHP / RP relative to metal')
plt.title('EHP per RP relative to metal (higher is better)')

plt.savefig("armour_materials.png", dpi = 60, bbox_inches = "tight")
plt.show()
