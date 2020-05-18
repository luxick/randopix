import os, sets, random, httpClient, json
import gintro/[gdkpixbuf]

const
  supportedExts = @[".png", ".jpg", ".jpeg"]
  foxesUrl = "https://randomfox.ca/floof/"

type
  ProviderKind* {.pure.} = enum
    Foxes = "foxes"     ## Some nice foxes
    Inspiro = "inspiro" ## Inspiring nonsense
    File = "file"       ## Images from a local path

  ImageProvider* = ref object
    case kind: ProviderKind
    of ProviderKind.Foxes, ProviderKind.Inspiro:
      url: string
    of ProviderKind.File:
      exts: HashSet[string]
      path*: string
      files*: seq[string]

var client = newHttpClient()  ## For loading images from the web

proc downloadFox(ip: ImageProvider): Pixbuf =
  ## Download image from the fox API
  let urlData = client.getContent(ip.url)
  let info = parseJson(urlData)
  let imageData = client.getContent(info["image"].getStr)
  let loader = newPixbufLoader()
  discard loader.write(imageData)
  loader.getPixbuf()

proc reloadFileList(ip: ImageProvider) =
  ## Reload the file list
  if ip.path == "":
    return

  for file in walkDirRec(ip.path):
    let split = splitFile(file)
    if ip.exts.contains(split.ext):
      ip.files.add(file)
  
  randomize()
  shuffle(ip.files)

proc next*(ip: ImageProvider): Pixbuf =
  ## Return a new image from the chosen image source
  case ip.kind
  of ProviderKind.Foxes, ProviderKind.Inspiro:
    return ip.downloadFox
  of ProviderKind.File:
    if ip.files.len < 1:
      ip.reloadFileList
    result = ip.files[0].newPixbufFromFile
    ip.files.delete(0)

proc newFileProvider(path: string): ImageProvider =
  result = ImageProvider(kind: ProviderKind.File, path: path, exts: supportedExts.toHashSet)
  result.reloadFileList

proc newFoxProvider(): ImageProvider = ImageProvider(kind: ProviderKind.Foxes, url: foxesUrl)

proc newImageProvider*(kind: ProviderKind, filePath: string = ""): ImageProvider =
  ## Create a new `ImageProvider` for the API chosen with thge `kind` parameter 
  case kind
  of ProviderKind.Foxes:
    newFoxProvider()
  of ProviderKind.Inspiro:
    # TODO
    newFoxProvider()
  of ProviderKind.File:
    newFileProvider(filePath)