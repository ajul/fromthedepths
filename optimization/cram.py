import math

minGauge = 0.2
maxGauge = 2.0

def biam(base, count, increase, rolloff):
    return base + increase * (1 - rolloff ** count) / (1 - rolloff)

def lerp(x, x0, y0, x1, y1):
    p = (x - x0) / (x1 - x0)
    return p * (y1 - y0) + y0

def computeGauge(cram):
    result = biam(minGauge, cram["gauge"], 0.1, 0.95)
    return min(result, maxGauge)

def computeLowRelativeVolume(cram):
    return (computeGauge(cram) / 0.4) ** 1.5

def computeHighRelativeVolume(cram):
    return (computeGauge(cram) / 0.4) ** 1.8

def computeVelocity(cram):
    gaugeBase = lerp(computeGauge(cram), minGauge, 60, maxGauge, 100)
    barrelMult = biam(1, cram["barrel"], 0.1, 0.9)
    return gaugeBase * barrelMult

def computeAmmoUse(cram):
    return computeLowRelativeVolume(cram) * 20

def computeReloadTime(cram):
    base = computeLowRelativeVolume(cram)
    return base * (1 + 1 / math.sqrt(0.1 * (1 + 2 * cram["ammo"])))

def computePelletsPerSecond(cram):
    return 0.25 * cram["pellet"]

def computePelletsPerShot(cram):
    return computePelletsPerSecond(cram) * computeReloadTime(cram)

def computeDensity(cram):
    pellets = computePelletsPerShot(cram)
    density = pellets / computeHighRelativeVolume(cram)
    return density

def computeShotPower(cram):
    pellets = computePelletsPerShot(cram)
    density = computeDensity(cram)
    if density == 0: return 0
    power = biam(0, density, pellets / density, 0.9)
    return min(power, 40)

costs = {
    'gauge' : 200,
    'barrel' : 200,
    'ammo' : 300,
    'pellet' : 1000,
    }

def computeCost(cram):
    result = 300
    for key, value in cram.items():
        result += costs[key] * value
    return result

def computeScore(cram):
    return 1000.0 * computeVelocity(cram) * computeShotPower(cram) ** 2 / (computeCost(cram) * computeReloadTime(cram))

def statString(cram):
    result = ""
    result += "Score: %0.2f Cost: %d\n" % (computeScore(cram), computeCost(cram))
    result += "Blocks: gauge %(gauge)d, barrel %(barrel)d, ammo %(ammo)d, pellet %(pellet)d\n" % cram
    result += "Velocity: %0.1f\n" % (computeVelocity(cram))
    result += "Gauge: %0.1f mm\n" % (computeGauge(cram) * 1000)
    result += "Reload time: %0.2f (lowest possible %0.2f)\n" % (computeReloadTime(cram), computeLowRelativeVolume(cram))
    result += "Pellets: %0.1f per s, %0.1f per shot, %0.1f density\n" % (computePelletsPerSecond(cram), computePelletsPerShot(cram), computeDensity(cram))
    result += "Ammo use: %0.1f per shot, %0.1f per s\n" % (computeAmmoUse(cram), computeAmmoUse(cram) / computeReloadTime(cram))
    return result


initial = {
    'gauge' : 0,
    'barrel' : 0,
    'ammo' : 8,
    'pellet' : 0,
    }

def optimize(initial):
    currentCram = initial
    currentScore = computeScore(currentCram)
    improved = True
    while improved:
        improved = False
        for key in ['barrel', 'ammo', 'pellet', 'gauge']:
            newCram = currentCram.copy()
            newCram[key] += 1
            newScore = computeScore(newCram)
            if newScore > currentScore:
                print(statString(newCram))
                currentScore = newScore
                currentCram = newCram
                improved = True
    return currentCram

optCram = optimize(initial)
