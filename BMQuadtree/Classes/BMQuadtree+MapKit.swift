//
//  BMQuadtree+MapKit.swift
//  Bikemap
//
//  Created by Adam Eri on 18/07/2017.
//  Copyright © 2017 Bikemap GmbH. Apache License 2.0
//

import CoreLocation
import Foundation
import MapKit
import simd

public extension BMQuad {
    /// Returns a region around the location with the specified offset in meters.
    ///
    /// - Parameter offset: Offset in meters.
    init(location: CLLocation, offset: CLLocationDistance) {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: offset,
            longitudinalMeters: offset
        )

        let min = SIMD2<Float>(
            Float(location.coordinate.latitude - region.span.latitudeDelta),
            Float(location.coordinate.longitude - region.span.longitudeDelta)
        )

        let max = SIMD2<Float>(
            Float(location.coordinate.latitude + region.span.latitudeDelta),
            Float(location.coordinate.longitude + region.span.longitudeDelta)
        )

        self.init(quadMin: min, quadMax: max)
    }
}

public extension MKOverlay {
    /// Returns the minX and minY coordinates of the overlays quad.
    /// Used for settung up the quadtree of the map objects.
    var quadMin: SIMD2<Float> {
        let region = MKCoordinateRegion(boundingMapRect)

        let centerX = region.center.latitude
        let centerY = region.center.longitude
        let spanX = region.span.latitudeDelta
        let spanY = region.span.longitudeDelta

        return SIMD2<Float>(
            Float(centerX - spanX),
            Float(centerY - spanY)
        )
    }

    /// Returns the maxX and maxY coordinates of the overlays quad.
    /// Used for settung up the quadtree of the map objects.
    var quadMax: SIMD2<Float> {
        let region = MKCoordinateRegion(boundingMapRect)

        let centerX = region.center.latitude
        let centerY = region.center.longitude
        let spanX = region.span.latitudeDelta
        let spanY = region.span.longitudeDelta

        return SIMD2<Float>(
            Float(centerX + spanX),
            Float(centerY + spanY)
        )
    }

    /// Returns the bounding quad of the overlay.
    /// Used for settung up the quadtree of the map objects.
    var boundingQuad: BMQuad {
        return BMQuad(quadMin: quadMin, quadMax: quadMax)
    }
}

public extension CLLocationCoordinate2D {
    var vector: vector_float2 {
        return SIMD2<Float>(
            Float(latitude),
            Float(longitude)
        )
    }
}

public extension CLLocation {
    var vector: vector_float2 {
        return SIMD2<Float>(
            Float(coordinate.latitude),
            Float(coordinate.longitude)
        )
    }
}

@available(OSX 10.12, *)
public extension BMQuadtree {
    // MARK: - Debug

    var debugOverlay: [MKPolygon] {
        let minx = CLLocationDegrees(quad.quadMin.x)
        let miny = CLLocationDegrees(quad.quadMin.y)
        let maxx = CLLocationDegrees(quad.quadMax.x)
        let maxy = CLLocationDegrees(quad.quadMax.y)
        let topLeft = CLLocationCoordinate2D(latitude: minx, longitude: maxy)
        let bottomLeft = CLLocationCoordinate2D(latitude: minx, longitude: miny)
        let topRight = CLLocationCoordinate2D(latitude: maxx, longitude: maxy)
        let bottomRight = CLLocationCoordinate2D(latitude: maxx, longitude: miny)
        let coords = [topLeft, bottomLeft, bottomRight, topRight]
        let treePolygon = MKPolygon(coordinates: coords, count: coords.count)
        var polygons: [MKPolygon] = [treePolygon]

        if hasQuads == true {
            polygons.append(contentsOf: northWest!.debugOverlay)
            polygons.append(contentsOf: northEast!.debugOverlay)
            polygons.append(contentsOf: southWest!.debugOverlay)
            polygons.append(contentsOf: northEast!.debugOverlay)
        }

        return polygons
    }
}
