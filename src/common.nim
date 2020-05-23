import json

const
  defaultPort* = 5555     ## Default port at which the control server will run

type
  OpResult* = object of RootObj ## Result object for signalling failure state across proc calls
    success*: bool              ## Indicating if the opration was successfull
    errorMsg*: string           ## Error meassge in case the operation failed

  Mode* {.pure.} = enum   ## Options for the display mode
    None = "none"         ## No images will be displayed
    Foxes = "foxes"       ## Some nice foxes
    Inspiro = "inspiro"   ## Inspiring nonsense
    File = "file"         ## Images from a local path

  Command* = enum
    cClose = "close"       ## Closes the control server and exists the applicaiton
    cRefresh = "refresh"   ## Force refresh of the image now
    cTimeout = "timeout"   ## Set image timeout to a new value
    cMode = "mode"         ## Change the servers display mode

  CommandMessage* = object of RootObj
    command*: Command     ## Command that the application should execute
    parameter*: string    ## Optional parameter for the command

proc newOpResult*(): OpResult =
  OpResult(success: true)

proc newOpResult*(msg: string): OpResult =
  OpResult(success: false, errorMsg: msg)

proc newCommand*(c: Command, p: string = ""): CommandMessage =
  CommandMessage(command: c, parameter: p)

proc wrap*(msg: CommandMessage): string =
  $(%msg) & "\r\L"

proc enumToStrings*(en: typedesc): seq[string] =
  for x in en:
    result.add $x