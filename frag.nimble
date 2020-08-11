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
    exec "clang++ -c -g -DCR_DEBUG --std=c++11 lib/cr.cpp -o lib/cr.o"    
    exec "clang++ -c -stdlib=libc++ -std=c++11 -Wno-missing-field-initializers -Wno-unused-variable -Wno-unused-parameter -Wno-unused-private-field -Wno-reorder -o lib/vma.o lib/vma.cpp"
    exec "cc -O0 -ffunction-sections -fdata-sections -g -m64 -fPIC  -DBOOST_CONTEXT_EXPORT -I./src/fragpkg/asm -o ./src/fragpkg/asm/make_combined_all_macho_gas.S.o -c ./src/fragpkg/asm/make_combined_all_macho_gas.S"
    exec "cc -O0 -ffunction-sections -fdata-sections -g -m64 -fPIC  -DBOOST_CONTEXT_EXPORT -I./src/fragpkg/asm -o ./src/fragpkg/asm/jump_combined_all_macho_gas.S.o -c ./src/fragpkg/asm/jump_combined_all_macho_gas.S"
    exec "cc -O0 -ffunction-sections -fdata-sections -g -m64 -fPIC  -DBOOST_CONTEXT_EXPORT -I./src/fragpkg/asm -o ./src/fragpkg/asm/ontop_combined_all_macho_gas.S.o -c ./src/fragpkg/asm/ontop_combined_all_macho_gas.S"
  else:
    echo "platform not supported"

task examples, "build examples":
  exec "nim c --app:lib --out:minimal.dylib examples/minimal.nim"

# Dependencies

requires "nim >= 1.3.5"
requires "nimterop >= 0.6.7"
requires "weave >= 0.4.9"
