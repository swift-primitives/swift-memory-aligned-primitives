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

import Affine_Primitives_Standard_Library_Integration
public import Byte_Primitives
public import Growth_Primitives
public import Index_Primitives
public import Memory_Alignment_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Span_Protocol_Primitives

extension Memory {
    /// A growable, aligned memory **region** with unique ownership.
    ///
    /// `Memory.Aligned` provides guaranteed memory alignment for performance-critical
    /// operations like direct I/O, SIMD processing, and memory-mapped files.
    ///
    /// ## Design Constraints
    ///
    /// `Memory.Aligned` is a **single-buffer**, alignment-constrained, out-of-line
    /// byte region — *not* a vending allocator (it owns one region for its owner; it
    /// does not sub-vend allocations the way `Memory.Arena` / `Memory.Pool` do). It is
    /// **growable in place** (it conforms ``Growth/Growable`` and carries a
    /// ``Growth/Policy`` — growth is a leaf capability per the placement calculus
    /// §5.3), but it does not support:
    /// - Reader/writer indices (use `Binary.Cursor` for positioned access)
    /// - Copy-on-write semantics (move-only ownership guarantees exclusivity)
    ///
    /// ## Ownership
    ///
    /// `Memory.Aligned` is move-only (`~Copyable`). This guarantees:
    /// - Unique ownership at compile time
    /// - No accidental copies of large allocations
    /// - Safe to send across concurrency domains (`Sendable`)
    ///
    /// Memory is deallocated when the region goes out of scope.
    ///
    /// ## Allocation
    ///
    /// Uses `UnsafeMutableRawPointer.allocate(byteCount:alignment:)` for pure Swift
    /// allocation with no platform-specific C imports.
    ///
    /// ## Safety Invariant
    ///
    /// `~Copyable` guarantees single ownership. The buffer owns an
    /// `UnsafeMutablePointer<Byte>` of a known byte count and alignment,
    /// deallocated in `deinit`. Transfer across threads is a move: the compiler
    /// invalidates the original binding after the move, and the old thread cannot
    /// access the memory after the move.
    ///
    /// ## Intended Use
    ///
    /// - Moving an aligned byte buffer from a producer thread to a consumer thread
    ///   as a one-shot transfer.
    /// - Sending into an `actor`'s initializer.
    ///
    /// ## Non-Goals
    ///
    /// Does NOT support concurrent access. The buffer has no internal locks.
    /// All access must be serialized by the owning thread; sendability is
    /// ownership transfer, not sharing.
    ///
    /// ## Usage
    ///
    /// For most APIs, accept `some Span.`Protocol``
    /// rather than `Memory.Aligned` directly. This keeps `Memory.Aligned` as
    /// an implementation detail, not a type that "infects" public interfaces.
    @safe
    public struct Aligned: ~Copyable, @unsafe @unchecked Sendable {
        /// Typed byte pointer to the allocated memory.
        ///
        /// Memory is bound to UInt8 at initialization.
        @usableFromInline
        var bytePointer: UnsafeMutablePointer<Byte>

        /// The number of addressable bytes in the region.
        ///
        /// Grows when the region is reallocated to a larger capacity
        /// (``ensureCapacity(minimum:)`` / ``reserveDiscardingContents(minimum:)``).
        public internal(set) var count: Index<Byte>.Count

        /// The alignment of the allocation (preserved across reallocations).
        public let alignment: Memory.Alignment

        /// The growth strategy applied when the region is reallocated to a larger capacity.
        ///
        /// Carried by the leaf per the placement calculus (§5.3): a growable leaf
        /// *conforms* ``Growth/Growable`` (it can grow) and *holds* a ``Growth/Policy``
        /// (it knows how fast) — orthogonal axes.
        public let growthPolicy: Growth.Policy<Byte>

        deinit {
            unsafe bytePointer.deallocate()
        }
    }
}

// MARK: - Initialization

extension Memory.Aligned {
    /// Creates an aligned buffer with uninitialized contents.
    ///
    /// - Parameters:
    ///   - byteCount: The number of bytes to allocate.
    ///   - alignment: The alignment boundary. `Memory.Alignment` guarantees
    ///     this is a valid power of 2.
    ///   - growthPolicy: The strategy applied when the region is reallocated to a larger capacity. Defaults to `.doubling`.
    /// - Throws: `Error.allocationFailed` if allocation fails.
    ///
    /// - Note: Empty buffers (`byteCount == 0`) allocate 1 byte with the
    ///   requested alignment. This avoids sentinel pointers and platform-specific
    ///   page size queries.
    public init(
        byteCount: Index<Byte>.Count,
        alignment: Memory.Alignment,
        growthPolicy: Growth.Policy<Byte> = .doubling
    ) throws(Self.Error) {
        let alignmentMagnitude: Int = alignment.magnitude()

        if byteCount == .zero {
            let raw = UnsafeMutableRawPointer.allocate(
                byteCount: 1,
                alignment: alignmentMagnitude
            )
            unsafe self.bytePointer = raw.bindMemory(to: Byte.self, capacity: 1)
            self.count = .zero
            self.alignment = alignment
            self.growthPolicy = growthPolicy
            return
        }

        // Convert to Int at the C/stdlib boundary [IMPL-010]
        let size = Int(bitPattern: byteCount)

        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: size,
            alignment: alignmentMagnitude
        )
        unsafe self.bytePointer = raw.bindMemory(to: Byte.self, capacity: size)

        self.count = byteCount
        self.alignment = alignment
        self.growthPolicy = growthPolicy
    }

    /// Creates an aligned buffer initialized with zeros.
    ///
    /// - Parameters:
    ///   - byteCount: The number of bytes to allocate.
    ///   - alignment: The alignment boundary.
    ///   - growthPolicy: The strategy applied when the region is reallocated to a larger capacity. Defaults to `.doubling`.
    /// - Returns: A newly allocated aligned region whose bytes are all zero.
    /// - Throws: `Error.allocationFailed` if allocation fails.
    public static func zeroed(
        byteCount: Index<Byte>.Count,
        alignment: Memory.Alignment,
        growthPolicy: Growth.Policy<Byte> = .doubling
    ) throws(Self.Error) -> Self {
        let buffer = try Self(
            byteCount: byteCount,
            alignment: alignment,
            growthPolicy: growthPolicy
        )
        unsafe buffer.bytePointer.initialize(repeating: Byte(0), count: Int(bitPattern: byteCount))
        return buffer
    }
}

// MARK: - Memory Access (Typed Throws)

extension Memory.Aligned {
    /// Provides read-only access to the buffer contents.
    ///
    /// - Warning: The pointer must not escape the closure scope.
    ///
    /// - Parameter body: A closure that receives a pointer to the buffer.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by the closure (use `Never` for non-throwing).
    @unsafe
    @inlinable
    public func withUnsafeBytes<R, E: Swift.Error>(
        _ body: (UnsafeRawBufferPointer) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafeRawBufferPointer(start: UnsafeRawPointer(bytePointer), count: count))
    }

    /// Provides read-write access to the buffer contents.
    ///
    /// - Warning: The pointer must not escape the closure scope.
    ///
    /// - Parameter body: A closure that receives a mutable pointer to the buffer.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by the closure (use `Never` for non-throwing).
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBytes<R, E: Swift.Error>(
        _ body: (UnsafeMutableRawBufferPointer) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(
            UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(bytePointer), count: count)
        )
    }
}

// MARK: - Alignment Verification

extension Memory.Aligned {
    /// Checks if the buffer is aligned to the given boundary.
    ///
    /// The buffer is always aligned to at least `self.alignment`.
    /// It may also be aligned to larger powers of 2 depending on
    /// the underlying allocator.
    ///
    /// - Parameter boundary: The alignment to check.
    /// - Returns: `true` if the buffer's base address is aligned to the boundary.
    @inlinable
    public func isAligned(to boundary: Memory.Alignment) -> Bool {
        unsafe boundary.isAligned(UnsafeRawPointer(bytePointer))
    }
}

// MARK: - Span Access

extension Memory.Aligned {
    /// Read-only span of the buffer as bytes.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the borrow of `self`.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - Violating this contract is undefined behavior.
    @inlinable
    public var bytes: Swift.Span<Byte> {
        @_lifetime(borrow self)
        borrowing get {
            unsafe Swift.Span(_unsafeStart: bytePointer, count: count)
        }
    }

    /// Mutable span of the buffer as bytes.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the exclusive mutable borrow.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - Violating this contract is undefined behavior.
    @inlinable
    public var mutableBytes: Swift.MutableSpan<Byte> {
        @_lifetime(&self)
        mutating get {
            unsafe Swift.MutableSpan(_unsafeStart: bytePointer, count: count)
        }
    }
}

// MARK: - Raw Span Access (Closure-Based)

extension Memory.Aligned {
    /// Provides read-only raw span access to the buffer.
    ///
    /// Use this when you need `byteCount` semantics or type reinterpretation.
    /// The span is valid only within the closure scope.
    @inlinable
    public func withRawSpan<R, E: Swift.Error>(
        _ body: (RawSpan) throws(E) -> R
    ) throws(E) -> R {
        let span = unsafe RawSpan(_unsafeStart: UnsafeRawPointer(bytePointer), byteCount: count)
        return try body(span)
    }

    /// Provides read-write raw span access to the buffer.
    ///
    /// Use this when you need `byteCount` semantics or type reinterpretation.
    /// The span is valid only within the closure scope.
    @inlinable
    public mutating func withMutableRawSpan<R, E: Swift.Error>(
        _ body: (inout MutableRawSpan) throws(E) -> R
    ) throws(E) -> R {
        var span = unsafe MutableRawSpan(
            _unsafeStart: UnsafeMutableRawPointer(bytePointer),
            byteCount: count
        )
        return try body(&span)
    }
}

// MARK: - Protocol Conformances

extension Memory.Aligned {
    /// Address space marker for buffer memory positions.
    public enum Space {}

    /// Scalar type for index arithmetic (default Int).
    public typealias Scalar = Int
}

// MARK: - Span.Protocol Conformance (tower reconform: the retired closure-borrow seam → the property-form read capability)

extension Memory.Aligned: Span.`Protocol` {
    /// The element type for this contiguous storage.
    public typealias Element = Byte

    /// Read-only span of the buffer's bytes.
    @inlinable
    public var span: Swift.Span<Byte> {
        @_lifetime(borrow self)
        borrowing get {
            bytes
        }
    }

    /// Mutable span of the buffer's bytes.
    @inlinable
    public var mutableSpan: Swift.MutableSpan<Byte> {
        @_lifetime(&self)
        mutating get {
            mutableBytes
        }
    }

    /// Provides read-only access via typed buffer pointer.
    ///
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Byte>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafeBufferPointer(start: bytePointer, count: count))
    }

    /// Provides read-write access via typed mutable buffer pointer.
    ///
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Byte>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafeMutableBufferPointer(start: bytePointer, count: count))
    }
}
