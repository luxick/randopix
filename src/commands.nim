import json
const
  defaultPort* = 5555     ## Default port at which the control server will run

type
  Command* = enum
    cClose = "close"       ## Closes the control server and exists the applicaiton
    cRefresh = "refresh"   ## Force refresh of the image now
    cTimeout = "timeout"   ## Set image timeout to a new value

  CommandMessage* = object
    command*: Command     ## Command that the application should execute
    parameter*: string    ## Optional parameter for the command

proc newCommand*(c: Command, p: string = ""): CommandMessage =
  CommandMessage(command: c, parameter: p)

proc wrap*(msg: CommandMessage): string =
  $(%msg) & "\r\L"