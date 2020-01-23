import httpClient, json
import gintro/[gtk, glib, gobject, gio, gdkpixbuf]

var
  client = newHttpClient()
  window: ApplicationWindow
  fullscreen = true

const 
  floofUrl = "https://randomfox.ca/floof/"

proc downloadImage(): Pixbuf =
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

proc updateImage(action: SimpleAction; parameter: Variant; widget: Image) =
  var pixbuf = downloadImage()
  pixbuf = pixbuf.resizeImage()
  widget.setFromPixbuf(pixbuf)

proc toggleFullscreen(action: SimpleAction; parameter: Variant; window: ApplicationWindow) =
  if fullscreen:
    window.unfullscreen
  else:
    window.fullscreen
  fullscreen = not fullscreen

proc quit(action: SimpleAction; parameter: Variant; app: Application) = 
    app.quit()
  
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

  let updateImageAction = newSimpleAction("update")
  discard updateImageAction.connect("activate", updateImage, imageWidget)
  app.setAccelsForAction("win.update", "U")
  window.actionMap.addAction(updateImageAction)

  window.showAll

proc main =
  let app = newApplication("org.gtk.example")
  connect(app, "activate", appActivate)
  discard run(app)

when isMainModule:
  main()