import net, json, marshal
import commands

var 
  chan*: Channel[CommandMessage]

proc closeServer*() =
  ## Sends a "Close" command to the server
  var socket = newSocket()
  socket.connect("127.0.0.1", Port(defaultPort))
  let c = newCommand(Command.Close)
  socket.send($(%c))
  socket.close()

proc runServer*() = 
  var socket = newSocket()
  socket.bindAddr(Port(defaultPort))
  socket.listen()
  echo "Control server is listening"

  while true:    
    # Process client requests
    var client = newSocket()
    socket.accept(client)
    echo("Incomming client")
    try:
      var line = client.recvLine()
      let msg = to[CommandMessage](line)
      case msg.command
      of Command.Close:
        echo "Server recieved termination command. Exiting."
        break
      else:
        # Pass command from client to main applicaiton
        chan.send(msg)

    except OSError:
      echo "Server error: ", getCurrentExceptionMsg()
    except:
      echo "Invalid command from client"