import math

def reflectChance(degrees, ap, strength):
    return math.sin(math.radians(degrees)) ** (max(1, ap) / max(1, 4 * strength))

def reflectChanceAngle(chance, ap, strength):
    ratio = (max(1, ap) / max(1, 4 * strength))
    return math.degrees(math.asin(chance ** (1 / ratio)))

aps = [1, 2, 5, 10, 15, 20, 25, 50]
angles = [1, 2, 5, 10, 15, 30, 45, 60, 75]
ratios = [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0]
chances = [0.25, 0.5, 0.75, 0.9, 0.95, 0.99]

# chance

result = '{|class = "wikitable"\n'
result += '! AP / Strength '

for angle in angles:
    result += '!! %d° ' % angle 

result += '\n'

for ratio in ratios:
    result += '|-\n'
    result += '| %0.1f ' % ratio
    for angle in angles:
        chance = reflectChance(angle, ratio * 10.0, 10.0)
        result += '|| %0.1f%% ' % (chance * 100.0)
    result += '\n'

result += '|}'

print(result)

# angle

result = '{|class = "wikitable"\n'
result += '! AP / Strength '

for chance in chances:
    result += '!! %d%% ' % (chance * 100.0)

result += '\n'

for ratio in ratios:
    result += '|-\n'
    result += '| %0.1f ' % ratio
    for chance in chances:
        angle = reflectChanceAngle(chance, ratio * 10.0, 10.0)
        result += '|| %0.1f° ' % angle
    result += '\n'

result += '|}'

print(result)

# efficiencies
