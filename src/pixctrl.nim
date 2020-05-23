import strutils, net
import argparse
import common

var socket = newSocket()

proc sendCommand*(server, port: string, msg: CommandMessage) =
  socket.connect(server, Port(port.parseInt))
  if not socket.trySend(msg.wrap):
    echo "Cannot send command: ", msg
  socket.close()

proc switchMode*(server, port: string, mode: string) =
  try:
    discard parseEnum[Mode](mode)
  except ValueError:
    echo "Invalid mode: ", mode
    echo "Accepted modes: ", enumToStrings(Mode).join(", ")
    return
  let c = newCommand(cMode, mode)
  sendCommand(server, port, c)

when isMainModule:
  var p = newParser("pixctrl"):
    help("Control utilitiy for randopix")
    option("-s", "--server", help="Host running the randopix server", default="127.0.0.1")
    option("-p", "--port", help="Port to connect to the randopix server", default = $defaultPort)

    command($cRefresh):
      help("Force image refresh now")
      run:
        let c = newCommand(cRefresh)
        sendCommand(opts.parentOpts.server, opts.parentOpts.port, c)

    command($cTimeout):
      help("Set timeout in seconds before a new image is displayed")
      arg("seconds", default = "300")
      run:
        let c = newCommand(cTimeout, opts.seconds)
        sendCommand(opts.parentOpts.server, opts.parentOpts.port, c)

    command($cMode):
      help("Change the display mode of the server")
      arg("mode")
      run:
        switchMode(opts.parentOpts.server, opts.parentOpts.port, opts.mode)
  try:
    p.run(commandLineParams())
  except:
    echo p.help