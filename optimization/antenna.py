import math

def requiredAntennaStrength(altitude, target = 9000):
    baseVision = 6 + 0.006 * altitude
    neededVision = 60 - baseVision
    return (neededVision / (0.06 * math.sqrt(altitude))) ** (1 / 0.7)

def requiredFourClusters(strength):
    return math.sqrt(strength / 3)

print(requiredFourClusters(requiredAntennaStrength(24)))
