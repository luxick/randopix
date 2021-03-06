import os, sets, random, httpClient, json, strutils, strformat, options, deques, times
from lenientops import `*`
import op, gintro/[gdkpixbuf, gobject]
import common

const
  supportedExts = @[".png", ".jpg", ".jpeg"]
  placeholderImg = slurp("resources/blank.png")
  foxesUrl = "https://randomfox.ca/floof/"
  inspiroUrl = "http://inspirobot.me/api?generate=true"

type
  ImageProvider* = ref object of RootObj
    ## Manages images that should be displayed
    verbose: bool         ## Additional logging for the image provider
    mode* : Mode          ## Selects the API that is used to get images
    path*: Option[string] ## Path on the local file syetem that will be used in `file` mode
    exts: HashSet[string] ## Allowed extensions that the `file` mode will display

var
  client = newHttpClient()  ## For loading images from the web
  tmpDir = getTempDir() / "randopix"
  tmpFile =  tmpDir / "tmp.png"
  fileList = initDeque[string]()

########################
# Constructors
########################

proc newImageProvider(verbose: bool, mode: Mode, path: Option[string]): ImageProvider =
  ImageProvider(verbose: verbose, mode: mode, path: path, exts: supportedExts.toHashSet)

proc newImageProvider*(verbose: bool): ImageProvider =
  newImageProvider(verbose, Mode.None, none(string))

proc newImageProvider*(verbose: bool, path: string): ImageProvider =
  newImageProvider(verbose, Mode.None, some(path))

proc newImageProvider*(verbose: bool, mode: Mode): ImageProvider =
  newImageProvider(verbose, mode, none(string))

proc newImageProvider*(verbose: bool, mode: Mode, path: string): ImageProvider =
  newImageProvider(verbose, mode, some(path))

########################
# Utilities
########################

proc log(ip: ImageProvider, things: varargs[string, `$`]) =
  if ip.verbose:
    echo things.join()

func calcImageSize(maxWidth, maxHeight, imgWidth, imgHeight: int): tuple[width: int, height: int] =
  ## Calculate the best fit for an image on the give screen size.
  ## This should keep the image aspect ratio
  let
    ratioMax = maxWidth / maxHeight
    ratioImg = imgWidth / imgHeight
  if (ratioMax > ratioImg):
    result.width = (imgWidth * (maxHeight / imgHeight)).toInt
    result.height = maxHeight
  else:
    result.width = maxWidth
    result.height = (imgHeight * (maxWidth / imgWidth)).toInt

########################
# Image Provider procs
########################

proc getPlaceHolder(ip: ImageProvider): OP[string] =
  ## Provide the placeholder image.
  ## This is used when no mode is active
  let f = fmt"{tmpFile}.blank"
  writeFile(f, placeholderImg)
  ok f

proc getFox(ip: ImageProvider): OP[string] =
  ## Download image from the fox API
  try:
    let urlData = client.getContent(foxesUrl)
    let info = parseJson(urlData)
    let imageData = client.getContent(info["image"].getStr)
    let dlFile = fmt"{tmpFile}.download"
    writeFile(dlFile, imageData)
    ok dlFile
  except JsonParsingError:
    ip.log fmt"Error while fetching from fox API: {getCurrentExceptionMsg()}"
    fail[string] "Json parsing error"
  except KeyError:
    ip.log fmt"No image in downloaded data: {getCurrentExceptionMsg()}"
    fail[string] "No image from API"

proc getInspiro(ip: ImageProvider): OP[string] =
  ## Download and save image from the inspiro API
  try:
    let imageUrl = client.getContent(inspiroUrl)
    ip.log fmt"Downloading inspiro image from: '{imageUrl}'"
    let imageData = client.getContent(imageUrl)
    let dlFile = fmt"{tmpFile}.download"
    writeFile(dlFile,imageData)
    ok dlFile
  except:
    ip.log fmt"Unexpected error while downloading: {getCurrentExceptionMsg()}"
    fail[string] getCurrentExceptionMsg()

proc getLocalFile(ip: var ImageProvider): OP[string] =
  ## Provide an image from a local folder

  # First, check if there are still images left to be loaded.
  # If not reread all files from the path
  if fileList.len == 0:
    var tmp: seq[string]
    var split: tuple[dir, name, ext: string]
    for file in walkDirRec(ip.path.get):
      split = splitFile(file)
      if ip.exts.contains(split.ext):
        tmp.add($file)

    ip.log fmt"Loaded {tmp.len} files"
    shuffle(tmp)
    for file in tmp:
      fileList.addLast(file)
  if fileList.len == 0:
    return fail[string] "No files found"

  let next = fileList.popFirst()
  # Remove the current file after
  ok next

proc getFileName(ip: var ImageProvider): OP[string] =
  ## Get the temporary file name of the next file to display
  case ip.mode
  of Mode.None:
    return ip.getPlaceHolder()
  of Mode.File:
    return ip.getLocalFile()
  of Mode.Foxes:
    return ip.getFox()
  of Mode.Inspiro:
    return ip.getInspiro()

########################
# Exported procs
########################

proc next*(ip: var ImageProvider, maxWidth, maxHeight: int): OP[string] =
  ## Uses the image provider to get a new image ready to display.
  ## `width` and `height` should be the size of the window.

  let r = ip.getFileName()
  if not r.isOk: return r

  var rawPixbuf = newPixbufFromFile(r.val)
  # Resize the pixbuf to best fit on screen
  let size = calcImageSize(maxWidth, maxHeight, rawPixbuf.width, rawPixbuf.height)
  ip.log "Scale image to: ", size
  let then = now()
  var pixbuf = rawPixbuf.scaleSimple(size.width, size.height, InterpType.nearest)
  let now = now()
  ip.log "Image scaled. Time: ", (now - then).inMilliseconds, "ms"
  # The pixbuf is written to disk and loaded again once because
  # directly setting the image from a pixbuf will leak memory
  let saved = pixbuf.savev(tmpFile, "png", @[])
  if not saved:
    return result.fail "Error while saving temporary image"

  # GTK pixbuf leaks memory when not manually decreasing reference count
  pixbuf.unref()
  rawPixbuf.unref()

  ok tmpFile

createDir(tmpDir)
randomize()