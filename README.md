# randopix
## Usage
```
randopix

Version 0.1 - Display random images from different sources

Usage:
  randopix [options] 

Options:
  -m, --mode=MODE            The image source mode. Possible values: [foxes, inspiro, file]
  -p, --path=PATH            Path to a directory with images ('file' mode only)
  -w, --windowed             Do not start in fullscreen mode
  -v, --verbose              Show more information
  -h, --help                 Show this help
```

## Build
Install the [Nim Compiler](https://nim-lang.org/install.html).

Use this command to install the dependencies and build the program:
```
$ nimble build
```