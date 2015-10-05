import math

def energyProportionUse(d):
    return 1 - 0.8 ** (d + 1)

def energyUse(c, d):
    return 100 * c * energyProportionUse(d)

c = 1
for d in range(1, 21):
    while energyUse(c + 2, d - 1) > energyUse(c, d):
        c += 1
    print('|-\n| %d || %d || %d || %0.1f%% || %0.1f ' % (d, c, energyUse(c, d) / 25, energyProportionUse(d) * 100, energyUse(c, d)))
