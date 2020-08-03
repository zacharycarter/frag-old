# FRAG

FRAG is a WIP game engine written in the [Nim programming language](https://nim-lang.org).

## Installation

Use the [Nimble package manager](https://github.com/nim-lang/nimble) to install FRAG.

```bash
git clone git@github.com:zacharycarter/frag.git && cd frag
nimble deps
nimble install
frag
```

## Usage

FRAG is still in early development, and doesn't do much yet. 

```nim
import frag

proc init() =
  echo "initializing app"

proc frame() =
  discard

proc event() =
  discard

proc cleanup() =
  echo "cleaning up"

proc main() =
  var appDesc = AppDesc(
    initCb: init,
    frameCb: frame,
    eventCb: event,
    cleanupCb: cleanup,
  )

  run(appDesc)

when isMainModule:
  main()
```

## Features

* Auto-generated bindings for volk, Vulkan Memory Allocator and GLFW via Nimterop
* Vulkan renderer

## Third party dependencies

* [Nimterop](https://github.com/nimterop/nimterop): A Nim package that aims to make C/C++ interop seamless
* [volk](https://github.com/zeux/volk): Meta-loader for Vulkan
* [Vulkan Memory Allocator](https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator): Easy to integrate Vulkan memory allocation library
* [GLFW](https://github.com/glfw/glfw): Multi-platform library for OpenGL, OpenGL ES and Vulkan application development
