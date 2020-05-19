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
    run:
      let c = newCommand(Command.Refresh)
      sendCommand(opts.parentOpts.server, opts.parentOpts.port, c)
      
p.run(commandLineParams())