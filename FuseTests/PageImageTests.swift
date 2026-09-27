import XCTest
import UIKit
@testable import Fuse

final class PageImageTests: XCTestCase {

    private func pixels(_ width: CGFloat = 300, _ height: CGFloat = 300) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func testDetectionResultParsing() {
        let found = PageImage.parse(#"{"src":"https://example.com/beach.jpg","alt":"Malibu","width":2000,"height":1300,"coverage":0.62}"#)
        XCTAssertEqual(found?.src, "https://example.com/beach.jpg")
        XCTAssertEqual(found?.alt, "Malibu")
        XCTAssertNil(PageImage.parse("null"))
        XCTAssertNil(PageImage.parse(#"{"src":"javascript:alert(1)"}"#))
    }

    func testDataURIDecoding() throws {
        let png = try XCTUnwrap(pixels(4, 4).pngData())
        XCTAssertEqual(PageImage.decodeDataURI("data:image/png;base64," + png.base64EncodedString()), png)
        XCTAssertNil(PageImage.decodeDataURI("data:image/svg+xml,<svg/>"))
        XCTAssertNil(PageImage.decodeDataURI("https://example.com/a.png"))
    }

    func testOlderRecordedVisitsStillDecode() throws {
        let old = #"[{"url":"https://a.com","title":"A","text":"t","selection":"","at":700000000}]"#
        let visits = try JSONDecoder().decode([SharedInbox.Visit].self, from: Data(old.utf8))
        XCTAssertEqual(visits.first?.title, "A")
        XCTAssertNil(visits.first?.image)
    }

    func testVisitWithoutPhotoIsAPage() async throws {
        let visit = SharedInbox.Visit(url: "https://a.com", title: "A", text: "hello", selection: "")
        let snapshot = try await visit.snapshot()
        XCTAssertEqual(snapshot.kind, .web)
        XCTAssertNil(snapshot.heroImage)
        XCTAssertNil(snapshot.metadata["content"])
        XCTAssertEqual(snapshot.metadata["url"], "https://a.com")
    }

    func testSafariResultDecodesWithTheExtensionsDateEncoding() throws {
        let result = FuseResult(recipe: "r", title: "Together", summary: "s", artifact: .markdown("m"))
        let data = try JSONEncoder().encode(result)
        XCTAssertEqual(try JSONDecoder().decode(FuseResult.self, from: data).title, "Together")
    }

    // The composer numbers references exactly like the engine picks sources: a Safari photo page
    // arrives as heroImage only and must still be "Reference image 1".
    func testComposerCountsPagePhotosAsReferences() {
        let person = SurfaceSnapshot(kind: .web, title: "Person A", metadata: ["content": "photo"], heroImage: pixels())
        let other = SurfaceSnapshot(kind: .web, title: "Person B", metadata: ["content": "photo"], heroImage: pixels())
        let prompt = Prompts.imageEdit(prompt: "Both people on the beach", left: person, right: other, instruction: nil, suggested: nil)
        XCTAssertTrue(prompt.contains("Reference image 1 is the LEFT screen"))
        XCTAssertTrue(prompt.contains("Reference image 2 is the RIGHT screen"))
        let article = SurfaceSnapshot(kind: .web, title: "Article", image: pixels())
        XCTAssertFalse(Prompts.imageEdit(prompt: "x", left: article, right: other, instruction: nil, suggested: nil).contains("is the LEFT screen"),
                       "a page screenshot is never a reference")
    }

    func testTwoPeopleIsAHeadlineCase() {
        XCTAssertTrue(Prompts.system.contains("two people, one on each screen"))
        let prompt = Prompts.imageEdit(prompt: "x", left: .empty(.photo), right: .empty(.photo), instruction: nil, suggested: nil)
        XCTAssertTrue(prompt.contains("never blend or swap features between people"))
    }
}
