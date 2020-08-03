# FRAG

FRAG is a WIP game engine written in the [Nim programming language](https://nim-lang.org).

The current focus of development is on the 3D Vulkan renderer and tooling. 

FRAG is being developed alongside a science-fiction roguelike game, so feature development will be limited in scope.

This document will be updated as new capabilities and examples are added to the project.

## Platforms

FRAG is being developed on a MacBook Pro, so macOS will be the first supported platform. Windows and Linux support will follow, in that order.

| Compiler Tested With | Operating System |
| -------- | ---------------- |
| ![clang - Apple clang version 11.0.0 (clang-1100.0.33.17)](https://img.shields.io/badge/CLANG-3.8+-ff69b4.svg) | ![supported](https://img.shields.io/badge/status-yes-green.svg) |

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
* Vulkan renderer (WIP)
* Direct3D 12 renderer (planned)
* Metal renderer (planned)

## Third party dependencies

* [Nimterop](https://github.com/nimterop/nimterop): A Nim package that aims to make C/C++ interop seamless
* [volk](https://github.com/zeux/volk): Meta-loader for Vulkan
* [Vulkan Memory Allocator](https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator): Easy to integrate Vulkan memory allocation library
* [GLFW](https://github.com/glfw/glfw): Multi-platform library for OpenGL, OpenGL ES and Vulkan application development

[License (MIT)](https://raw.githubusercontent.com/zacharycarter/frag/master/LICENSE)
--------------------------------------------------------------------------------------------

<a href="http://opensource.org/licenses/MIT" target="_blank">
<img align="right" src="http://opensource.org/trademarks/opensource/OSI-Approved-License-100x137.png">
</a>

        Copyright (c) 2020 Zachary Carter

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
