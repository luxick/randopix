import os, options, strformat
import gintro/[glib, gobject, gtk, gio]
import gintro/gdk except Window
import argparse except run
import providers, server, common

const
  css = slurp("resources/app.css")
  version = slurp("version")
  helpString = [
    "ESC\tClose program",
    "H\tShow/Hide this help",
    "F\tToggle fullscreen",
    "U\tForce refresh"
  ].join("\n")

type
  Args = ref object
    fullscreen: bool    ## Applicaion is show in fullscreen mode
    verbose: bool       ## More debug information in notification label
    timeout: int        ## Milliseconds between image refreshes
    port: int           ## Port to host the control server

var
  imageProvider: ImageProvider  ## Gets images from the chosen source
  args: Args                    ## The parsed command line args
  updateTimeout: int            ## ID of the timeout that updates the images
  # Widgets
  window: ApplicationWindow
  label: Label
  box: Box
  # Server vor recieving commands from external tools
  serverWorker: system.Thread[ServerArgs]

proc log(things: varargs[string, `$`]) =
  if args.verbose:
    echo things.join()

proc notify(label: Label, things: varargs[string, `$`]) =
  ## Shows the notification box in the lower left corner.
  ## If no message is passed, the box will be hidden
  label.text = things.join()
  if (label.text == ""):
    box.hide
  else:
    box.show

proc newArgs(): Option[Args] =
  let p = newParser("randopix"):
    help(fmt"Version {version} - Display random images from different sources")
    option("-m", "--mode", help="The image source mode.", choices=enumToStrings(Mode))
    option("-d", "--directoy", help="Path to a directory with images for the 'file' mode")
    option("-t", "--timeout", help="Seconds before the image is refreshed", default="300")
    option("-p", "--port", help="Port over which the control server should be accessible", default="8080")
    flag("-w", "--windowed", help="Do not start in fullscreen mode")
    flag("-v", "--verbose", help="Show more information")

  try:
    let opts = p.parse(commandLineParams())

    # Catch the help option. Do nothing more
    if opts.help:
      return

    # Parse the starting mode
    var startMode: Mode
    try:
      startMode= parseEnum[Mode](opts.mode)
    except ValueError:
      startMode = Mode.None

    # Create the image provider
    if opts.directoy != "":
      imageProvider = newImageProvider(opts.verbose, startMode, opts.directoy)
    else:
      imageProvider = newImageProvider(opts.verbose, startMode)

    ## Timeout is given in seconds as an argument
    var timeout = 3000
    try:
      timeout = opts.timeout.parseInt * 1000
    except ValueError:
      raise newException(UsageError, fmt"Invalid timeout value: {opts.timeout}")

    return some(Args(
      fullscreen: not opts.windowed,
      verbose: opts.verbose,
      timeout: timeout,
      port: opts.port.parseInt))
  except:
    echo p.help

proc updateImage(image: Image): bool =
  ## Updates the UI with a new image
  try:
    if args.verbose: log "Refreshing..."

    if imageProvider.mode == Mode.None:
      log "No display mode"
      label.notify "No mode selected"
      return true

    var wWidth, wHeight: int
    window.getSize(wWidth, wHeight)

    let op = imageProvider.next(wWidth, wHeight)
    result = op.success
    if not op.success:
      label.notify op.errorMsg
      return

    image.setFromFile(op.file)
    label.notify
  except:
    let
      e = getCurrentException()
      msg = getCurrentExceptionMsg()
    log "Got exception ", repr(e), " with message ", msg
    label.notify "Error while refreshing, retrying..."
    return false

proc timedUpdate(image: Image): bool =
  discard updateImage(image)
  # Force garbage collection now. Otherwise the RAM will fill up until the GC is triggered.
  GC_fullCollect()
  updateTimeout = int(timeoutAdd(uint32(args.timeout), timedUpdate, image))
  return false

proc forceUpdate(action: SimpleAction; parameter: Variant; image: Image): void =
  log "Refreshing..."
  label.notify "Refreshing..."
  if updateTimeout > 0:
    discard updateTimeout.remove
  updateTimeout = int(timeoutAdd(500, timedUpdate, image))

proc checkServerChannel(image: Image): bool =
  ## Check the channel from the control server for incomming commands
  let tried = chan.tryRecv()

  if tried.dataAvailable:
    let msg: CommandMessage = tried.msg
    log "Recieved command: ", msg.command

    case msg.command
    of cRefresh:
      forceUpdate(nil, nil, image)

    of cTimeout:
      let val = msg.parameter.parseInt * 1000
      log "Setting timeout to ", val
      args.timeout = val
      if updateTimeout > 0:
        discard updateTimeout.remove
      updateTimeout = int(timeoutAdd(uint32(args.timeout), timedUpdate, image))

    of cMode:
      try:
        let mode = parseEnum[Mode](msg.parameter)
        imageProvider.mode = mode
        forceUpdate(nil, nil, image)
        log "Switching mode: ", mode
        label.notify fmt"Switch Mode: {msg.parameter.capitalizeAscii()}"
      except ValueError:
        log "Invalid mode: ", msg.parameter

    else:
      log "Command ignored: ", msg.command

  sleep(100)
  result = true

proc toggleFullscreen(action: SimpleAction; parameter: Variant; window: ApplicationWindow) =
  ## Fullscreen toggle event
  if args.fullscreen:
    window.unfullscreen
  else:
    window.fullscreen
  args.fullscreen = not args.fullscreen

proc toggleHelp(action: SimpleAction; parameter: Variant; box: Box) =
  if box.visible:
    box.hide
  else:
    box.show

proc cleanUp(w: ApplicationWindow, app: Application) =
  ## Stop the control server and exit the GTK application
  chan.close()
  log "Server channel closed."
  app.quit()

proc quit(action: SimpleAction; parameter: Variant; app: Application) =
  ## Application quit event
  cleanUp(window, app)

proc hidePointer(window: ApplicationWindow): void =
  ## Hides the mouse pointer for the application.
  let cur = window.getDisplay().newCursorForDisplay(CursorType.blankCursor)
  let win = window.getWindow()
  win.setCursor(cur)

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
  label = newLabel(fmt"Starting ('H' for help)...")

  let spinner = newSpinner()
  spinner.start()

  box = newBox(Orientation.horizontal, 2)
  box.halign = Align.`end`
  box.valign = Align.`end`
  box.packStart(spinner, true, true, 10)
  box.packStart(label, true, true, 0)

  let helpText = newLabel(helpString)
  let helpBox = newBox(Orientation.vertical, 0)
  helpBox.packStart(helpText, true, true, 0)
  helpBox.halign = Align.start
  helpBox.valign = Align.start

  let container = newOverlay()
  container.addOverlay(box)
  container.addOverlay(helpBox)
  window.add(container)

  let image = newImage()
  container.add(image)

  if args.fullscreen:
    window.fullscreen

  ## Connect the GTK signals to the procs
  var action: SimpleAction

  action = newSimpleAction("fullscreen")
  discard action.connect("activate", toggleFullscreen, window)
  app.setAccelsForAction("win.fullscreen", "F")
  window.actionMap.addAction(action)

  action = newSimpleAction("quit")
  discard action.connect("activate", quit, app)
  app.setAccelsForAction("win.quit", "Escape")
  window.actionMap.addAction(action)

  action = newSimpleAction("update")
  discard action.connect("activate", forceUpdate, image)
  app.setAccelsForAction("win.update", "U")
  window.actionMap.addAction(action)

  action = newSimpleAction("help")
  discard action.connect("activate", toggleHelp, helpBox)
  app.setAccelsForAction("win.help", "H")
  window.actionMap.addAction(action)

  window.connect("destroy", cleanUp, app)
  window.connect("realize", hidePointer)

  window.showAll
  # Help is only shown on demand
  helpBox.hide

  # Setting the inital image
  # Fix 1 second timeout to make sure all other initialization has finished
  updateTimeout = int(timeoutAdd(1000, timedUpdate, image))

  ## open communication channel from the control server
  chan.open()

  ## Start the server for handling incoming commands
  let serverArgs = ServerArgs(verbose: args.verbose, port: args.port)
  createThread(serverWorker, runServer, serverArgs)
  discard idleAdd(checkServerChannel, image)

when isMainModule:
  let app = newApplication("org.luxick.randopix")
  connect(app, "activate", appActivate)
  discard run(app)