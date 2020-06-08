import asyncdispatch, strutils, json, logging
import jester
import common

const
  index = slurp("resources/index.html")
  style = slurp("resources/site.css")
  pixctrlJs = slurp("resources/pixctrl.js")
  script = slurp("resources/script.js")

type
  ServerArgs* = object of RootObj
    verbose*: bool
    port*: int

var
  chan*: Channel[CommandMessage]
  verbose: bool

proc log(things: varargs[string, `$`]) =
  if verbose:
    echo things.join()

router randopixRouter:
  get "/":
    resp index

  get "/site.css":
    resp(style, contentType="text/css")

  get "/pixctrl.js":
    resp(pixctrlJs, contentType="text/javascript")

  get "/script.js":
    resp(script, contentType="text/javascript")

  post "/":
    try:
      log "Command from ", request.ip
      let json = request.body.parseJson
      let msg = json.to(CommandMessage)
      log "Got message: ", $msg
      # Pass command from client to main applicaiton
      chan.send(msg)
      resp Http200
    except:
      log "Error: ", getCurrentExceptionMsg()

proc runServer*[ServerArgs](arg: ServerArgs) {.thread, nimcall.} =
  verbose = arg.verbose
  if verbose:
    logging.setLogFilter(lvlInfo)
  else:
    logging.setLogFilter(lvlNotice)
  let port = Port(arg.port)
  let settings = newSettings(port=port)
  var server = initJester(randopixRouter, settings=settings)
  server.serve()