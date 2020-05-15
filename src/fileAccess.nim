import os, sets, random

const
  supportedExts = @[".png", ".jpg", ".jpeg"]

type
  FileProvider* = ref object
    exts: HashSet[string]
    path*: string
    files*: seq[string]

proc load*(fp: FileProvider) =
  ## Reload the file list
  if fp.path == "":
    return

  for file in walkDirRec(fp.path):
    let split = splitFile(file)
    if fp.exts.contains(split.ext):
      fp.files.add(file)
  
  randomize()
  shuffle(fp.files)

proc next*(fp: FileProvider): string = 
  if fp.files.len < 1:
    fp.load
  result = fp.files[0]
  fp.files.delete(0)

proc newFileProvider*(path: string): FileProvider =
  result = FileProvider(path: path, exts: supportedExts.toHashSet)
  result.load