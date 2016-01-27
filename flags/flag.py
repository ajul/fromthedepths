import math
from PIL import Image, ImageDraw

rawResolution = 2048
finalResolution = 512

flagAspectRatio = 1.5

iconImage = Image.new("RGB", (rawResolution, rawResolution))
flagImage = Image.new("RGB", (round(rawResolution * flagAspectRatio), rawResolution))

iconDraw = ImageDraw.Draw(iconImage)
flagDraw = ImageDraw.Draw(flagImage)

def iconXY(xy):
    return [(round((x + 0.5) * rawResolution),
             round((0.5 - y) * rawResolution)) for x, y in xy]

def flagXY(xy):
    return [(round((x + 0.5 * flagAspectRatio) * rawResolution),
             round((0.5 - y) * rawResolution)) for x, y in xy]

def drawLine(xy, width, **kwargs):
    iconDraw.line(iconXY(xy),
                  width = round(width * rawResolution), **kwargs)
    flagDraw.line(flagXY(xy),
                  width = round(width * rawResolution), **kwargs)

def drawPolygon(xy, **kwargs):
    iconDraw.polygon(iconXY(xy), **kwargs)
    flagDraw.polygon(flagXY(xy), **kwargs)

# red hexagon
hexRadius = 1/4
hexXY = [(hexRadius * math.cos(math.radians(angle)),
          hexRadius * math.sin(math.radians(angle))) for angle in range(0, 360, 60)]
drawPolygon(hexXY, fill=(170, 0, 0))

# white "aperture"
apertureLineWidth = 1/8
for angle in range(0, 360, 60):
    start = (hexRadius * math.cos(math.radians(angle)),
             hexRadius * math.sin(math.radians(angle)))
    end = (2.0 * math.cos(math.radians(angle + 120)) + start[0],
           2.0 * math.sin(math.radians(angle + 120)) + start[1])
    xy = [start, end]
    drawLine(xy, apertureLineWidth, fill=(255, 255, 255))

# green "aperture"
apertureLineWidth = 1/32
for angle in range(0, 360, 60):
    start = (hexRadius * math.cos(math.radians(angle)),
             hexRadius * math.sin(math.radians(angle)))
    end = (2.0 * math.cos(math.radians(angle + 120)) + start[0],
           2.0 * math.sin(math.radians(angle + 120)) + start[1])
    xy = [start, end]
    drawLine(xy, apertureLineWidth, fill=(0, 85, 0))

iconImage.resize((finalResolution, finalResolution), Image.ANTIALIAS).save("out/icon.png")
flagImage = flagImage.resize((round(finalResolution * flagAspectRatio), finalResolution), Image.ANTIALIAS)
flagImage.save("out/flag.png")
flagImage.transpose(Image.FLIP_LEFT_RIGHT).save("out/flag_reverse.png")
# http://imgur.com/a/tFKpr
