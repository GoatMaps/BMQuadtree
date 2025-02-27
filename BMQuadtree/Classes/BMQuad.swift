//
//  BMQuad.swift
//  BMQuadtree
//
//  Created by Adam Eri on 04.12.18.
//

import Foundation
import simd

/// Representation of an axis aligned quad via its min corner (lower-left)
/// and max corner (upper-right)
public struct BMQuad: Equatable {
    /// The lower-left coordinate of the element
    public var quadMin: vector_float2

    /// The upper-right coordinate of the element
    public var quadMax: vector_float2

    public init(quadMin: vector_float2, quadMax: vector_float2) {
        self.quadMin = quadMin
        self.quadMax = quadMax
    }

    public static func == (lhs: BMQuad, rhs: BMQuad) -> Bool {
        return lhs.quadMin == rhs.quadMin && lhs.quadMax == rhs.quadMax
    }
}

public extension BMQuad {
    /// Checks if the point specified is within this quad.
    ///
    /// - Parameter point: the point to query
    /// - Returns: Returns true if the point specified is within this quad.
    func contains(_ point: vector_float2) -> Bool {
        // Above lower left corner
        let gtMin = (point.x >= quadMin.x && point.y >= quadMin.y)

        // Below upper right coner
        let leMax = (point.x <= quadMax.x && point.y <= quadMax.y)

        // If both is true, the point is inside the quad.
        return gtMin && leMax
    }

    /// Checks if the specified quad intersects with self.
    ///
    /// - Parameter quad: the quad to query
    /// - Returns: Returns true if the quad intersects
    func intersects(_ quad: BMQuad) -> Bool {
        if quadMin.x > quad.quadMax.x ||
            quadMin.y > quad.quadMax.y {
            return false
        }

        if quadMax.x < quad.quadMin.x ||
            quadMax.y < quad.quadMin.y {
            return false
        }

        return true
    }
}
