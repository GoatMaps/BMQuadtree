import XCTest
@testable import BMQuadtree

final class BMQuadtreeTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(BMQuadtree().text, "Hello, World!")
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
