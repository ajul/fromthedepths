import math

class Module():
    def __init__(self, name, speed, ap, kinetic):
        self.name = name
        self.speed = speed
        self.ap = ap
        self.kinetic = kinetic

Module.null = Module('Null', None, 0.5, 0.5)

def exponentialWeightedMean(iterator, base):
    iteratorList = [x for x in iterator]
    return (
        sum(value * base ** i for i, value in enumerate(iteratorList)) /
        sum(base ** i for i, value in enumerate(iteratorList)) 
        )

def speedModifier(modules):
    return exponentialWeightedMean((module.speed for module in modules), base = 0.75)

def apModifier(modules):
    if len(modules) < 3:
        modules = modules + [Module.null] * (3 - len(modules))

    return exponentialWeightedMean((module.ap for module in modules), base = 0.75)

def kineticModifier(modules):
    if len(modules) < 3:
        modules = modules + [Module.null] * (3 - len(modules))
    return exponentialWeightedMean((module.kinetic for module in modules), base = 1.0)

def shellVolume(shellCount, gauge):
    return 0.25 * math.pi * shellCount * gauge**3.0

def computeAmmoCost(shellModules, propellantCount, gauge):
    shellCount = len(shellModules)
    return 8.0 * (shellCount + propellantCount) * math.sqrt((gauge/0.2)**3.0)

def computeMuzzleVelocity(shellModules, propellantCount, gauge):
    shellCount = len(shellModules)
    result = (700.0 *
              propellantCount / (propellantCount + shellCount) *
              speedModifier(shellModules) *
              shellVolume(shellCount, gauge)**0.03
              )
    if any('Bleeder' in module.name for module in shellModules): result *= 1.2
    return result

def computeKineticDamage(shellModules, propellantCount, gauge):
    return (1.25 *
            kineticModifier(shellModules) *
            computeMuzzleVelocity(shellModules, propellantCount, gauge) *
            math.sqrt(len((shellModules)) * (gauge / 0.2)**3.0)
            )

def computeAP(shellModules, propellantCount, gauge):
    return (0.01 *
            apModifier(shellModules) *
            computeMuzzleVelocity(shellModules, propellantCount, gauge)
            )

def computePenetrationFactor(ap, armour):
    return min(0.05 + 0.45 * ap / armour, 1.0)

modules = {
    'head_ap' : Module('Head, AP Capped', 1.5, 3.5, 7.5),
    'head_composite' : Module('Head, Composite', 1.6, 4.5, 5.0),
    'head_sabot' : Module('Head, Sabot', 2.05, 6.75, 1.8),
    'body_sabot' : Module('Body, Sabot', 1.75, 3.6, 2.7),
    'body_solid' : Module('Body, Solid', 1.3, 2, 5),
    'base_bleeder' : Module('Base, Bleeder', 1.1, 1.0, 1.0),
}

maxModuleCount = 54 # 8 = 125 mm
testGauge = 1.0 / maxModuleCount
testArmour = 10

def allBodiesIterator(bodyCount):
    if bodyCount == 0:
        yield []
    else:
        for restOfBody in bodiesIterator(bodyCount - 1):
            yield ['body_sabot'] + restOfBody
            yield ['body_solid'] + restOfBody

# kinetic has better weight at rear relative to ap
def sabotFirstBodiesIterator(bodyCount):
    for i in range(0, bodyCount + 1):
        yield ['body_sabot'] * i + ['body_solid'] * (bodyCount - i)

def testShellsIterator(maxBodyCount):
    for head in ['head_ap', 'head_composite', 'head_sabot']:
        for bodyCount in range(maxBodyCount + 1):
            for bodies in sabotFirstBodiesIterator(bodyCount):
                yield [head] + bodies # + ['base_bleeder']

bestScoreOverall = 0.0
bestShellOverall = None

for shell in testShellsIterator(4):
    shellCount = len(shell)

    if shellCount >= 0.4 * maxModuleCount: continue
    
    shellModules = [modules[moduleKey] for moduleKey in shell]
    print('-' * 64)
    print('Shell: %s' % shell)
    print('Speed, AP, Kinetic modifier: %0.3f, %0.3f, %0.3f' % (speedModifier(shellModules),
                                                                apModifier(shellModules),
                                                                kineticModifier(shellModules)))
    print()

    propellantCount = shellCount

    bestScore = 0.0 # net damage per ammo
    bestPropellantCount = propellantCount
    maxPropellantCount = min(3 * shellCount, maxModuleCount - shellCount)
    while propellantCount <= maxPropellantCount:
        vel = computeMuzzleVelocity(shellModules, propellantCount, testGauge)
        kd = computeKineticDamage(shellModules, propellantCount, testGauge)
        ap = computeAP(shellModules, propellantCount, testGauge)
        netDamage = kd * computePenetrationFactor(ap, testArmour)
        ammoCost = computeAmmoCost(shellModules, propellantCount, testGauge)
        score = vel * netDamage / ammoCost
        if score > bestScore:
            bestScore = score
            bestPropellantCount = propellantCount
        propellantCount += 2

    print('Best props: %d' % bestPropellantCount)
    print('Velocity, AP, Kinetic : %0.1f, %0.1f, %0.1f' % (computeMuzzleVelocity(shellModules, bestPropellantCount, testGauge),
                                                           computeAP(shellModules, bestPropellantCount, testGauge),
                                                           computeKineticDamage(shellModules, bestPropellantCount, testGauge),
                                                           ))
    print('Ammo cost: %0.1f' % computeAmmoCost(shellModules, bestPropellantCount, testGauge))
    print('Score: %0.1f' % bestScore)

    if bestScore > bestScoreOverall:
        bestScoreOverall = bestScore
        bestShellOverall = shell

print('-' * 64)
print('Grand champion: %s (%0.2f)' % (bestShellOverall, bestScoreOverall))
