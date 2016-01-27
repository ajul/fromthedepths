import numpy
import scipy.optimize

# slope, forwardCD, sideCD
shapes = [
    (0.25, 0.1),
    (0.5, 0.2),
    (1, 0.4),
    (2, 0.8),
    (4, 1),
    ]

skinDragMult = 0.01

def pyramidalForm(x):
    currentRadius = 1.0
    forwardDrag = 0.0
    sideArea = 0.0
    volume = 0.0
    
    # flat side
    sideArea += 2 * x[0]
    volume += x[0]

    # faces
    for i, (slope, forwardCD) in enumerate(shapes):
        length = x[i+1]
        nextRadius = currentRadius - length * slope
        forwardDrag += abs((currentRadius * currentRadius) - (nextRadius * nextRadius)) * forwardCD
        sideArea += abs(currentRadius + nextRadius) * length
        volume += 1/3 * length * abs(currentRadius * currentRadius + nextRadius * nextRadius + currentRadius * nextRadius)
        currentRadius = nextRadius

    # flat front
    forwardDrag += currentRadius * currentRadius
    return forwardDrag, sideArea, volume

def wedgeForm(x):
    currentRadius = 1.0
    forwardDrag = 0.0
    sideArea = 0.0
    volume = 0.0

    # flat side
    sideArea += 2 * x[0]
    volume += x[0]

    # faces
    for i, (slope, forwardCD) in enumerate(shapes):
        length = x[i+1]
        nextRadius = currentRadius - length * slope
        forwardDrag += abs(currentRadius - nextRadius) * forwardCD
        sideArea += (0.5 * abs(currentRadius + nextRadius) + 1) * length
        volume += 0.5 * abs(currentRadius + nextRadius) * length
        currentRadius = nextRadius

    # flat front
    forwardDrag += abs(currentRadius)
    return forwardDrag, sideArea, volume
    
def computeScore(form):
    def result(x):
        forwardDrag, sideArea, volume = form(x)
        totalDrag = forwardDrag + skinDragMult * sideArea
        return totalDrag ** (1/2) / (volume ** (1/3))
    return result

initial = numpy.array([6, 0, 0, 0, 0, 0])
bounds = [(0, None)] * (len(shapes) + 1)
method = "SLSQP"

result = scipy.optimize.minimize(computeScore(pyramidalForm), initial, method = method, bounds = bounds)
print(result.x, pyramidalForm(result.x), result.fun)

result = scipy.optimize.minimize(computeScore(wedgeForm), initial, method = method, bounds = bounds)
print(result.x, wedgeForm(result.x), result.fun)
