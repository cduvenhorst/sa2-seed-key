# SA2SeedKey

🇩🇪 Deutsch · [🇬🇧 English](README.en.md)

Swift-Package für die SA2-Seed/Key-Authentifizierung von Steuergeräten des Volkswagen-Konzerns.
Portierung des Python-Moduls [bri3d/sa2_seed_key](https://github.com/bri3d/sa2_seed_key).

SA2 ist das Seed/Key-Verfahren, mit dem sich Test- und Flash-Werkzeuge gegenüber einem Steuergerät
ausweisen, meist um eine Programmiersitzung freizuschalten. Das SA2-„Skript“ steckt im FRF- bzw.
ODX-Flash-Container und besteht aus Bytecode für eine kleine virtuelle Maschine, die den vom
Steuergerät gelieferten Seed in den passenden Key umrechnet.

Eine ausführliche Beschreibung von Algorithmus und Datentypen für Entwickler steht in
[doc/SA2SeedKey.de.md](doc/SA2SeedKey.de.md)
(englische Fassung: [doc/SA2SeedKey.en.md](doc/SA2SeedKey.en.md)).

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

## Verwendung

```swift
import SA2SeedKey

let script: SA2Script = [
    0x68, 0x02, 0x81, 0x49, 0x93, 0xA5, 0x5A, 0x55, 0xAA, 0x4A, 0x05, 0x87, 0x81, 0x05, 0x95,
    0x26, 0x68, 0x05, 0x82, 0x49, 0x84, 0x5A, 0xA5, 0xAA, 0x55, 0x87, 0x03, 0xF7, 0x80, 0x6A, 0x4C,
]

let key = try script.key(forSeed: 0x1A1B_1C1D) // 0x6A37F02E
```

Ein Skript lässt sich auch aus `Data` oder einer beliebigen `Sequence<UInt8>` erzeugen:

```swift
let script = SA2Script(data)
```

### Disassemblieren

```swift
print(try script.disassembly())
// for 2
// rsl
// next
// add 0xA55A55AA
// ...

let instructions: [SA2Instruction] = try script.instructions()
```

### Fehlerbehandlung

Anders als das Python-Original bricht ein fehlerhaftes Skript nicht mit einer Laufzeitausnahme ab,
sondern wirft einen typisierten `SA2Error`:

| Fall                                          | Fehler                                        |
| --------------------------------------------- | --------------------------------------------- |
| Unbekannter Opcode                            | `.unknownOpcode(_:offset:)`                   |
| Operanden reichen über das Skriptende hinaus  | `.truncatedInstruction(opcode:offset:)`       |
| `next` ohne zugehörige Schleife               | `.unmatchedNext(offset:)`                     |

## Befehlssatz

| Opcode | `SA2Instruction`             | Größe | Wirkung                                                         |
| ------ | ---------------------------- | ----- | --------------------------------------------------------------- |
| `0x81` | `.rotateLeft`                | 1     | Register um 1 Bit nach links rotieren, herausgeschobenes Bit → Carry |
| `0x82` | `.rotateRight`               | 1     | Register um 1 Bit nach rechts rotieren, herausgeschobenes Bit → Carry |
| `0x93` | `.add(UInt32)`               | 5     | Addition, Carry bei Überlauf                                    |
| `0x84` | `.subtract(UInt32)`          | 5     | Subtraktion, Carry bei Unterlauf                                |
| `0x87` | `.exclusiveOr(UInt32)`       | 5     | Exklusiv-Oder                                                   |
| `0x68` | `.loop(count:)`              | 2     | Schleifenbeginn, Rumpf läuft `count`-mal (mindestens einmal)    |
| `0x49` | `.next`                      | 1     | Ende des innersten Schleifenrumpfs                              |
| `0x4A` | `.branchIfCarryClear(offset:)` | 2   | Überspringt `offset` Bytes, falls Carry nicht gesetzt ist       |
| `0x6B` | `.branch(offset:)`           | 2     | Überspringt `offset` Bytes                                      |
| `0x4C` | `.finish`                    | 1     | Skriptende (hält die Maschine nicht an)                         |

32-Bit-Operanden sind Big-Endian kodiert.

## Unterschiede zum Python-Original

- `SA2Script` ist ein unveränderlicher Werttyp; `key(forSeed:)` kann beliebig oft und nebenläufig
  aufgerufen werden. (Im Original teilen sich alle Instanzen den Schleifenstapel, und ein zweiter
  Aufruf von `execute()` liefert nur das bereits berechnete Register zurück.)
- Fehlerhafter Bytecode führt zu einem `SA2Error` statt zu `KeyError`/`IndexError`.

## Tests

```sh
swift test
```

## Lizenz

MIT. Das Original stammt von Brian Ledbetter (MIT-Lizenz, © 2022).
