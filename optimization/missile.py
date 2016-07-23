class Missile():
    def __init__(self, baseDrags, warheads, fuelTanks, fins, propellers=0):
        self.warheads = warheads
        self.fuelTanks = fuelTanks
        self.fins = fins
        self.propellers = propellers
        self.drags = baseDrags + [0.02] * (warheads + fuelTanks + propellers) + [0.05] * fins

    def fuelScore(self):
        totalDrag = 1
        for i, drag in enumerate(self.drags):
            totalDrag += 10.0 * drag / (i + 1.0)
        if self.propellers == 0:
            effectiveTanks = self.fuelTanks
        else:
            effectiveTanks = min(self.fuelTanks, self.propellers * 15 / 50)
        return effectiveTanks / len(self.drags) / totalDrag

    def finScore(self):
        return self.fins / len(self.drags)
        
    def score(self, warheadPower = 0.8, fuelPower = 1.0, finPower = 0.5):
        return (self.warheads ** warheadPower
                * self.fuelScore() ** fuelPower
                * self.finScore() ** finPower) / len(self.drags)

    def printScore(self, *args, **kwargs):
        score = self.score(*args, **kwargs)
        print('%d warheads, %d fuel tanks, %d fins, %d propellers -> %f score' % (
            self.warheads, self.fuelTanks, self.fins, self.propellers, self.score()))

    def modules(self):
        return len(self.drags)

        
baseDrags = [0.01, 0.02] # Lua transceiver, VT

scoreArgs = {
    'warheadPower' : 0.8,
    'fuelPower' : 1.0,
    'finPower' : 0.5,
    }

print('Air missiles (Lua)')

for warheads in range(1, 10):
    bestMissile = None
    for fuelTanks in range(2, 10):
        for fins in range(1, 10):
            missile = Missile(baseDrags, warheads, fuelTanks, fins)
            if missile.modules() % 2 != 0: continue
            if bestMissile is None or missile.score(**scoreArgs) > bestMissile.score(**scoreArgs):
                bestMissile = missile
    bestMissile.printScore()

print('Torpedoes (Lua)')
for warheads in range(1, 10):
    bestMissile = None
    for fuelTanks in range(2, 10):
        for fins in range(1, 10):
            for propellers in range(1, 12):
                missile = Missile(baseDrags, warheads, fuelTanks, fins, propellers)
                if missile.modules() % 2 != 0: continue
                if bestMissile is None or missile.score(**scoreArgs) > bestMissile.score(**scoreArgs):
                    bestMissile = missile
    bestMissile.printScore(**scoreArgs)
