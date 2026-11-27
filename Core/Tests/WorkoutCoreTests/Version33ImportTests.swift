import XCTest
@testable import WorkoutCore

final class Version33ImportTests: XCTestCase {
    let base = URL(string: "https://example.com/machines/")!

    func testDemoPageGivesSixMachines() {
        let c = MachineImport.candidates(html: MachineImport.demoHTML, base: base, existing: [])
        XCTAssertEqual(c.map(\.name), ["Leg press", "Chest press", "Lat pulldown", "Rowing machine", "Treadmill", "Seated leg curl"])
        XCTAssertEqual(c[4].imageURL?.absoluteString, "https://example.com/img/treadmill.jpg")
    }

    func testRelativeUrlsEntitiesDuplicatesAndExisting() {
        let html = """
        <img src="/p/a.jpg" alt="Smith &amp; Co press&nbsp;  &#39;X&#39;">
        <img src="//cdn.example.com/b.jpg" alt="Cable row">
        <img src="b2.jpg" alt="cable ROW">
        <img src="data:image/gif;base64,AAA" alt="Pec deck">
        <img src="icon.svg" alt="Hack squat">
        """
        let c = MachineImport.candidates(html: html, base: base, existing: [" cable row "])
        XCTAssertEqual(c.count, 4)
        XCTAssertEqual(c[0].name, "Smith & Co press 'X'")
        XCTAssertEqual(c[0].imageURL?.absoluteString, "https://example.com/p/a.jpg")
        XCTAssertEqual(c[1].imageURL?.absoluteString, "https://cdn.example.com/b.jpg")
        XCTAssertTrue(c[1].alreadyThere)
        XCTAssertNil(c[2].imageURL)
    }

    func testJSONLD() {
        let html = """
        <script type="application/ld+json">{"@type":"Product","name":"Hip abductor","image":["https://example.com/h.jpg"]}</script>
        <script type="application/ld+json">{"@graph":[{"@type":"ExerciseEquipment","name":"Calf raise","image":{"url":"/c.jpg"}}]}</script>
        """
        let c = MachineImport.candidates(html: html, base: base, existing: [])
        XCTAssertEqual(c.map(\.name), ["Hip abductor", "Calf raise"])
        XCTAssertEqual(c[1].imageURL?.absoluteString, "https://example.com/c.jpg")
    }

    func testNormalised() {
        XCTAssertEqual(MachineImport.normalised("example.com/x")?.absoluteString, "https://example.com/x")
        XCTAssertNil(MachineImport.normalised("ftp://example.com"))
        XCTAssertNil(MachineImport.normalised("not a link"))
    }
}
