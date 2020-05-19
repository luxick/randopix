import net
import argparse
import commands

var socket = newSocket()

proc sendCommand(server, port: string, msg: CommandMessage) =
  socket.connect(server, Port(port.parseInt))
  if not socket.trySend(msg.wrap):
    echo "Cannot send command: ", msg
  socket.close()

var p = newParser("pixctrl"):
  help("Control utilitiy for randopix")
  option("-s", "--server", help="Host running the randopix server", default="127.0.0.1")
  option("-p", "--port", help="Port to connect to the randopix server", default = $defaultPort)
  command("refresh"):
    help("Force image refresh now")
    run:
      let c = newCommand(cRefresh)
      sendCommand(opts.parentOpts.server, opts.parentOpts.port, c)  
  command("timeout"):
    help("Set timeout in seconds before a new image is displayed")
    arg("seconds", default = "300")
    run:
      let c = newCommand(cTimeout, opts.seconds)
      sendCommand(opts.parentOpts.server, opts.parentOpts.port, c)
      
p.run(commandLineParams())