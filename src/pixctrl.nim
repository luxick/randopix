import net
import argparse
import commands

var p = newParser("pixctrl"):
  help("Control utilitiy for randopix")
  option("-s", "--server", help="Host running the randopix server", default="127.0.0.1")
  option("-p", "--port", help="Port to connect to the randopix server", default = $defaultPort)

var socket = newSocket()
socket.connect("127.0.0.1", Port(defaultPort))
socket.send("Hello, Sockets!\r\L")
socket.close()