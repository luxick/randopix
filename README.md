# randopix
## Usage
### Server
The server is run with an inital mode. All settings can later be changed with the client.
```
randopix

Version 0.1 - Display random images from different sources

Usage:
  randopix [options]

Options:
  -m, --mode=MODE            The image source mode. Possible values: [none, foxes, inspiro, file]
  -p, --path=PATH            Path to a directory with images for the 'file' mode
  -t, --timeout=TIMEOUT      Seconds before the image is refreshed (default: 300)
  -w, --windowed             Do not start in fullscreen mode
  -v, --verbose              Show more information
  -h, --help                 Show this help
```
### Client
The `pixctrl` client is used to issue commands to a running server.
Per default the client will try to connect to a server running on the same maschine. Use the `-s HOSTNAME` option to control a server over the network.
```
pixctrl

Control utilitiy for randopix

Usage:
  pixctrl [options] COMMAND

Commands:

  refresh          Force image refresh now
  timeout          Set timeout in seconds before a new image is displayed
  mode             Change the display mode. Possible values: [none, foxes, inspiro, file]

Options:
  -s, --server=SERVER        Host running the randopix server (default: 127.0.0.1)
  -p, --port=PORT            Port to connect to the randopix server (default: 5555)
  -h, --help                 Show this help
```
## Build
Install the [Nim Compiler](https://nim-lang.org/install.html).

Use this command to install the dependencies and build the program:
```
$ nimble build
```