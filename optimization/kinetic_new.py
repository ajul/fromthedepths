import math

class Module():
    def __init__(self, name, speed, ap, kinetic):
        self.name = name
        self.speed = speed
        self.ap = ap
        self.kinetic = kinetic

MODULES = {
    'head_ap' : Module('Head, AP Capped', 1.5, 3.5, 7.5),
    'head_composite' : Module('Head, Composite', 1.6, 4.5, 5.0),
    'head_sabot' : Module('Head, Sabot', 2.05, 6.75, 1.8),
    'head_hollow_point' : Module('Head, Hollow Point', 1.4, 0.25, 1.2),
    'body_gravity_compensator' : Module('Body, Gravity Compensator', 0.9, 0.4, 0.6),
    'body_sabot' : Module('Body, Sabot', 1.75, 3.6, 2.7),
    'body_solid' : Module('Body, Solid', 1.3, 2, 5),
    'base_bleeder' : Module('Base, Bleeder', 1.1, 1.0, 1.0),
    'base_supercavitation' : Module('Base, Supercavitation', 0.9, 0.4, 0.6),
    'base_graviton_ram' : Module('Base, Graviton Ram', 0.9, 0.5, 1.0),
    'null' : Module('Null', None, 0.5, 0.5),
}

def exponentialWeightedMean(iterator, base):
    iteratorList = [x for x in iterator]
    return (
        sum(value * base ** i for i, value in enumerate(iteratorList)) /
        sum(base ** i for i, value in enumerate(iteratorList)) 
        )

class KineticCartridge():
    def __init__(self, gauge, head, sabots, solids, base, propellants):
        self.gauge = gauge
        self.head = head
        self.sabots = sabots
        self.solids = solids
        self.base = base
        self.propellants = propellants

    def shellModules(self, nullPad = False):
        for module in self.head: yield module
        for i in range(self.sabots): yield MODULES['body_sabot']
        for i in range(self.solids): yield MODULES['body_solid']
        for module in self.base: yield module
        if nullPad:
            for i in range(3 - self.shellModuleCount()): yield MODULES['null']

    def moduleString(self):
        return ', '.join([
            ', '.join(head),
            '%d body_sabot' % self.sabots,
            '%d body_solid' % self.solids,
            ', '.join(base),
            '%d propellant' % self.propellants])

    def moduleVolume(self):
        return 0.25 * math.pi * gauge**3.0

    def moduleVolumeNormalized(self):
        return (gauge / 0.2)**3.0

    def shellModuleCount(self):
        return len(head) + self.sabots + self.solids + len(base)

    def moduleCount(self):
        return self.shellModuleCount() + self.propellants

    def shellVolume(self):
        return self.shellModuleCount() * self.moduleVolume()

    def shellVolumeNormalized(self):
        return self.shellModuleCount() * self.moduleVolumeNormalized()

    def ammo(self):
        return 8.0 * self.moduleVolumeNormalized() * self.moduleCount()

    def speedModifier(self):
        return exponentialWeightedMean(module.speed for module in self.shellModules(), base = 0.75)

    def apModifier(self):
        return exponentialWeightedMean(module.ap for module in self.shellModules(nullPad = True), base = 0.75)

    def kineticModifier(self):
        return exponentialWeightedMean(module.kinetic for module in self.shellModules(nullPad = True), base = 1.0)

    def speed(self):
        result = (
            700.0 *
            self.propellants / self.moduleCount *
            self.speedModifier() *
            self.shellVolume()**0.03)
        if any('Bleeder' in module.name for module in self.base):
            result *= 1.2
        return result
            
    def ap(self):
        return (
            0.01 *
            self.apModifier() *
            self.speed())

    def kinetic(self):
        return (
            1.25 *
            self.kineticModifier() *
            self.speed() *
            self.shellVolumeNormalized() ** 0.65)
    
