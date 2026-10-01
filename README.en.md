# SA2-Seed/Key

🇬🇧 English · [🇩🇪 Deutsch](README.md)

Swift package for SA2 seed/key authentication with Volkswagen Group control units.
A port of the Python module [bri3d/sa2_seed_key](https://github.com/bri3d/sa2_seed_key).

SA2 is the seed/key mechanism that test and flashing tools use to authenticate with a control
unit, usually to unlock a programming session. The SA2 "script" is contained in the FRF or ODX
flash container and consists of bytecode for a small virtual machine that transforms the seed
provided by the control unit into the matching key.

A detailed description of the algorithm and data types for developers is available in
[doc/SA2SeedKey.en.md](doc/SA2SeedKey.en.md)
(German version: [doc/SA2SeedKey.de.md](doc/SA2SeedKey.de.md)).

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/cduvenhorst/sa2-seed-key.git", branch: "main"),
],
targets: [
    .target(name: "MyTool", dependencies: [
        .product(name: "SA2SeedKey", package: "sa2-seed-key"),
    ]),
]
```

## Usage

```swift
import SA2SeedKey

let script: SA2Script = [
    0x68, 0x02, 0x81, 0x49, 0x93, 0xA5, 0x5A, 0x55, 0xAA, 0x4A, 0x05, 0x87, 0x81, 0x05, 0x95,
    0x26, 0x68, 0x05, 0x82, 0x49, 0x84, 0x5A, 0xA5, 0xAA, 0x55, 0x87, 0x03, 0xF7, 0x80, 0x6A, 0x4C,
]

let key = try script.key(forSeed: 0x1A1B_1C1D) // 0x6A37F02E
```

A script can also be created from `Data` or any `Sequence<UInt8>`:

```swift
let script = SA2Script(data)
```

### Disassembling

```swift
print(try script.disassembly())
// for 2
// rsl
// next
// add 0xA55A55AA
// ...

let instructions: [SA2Instruction] = try script.instructions()
```

### Error Handling

Unlike the Python original, a malformed script does not crash with a runtime exception but throws
a typed `SA2Error`:

| Case                                          | Error                                         |
| --------------------------------------------- | --------------------------------------------- |
| Unknown opcode                                | `.unknownOpcode(_:offset:)`                   |
| Operands extend past the end of the script    | `.truncatedInstruction(opcode:offset:)`       |
| `next` without a matching loop                | `.unmatchedNext(offset:)`                     |

## Instruction Set

| Opcode | `SA2Instruction`               | Size | Effect                                                            |
| ------ | ------------------------------ | ---- | ----------------------------------------------------------------- |
| `0x81` | `.rotateLeft`                  | 1    | Rotate register left by 1 bit, bit shifted out → carry            |
| `0x82` | `.rotateRight`                 | 1    | Rotate register right by 1 bit, bit shifted out → carry           |
| `0x93` | `.add(UInt32)`                 | 5    | Addition, carry on overflow                                       |
| `0x84` | `.subtract(UInt32)`            | 5    | Subtraction, carry on underflow                                   |
| `0x87` | `.exclusiveOr(UInt32)`         | 5    | Exclusive or                                                      |
| `0x68` | `.loop(count:)`                | 2    | Loop start, body runs `count` times (at least once)               |
| `0x49` | `.next`                        | 1    | End of the innermost loop body                                    |
| `0x4A` | `.branchIfCarryClear(offset:)` | 2    | Skips `offset` bytes if carry is not set                          |
| `0x6B` | `.branch(offset:)`             | 2    | Skips `offset` bytes                                              |
| `0x4C` | `.finish`                      | 1    | End of script (does not halt the machine)                         |

32-bit operands are encoded big-endian.

## Differences from the Python Original

- `SA2Script` is an immutable value type; `key(forSeed:)` can be called any number of times and
  concurrently. (In the original, all instances share the loop stack, and a second call to
  `execute()` merely returns the previously computed register.)
- Malformed bytecode results in an `SA2Error` instead of `KeyError`/`IndexError`.

## Tests

```sh
swift test
```

## License

MIT. The original is by Brian Ledbetter (MIT License, © 2022).
