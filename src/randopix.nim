import httpClient, json, os, options, strformat
import gintro/[gtk, glib, gobject, gio, gdkpixbuf]
import gintro/gdk except Window
import argparse except run
import fileAccess

const
  css = slurp("app.css")
  version = "0.1"
  floofUrl = "https://randomfox.ca/floof/"

type
  Mode {.pure.} = enum
    Foxes = "foxes"     ## Some nice foxes
    Inspiro = "inspiro" ## Inspiring nonsense
    File = "file"       ## Images from a local path

  Args = object
    fullscreen: bool    ## Applicaion is show in fullscreen mode
    verbose: bool       ## More debug information in notification label
    mode: Option[Mode]  ## The chosen image source
    path: string        ## File mode only: the path to the images
    timeout: int        ## Milliseconds between image refreshes

var
  client = newHttpClient()    ## For loading images from the web
  fileProvider: FileProvider  ## Gets images from the chosen source
  args: Args                  ## The parsed command line args
  # Widgets
  window: ApplicationWindow
  imageWidget: Image
  label: Label

proc enumToStrings(en: typedesc): seq[string] = 
  for x in en:
    result.add $x

proc notify(label: Label, message: string = "") =
  ## Shows the notification box in the lower left corner.
  ## If no message is passed, the box will be hidden
  label.text = message
  if (message == ""):
    label.hide
  else:
    label.show

proc newArgs(): Args =
  let p = newParser("randopix"):
    help(fmt"Version {version} - Display random images from different sources")
    option("-m", "--mode", help="The image source mode.", choices=enumToStrings(Mode))
    option("-p", "--path", help="Path to a directory with images ('file' mode only)")
    option("-t", "--timeout", help="Seconds before the image is refreshed", default="300")
    flag("-w", "--windowed", help="Do not start in fullscreen mode")
    flag("-v", "--verbose", help="Show more information")
  let opts = p.parse(commandLineParams())
  var mode: Option[Mode]  
  if (opts.mode == ""):
    echo p.help
    return

  try:
    mode = some(parseEnum[Mode](opts.mode))
  except ValueError:
    echo fmt"Invaild mode: {opts.mode}"
    echo p.help
    return

  if (mode.get == Mode.File):
    fileProvider = newFileProvider(opts.path)

  ## Timeout is given in seconds as an argument
  var timeout = 3000
  try:
    timeout = opts.timeout.parseInt * 1000    
  except ValueError:
    echo "Invalid timeout: ", opts.timeout

  Args(
    fullscreen: not opts.windowed,
    verbose: opts.verbose,
    mode: mode,
    path: opts.path,
    timeout: timeout)

proc downloadFox(): Pixbuf =
  let urlData = client.getContent(floofUrl)
  let info = parseJson(urlData)
  let imageData = client.getContent(info["image"].getStr)
  let loader = newPixbufLoader()
  discard loader.write(imageData)
  loader.getPixbuf()

proc getLocalImage(): Pixbuf = 
  ## let the file provider serve another image
  fileProvider.next.newPixbufFromFile

proc tryGetImage(): Option[Pixbuf] =
  ## Get the raw image from an image provider
  ## The kind of image is based on the command line args
  if args.mode.isSome:
    case args.mode.get
    of Mode.Foxes:
      result = some(downloadFox())
    of Mode.Inspiro:
      echo "Not Implemented"
    of Mode.File:
      result = some(getLocalImage())

proc updateImage(): bool =
  ## Updates the UI with a new image
  # Loading new image
  try:
    if (args.verbose): echo "Refreshing..."
    let data = tryGetImage();
    if data.isNone:
      label.notify "No image to display..."
      return false;

    ## Resize image to best fit the window 
    var pixbuf = data.get()
    var wWidth, wHeight, width, height: int
    window.getSize(wWidth, wHeight)
    if (wWidth > wHeight):
      height = wHeight
      width = ((pixbuf.width * height) / pixbuf.height).toInt 
    else:
      width = wWidth
      height = ((pixbuf.height * width) / pixbuf.width).toInt
    pixbuf = pixbuf.scaleSimple(width, height, InterpType.bilinear)

    # Update the UI with the image
    imageWidget.setFromPixbuf(pixbuf)
    if (args.verbose):
      label.notify "New image set"
    else:
      label.notify
    return true

  except:
    let
      e = getCurrentException()
      msg = getCurrentExceptionMsg()
    echo "Got exception ", repr(e), " with message ", msg
    return false

proc forceUpdate(action: SimpleAction; parameter: Variant;) =
  discard updateImage()

proc timedUpdate(image: Widget): bool = 
  let ok = updateImage();
  if ok:
    return true;
  else:
    label.notify "Error while refreshing image, retrying..."
    discard timeoutAdd(uint32(args.timeout), timedUpdate, imageWidget)
    return false

proc toggleFullscreen(action: SimpleAction; parameter: Variant; window: ApplicationWindow) =
  ## Fullscreen toggle event
  if args.fullscreen:
    window.unfullscreen
  else:
    window.fullscreen
  args.fullscreen = not args.fullscreen

proc quit(action: SimpleAction; parameter: Variant; app: Application) =
  ## Application quit event
  app.quit()
  
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
  discard updateImageAction.connect("activate", forceUpdate)
  app.setAccelsForAction("win.update", "U")
  window.actionMap.addAction(updateImageAction)

proc appActivate(app: Application) =
  # Parse arguments from the command line
  args = newArgs()
  # No mode was given, exit and display the help text
  if (args.mode.isNone): return

  window = newApplicationWindow(app)
  window.title = "randopix"
  window.setKeepAbove(true)
  window.setDefaultSize(800, 600)

  # Custom styling for e.g. the background color CSS data is in the "style.nim" module 
  let provider = newCssProvider()
  discard provider.loadFromData(css)
  addProviderForScreen(getDefaultScreen(), provider, STYLE_PROVIDER_PRIORITY_USER)

  # Create all windgets we are gonna use
  var overlay = newOverlay()
  imageWidget = newImage()
  label = newLabel("Starting...")
  label.halign = Align.`end`
  label.valign = Align.`end`

  overlay.addOverlay(label)
  overlay.add(imageWidget)
  window.add(overlay)
  
  if args.fullscreen:
    window.fullscreen

  app.connectSignals
  window.showAll

  discard updateImage()
  discard timeoutAdd(uint32(args.timeout), timedUpdate, imageWidget)

when isMainModule:
  let app = newApplication("org.luxick.randopix")
  connect(app, "activate", appActivate)
  discard run(app)