import strutils, httpClient
import argparse
import common

const modeHelp = "Change the display mode. Possible values: [$1]" % Mode.enumToStrings().join(", ")

var
  randopixServer*: string     ## URL for the randopix server
  client = newHttpClient()

proc sendCommand(msg: CommandMessage) =
  let resp = client.post(randopixServer, msg.wrap)
  if not resp.status.contains("200"):
    echo "Error while sending command: ", resp.status

proc sendCommand(cmd: Command) =
  sendCommand(newCommandMessage(cmd))

proc switchMode*(mode: string) =
  ## Update the display mode
  try:
    discard parseEnum[Mode](mode)
  except ValueError:
    echo "Invalid mode: ", mode
    echo "Possible values: [$1]" % Mode.enumToStrings().join(", ")
    return
  sendCommand(newCommandMessage(cMode, mode))

proc refresh*() =
  ## Force refresh of the current image
  sendCommand(cRefresh)

proc setTimeout*(seconds: string) =
  ## Set the image timeout to this value
  sendCommand(newCommandMessage(cTimeout, seconds))

when isMainModule:
  var p = newParser("pixctrl"):
    help("Control utilitiy for randopix")
    option("-s", "--server", help="Host running the randopix server", default="http://localhost:8080/")
    run:
      randopixServer = opts.server

    command($cRefresh):
      ## Force refresh command
      help("Force image refresh now")
      run:
        refresh()

    command($cTimeout):
      ## Timeout Command
      help("Set timeout in seconds before a new image is displayed")
      arg("seconds", default = "300")
      run:
        setTimeout(opts.seconds)

    command($cMode):
      ## Mode switch command
      help(modeHelp)
      arg("mode")
      run:
        switchMode(opts.mode)
  try:
    p.run(commandLineParams())
  except:
    echo getCurrentExceptionMsg()