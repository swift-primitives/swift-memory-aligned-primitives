// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Index_Primitives
import Memory_Aligned_Primitives_Test_Support
import Testing

@Suite("Memory.Aligned Tests")
struct `Memory.Aligned Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Memory.Aligned Tests`.Unit {
    @Test
    func `allocates with requested alignment and count`() throws {
        let alignment = try Memory.Alignment(64)
        let buffer = try Memory.Aligned(byteCount: 64, alignment: alignment)
        #expect(buffer.count == Index<Byte>.Count(64))
        let aligned = buffer.isAligned(to: alignment)
        #expect(aligned)
    }

    @Test
    func `zeroed buffer reads zero everywhere`() throws {
        let buffer = try Memory.Aligned.zeroed(byteCount: 16, alignment: try Memory.Alignment(16))
        unsafe buffer.withUnsafeBytes { bytes in
            for b in unsafe bytes { #expect(b == 0) }
        }
    }

    @Test
    func `round-trips bytes through mutable access`() throws {
        var buffer = try Memory.Aligned(byteCount: 4, alignment: try Memory.Alignment(8))
        unsafe buffer.withUnsafeMutableBytes { bytes in
            for i in 0..<4 { unsafe bytes[i] = UInt8(i + 1) }
        }
        unsafe buffer.withUnsafeBytes { bytes in
            #expect(unsafe bytes[3] == 4)
        }
    }
}
