# hook

Hooking library written for GTA:SA (MP) in Lua language for 32-bit architecture.

## Features

* Auto-size detection.
* Relay (hook object in callback parameters)
* Hook installation without a callback (thanks to the relays)
* Code generation for trampoline (thanks MinHook)
* Hook-on-hook support.
* Unloading in any conditions.

## Installation

Extract `src` directory to your `moonloader/lib` directory.

## Usage / Examples

See `demo/init.lua` for examples and usage.

## Credits

* [MinHook](https://github.com/TsudaKageyu/minhook) (for trampoline code generation)
* Vyacheslav Patkov for implementing Hacker Disassemble Engine.

## See also

* hook written using [moonly](https://github.com/themusaigen/moonly)

## License

`hook` licensed under `MIT` license. See `LICENSE` for details.