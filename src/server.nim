import net, json, strutils
import common

type
  ServerArgs* = object of RootObj
    verbose: bool

var
  chan*: Channel[CommandMessage]
  verbose: bool

proc newServerArgs*(verbose: bool): ServerArgs =
  ServerArgs(verbose: verbose)

proc log(things: varargs[string, `$`]) =
  if verbose:
    echo things.join()

proc closeServer*() =
  ## Sends a "Close" command to the server
  var socket = newSocket()
  socket.connect("127.0.0.1", Port(defaultPort))
  let c = newCommand(cClose)
  socket.send(c.wrap)
  socket.close()

proc runServer*[ServerArgs](arg: ServerArgs) {.thread, nimcall.} =
  verbose = arg.verbose
  var server = net.newSocket()
  server.bindAddr(Port(defaultPort))
  server.listen()
  log "Control server is listening"

  while true:
    # Process client requests
    var client = net.newSocket()
    server.accept(client)
    log "Client connected"
    try:
      var line = client.recvLine()
      if line == "":
        log "No data from client"
        continue

      var jsonData = parseJson(line)
      let msg = jsonData.to(CommandMessage)
      case msg.command
      of cClose:
        log "Server recieved termination command. Exiting."
        break
      else:
        # Pass command from client to main applicaiton
        chan.send(msg)

    except OSError:
      log "Server error: ", getCurrentExceptionMsg()
    except:
      log "Invalid command from client: ", getCurrentExceptionMsg()
      log repr(getCurrentException())
  server.close()