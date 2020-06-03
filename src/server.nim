import asyncdispatch, strutils, json
import jester
import common

const
  index = slurp("resources/index.html")
  style = slurp("resources/site.css")
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
    log "Access from ", request.ip
    resp index

  get "/style":
    resp(style, contentType="text/css")

  get "/script":
    resp(script, contentType="text/javascript")

  post "/":
    let json = request.body.parseJson
    let msg = json.to(CommandMessage)
    # Pass command from client to main applicaiton
    chan.send(msg)
    resp Http200

proc runServer*[ServerArgs](arg: ServerArgs) {.thread, nimcall.} =
  verbose = arg.verbose
  let port = Port(arg.port)
  let settings = newSettings(port=port)
  var server = initJester(randopixRouter, settings=settings)
  server.serve()