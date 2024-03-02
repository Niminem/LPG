# Package
version       = "0.1.0"
author        = "Niminem"
description   = "A Simple Labeled Property Graph Database implementation in Nim using SQLite."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests"]

# Dependencies
requires "nim >= 2.0.0"
requires "db_connector >= 0.1.0"

import os
task cleanup, "Remove generated files from 'tests' directory":
    var deleteTheseFiles: seq[string]
    for kind, path in walkDir(currentSourcePath().parentDir() / "tests"):
        if kind == pcFile:
            let ext = path.splitFile().ext
            if ext notin [".nim",".nims"]:
                deleteTheseFiles.add(path)
    for file in deleteTheseFiles:
        rmFile(file)