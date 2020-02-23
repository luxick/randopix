import os, httpClient, json, threadpool
import gintro/[gtk, glib, gobject, gio, gdkpixbuf]

var 
  window: ApplicationWindow
  fullscreen = true

const 
  floofUrl = "https://randomfox.ca/floof/"
  updateTime = 300

type ImageProvider =  
  tuple[
    get: proc(): Pixbuf
  ]

proc downloadImage(): Pixbuf =
  let client = newHttpClient()
  let urlData = client.getContent(floofUrl)
  let info = parseJson(urlData)
  let imageData = client.getContent(info["image"].getStr)
  let loader = newPixbufLoader()
  discard loader.write(imageData)
  loader.getPixbuf()

proc resizeImage(pixbuf: Pixbuf, maxWidth, maxHeight: int): Pixbuf = 
  var width, height: int
  if (maxWidth > maxHeight):
    height = maxHeight
    width = ((pixbuf.width * height) / pixbuf.height).toInt 
  else:
    width = maxWidth
    height = ((pixbuf.height * width) / pixbuf.width).toInt

  pixbuf.scaleSimple(width, height, InterpType.bilinear)

proc replaceImage(widget: Image, width, height: int) = 
  var pixbuf = downloadImage()
  pixbuf = pixbuf.resizeImage(width, height)
  widget.setFromPixbuf(pixbuf)

proc updateCommand(action: SimpleAction; parameter: Variant; widget: Image) =
  var width, height: int
  window.getSize(width, height)
  replaceImage(widget, width, height)

proc toggleFullscreen(action: SimpleAction; parameter: Variant; window: ApplicationWindow) =
  if fullscreen:
    window.unfullscreen
  else:
    window.fullscreen
  fullscreen = not fullscreen

proc quit(action: SimpleAction; parameter: Variant; app: Application) = 
    app.quit()

proc runUpdater(window: ApplicationWindow, image: Image) = 
  echo "Start Updater"
  var width, height: int
  window.getSize(width, height)
  spawn replaceImage(image, width, height)
  
proc appActivate(app: Application) =
  window = newApplicationWindow(app)
  window.title = "Randopics"
  window.setKeepAbove(true)

  let cssProvider = newCssProvider()
  let data = "window { background: black; }"
  discard cssProvider.loadFromData(data)
  let styleContext = window.getStyleContext()
  styleContext.addProvider(cssProvider, STYLE_PROVIDER_PRIORITY_USER)

  let imageWidget = newImage()
  window.add(imageWidget)
  window.connect("show", runUpdater, imageWidget)

  if fullscreen:
    window.fullscreen

  let fullscreenAction = newSimpleAction("fullscreen")
  discard fullscreenAction.connect("activate", toggleFullscreen, window)
  app.setAccelsForAction("win.fullscreen", "F")
  window.actionMap.addAction(fullscreenAction)

  let quitAction = newSimpleAction("quit")
  discard quitAction.connect("activate", quit, app)
  app.setAccelsForAction("win.quit", "Escape")
  window.actionMap.addAction(quitAction)

  let updateAction = newSimpleAction("update")
  discard updateAction.connect("activate", updateCommand, imageWidget)
  app.setAccelsForAction("win.update", "U")
  window.actionMap.addAction(updateAction)

  window.showAll

proc main =
  let app = newApplication("org.gtk.example")
  connect(app, "activate", appActivate)
  discard run(app)

when isMainModule:
  main()