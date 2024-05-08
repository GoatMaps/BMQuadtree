//
//  BMQuadtree.swift
//  Bikemap
//
//  Created by Adam Eri on 22/06/2017.
//  Copyright © 2017 Bikemap GmbH. All rights reserved.
//

import Foundation
import simd

/// The BMQuadtree is an almost drop-in replacement for the GKQuadtree,
/// as that one is reportedly not working as of iOS10.
///
/// A tree data structure where each level has 4 children that subdivide a
/// given space into the four quadrants.
/// Stores arbitrary data of any class via points and quads.
public final class BMQuadtree<T: AnyObject> {
    /// Typealias to use for objects stored in the tree
    public typealias Object = (T, vector_float2?, BMQuad?)

    // Bounding quad
    var quad: BMQuad

    /// Child Quad Trees
    var northWest: BMQuadtree?
    var northEast: BMQuadtree?
    var southWest: BMQuadtree?
    var southEast: BMQuadtree?

    /// The depth of the tree
    var depth: Int64 = 0

    /// The maximum depth of the tree. The limit is there to avoid infinite loops
    /// when adding the same, or very close elements in large numbers.
    /// This limits the maximum amount of elements to be stored in the tree:
    /// numberOfNodes ^ maximumDepth * minCellSize
    /// 4 ^ 10 * 3 = 3.145.728
    private var maximumDepth: Int64

    public init(
        boundingQuad quad: BMQuad,
        minimumCellSize minCellSize: Int64 = 1,
        maximumDepth: Int64 = 10
    ) {
        self.quad = quad
        self.minCellSize = minCellSize
        self.maximumDepth = maximumDepth
    }

    /// Adds an NSObject to this quadtree with a given point.
    /// This data will always reside in the leaf node its point is in.
    ///
    /// - Parameters:
    ///   - element: the element to store
    ///   - point: the point associated with the element you want to store
    /// - Returns: the quadtree node the element was added to
    @discardableResult
    public func add(_ element: T, at point: vector_float2) -> BMQuadtreeNode<T>? {
        // Checking if the point specified should be within this quad.
        // With the initial tree, it is always true. This comes handy when
        // subdividing the quad and need to place the object to a specific quad.
        if quad.contains(point) == false {
            return nil
        }

        // We check the minCellSize to see if the object still fits and that the
        // tree has no leafs. If it has, the point goes into the leafs.
        if objects.count < minCellSize, hasQuads == false {
            objects.append((element, point, nil))
            return BMQuadtreeNode(tree: self)
        }

        // Otherwise, subdivide and add the point to whichever child will accept it
        if hasQuads == false {
            guard depth < maximumDepth else {
                // Can't subdivide any further, so add to this node.
                objects.append((element, point, nil))
                return BMQuadtreeNode(tree: self)
            }
            subdivide()
        }

        // Adding the new point to the leafs.
        // If necessary, this will take care of the multiple splitting
        if let NW = northWest!.add(element, at: point) {
            return NW
        } else if let NE = northEast!.add(element, at: point) {
            return NE
        } else if let SW = southWest!.add(element, at: point) {
            return SW
        } else if let SE = southEast!.add(element, at: point) {
            return SE
        }

        // It should never actually fail.
        return nil
    }

    /**
     * Adds an NSObject to this quadtree with a given quad.
     * This data will reside in the lowest node that its quad fits in completely.
     *
     * @param data the data to store
     * @param quad the quad associated with the element you want to store
     * @return the quad tree node the element was added to
     */
    @discardableResult
    public func add(_ element: T, in quad: BMQuad) -> [BMQuadtreeNode<T>]? {
        // Checking if the point specified should be within this quad.
        // With the initial tree, it is always true. This comes handy when
        // subdividing the quad and need to place the object to a specific quad.
        if self.quad.intersects(quad) == false {
            return nil
        }

        // We check the minCellSize to see if the object still fits and that the
        // tree has no leafs. If it has, the point goes into the leafs.
        if objects.count < minCellSize, hasQuads == false {
            objects.append((element, nil, quad))
            return [BMQuadtreeNode(tree: self)]
        }

        // Otherwise, subdivide and add the point to whichever child will accept it
        if hasQuads == false {
            guard depth < maximumDepth else {
                // Can't subdivide any further, so add to this node.
                objects.append((element, nil, quad))
                return [BMQuadtreeNode(tree: self)]
            }
            subdivide()
        }

        // Adding the new point to the leafs.
        // If necessary, this will take care of the multiple splitting
        var ret: [BMQuadtreeNode<T>] = []
        if let NW = northWest!.add(element, in: quad) {
            ret.append(contentsOf: NW)
        }
        if let NE = northEast!.add(element, in: quad) {
            ret.append(contentsOf: NE)
        }
        if let SW = southWest!.add(element, in: quad) {
            ret.append(contentsOf: SW)
        }
        if let SE = southEast!.add(element, in: quad) {
            ret.append(contentsOf: SE)
        }

        if ret.count > 0 {
            return ret
        }

        // It should never actually fail.
        return nil
    }

    /// Returns all of the elements in the quadtree node this
    /// point would be placed in
    ///
    /// - Parameter point: the point to query
    /// - Returns: an NSArray of all the data found at the quad tree node this
    /// point would be placed in
    public func elements(at point: vector_float2) -> [T] {
        var elements: [T] = []

        // If point is outside the tree bounds, return empty array.
        if quad.contains(point) == false {
            return elements
        }

        if hasQuads == false {
            elements = objects.compactMap { $0.0 }
        } else {
            elements.append(contentsOf: northWest!.elements(at: point))
            elements.append(contentsOf: northEast!.elements(at: point))
            elements.append(contentsOf: southWest!.elements(at: point))
            elements.append(contentsOf: southEast!.elements(at: point))
        }
        return elements
    }

    /// Returns all of the elements that resides in quad tree nodes which
    /// intersect the given quad. Recursively check if the earch quad contains
    /// the points in the quad.
    ///
    /// - Parameter quad: the quad you want to test
    /// - Returns: an NSArray of all the elements in all of the nodes that
    /// intersect the given quad
    public func elements(in quad: BMQuad) -> [T] {
        var elements: [T] = []

        // Return if the search quad does not intersect with self.

        if self.quad.intersects(quad) == false {
            return elements
        }

        if hasQuads == false {
            // If there is no leaf, filter the objects, which are in the searchQuad.
            elements = objects
                .filter { ($0.1 != nil && quad.contains($0.1!)) || ($0.2 != nil && quad.intersects($0.2!)) }
                .compactMap { $0.0 }
        } else {
            elements.append(contentsOf: northWest!.elements(in: quad))
            elements.append(contentsOf: northEast!.elements(in: quad))
            elements.append(contentsOf: southWest!.elements(in: quad))
            elements.append(contentsOf: southEast!.elements(in: quad))
        }

        return elements
    }

    /// Returns the element nearest ot the specified point.
    ///
    /// - Parameter point: The point used for the search
    /// - Returns: The nearest element in the tree to the specified point, or nil
    /// if the tree is empty
    public func element(nearestTo point: vector_float2) -> T? {
        let nearestElement =
            element(nearestTo: point, ofType: AnyObject.self, nearest: nil)
        return nearestElement?.element
    }

    /// Returns the element of the specified type nearest ot the specified point.
    ///
    /// - Parameter:
    ///   - point: The point used for the search
    ///   - type: The type of elements to search for
    /// - Returns: The nearest element in the tree to the specified point, or nil
    /// if the tree is empty
    public func element<U: AnyObject>(
        nearestTo point: vector_float2,
        ofType elementType: U.Type
    ) -> T? {
        let nearestElement =
            element(nearestTo: point, ofType: elementType, nearest: nil)
        return nearestElement?.element
    }

    /// A custom type for the nearest element, a tuple containing the actual
    /// element in the tree, plus the distance to the specified point.
    typealias NearestElement = (element: T, distance: Float)

    /// Returns the object nearest ot the specified point.
    ///
    /// Performs a lookup in the tree and it's subquads for objects, which are
    /// near the specified point.
    ///
    /// The objects might be in the same quad or in neigbouring quads.
    /// We exculde quads, which are further on any axis then the last found
    /// nearest element. This way we minimise the number of Euclidean distance
    /// calculations.
    ///
    /// - Parameters:
    ///   - point: The point used for the search
    ///   - nearest: The last found nearest element
    /// - Returns: The nearest object in the tree to the specified point, or nil
    private func element<U: AnyObject>(
        nearestTo point: vector_float2,
        ofType elementType: U.Type,
        nearest: NearestElement? = nil
    ) -> NearestElement? {
        var nearestElement = nearest

        let a = point.x
        let b = point.y
        let x1 = quad.quadMin.x
        let y1 = quad.quadMin.y
        let x2 = quad.quadMax.x
        let y2 = quad.quadMax.y

        // Distance is either the distance to the last found nearest element
        // or the full width of the node.
        let shortestDistance: Float = nearestElement?.distance ?? x2 - (x2 - x1)

        // We exculde quads, which are further on any axis then the last found
        // nearest element. This way we minimise the number of Euclidean distance
        // calculations.
        if a - shortestDistance > x2 ||
            b + shortestDistance < y1 ||
            a + shortestDistance < x1 ||
            b - shortestDistance > y2 {
            return nearest
        }

        if hasQuads == false, objects.count > 0 {
            // Test the elements of the node by calculating Euclidean distance to the
            // point.
            for object in objects {
                // Filter for the specified type
                if elementType != AnyObject.self, type(of: object.0) != elementType {
                    continue
                }

                if object.1 != nil {
                    let dx = object.1!.x - a
                    let dy = object.1!.y - b
                    let distance = sqrt(dx * dx + dy * dy)

                    if distance < shortestDistance {
                        nearestElement = (object.0, distance)
                    }
                } else if object.2 != nil {
                    if quad.contains(point) {
                        nearestElement = (object.0, 0)
                    } else {
                        let dx = object.2!.quadMax.x - a
                        let dy = object.2!.quadMax.y - b
                        let distance = sqrt(dx * dx + dy * dy)
                        // TODO: this should check all for corners of the quad, but we dont use this so im not doing it
                        if distance < shortestDistance {
                            nearestElement = (object.0, distance)
                        }
                    }
                }
            }
        } else {
            // Scanning the sub-nodes for nearest element
            nearestElement = northWest?
                .element(
                    nearestTo: point,
                    ofType: elementType,
                    nearest: nearestElement
                ) ??
                nearestElement

            nearestElement = northEast?
                .element(
                    nearestTo: point,
                    ofType: elementType,
                    nearest: nearestElement
                ) ??
                nearestElement

            nearestElement = southWest?
                .element(
                    nearestTo: point,
                    ofType: elementType,
                    nearest: nearestElement
                ) ??
                nearestElement

            nearestElement = southEast?
                .element(
                    nearestTo: point,
                    ofType: elementType,
                    nearest: nearestElement
                ) ??
                nearestElement
        }

        return nearestElement
    }

    /// Removes the given NSObject from this quad tree.
    /// If there are no more items in the node, we try unifying. See `unify()`.
    ///
    /// Note that this is an exhaustive search and is slow.
    /// Cache the relevant GKQuadTreeNode and use removeElement:WithNode:
    /// for better performance.
    ///
    /// - Parameter element: the data to be removed
    /// - Returns: returns true if the data was removed, false otherwise
    public func remove(_ element: T) -> Bool {
        if hasQuads == false {
            // Node does not contain this element
            let index = objects.firstIndex { element === $0.0 }

            guard index != nil,
                  index! >= 0 else {
                return false
            }

            // Removing element
            objects.remove(at: index!)

            // Try unifying quads if node is empty
            if objects.count == 0 {
                parent?.unify()
            }

            return true
        } else {
            // Trying to remove from all child nodes
            let nw = northWest!.remove(element)
            let ne = northEast!.remove(element)
            let sw = southWest!.remove(element)
            let se = southEast!.remove(element)

            return nw || ne || sw || se
        }
    }

    // MARK: - Private

    /// Keeping a reference to the parent so we can search nearby quads
    /// and unsubdivide after deletion.
    private weak var parent: BMQuadtree? {
        didSet {
            depth = parent!.depth + 1
        }
    }

    /// The number of objects stored in the cell
    private var minCellSize: Int64 = 1

    /// Objects stored in this node
    private var objects: [Object] = []

    /// True, if the tree has leafs.
    /// It means, there are no objects stored direclty in the tree, but only
    /// in its leafs.
    var hasQuads: Bool {
        return northWest != nil
    }

    /// Function to subdivide a QuadTree into 4 smaller QuadTrees
    private func subdivide() {
        let minX = quad.quadMin.x
        let minY = quad.quadMin.y
        let maxX = quad.quadMax.x
        let maxY = quad.quadMax.y

        let deltaX = maxX - minX
        let deltaY = maxY - minY

        let quadNW = BMQuad(
            quadMin: SIMD2<Float>(minX, minY + deltaY / 2),
            quadMax: SIMD2<Float>(maxX - deltaX / 2, maxY)
        )

        let quadNE = BMQuad(
            quadMin: SIMD2<Float>(minX + deltaX / 2, minY + deltaY / 2),
            quadMax: SIMD2<Float>(maxX, maxY)
        )

        let quadSW = BMQuad(
            quadMin: SIMD2<Float>(minX, minY),
            quadMax: SIMD2<Float>(minX + deltaX / 2, minY + deltaY / 2)
        )

        let quadSE = BMQuad(
            quadMin: SIMD2<Float>(minX + deltaX / 2, minY),
            quadMax: SIMD2<Float>(maxX, maxY - deltaY / 2)
        )

        northWest = BMQuadtree(
            boundingQuad: quadNW,
            minimumCellSize: minCellSize,
            maximumDepth: maximumDepth
        )
        northWest?.parent = self

        northEast = BMQuadtree(
            boundingQuad: quadNE,
            minimumCellSize: minCellSize,
            maximumDepth: maximumDepth
        )
        northEast?.parent = self

        southWest = BMQuadtree(
            boundingQuad: quadSW,
            minimumCellSize: minCellSize,
            maximumDepth: maximumDepth
        )
        southWest?.parent = self

        southEast = BMQuadtree(
            boundingQuad: quadSE,
            minimumCellSize: minCellSize,
            maximumDepth: maximumDepth
        )
        southEast?.parent = self

        // Relocate the tree's object to the leafs
        for object in objects {
            if let point = object.1 {
                if northWest!.add(object.0, at: point) != nil {
                    continue
                } else if northEast!.add(object.0, at: point) != nil {
                    continue
                } else if southWest!.add(object.0, at: point) != nil {
                    continue
                } else if southEast!.add(object.0, at: point) != nil {
                    continue
                }
            } else if let quad = object.2 {
                northWest!.add(object.0, in: quad)
                northEast!.add(object.0, in: quad)
                southWest!.add(object.0, in: quad)
                southEast!.add(object.0, in: quad)
            }
        }

        objects.removeAll()
    }

    /// Optimising the quadtree by cleanin up after removing elements.
    /// If the number of elements in all subquads are less then minimumCellSize,
    /// delete all the sub-quads and place the objects into the parent.
    private func unify() {
        // If all guads are empty, delete them all
        if northWest?.objects.count == 0,
           northEast?.objects.count == 0,
           southWest?.objects.count == 0,
           southEast?.objects.count == 0 {
            northWest = nil
            northEast = nil
            southWest = nil
            southEast = nil
        }

        // BMTODO: Collect all elements in sub-quads and place them in self instead
        // if collective object count in sub-quads is less then minimumCellSize
    }
}
