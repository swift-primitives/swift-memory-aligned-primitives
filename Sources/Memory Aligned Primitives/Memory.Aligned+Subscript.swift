import Affine_Primitives_Standard_Library_Integration
public import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration

extension Memory.Aligned {

    @inlinable
    public subscript(range: Swift.Range<Int>) -> Span<Byte> {
        @_lifetime(borrow self)
        borrowing get {
            bytes.extracting(range)
        }
    }

    @inlinable
    public subscript(range: PartialRangeFrom<Int>) -> Span<Byte> {
        @_lifetime(borrow self)
        borrowing get {
            bytes.extracting(range.lowerBound..<Int(bitPattern: count))
        }
    }

    @inlinable
    public subscript(range: PartialRangeUpTo<Int>) -> Span<Byte> {
        @_lifetime(borrow self)
        borrowing get {
            bytes.extracting(0..<range.upperBound)
        }
    }

    @inlinable
    public subscript(range: PartialRangeThrough<Int>) -> Span<Byte> {
        @_lifetime(borrow self)
        borrowing get {
            bytes.extracting(0...range.upperBound)
        }
    }
}
