block_cost = {
    'breech' : 225,
    'predictor' : 450,
    'ai' : 310,
    'elevation_and_motor_barrel' : 200,
    'standard_and_motor_barrel' : 170,
    'connector' : 450,
    'loader' : 190,
    'gauge' : 210,
    'ammo' : 105,
    'he' : 1480,
    'ap' : 420,
    }

connection_tax = (
    block_cost['connector'] +
    2 * block_cost['loader']
    ) / 8

for block in ('gauge', 'ammo', 'he', 'ap'):
    block_cost[block] += connection_tax

num_ammo = 30

block_cost['base'] = (
    block_cost['breech'] +
    block_cost['predictor'] +
    block_cost['ai'] +
    block_cost['elevation_and_motor_barrel'] +
    num_ammo * block_cost['ammo']
    )

def geo(n, base = 0.9):
    return (1 - base ** n) / (1 - base)

muzzle_velocity_per_gauge = 0.2

def muzzleVelocity(q):
    base = 50 + 10 * q['standard_and_motor_barrel']
    return base * (1 + geo(q['gauge']) * muzzle_velocity_per_gauge)

def damage(q):
    ap = (3 + geo(q['ap']))
    explosive = 10 * geo(q['he']) * ap # radius?
    return explosive

def cost(q):
    result = block_cost['base']
    for part, qty in q.items():
        result += qty * block_cost[part]
    return result

def objective(q):
    return damage(q) * muzzleVelocity(q)

start_q = {
    'standard_and_motor_barrel' : 6,
    'gauge' : 6,
    'he' : 21,
    'ap' : 0,
    }

max_q = {
    'standard_and_motor_barrel' : 6,
    'gauge' : 1000,
    'he' : 1000,
    'ap' : 1000,
    }

def optimize(q):
    ratio = objective(q) / cost(q)
    improved = True
    while improved:
        improved = False
        for part in q:
            if q[part] >= max_q[part]: continue
            new_q = q.copy()
            new_q[part] += 1
            new_ratio = objective(new_q) / cost(new_q)
            if new_ratio > ratio:
                print('Added %s (%d), ratio %0.3f' % (part, new_q[part], new_ratio))
                improved = True
                q = new_q
                ratio = new_ratio

    return q, ratio

opt_q, opt_ratio = optimize(start_q)

print(opt_q)
print(opt_ratio)
