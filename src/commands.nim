
const
  defaultPort* = 5555     ## Default port at which the control server will run

type
  Command* {.pure.} = enum
    Close = "close"       ## Closes the control server and exists the applicaiton
    Refresh = "refresh"   ## Force refresh of the image now

  CommandMessage* = object
    command*: Command     ## Command that the application should execute
    parameter*: string    ## Optional parameter for the command

proc newCommand*(c: Command, p: string = ""): CommandMessage =
  CommandMessage(command: c, parameter: p)