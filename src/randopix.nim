import httpClient, json, os, options, strformat
import gintro/[gtk, glib, gobject, gio, gdkpixbuf]
import argparse except run

const
  version = "0.1"
  floofUrl = "https://randomfox.ca/floof/"

type
  Mode {.pure.} = enum
    Foxes = "foxes"     ## Some nice foxes
    Inspiro = "inspiro" ## Inspiring nonsense 

var
  client = newHttpClient()
  window: ApplicationWindow
  imageWidget: Image
  fullscreen = true
  mode: Option[Mode]
  argParser = newParser("randopix"):
    help(fmt"Version {version} - Display random images from different sources")
    option("-m", "--mode", help="foxes, inspiro, inspiro-xmas")
    flag("-w", "--windowed", help="Do not start in fullscreen mode")

proc downloadFox(): Pixbuf =
  let urlData = client.getContent(floofUrl)
  let info = parseJson(urlData)
  let imageData = client.getContent(info["image"].getStr)
  let loader = newPixbufLoader()
  discard loader.write(imageData)
  loader.getPixbuf()

proc resizeImage(pixbuf: Pixbuf): Pixbuf = 
  var wWidth, wHeight, width, height: int
  window.getSize(wWidth, wHeight)

  if (wWidth > wHeight):
    height = wHeight
    width = ((pixbuf.width * height) / pixbuf.height).toInt 
  else:
    width = wWidth
    height = ((pixbuf.height * width) / pixbuf.width).toInt

  pixbuf.scaleSimple(width, height, InterpType.bilinear)

proc getImage(): Option[Pixbuf] = 
  if mode.isSome:
    case mode.get
    of Mode.Foxes:
      result = some(downloadFox())
    of Mode.Inspiro:
      echo "Not Implemented"

proc updateImage(action: SimpleAction; parameter: Variant;) =
  let data = getImage();
  if (data.isNone): return
  var pixbuf = data.get().resizeImage()
  imageWidget.setFromPixbuf(pixbuf)

proc toggleFullscreen(action: SimpleAction; parameter: Variant; window: ApplicationWindow) =
  if fullscreen:
    window.unfullscreen
  else:
    window.fullscreen
  fullscreen = not fullscreen

proc quit(action: SimpleAction; parameter: Variant; app: Application) = 
    app.quit()

proc applyStyle(window: Window) =
  let cssProvider = newCssProvider()
  let data = "window { background: black; }"
  discard cssProvider.loadFromData(data)
  let styleContext = window.getStyleContext()
  styleContext.addProvider(cssProvider, STYLE_PROVIDER_PRIORITY_USER)
  
proc connectSignals(app: Application) =
  ## Connect th GTK signals to the procs 
  let fullscreenAction = newSimpleAction("fullscreen")
  discard fullscreenAction.connect("activate", toggleFullscreen, window)
  app.setAccelsForAction("win.fullscreen", "F")
  window.actionMap.addAction(fullscreenAction)

  let quitAction = newSimpleAction("quit")
  discard quitAction.connect("activate", quit, app)
  app.setAccelsForAction("win.quit", "Escape")
  window.actionMap.addAction(quitAction)

  let updateImageAction = newSimpleAction("update")
  discard updateImageAction.connect("activate", updateImage)
  app.setAccelsForAction("win.update", "U")
  window.actionMap.addAction(updateImageAction)

proc parseArgs(): void =
  ## Parse and apply options from the command line
  let opts = argparser.parse(commandLineParams())
  fullscreen = not opts.windowed
  if (opts.mode != ""):
    try:
      mode = some(parseEnum[Mode](opts.mode))
    except ValueError:
      echo "Invaild image source: ", opts.mode

proc appActivate(app: Application) =
  parseArgs()
  # No mode was given, exit and display the help text
  if (mode.isNone):
    echo argParser.help
    return

  window = newApplicationWindow(app)
  window.title = "Randopics"
  window.setKeepAbove(true)
  window.setDefaultSize(600, 600)

  # Custom styling for e.g. the background color
  window.applyStyle

  imageWidget = newImage()
  window.add(imageWidget)
  
  if fullscreen:
    window.fullscreen

  app.connectSignals
  window.showAll

when isMainModule:
  let app = newApplication("org.gtk.example")
  connect(app, "activate", appActivate)
  discard run(app)