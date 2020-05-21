import os, options, strformat
import gintro/[glib, gobject, gdkpixbuf, gtk, gio]
import gintro/gdk except Window
import argparse except run
import providers, server, commands

const
  css = slurp("app.css")
  version = "0.1"

type
  Args = ref object
    fullscreen: bool    ## Applicaion is show in fullscreen mode
    verbose: bool       ## More debug information in notification label
    timeout: int        ## Milliseconds between image refreshes

var
  imageProvider: ImageProvider  ## Gets images from the chosen source
  args: Args                    ## The parsed command line args
  # Widgets
  window: ApplicationWindow
  label: Label
  # Server vor recieving commands from external tools
  serverWorker: system.Thread[void]

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

proc newArgs(): Option[Args] =
  let p = newParser("randopix"):
    help(fmt"Version {version} - Display random images from different sources")
    option("-m", "--mode", help="The image source mode.", choices=enumToStrings(ProviderKind))
    option("-p", "--path", help="Path to a directory with images for the 'file' mode")
    option("-t", "--timeout", help="Seconds before the image is refreshed", default="300")
    flag("-w", "--windowed", help="Do not start in fullscreen mode")
    flag("-v", "--verbose", help="Show more information")

  try:
    let opts = p.parse(commandLineParams())
    let mode = some(parseEnum[ProviderKind](opts.mode))
    imageProvider = newImageProvider(mode.get, opts.path)
    ## Timeout is given in seconds as an argument
    var timeout = 3000
    try:
      timeout = opts.timeout.parseInt * 1000    
    except ValueError:
      raise newException(UsageError, fmt"Invalid timeout value: {opts.timeout}")

    return some(Args(
      fullscreen: not opts.windowed,
      verbose: opts.verbose,
      timeout: timeout))
  except:
    echo getCurrentExceptionMsg()
    echo p.help

proc updateImage(image: Image): bool =
  ## Updates the UI with a new image
  try:
    if (args.verbose): echo "Refreshing..."

    var wWidth, wHeight: int
    window.getSize(wWidth, wHeight)

    let op = imageProvider.next(wWidth, wHeight)
    result = op.success
    if op.success:
      image.setFromFile(op.file)
    else:
      label.notify op.errorMsg
  except:
    let
      e = getCurrentException()
      msg = getCurrentExceptionMsg()
    echo "Got exception ", repr(e), " with message ", msg
    return false

proc forceUpdate(action: SimpleAction; parameter: Variant; image: Image) =
  discard updateImage(image)

proc timedUpdate(image: Image): bool = 
  let ok = updateImage(image);
  if not ok:
    label.notify "Error while refreshing image, retrying..."
  else:
    label.notify
  discard timeoutAdd(uint32(args.timeout), timedUpdate, image)
  return false

proc checkServerChannel(image: Image): bool =
  ## Check the channel from the control server for incomming commands
  let tried = chan.tryRecv()

  if tried.dataAvailable:
    let msg: CommandMessage = tried.msg
    echo "Main app got message: ", msg.command

    case msg.command
    of cRefresh:
      discard updateImage(image)
    of cTimeout:
      let val = msg.parameter.parseInt * 1000
      echo "Setting timeout to ", val
      args.timeout = val
    else:
      echo "Command ignored: ", msg.command

  sleep(100)
  result = true
  # discard idleAdd(checkServerChannel, parameter)

proc toggleFullscreen(action: SimpleAction; parameter: Variant; window: ApplicationWindow) =
  ## Fullscreen toggle event
  if args.fullscreen:
    window.unfullscreen
  else:
    window.fullscreen
  args.fullscreen = not args.fullscreen

proc cleanUp(w: ApplicationWindow, app: Application) =
  ## Stop the control server and exit the GTK application
  echo "Stopping control server..."
  closeServer()  
  serverWorker.joinThread()
  chan.close()
  echo "Server stopped."
  app.quit()

proc quit(action: SimpleAction; parameter: Variant; app: Application) =
  ## Application quit event
  cleanUp(window, app)
  
proc appActivate(app: Application) =
  # Parse arguments from the command line
  let parsed = newArgs()
  if parsed.isNone:
    return
  else:
    args = parsed.get

  window = newApplicationWindow(app)
  window.title = "randopix"
  window.setKeepAbove(false)
  window.setDefaultSize(800, 600)

  # Custom styling for e.g. the background color CSS data is in the "style.nim" module 
  let provider = newCssProvider()
  discard provider.loadFromData(css)
  addProviderForScreen(getDefaultScreen(), provider, STYLE_PROVIDER_PRIORITY_USER)

  # Create all windgets we are gonna use
  label = newLabel("Starting...")
  label.halign = Align.`end`
  label.valign = Align.`end`

  let container = newOverlay()
  container.addOverlay(label)
  window.add(container)
  
  let image = newImage()
  container.add(image)

  if args.fullscreen:
    window.fullscreen

  ## Connect the GTK signals to the procs 
  let fullscreenAction = newSimpleAction("fullscreen")
  discard fullscreenAction.connect("activate", toggleFullscreen, window)
  app.setAccelsForAction("win.fullscreen", "F")
  window.actionMap.addAction(fullscreenAction)

  let quitAction = newSimpleAction("quit")
  discard quitAction.connect("activate", quit, app)
  app.setAccelsForAction("win.quit", "Escape")
  window.actionMap.addAction(quitAction)

  let updateImageAction = newSimpleAction("update")
  discard updateImageAction.connect("activate", forceUpdate, image)
  app.setAccelsForAction("win.update", "U")
  window.actionMap.addAction(updateImageAction)

  window.connect("destroy", cleanUp, app)

  window.showAll

  var timerId = timeoutAdd(500, timedUpdate, image)

  ## open communication channel from the control server
  chan.open()

  ## Start the server for handling incoming commands
  createThread(serverWorker, runServer)
  discard idleAdd(checkServerChannel, image)

when isMainModule:
  let app = newApplication("org.luxick.randopix")
  connect(app, "activate", appActivate)
  discard run(app)