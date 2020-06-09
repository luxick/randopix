import asyncdispatch, strutils, json, logging, os
import jester
import common

when defined(release):
  proc slurpResources(): Table[string, string] {.compileTime.} =
    ## Include everything from the www dir into the binary.
    ## This way the final executable will not need an static web folder.
    for item in walkDir("src/resources/www/", true):
      if item.kind == pcFile:
        result[item.path] = slurp("resources/www/" & item.path)

  const resources = slurpResources()

const
  contentTypes = {
    ".js": "text/javascript",
    ".css": "text/css"
  }.toTable

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

when defined(release):
  ## When in release mode, use resources includes in the binary.
  ## When developing use the files directly.
  router getRouter:
    get "/":
      resp resources["index.html"]

    get "/@resource":
      try:
        var cType: string
        if contentTypes.hasKey(@"resource".splitFile.ext):
          cType = contentTypes[@"resource".splitFile.ext]
        resp resources[@"resource"], contentType=cType
      except KeyError:
        log "Resource not found: ", @"resource"
        resp Http404
else:
  router getRouter:
    get "/":
      resp readFile("src/resources/www/index.html")
    get "/@resource":
      try:
        var cType: string
        if contentTypes.hasKey(@"resource".splitFile.ext):
          cType = contentTypes[@"resource".splitFile.ext]
        resp readFile("src/resources/www/" & @"resource"), contentType=cType
      except KeyError:
        log "Resource not found: ", @"resource"
        resp Http404

router postRouter:
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

router randopixRouter:
  extend postRouter, ""
  extend getRouter, ""

proc runServer*[ServerArgs](arg: ServerArgs) {.thread, nimcall.} =
  verbose = arg.verbose
  logging.setLogFilter(lvlInfo)
  let port = Port(arg.port)
  let settings = newSettings(port=port)
  var server = initJester(randopixRouter, settings=settings)
  server.serve()