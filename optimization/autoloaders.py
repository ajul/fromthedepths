import math

costs = {
    'clip' : 170,
    'feeder' : 200,
    'loader' : 680,
    }

# clipsPerLoader, feedersPerLoader
configurations = [
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

def computeLoaderCost(loaders, clipsPerLoader, feedersPerLoader):
    unitCost = (costs['loader'] +
                costs['clip'] * clipsPerLoader +
                costs['feeder'] * feedersPerLoader)
    return unitCost * loaders

def computeRateOfFire(loaders, clipsPerLoader, feedersPerLoader):
    feederRate = loaders * feedersPerLoader
    loaderRate = 2 * math.sqrt(clipsPerLoader) * loaders ** 0.75
    return min(feederRate, loaderRate)
    
def optimize(fixedCost):
    for clipsPerLoader, feedersPerLoader in configurations:
        prevScore = 0
        prevTotalCost = 0
        prevRateOfFire = 0
        for loaders in range(400):
            totalCost = fixedCost + computeLoaderCost(loaders, clipsPerLoader, feedersPerLoader)
            rateOfFire = computeRateOfFire(loaders, clipsPerLoader, feedersPerLoader)
            score = 1e6 * rateOfFire / totalCost
            if score < prevScore:
                s = 'Configuration: %3d loaders with %d clips and %d feeder(s) each\n' % (loaders - 1, clipsPerLoader, feedersPerLoader)
                s += 'Rate of fire %6.2f / cost %6d = score %4.1f u\n' % (prevRateOfFire, prevTotalCost, prevScore)
                print(s)
                break
            prevScore = score
            prevTotalCost = totalCost
            prevRateOfFire = rateOfFire

optimize(15000)
