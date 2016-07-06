y = 0
t = 0
v = 81.2
frameTime = 1/40

while y < 400 and y >= 0:
    t += frameTime
    y += v * frameTime
    v -= (400 - y) / 400 * 9.81 * frameTime

print(t, v)
