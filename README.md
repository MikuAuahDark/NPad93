NPad Libraries
=====

Various NPad Lua libraries for LOVE can be found here. Most libs are single files unless noted.

Check each file/folder for license terms.

ts-declarations
-----

This is not a library, but it's TypeScript definitions meant to be used with [TypeScriptToLua](https://github.com/TypeScriptToLua/TypeScriptToLua).

Each file correspond to each module, unless noted. Note that some module may not have TypeScript definitions, yet.

NVec
-----

**N**Pad **Vec**tor library, LuaJIT FFI-accelerated [hump.vector](https://github.com/vrld/hump/blob/master/vector.lua)-compatible
vector library. Meant as drop-in replacement of hump.vector. Originally written for my game for optimization
purpose, but I think it's better if I make this as standalone and let everyone use it.

For documentation, check out hump.vector documentation: https://hump.readthedocs.io/en/latest/vector.html

NGrading
-----

**N**Pad Color **Grading**, provides easy color grading for your post-processing needs.

For documentation, check out the `ngrading` folder.

NWFC
-----

**N**Pad [**W**ave **F**unction **C**ollapse](https://github.com/mxgmn/WaveFunctionCollapse), WFC implemented in Lua and tries to
be 1:1 mapping between the original WFC.

NFML
-----

**N**Pad **F**FI/Fast/Fine **M**ath **L**ibrary, meant as alternative to CPML. **Work in progress!**

Functions mostly follows [GLSL function names](http://www.shaderific.com/glsl-functions).

NLog
-----

**N**Pad **Log**ging library.

* Uses ANSI color codes on Linux, macOS, and Windows 10 1607

* Uses Windows console API on Windows 10 prior 1607

* Uses [Android native logging](https://developer.android.com/ndk/reference/group/logging) functions

This library missed iOS implementation and may not run with it.

The log level are divided by 4: `info`, `warn`, `error`, and `debug`. NLog exports `nlog.info`, `nlog.warn`, ... and so on.
Furthermore, there's also functions with `f` suffix (`nlog.infof`) which accepts formatted string same as `string.format`.

There's `nlog.getLevel` to retrieve the current logging level:

* 0 = don't print anything

* 1 = print errors (`nlog.error`/`nlog.errorf`)

* 2 = print warnings (`nlog.warn`/`nlog.warnf`)

* 3 = print information (`nlog.info`/`nlog.infof`)

* 4 = print debug information (`nlog.debug`/`nlog.debugf`)

Ensure to modify the `ENVIRONMENT_VARIABLE` variable prior using the library. It's `NLOG_LOGLEVEL` environment variable by default.
