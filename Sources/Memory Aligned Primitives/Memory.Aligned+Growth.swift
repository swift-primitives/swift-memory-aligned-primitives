import Affine_Primitives_Standard_Library_Integration
public import Byte_Primitives
public import Growth_Primitives
public import Index_Primitives
public import Memory_Alignment_Primitives
import Ordinal_Primitives_Standard_Library_Integration

extension Memory.Aligned: Growth.Growable {}

extension Memory.Aligned {

    @inlinable
    public mutating func ensureCapacity(
        minimum: Index<Byte>.Count
    ) throws(Self.Error) {
        guard minimum > count else { return }

        try reallocate(
            to: Index<Byte>.Count.max(growthPolicy.capacity(from: count), minimum),
            preserving: true
        )
    }

    @inlinable
    public mutating func ensureCapacity(
        __unchecked: Void = (),
        minimum: Index<Byte>.Count
    ) {
        guard minimum > count else { return }

        do {
            try reallocate(
                to: Index<Byte>.Count.max(growthPolicy.capacity(from: count), minimum),
                preserving: true
            )
        } catch {
            preconditionFailure("Aligned region reallocation failed: \(error)")
        }
    }

    @inlinable
    public mutating func reserveDiscardingContents(
        minimum: Index<Byte>.Count
    ) throws(Self.Error) {
        guard minimum > count else { return }

        try reallocate(
            to: Index<Byte>.Count.max(growthPolicy.capacity(from: count), minimum),
            preserving: false
        )
    }

    @usableFromInline
    internal mutating func reallocate(
        to newCapacity: Index<Byte>.Count,
        preserving: Bool
    ) throws(Self.Error) {
        var newRegion = try Memory.Aligned(
            byteCount: newCapacity,
            alignment: alignment,
            growthPolicy: growthPolicy
        )

        if preserving {
            let bytesToCopy = Int(
                bitPattern: Index<Byte>.Count.min(count, newCapacity).underlying.rawValue
            )
            unsafe newRegion.withUnsafeMutableBytes { dest in
                unsafe withUnsafeBytes { src in
                    unsafe dest.copyMemory(
                        from: UnsafeRawBufferPointer(rebasing: src.prefix(bytesToCopy))
                    )
                }
            }
        }

        self = newRegion
    }
}
