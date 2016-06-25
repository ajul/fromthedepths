import math

componentCosts = {
    'rp' : {
        'autoloader' : {
            1 : 680,
            2 : 860,
            3 : 955,
            4 : 1050,
            6 : 1165,
            8 : 1280,
            },
        'clip' : {
            1 : 170,
            2 : 300,
            3 : 365,
            4 : 430,
            6 : 495,
            8 : 560,
            },
        'feeder' : 200,
        'ejector' : 580,
        },
    # other cost metrics?
    }

scaleLetters = {
    '' : 1.0,
    'm' : 1.0e-3,
    'u' : 1.0e-6,
    }

class Magazine():
    def fireRate(self, **kwargs):
        raise NotImplementedError()

    def cost(self, costType, **kwargs):
        raise NotImplementedError()

    def optimisationIterator(self):
        # yield **kwargs to consider
        raise NotImplementedError()

    def score(self, costType, extraCostFunction, **kwargs):
        fireRate = self.fireRate(**kwargs)
        cost = self.cost(costType, **kwargs)
        totalCost = cost + extraCostFunction(fireRate)
        return fireRate / totalCost

    def optimise(self, costType, extraCostFunction):
        # costFunction should be a function of the fire rate
        return max(
            (self.score(costType, extraCostFunction, **kwargs), kwargs)
            for kwargs in self.optimisationIterator()
            )

    def printOptimal(self, costType, extraCostFunction, scaleLetter = ''):
        score, kwargs = self.optimise(costType, extraCostFunction)
        fireRate = self.fireRate(**kwargs)
        cost = self.cost(costType, **kwargs)
        totalCost = cost + extraCostFunction(fireRate)

        if len(kwargs) > 0:
            kwargString = 'Optimal: ' + ', '.join(
                ('%d %s' % (v, k)) for k, v in sorted(kwargs.items())) + '\n'
        else:
            kwargString = ''

        scoreString = 'Fire rate %0.1f / cost %d = score %0.1f%s' % (
            fireRate, totalCost, score / scaleLetters[scaleLetter], scaleLetter)

        print(str(self) + kwargString + scoreString)

class ConventionalMagazine(Magazine):
    def __init__(self, length=1, clipRatio=1, useEjectors=False):
        self.length = length
        self.clipRatio = clipRatio
        self.useEjectors = useEjectors

    def loadRate(self, autoloaderCount, feederRatio):
        if self.clipRatio > 0:
            return 2.0 * autoloaderCount ** 0.75 * math.sqrt(self.clipRatio * self.length)
        else:
            return (4.0/3.0) * autoloaderCount ** 0.75 * math.sqrt(self.length)

    def feedRate(self, autoloaderCount, feederRatio):
        return feederRatio * autoloaderCount

    def fireRate(self, **kwargs):
        return min(self.loadRate(**kwargs), self.feedRate(**kwargs))

    def costPerAutoloader(self, costType, feederRatio):
        return (
            componentCosts[costType]['autoloader'][self.length] +
            componentCosts[costType]['clip'][self.length] * self.clipRatio +
            componentCosts[costType]['feeder'] * feederRatio +
            componentCosts[costType]['ejector'] * self.useEjectors
            )

    def cost(self, costType, autoloaderCount, feederRatio):
        return self.costPerAutoloader(costType, feederRatio) * autoloaderCount

    def componentsPerAutoloader(self, feederRatio):
        return 1 + self.clipRatio + feederRatio + self.useEjectors

    def optimisationIterator(self):
        for feederRatio in range(1, self.clipRatio * 2 + 5):
            for autoloaderCount in range(1, 1000 // self.componentsPerAutoloader(feederRatio)):
                yield {
                    'autoloaderCount' : autoloaderCount,
                    'feederRatio' : feederRatio
                    }

    def attachmentString(self):
        return ('%dm length, %d clipRatio'
                % (self.length, self.clipRatio)
                + ', with ejectors' * self.useEjectors
                + '\n')

    def __str__(self):
        return 'Conventional autoloaders: ' + self.attachmentString()

class BeltfedMagazine(ConventionalMagazine):
    def loadRate(self, **kwargs):
        return 5.0 * ConventionalMagazine.loadRate(self, **kwargs)

    def fireRate(self, **kwargs):
        return 1.0 / (1.0 / self.loadRate(**kwargs)
                      + 1.0 / self.feedRate(**kwargs))

    def __str__(self):
        return 'Beltfed autoloaders: ' + self.attachmentString()

class DirectfedMagazine(Magazine):
    def __init__(self, feederRatio):
        self.feederRatio = feederRatio

    def fireRate(self):
        return self.feederRatio

    def cost(self, costType):
        return componentCosts[costType]['feeder'] * self.feederRatio

    def optimisationIterator(self):
        yield {}

    def __str__(self):
        return 'Directfed: %d feeder ratio\n' % self.feederRatio

magazinesToConsider = [
    DirectfedMagazine(4),
    BeltfedMagazine(length=1, clipRatio=1, useEjectors=True),
    ConventionalMagazine(length=8, clipRatio=0, useEjectors=True),
    ConventionalMagazine(length=8, clipRatio=2, useEjectors=True),
    ConventionalMagazine(length=8, clipRatio=4, useEjectors=True),

    BeltfedMagazine(length=1, clipRatio=1, useEjectors=False),
    ConventionalMagazine(length=8, clipRatio=0, useEjectors=False),
    ConventionalMagazine(length=8, clipRatio=2, useEjectors=False),
    ConventionalMagazine(length=8, clipRatio=4, useEjectors=False),
    ]

costType = 'rp'
extraCostFunction = lambda fireRate: 20000.0 - 760.0 * math.log(fireRate * 0.25, 0.92)

for magazine in magazinesToConsider:
    magazine.printOptimal(costType, extraCostFunction, 'u')
    print()
