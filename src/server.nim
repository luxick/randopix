import net, json
import commands

var 
  chan*: Channel[CommandMessage]

proc closeServer*() =
  ## Sends a "Close" command to the server
  var socket = newSocket()
  socket.connect("127.0.0.1", Port(defaultPort))
  let c = newCommand(Command.Close)
  socket.send(c.wrap)
  socket.close()

proc runServer*() = 
  var server = newSocket()
  server.bindAddr(Port(defaultPort))
  server.listen()
  echo "Control server is listening"

  while true:    
    # Process client requests
    var client = newSocket()
    server.accept(client)
    echo("Client connected")
    try:
      var line = client.recvLine()
      if line == "":
        echo "No data from client"
        continue
      
      var jsonData = parseJson(line)
      let msg = jsonData.to(CommandMessage)
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
      echo "Invalid command from client: ", getCurrentExceptionMsg()
      echo repr(getCurrentException())
  server.close()