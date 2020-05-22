import os, sets, random, httpClient, json, strformat
import gintro/[gdkpixbuf, gobject]
import commands

const
  supportedExts = @[".png", ".jpg", ".jpeg"]
  foxesUrl = "https://randomfox.ca/floof/"
  inspiroUrl = "http://inspirobot.me/api?generate=true"
  tmpFile = "/tmp/randopix_tmp.png"

type
  FileOpResult* = object of OpResult
    file*: string

  ProviderKind* {.pure.} = enum
    Foxes = "foxes"       ## Some nice foxes
    Inspiro = "inspiro"   ## Inspiring nonsense
    File = "file"         ## Images from a local path

  ImageProvider* = ref object of RootObj
    verbose: bool
    case kind: ProviderKind
    of ProviderKind.Foxes, ProviderKind.Inspiro:
      url: string
    of ProviderKind.File:
      exts: HashSet[string]
      path*: string
      files*: seq[string]

var
  client = newHttpClient()  ## For loading images from the web

########################
# Constructors
########################

proc newFileProvider(path: string): ImageProvider =
  ## Create an image provider to access images from the local file system 
  randomize()
  result = ImageProvider(kind: ProviderKind.File, path: path, exts: supportedExts.toHashSet)

proc newInspiroProvider(): ImageProvider =
  ## Create an image provider for the inspiro bot API
  ImageProvider(kind: ProviderKind.Inspiro, url: inspiroUrl)

proc newFoxProvider(): ImageProvider =
  ## Create an image provider to access the API at "https://randomfox.ca/floof/".
  ImageProvider(kind: ProviderKind.Foxes, url: foxesUrl)

proc newImageProvider*(kind: ProviderKind, filePath: string = ""): ImageProvider =
  ## Create a new `ImageProvider` for the API.
  case kind
  of ProviderKind.Foxes:
    newFoxProvider()
  of ProviderKind.Inspiro:
    newInspiroProvider()
  of ProviderKind.File:
    newFileProvider(filePath)

proc newFileOpResultError(msg: string): FileOpResult =
  FileOpResult(success: false, errorMsg: msg)

proc newFileOpResult(file: string): FileOpResult =
  FileOpResult(success: true, file: file)

########################
# Utilities
########################

proc log(ip: ImageProvider, msg: string) =
  if ip.verbose: echo msg

########################
# Image Provider procs
########################

proc getFox(ip: ImageProvider): FileOpResult =
  ## Download image from the fox API
  try:
    let urlData = client.getContent(ip.url)
    let info = parseJson(urlData)
    let imageData = client.getContent(info["image"].getStr)
    let dlFile = fmt"{tmpFile}.download"
    writeFile(dlFile, imageData)
    return newFileOpResult(dlFile)
  except JsonParsingError:
    ip.log fmt"Error while fetching from fox API: {getCurrentExceptionMsg()}"
    return newFileOpResultError("Json parsing error")
  except KeyError:
    ip.log fmt"No image in downloaded data: {getCurrentExceptionMsg()}"
    return newFileOpResultError("No image from API")

proc getInspiro(ip: ImageProvider): FileOpResult =
  ## Download and save image from the inspiro API
  try:
    let imageUrl = client.getContent(ip.url)
    ip.log fmt"Downloading inspiro image from: '{imageUrl}'"
    let imageData = client.getContent(imageUrl)
    let dlFile = fmt"{tmpFile}.download"
    writeFile(dlFile,imageData)
    return newFileOpResult(dlFile)
  except:
    ip.log fmt"Unexpected error while downloading: {getCurrentExceptionMsg()}"
    return newFileOpResultError(getCurrentExceptionMsg())

proc getLocalFile(ip: var ImageProvider): FileOpResult =
  ## Provide an image from a local folder
  # First, check if there are still images left to be loaded.
  # If not reread all files from the path
  if ip.files.len < 1:    
    if ip.path == "":
      return newFileOpResultError("No path for image loading")
    ip.log "Reloading file list..."
    for file in walkDirRec(ip.path):
      let split = splitFile(file)
      if ip.exts.contains(split.ext):
        ip.files.add(file)
    ip.log fmt"Loaded {ip.files.len} files"
    shuffle(ip.files)
  # Remove the current file after 
  result = newFileOpResult(ip.files[0])
  ip.files.delete(0)

proc getFileName(ip: var ImageProvider): FileOpResult =
  ## Get the temporary file name of the next file to display
  case ip.kind
  of ProviderKind.File:
    return ip.getLocalFile()
  of ProviderKind.Foxes:
    return ip.getFox()
  of ProviderKind.Inspiro:
    return ip.getInspiro()
  return newFileOpResultError("Not implemented")

########################
# Exported procs
########################

proc next*(ip: var ImageProvider, width, height: int): FileOpResult =
  ## Uses the image provider to get a new image ready to display.
  ## `width` and `height` should be the size of the window.
  let op = ip.getFileName()
  if not op.success: return op

  var rawPixbuf = newPixbufFromFile(op.file)
  # resize the pixbuf to best fit on screen
  var w, h: int
  if (width > height):
    h = height
    w = ((rawPixbuf.width * h) / rawPixbuf.height).toInt 
  else:
    w = width
    h = ((rawPixbuf.height * w) / rawPixbuf.width).toInt
  var pixbuf = rawPixbuf.scaleSimple(w, h, InterpType.bilinear)
  # The pixbuf is written to disk and loaded again once because
  # directly setting the image from a pixbuf will leak memory
  let saved = pixbuf.savev(tmpFile, "png", @[])
  if not saved:
    return newFileOpResultError("Error while saving temporary image")

  # GTK pixbuf leaks memory when not manually decreasing reference count
  pixbuf.genericGObjectUnref()
  rawPixbuf.genericGObjectUnref()

  newFileOpResult(tmpFile)