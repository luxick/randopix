import strutils, json
import common

when defined(js):
  import ajax, jsconsole, dom
else:
  import httpClient, strformat
  import argparse
  var randopixServer* {.exportc.}: string     ## URL for the randopix server

proc sendCommand(msg: CommandMessage) =
  when defined(js):
    console.log("Sending:", $msg, "to URL:", document.URL)
    var req = newXMLHttpRequest()

    proc processSend(e:Event) =
      if req.readyState == rsDONE:
        if req.status != 200:
          console.log("There was a problem with the request.")
          console.log($req.status, req.statusText)

    req.onreadystatechange = processSend
    req.open("POST", document.URL)
    req.send(cstring($(%*msg)))
  else:
    let client = newHttpClient()
    let resp = client.post(randopixServer, $(%msg))
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

proc refresh*() {.exportc.} =
  ## Force refresh of the current image
  sendCommand(cRefresh)

proc setTimeout*(seconds: string) =
  ## Set the image timeout to this value
  sendCommand(newCommandMessage(cTimeout, seconds))

when defined(js):
  proc getModes(): seq[cstring] {.exportc.} =
    for mode in enumToStrings(Mode):
      result.add cstring(mode)
  proc switchMode*(mode: cstring) {.exportc.} =
    switchMode($mode)
  proc setTimeout*(seconds: cstring) {.exportc.} =
    setTimeout($seconds)
else:
  when isMainModule:
    const modeHelp = "Change the display mode. Possible values: [$1]" % Mode.enumToStrings().join(", ")
    var p = newParser("pixctrl"):
      help("Control utilitiy for randopix")
      option("-s", "--server", help="Host running the randopix server", default="http://localhost:8080/")
      run:
        if opts.server.startsWith("http://"):
          randopixServer = opts.server
        else:
          randopixServer = fmt"http://{opts.server}"

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