import math

class Module():
    def __init__(self, name, speed, ap, kinetic, maxLength = None):
        self.name = name
        self.speed = speed
        self.ap = ap
        self.kinetic = kinetic
        self.maxLength = maxLength

    def __str__(self):
        return self.name

MODULES = {
    'head_ap' : Module('Head, AP Capped', 1.5, 3.5, 7.5),
    'head_composite' : Module('Head, Composite', 1.6, 4.5, 5.0),
    'head_sabot' : Module('Head, Sabot', 2.05, 6.75, 1.8),
    'head_hollow_point' : Module('Head, Hollow Point', 1.4, 0.25, 1.2),
    'body_gravity_compensator' : Module('Body, Gravity Compensator', 0.9, 0.4, 0.6),
    'body_sabot' : Module('Body, Sabot', 1.75, 3.6, 2.7),
    'body_solid' : Module('Body, Solid', 1.3, 2, 5),
    'base_bleeder' : Module('Base, Bleeder', 1.1, 1.0, 1.0, 0.1),
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

def apArmourFactor(ap, armour):
    return min(0.05 + 0.45 * ap / armour, 1.0)

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

    def statString(self):
        return '%0.1f speed, %0.1f kinetic, %0.1f ap, %0.1f ammo, %0.1f burn length' % (
            self.speed(), self.kinetic(), self.ap(), self.ammo(), self.burnLength())

    def moduleString(self):
        modules = '[' + ' + '.join(
            [str(module) for module in head] +
            ['%d body_sabot' % self.sabots] +
            ['%d body_solid' % self.solids] + 
            [str(module) for module in base] +
            ['%d propellant' % self.propellants]) + ']'
        return '%dmm %s' % (self.gauge * 1000.0, modules)

    def moduleVolume(self):
        return 0.25 * math.pi * self.gauge**3.0

    def moduleVolumeNormalized(self):
        return (self.gauge / 0.2)**3.0

    def shellLength(self):
        return sum(min(module.maxLength or gauge, gauge) for module in self.shellModules())

    def propellantLength(self):
        return self.gauge * self.propellants

    def length(self):
        return self.shellLength() + self.propellantLength()

    def shellModuleCount(self):
        return len(head) + self.sabots + self.solids + len(base)

    def moduleCount(self):
        return self.shellModuleCount() + self.propellants

    def hasEvenModuleCount(self):
        return self.moduleCount() % 2 == 0

    def shellVolume(self):
        return self.shellLength() * 0.25 * math.pi * self.gauge**2.0

    def shellVolumeNormalized(self):
        return self.shellLength() / 0.2 * (self.gauge / 0.2)**2.0

    def ammo(self):
        return 8.0 * self.moduleVolumeNormalized() ** 0.5 * self.moduleCount()

    def speedModifier(self):
        return exponentialWeightedMean((module.speed for module in self.shellModules()), base = 0.75)

    def apModifier(self):
        return exponentialWeightedMean((module.ap for module in self.shellModules(nullPad = True)), base = 0.75)

    def kineticModifier(self):
        return exponentialWeightedMean((module.kinetic for module in self.shellModules(nullPad = True)), base = 1.0)

    def speed(self):
        result = (
            700.0 *
            self.propellantLength() / self.length() *
            self.speedModifier() *
            self.shellVolume()**0.03)
        if any('Bleeder' in module.name for module in self.base):
            result *= 1.2
        return result
            
    def ap(self):
        if any('Hollow' in module.name for module in self.head): return 6.0
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

    def burnLength(self):
        return 12.0 * (self.propellants * self.gauge)**0.75

def makeScoreFunction(speedPower = 1.0,
                      apPower = 0.0,
                      armour = None,
                      maxDamage = None,
                      maxBurnLength = None):
    def result(cartridge):
        if maxBurnLength is not None and cartridge.burnLength() > maxBurnLength: return 0.0
        
        if armour is None:
            damage = cartridge.kinetic()
        else:
            damage = cartridge.kinetic() * apArmourFactor(cartridge.ap(), armour)

        if maxDamage is not None:
            damage = min(damage, maxDamage)

        return damage * cartridge.speed() ** speedPower * cartridge.ap() ** apPower / cartridge.ammo()
    return result

def bodyPropellantIterator(gauge, head, base, maxModuleCount, scoreFunction):
    for sabots in range(maxModuleCount):
        for solids in range(maxModuleCount):
            for propellants in range(maxModuleCount):
                cartridge = KineticCartridge(gauge, head, sabots, solids, base, propellants)
                if cartridge.length() > 8: continue
                if not cartridge.hasEvenModuleCount(): continue
                if cartridge.moduleCount() > maxModuleCount: continue
                yield cartridge

standardHeads = [
    [MODULES['head_ap']],
    [MODULES['head_composite']],
    [MODULES['head_sabot']],
    ]

hollowPointHeads = [
    [MODULES['head_hollow_point']],
    ]

standardBases = [
    [],
    [MODULES['base_bleeder']],
    ]

scoreFunction = makeScoreFunction(speedPower = 1.0, armour = 10.0)

for gauge in [0.15]:
    for head in standardHeads:
        for base in standardBases:
            score, cartridge = max((scoreFunction(cartridge), cartridge)
                                   for cartridge in bodyPropellantIterator(gauge, head, base, 50, scoreFunction))
            print('----')
            print('%d' % score)
            print(cartridge.statString())
            print(cartridge.moduleString())

