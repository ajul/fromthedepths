import math

rpCosts = {
    'base' : 15000,
    'clip' : 170,
    'feeder' : 200,
    'loader' : 680,
    }

rpCosts2 = {
    'base' : 40000,
    'clip' : 300,
    'feeder' : 200,
    'loader' : 860,
    }

blockCountCosts = {
    'base' : 20,
    'clip' : 1,
    'feeder' : 1,
    'loader' : 1,
    }

blockCountCosts2 = {
    'base' : 20,
    'clip' : 2,
    'feeder' : 1,
    'loader' : 2,
    }

massCosts = {
    'base' : 10,
    'clip' : 0.1,
    'feeder' : 0.1,
    'loader' : 0.3,
    }

# clipsPerLoader, feedersPerLoader
configurations = [
    (-1, 2),
    (-1, 3),
    (-1, 4),
    (-1, 5),
    (-1, 6),
    (0, 1),
    (1, 2),
    (1, 1),
    (2, 2),
    (2, 1),
    (3, 2),
    #(3, 1), # too large
    (4, 3),
    (4, 2),
    #(4, 1), # too large
    ]

def computeLoaderClipMult(clipsPerLoader):
    if clipsPerLoader == 0:
        return 2/3
    else:
        return math.sqrt(clipsPerLoader)

def computeLoaderCost(loaders, clipsPerLoader, feedersPerLoader, blockCosts):
    unitCost = (blockCosts['loader'] +
                blockCosts['clip'] * abs(clipsPerLoader) +
                blockCosts['feeder'] * feedersPerLoader)
    return unitCost * loaders

def computeRateOfFire(loaders, clipsPerLoader, feedersPerLoader):
    if clipsPerLoader >= 0:
        feederRate = loaders * feedersPerLoader
        loaderRate = 2 * computeLoaderClipMult(clipsPerLoader) * loaders ** 0.75
        return min(feederRate, loaderRate)
    else:
        feedTime = 1 / feedersPerLoader
        loadTime = 0.1 * loaders ** 0.25
        return loaders / (feedTime + loadTime)

def computeScore(loaders, clipsPerLoader, feedersPerLoader, blockCosts):
    totalCost = blockCosts['base'] + computeLoaderCost(loaders, clipsPerLoader, feedersPerLoader, blockCosts)
    rateOfFire = computeRateOfFire(loaders, clipsPerLoader, feedersPerLoader)
    return blockCosts['base'] * rateOfFire / totalCost
    
def optimize(blockCosts):
    for clipsPerLoader, feedersPerLoader in configurations:
        prevScore = 0
        prevTotalCost = 0
        prevRateOfFire = 0
        for loaders in range(400):
            totalCost = blockCosts['base'] + computeLoaderCost(loaders, clipsPerLoader, feedersPerLoader, blockCosts)
            rateOfFire = computeRateOfFire(loaders, clipsPerLoader, feedersPerLoader)
            score = blockCosts['base'] * rateOfFire / totalCost
            # concave down
            if score < prevScore:
                s = 'Configuration: %3d loaders with %d clips and %d feeder(s) each\n' % (loaders - 1, clipsPerLoader, feedersPerLoader)
                s += 'Rate of fire %6.2f / cost %6d = score %6.2f \n' % (prevRateOfFire, prevTotalCost, prevScore)
                print(s)
                break
            prevScore = score
            prevTotalCost = totalCost
            prevRateOfFire = rateOfFire

optimize(rpCosts2)
