import Testing
@testable import SA2SeedKey

struct SA2ScriptTests {
    static let loopScript: SA2Script = [
        0x68, 0x02, 0x81, 0x49, 0x93, 0xA5, 0x5A, 0x55, 0xAA, 0x4A, 0x05, 0x87, 0x81, 0x05, 0x95,
        0x26, 0x68, 0x05, 0x82, 0x49, 0x84, 0x5A, 0xA5, 0xAA, 0x55, 0x87, 0x03, 0xF7, 0x80, 0x6A, 0x4C,
    ]

    static let nestedScript: SA2Script = [
        0x68, 0x02, 0x81, 0x4A, 0x10, 0x68, 0x04, 0x93, 0x08, 0x08, 0x20, 0x09, 0x4A, 0x05, 0x87,
        0x22, 0x12, 0x19, 0x54, 0x82, 0x49, 0x93, 0x07, 0x12, 0x20, 0x11, 0x82, 0x4A, 0x05, 0x87,
        0x03, 0x11, 0x20, 0x10, 0x82, 0x4A, 0x01, 0x81, 0x49, 0x4C,
    ]

    @Test(arguments: [
        (loopScript, UInt32(0x1A1B_1C1D), UInt32(0x6A37_F02E)),
        (nestedScript, UInt32(0xA04E_B1ED), UInt32(0x3C78_76D8)),
    ])
    func computesKey(script: SA2Script, seed: UInt32, expectedKey: UInt32) throws {
        #expect(try script.key(forSeed: seed) == expectedKey)
    }

    @Test func isDeterministic() throws {
        let script = Self.nestedScript
        #expect(try script.key(forSeed: 0xA04E_B1ED) == script.key(forSeed: 0xA04E_B1ED))
    }

    @Test func decodesInstructions() throws {
        #expect(try Self.loopScript.instructions() == [
            .loop(count: 2),
            .rotateLeft,
            .next,
            .add(0xA55A_55AA),
            .branchIfCarryClear(offset: 5),
            .exclusiveOr(0x8105_9526),
            .loop(count: 5),
            .rotateRight,
            .next,
            .subtract(0x5AA5_AA55),
            .exclusiveOr(0x03F7_806A),
            .finish,
        ])
    }

    @Test(arguments: [loopScript, nestedScript])
    func roundTripsInstructions(script: SA2Script) throws {
        #expect(try SA2Script(instructions: script.instructions()) == script)
    }

    @Test func disassembles() throws {
        let script: SA2Script = [0x68, 0x03, 0x81, 0x49, 0x87, 0x00, 0x00, 0xBE, 0xEF, 0x4C]
        #expect(try script.disassembly() == """
            for 3
            rsl
            next
            eor 0x0000BEEF
            finish
            """)
    }

    @Test func rotatesThroughCarry() throws {
        #expect(try SA2Script([0x81]).key(forSeed: 0x8000_0001) == 0x0000_0003)
        #expect(try SA2Script([0x82]).key(forSeed: 0x8000_0001) == 0xC000_0000)
    }

    @Test func branchesOnCarry() throws {
        // add overflows -> carry set -> branch not taken -> eor runs
        let overflowing: SA2Script = [0x93, 0x00, 0x00, 0x00, 0x02, 0x4A, 0x05, 0x87, 0x00, 0x00, 0x00, 0xFF]
        #expect(try overflowing.key(forSeed: 0xFFFF_FFFF) == 0x0000_00FE)
        // no overflow -> carry clear -> branch taken -> eor skipped
        #expect(try overflowing.key(forSeed: 0x0000_0001) == 0x0000_0003)
        // sub underflows -> carry set
        let underflowing: SA2Script = [0x84, 0x00, 0x00, 0x00, 0x02, 0x4A, 0x05, 0x87, 0x00, 0x00, 0x00, 0xFF]
        #expect(try underflowing.key(forSeed: 0x0000_0001) == 0xFFFF_FF00)
    }

    @Test func branchesUnconditionally() throws {
        let script: SA2Script = [0x6B, 0x01, 0x81, 0x82]
        #expect(try script.key(forSeed: 0x0000_0002) == 0x0000_0001)
    }

    @Test func loopWithZeroCountRunsOnce() throws {
        let script: SA2Script = [0x68, 0x00, 0x81, 0x49]
        #expect(try script.key(forSeed: 0x0000_0001) == 0x0000_0002)
    }

    @Test func rejectsUnknownOpcode() {
        #expect(throws: SA2Error.unknownOpcode(0xFF, offset: 1)) {
            try SA2Script([0x81, 0xFF]).key(forSeed: 0)
        }
    }

    @Test func rejectsTruncatedInstruction() {
        #expect(throws: SA2Error.truncatedInstruction(opcode: 0x93, offset: 1)) {
            try SA2Script([0x81, 0x93, 0x00, 0x00]).key(forSeed: 0)
        }
    }

    @Test func rejectsUnmatchedNext() {
        #expect(throws: SA2Error.unmatchedNext(offset: 0)) {
            try SA2Script([0x49]).key(forSeed: 0)
        }
    }

    @Test func emptyScriptReturnsSeed() throws {
        #expect(try SA2Script([]).key(forSeed: 0x1234_5678) == 0x1234_5678)
    }
}
