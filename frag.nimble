# Package

version       = "0.1.0"
author        = "Zachary Carter"
description   = "Game Engine"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["frag"]

# Tasks
task deps, "build and install dependencies":
  when defined(macosx):
    exec "clang++ -c -stdlib=libc++ -std=c++11 -Wno-missing-field-initializers -Wno-unused-variable -Wno-unused-parameter -Wno-unused-private-field -Wno-reorder -o lib/vma.o lib/vma.cpp"

# Dependencies

requires "nim >= 1.3.5"
requires "nimterop >= 0.6.7"
