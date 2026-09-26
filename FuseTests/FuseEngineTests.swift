import XCTest
import UIKit
@testable import Fuse

final class FuseEngineTests: XCTestCase {

    func testDecodesItineraryResult() throws {
        let json = """
        {"recipe":"travel_plan","title":"One day at Islands","summary":"Start at Hagrid's.",
         "artifact":{"type":"itinerary","destination":"Islands of Adventure",
           "days":[{"title":"Day 1","stops":[{"name":"Hagrid's","time":"9:05 AM","latitude":28.47,"longitude":-81.47}]}],
           "tips":["Buy Express"]},
         "follow_ups":["Add to calendar"]}
        """
        let result = try FuseEngine.decode(json)
        XCTAssertEqual(result.recipe, "travel_plan")
        XCTAssertEqual(result.followUps, ["Add to calendar"])
        guard case .itinerary(let it) = result.artifact else { return XCTFail("expected itinerary") }
        XCTAssertEqual(it.days.count, 1)
        XCTAssertEqual(it.allStops.first?.latitude, 28.47)
    }

    func testDecodesEventWithSnakeCaseAndLenientDates() throws {
        let json = """
        {"recipe":"event","title":"Demo","summary":"",
         "artifact":{"type":"event","title":"Swiftsonic keynote","start":"2026-11-20T09:30:00","all_day":false,"location":"Nashville"}}
        """
        let result = try FuseEngine.decode(json)
        guard case .event(let e) = result.artifact else { return XCTFail("expected event") }
        XCTAssertNotNil(e.startDate)
        XCTAssertEqual(e.location, "Nashville")
        XCTAssertNotNil(e.endDate, "end defaults to one hour after start")
    }

    func testUnknownArtifactFallsBackToMarkdown() throws {
        let json = """
        {"recipe":"x","title":"t","summary":"s","artifact":{"type":"haiku","text":"fold the phone"}}
        """
        let result = try FuseEngine.decode(json)
        guard case .markdown(let md) = result.artifact else { return XCTFail("expected markdown") }
        XCTAssertEqual(md, "fold the phone")
    }

    func testCodeFencesAreStripped() throws {
        let raw = "```json\n{\"recipe\":\"code\",\"title\":\"Patch\",\"summary\":\"\",\"artifact\":{\"type\":\"code\",\"language\":\"swift\",\"code\":\"print(1)\"}}\n```"
        let result = try FuseEngine.decode(raw)
        guard case .code(let c) = result.artifact else { return XCTFail("expected code") }
        XCTAssertEqual(c.language, "swift")
    }

    func testGarbageNeverThrows() throws {
        let result = try FuseEngine.decode("not json at all")
        guard case .markdown = result.artifact else { return XCTFail("expected markdown fallback") }
    }

    func testArtifactRoundTripsThroughCodable() throws {
        let original = FuseResult(
            recipe: "grade", title: "7/10", summary: "ok",
            artifact: .grade(GradeReport(score: "7/10", items: [.init(question: "q", yourAnswer: "a", correct: true)], weaknesses: ["x"], nextSteps: ["y"])),
            followUps: ["Quiz me"], inputs: [InputSummary(kind: .notes, title: "Test"), InputSummary(kind: .notes, title: "Answers")]
        )
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(FuseResult.self, from: data)
        XCTAssertEqual(back.title, "7/10")
        guard case .grade(let g) = back.artifact else { return XCTFail("expected grade") }
        XCTAssertEqual(g.items.count, 1)
        XCTAssertEqual(back.inputs.map(\.kind), [.notes, .notes])
    }

    func testIntentPreviewDecodesTopThree() {
        let raw = """
        {"suggestions":[{"title":"Plan the day","instruction":"Plan one day","artifact":"itinerary","symbol":"map"},
                        {"title":"Add to calendar","instruction":"Add it","artifact":"event"},
                        {"title":"Compare","instruction":"Compare","artifact":"table"},
                        {"title":"Fourth","instruction":"x","artifact":"markdown"}]}
        """
        let s = IntentPreviewer.decode(raw)
        XCTAssertEqual(s.count, 3)
        XCTAssertEqual(s.first?.resolvedSymbol, "map")
        XCTAssertEqual(s[1].resolvedSymbol, "calendar.badge.plus")
    }

    func testDateParsingVariants() {
        XCTAssertNotNil(FuseDates.parse("2026-10-03T18:00:00Z"))
        XCTAssertNotNil(FuseDates.parse("2026-10-03T18:00:00"))
        XCTAssertNotNil(FuseDates.parse("2026-10-03 18:00"))
        XCTAssertNotNil(FuseDates.parse("2026-10-03"))
        XCTAssertNil(FuseDates.parse("tomorrow-ish"))
    }

    func testConfigOverridesInfoPlist() {
        AppConfig.set("gpt-6-astra", for: .openAIModel)
        XCTAssertEqual(AppConfig.openAIModel, "gpt-6-astra")
        AppConfig.set("", for: .openAIModel)
        XCTAssertFalse(AppConfig.openAIModel.isEmpty, "falls back to plist or default")
        AppConfig.set("abc", for: .supabaseProjectRef)
        XCTAssertEqual(AppConfig.supabaseURL?.absoluteString, "https://abc.supabase.co")
        AppConfig.set("", for: .supabaseProjectRef)
    }

    @MainActor
    func testPromptsMentionEveryArtifactType() {
        let system = Prompts.system
        for type in ["itinerary", "event", "email", "quiz", "grade", "slides", "code", "diff", "table", "checklist", "image_edit", "markdown"] {
            XCTAssertTrue(system.contains("\"type\":\"\(type)\""), "catalogue is missing \(type)")
        }
    }

    @MainActor
    func testDemoScenariosAreWellFormed() {
        let all = DemoScenario.all
        XCTAssertGreaterThanOrEqual(all.count, 13)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "ids must be unique")
        for s in all { XCTAssertFalse(s.title.isEmpty); XCTAssertFalse(s.symbol.isEmpty) }
    }

    @MainActor
    func testReplacingSameSizePhotoChangesPreviewContentKey() {
        let model = AppModel()
        let size = CGSize(width: 100, height: 80)
        model.left.apply(.image(solidImage(size: size, color: .red)), as: .photo)
        model.right.apply(.image(solidImage(size: size, color: .blue)), as: .photo)
        let originalKey = model.contentKey
        let originalHeadline = model.left.model.headline

        model.left.apply(.image(solidImage(size: size, color: .green)), as: .photo)
        XCTAssertEqual(model.left.model.headline, originalHeadline, "the old headline-only key cannot detect this replacement")
        XCTAssertNotEqual(model.contentKey, originalKey)

        let leftUpdatedKey = model.contentKey
        model.right.apply(.image(solidImage(size: size, color: .yellow)), as: .photo)
        XCTAssertNotEqual(model.contentKey, leftUpdatedKey, "either photo can invalidate the proposed edit")
    }

    @MainActor
    func testContentChangeClearsSelectedEditButPreservesUserInstruction() {
        let suggestion = FuseSuggestion(title: "Place the chair", instruction: "Put the red chair beside the window", artifact: "image_edit", symbol: "photo")
        let instructions: [String?] = [nil, "Keep the furniture fabric unchanged"]
        for replacementInstruction in instructions {
            let model = AppModel()
            model.left.open(.photo)
            model.right.open(.photo)
            model.suggestions = [suggestion]
            model.choose(suggestion)
            if let replacementInstruction { model.instruction = replacementInstruction }
            model.isPreviewing = true

            // Empty panes exercise synchronous invalidation without reading a key or starting a request.
            XCTAssertEqual(model.readiness, 0)
            model.schedulePreview()
            XCTAssertNil(model.chosenSuggestion)
            XCTAssertTrue(model.suggestions.isEmpty)
            XCTAssertFalse(model.isPreviewing)
            XCTAssertEqual(model.instruction, replacementInstruction ?? "")
        }
    }

    @MainActor
    func testPhotoCaptureRetainsUpTo2048PixelReferences() async throws {
        let photo = PhotoSurfaceModel()
        photo.setImage(solidImage(size: CGSize(width: 3000, height: 1500), color: .red), source: "test")
        let snapshot = await photo.capture()
        let pixels = try XCTUnwrap(snapshot.image?.cgImage)
        XCTAssertEqual(pixels.width, 2048)
        XCTAssertEqual(pixels.height, 1024)

        photo.setImage(solidImage(size: CGSize(width: 1600, height: 800), color: .blue), source: "test")
        let smallerSnapshot = await photo.capture()
        XCTAssertEqual(smallerSnapshot.image?.cgImage?.width, 1600, "photo capture must not shrink references to the router's 1024-pixel limit")
        XCTAssertEqual(smallerSnapshot.image?.cgImage?.height, 800)
    }

    func testDownscaledImageCapsRetinaPixelDimensions() throws {
        let retina = solidImage(size: CGSize(width: 600, height: 300), color: .red, scale: 3)
        XCTAssertEqual(retina.cgImage?.width, 1800)
        let scaled = retina.fuseDownscaled(maxEdge: 1024)
        let pixels = try XCTUnwrap(scaled.cgImage)
        XCTAssertEqual(pixels.width, 1024)
        XCTAssertEqual(pixels.height, 512)
    }

    private func solidImage(size: CGSize, color: UIColor, scale: CGFloat = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Image API and pipeline regression tests

final class OpenAIImageTests: XCTestCase {
    func testEditSendsBothReferencesInOrderWithAutomaticAspectRatio() async throws {
        let first = image(color: .red, size: CGSize(width: 24, height: 12))
        let second = image(color: .blue, size: CGSize(width: 12, height: 24))
        let output = try XCTUnwrap(image(color: .green).pngData())
        let fixture = try makeFixture(response: imageResponse(output))
        defer { fixture.close() }

        let result = try await fixture.client.imageEdit(prompt: "Combine these references", images: [first, second])

        XCTAssertEqual(result, output)
        let request = try XCTUnwrap(fixture.state.requests.first)
        XCTAssertEqual(fixture.state.requests.count, 1)
        XCTAssertEqual(request.url?.path, "/v1/images/edits")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer unit-test-key")
        let parts = try multipartParts(request)
        let files = parts.filter { $0.filename != nil }
        XCTAssertEqual(files.map(\.name), ["image[]", "image[]"])
        XCTAssertEqual(files.compactMap(\.filename), ["image1.png", "image2.png"])
        XCTAssertEqual(files.map(\.data), try [XCTUnwrap(first.pngData()), XCTUnwrap(second.pngData())])
        XCTAssertEqual(parts.first { $0.name == "model" }?.text, "gpt-image-2")
        XCTAssertEqual(parts.first { $0.name == "size" }?.text, "auto")
        XCTAssertEqual(parts.first { $0.name == "prompt" }?.text, "Combine these references")
        XCTAssertFalse(parts.contains { $0.name == "input_fidelity" })
    }

    func testEditCapsReferencePixelsAt2048AndPreservesAspectRatio() async throws {
        // A Retina input has only 1,500 points but 3,000 pixels on its long edge.
        let reference = image(color: .red, size: CGSize(width: 1500, height: 750), scale: 2)
        let fixture = try makeFixture(response: imageResponse(XCTUnwrap(image(color: .green).pngData())))
        defer { fixture.close() }

        _ = try await fixture.client.imageEdit(prompt: "Use this reference", images: [reference])

        let request = try XCTUnwrap(fixture.state.requests.first)
        let file = try XCTUnwrap(multipartParts(request).first { $0.filename != nil })
        let received = try XCTUnwrap(UIImage(data: file.data)?.cgImage)
        XCTAssertEqual(received.width, 2048)
        XCTAssertEqual(received.height, 1024)
    }

    func testEditRejectsEmptyAndTooManyReferencesBeforeNetworking() async throws {
        let fixture = makeFixture(response: Data())
        defer { fixture.close() }
        for count in [0, 5] {
            do {
                _ = try await fixture.client.imageEdit(prompt: "Combine", images: Array(repeating: image(color: .red), count: count))
                XCTFail("Expected invalid reference count")
            } catch OpenAIClient.ClientError.invalidImageCount(let received) {
                XCTAssertEqual(received, count)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertTrue(fixture.state.requests.isEmpty)
    }

    func testEditNormalizesMirroredReferencePixelsBelowSizeLimit() async throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 16), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 16, y: 0, width: 16, height: 16))
        }
        let mirrored = UIImage(cgImage: try XCTUnwrap(source.cgImage), scale: 1, orientation: .upMirrored)
        let fixture = try makeFixture(response: imageResponse(XCTUnwrap(image(color: .green).pngData())))
        defer { fixture.close() }

        _ = try await fixture.client.imageEdit(prompt: "Use this reference", images: [mirrored])

        let parts = try multipartParts(XCTUnwrap(fixture.state.requests.first))
        let file = try XCTUnwrap(parts.first { $0.filename != nil })
        let received = try XCTUnwrap(UIImage(data: file.data))
        XCTAssertEqual(received.imageOrientation, .up)
        let pixels = try XCTUnwrap(received.cgImage)
        let left = try XCTUnwrap(pixels.cropping(to: CGRect(x: 0, y: 0, width: 16, height: 16)))
        let right = try XCTUnwrap(pixels.cropping(to: CGRect(x: 16, y: 0, width: 16, height: 16)))
        XCTAssertEqual(try dominantChannel(UIImage(cgImage: left)), 2, "Displayed left half is blue after mirroring")
        XCTAssertEqual(try dominantChannel(UIImage(cgImage: right)), 0, "Displayed right half is red after mirroring")
    }

    func testEditRejectsUnencodableSecondReferenceWithoutSendingFirst() async throws {
        let fixture = makeFixture(response: Data())
        defer { fixture.close() }
        do {
            _ = try await fixture.client.imageEdit(prompt: "Combine", images: [image(color: .red), UIImage()])
            XCTFail("Expected invalid reference")
        } catch OpenAIClient.ClientError.invalidReference(let index) {
            XCTAssertEqual(index, 2)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertTrue(fixture.state.requests.isEmpty)
    }

    func testBothEndpointsRejectMalformedImageResponses() async throws {
        let invalidResponses = [
            Data("not json".utf8),
            Data("[]".utf8),
            Data("{\"data\":[]}".utf8),
            Data("{\"data\":[{\"b64_json\":\"%%%\"}]}".utf8),
            try imageResponse(Data("valid base64, not image pixels".utf8)),
            Data("{\"status\":\"failed\",\"error\":{\"message\":\"Failed\"}}".utf8)
        ]
        for response in invalidResponses {
            for edit in [true, false] {
                let fixture = makeFixture(response: response)
                defer { fixture.close() }
                do {
                    if edit {
                        _ = try await fixture.client.imageEdit(prompt: "Combine", images: [image(color: .red)])
                    } else {
                        _ = try await fixture.client.imageGenerate(prompt: "Create")
                    }
                    XCTFail("Expected malformed image response")
                } catch OpenAIClient.ClientError.malformed {
                    // Both endpoints must validate the payload, including decoded image bytes.
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }

    func testBothEndpointsReportAuthenticationFailureWithoutEchoingResponseBody() async throws {
        let response = Data("{\"error\":{\"message\":\"Incorrect API key: server-echoed-secret\"}}".utf8)
        for edit in [true, false] {
            let fixture = makeFixture(status: 401, response: response)
            defer { fixture.close() }
            do {
                if edit {
                    _ = try await fixture.client.imageEdit(prompt: "Combine", images: [image(color: .red)])
                } else {
                    _ = try await fixture.client.imageGenerate(prompt: "Create")
                }
                XCTFail("Expected authentication error")
            } catch let error as OpenAIClient.ClientError {
                guard case .http(let status, let message) = error else {
                    XCTFail("Expected HTTP error, got \(error)")
                    continue
                }
                XCTAssertEqual(status, 401)
                XCTAssertTrue(message.contains("Authentication failed"))
                XCTAssertFalse(error.localizedDescription.contains("server-echoed-secret"))
            }
        }
    }

    func testGenerationUsesAutomaticAspectRatioAndReturnsDecodedImage() async throws {
        let output = try XCTUnwrap(image(color: .green).pngData())
        let fixture = try makeFixture(response: imageResponse(output))
        defer { fixture.close() }

        let result = try await fixture.client.imageGenerate(prompt: "Create a landscape")

        XCTAssertEqual(result, output)
        let request = try XCTUnwrap(fixture.state.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/images/generations")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["model"], "gpt-image-2")
        XCTAssertEqual(json["size"], "auto")
        XCTAssertNil(json["input_fidelity"])
    }

    func testConcurrentSessionsKeepResponsesAndRequestsIsolated() async throws {
        let firstOutput = try XCTUnwrap(image(color: .red).pngData())
        let secondOutput = try XCTUnwrap(image(color: .blue).pngData())
        let first = try makeFixture(response: imageResponse(firstOutput))
        let second = try makeFixture(response: imageResponse(secondOutput))
        defer { first.close(); second.close() }

        async let firstResult = first.client.imageGenerate(prompt: "First session")
        async let secondResult = second.client.imageGenerate(prompt: "Second session")
        let results = try await (firstResult, secondResult)

        XCTAssertEqual(results.0, firstOutput)
        XCTAssertEqual(results.1, secondOutput)
        XCTAssertEqual(first.state.requests.count, 1)
        XCTAssertEqual(second.state.requests.count, 1)
        for (fixture, prompt) in [(first, "First session"), (second, "Second session")] {
            let body = try XCTUnwrap(fixture.state.requests.first?.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
            XCTAssertEqual(json["prompt"], prompt)
        }
    }

    func testEngineEditsBothReferencesInEitherOrderAndReplacesRouterPixels() async throws {
        let room = SurfaceSnapshot(kind: .photo, title: "Living room", image: image(color: .red))
        let chair = SurfaceSnapshot(kind: .photo, title: "Green armchair", image: image(color: .blue))
        let fakePixels = try XCTUnwrap(image(color: .green).pngData())
        let actualPixels = try XCTUnwrap(image(color: .yellow).pngData())
        let router = try chatResponse([
            "recipe": "room_preview", "title": "Chair in room", "summary": "A visual preview.",
            "artifact": ["type": "image_edit", "prompt": "Place the chair in the room.",
                         "image_base64": fakePixels.base64EncodedString()]
        ])
        let instruction = "Place the armchair beside the window and keep the existing rug."
        for (left, right) in [(room, chair), (chair, room)] {
            let fixture = try makeFixture(responses: [
                "/v1/chat/completions": router,
                "/v1/images/edits": imageResponse(actualPixels)
            ])
            defer { fixture.close() }

            let result = try await FuseEngine(client: fixture.client).fuse(
                left: left, right: right, instruction: instruction, progress: { _ in }
            )

            guard case .image(let artifact) = result.artifact else { return XCTFail("Expected an image artifact") }
            XCTAssertEqual(artifact.imageBase64, actualPixels.base64EncodedString())
            XCTAssertNotEqual(artifact.imageBase64, fakePixels.base64EncodedString())
            XCTAssertNotNil(artifact.uiImage)
            XCTAssertEqual(result.inputs.map(\.title), [left.title, right.title])
            XCTAssertEqual(result.instruction, instruction)
            let requests = fixture.state.requests
            XCTAssertEqual(requests.compactMap { $0.url?.path }, ["/v1/chat/completions", "/v1/images/edits"])
            let edit = try XCTUnwrap(requests.last)
            let parts = try multipartParts(edit)
            let files = parts.filter { $0.filename != nil }
            XCTAssertEqual(files.compactMap(\.filename), ["image1.png", "image2.png"])
            XCTAssertEqual(files.map(\.data), try [XCTUnwrap(left.image?.pngData()), XCTUnwrap(right.image?.pngData())])
            let prompt = try XCTUnwrap(parts.first { $0.name == "prompt" }?.text)
            XCTAssertTrue(prompt.contains(instruction), "The original user instruction must reach the edit endpoint")
            XCTAssertTrue(prompt.contains("Reference image 1 is the LEFT screen."))
            XCTAssertTrue(prompt.contains("Reference image 2 is the RIGHT screen."))
            let firstTitle = try XCTUnwrap(prompt.range(of: "Title: \(left.title)"))
            let secondTitle = try XCTUnwrap(prompt.range(of: "Title: \(right.title)"))
            XCTAssertLessThan(firstTitle.lowerBound, secondTitle.lowerBound)
        }
    }

    func testEngineHonorsExplicitTextResultsWithoutCallingImageEndpoint() async throws {
        let artifacts: [[String: Any]] = [
            ["type": "markdown", "markdown": "The armchair has blue upholstery."],
            ["type": "table", "title": "Comparison", "columns": ["Item", "Color"], "rows": [["Armchair", "Blue"]]]
        ]
        let left = SurfaceSnapshot(kind: .photo, title: "Room", image: image(color: .red))
        let right = SurfaceSnapshot(kind: .photo, title: "Chair", image: image(color: .blue))
        for artifact in artifacts {
            let fixture = try makeFixture(responses: ["/v1/chat/completions": chatResponse([
                "recipe": "comparison", "title": "Compare", "summary": "A text comparison.", "artifact": artifact
            ])])
            defer { fixture.close() }
            let instruction = "Compare the colors in text. Do not create an image."

            let result = try await FuseEngine(client: fixture.client).fuse(
                left: left, right: right, instruction: instruction, progress: { _ in }
            )

            XCTAssertEqual(result.artifact.typeName, try XCTUnwrap(artifact["type"] as? String))
            XCTAssertEqual(fixture.state.requests.compactMap { $0.url?.path }, ["/v1/chat/completions"])
        }
    }

    func testPreviewIncludesTwoSmallVisionImagesInSourceOrder() async throws {
        let fixture = try makeFixture(response: chatResponse(["suggestions": []]))
        defer { fixture.close() }
        let left = SurfaceSnapshot(kind: .photo, title: "Room", image: image(color: .red, size: CGSize(width: 1600, height: 800)))
        let right = SurfaceSnapshot(kind: .photo, title: "Chair", image: image(color: .blue, size: CGSize(width: 800, height: 1600)))

        _ = try await IntentPreviewer(client: fixture.client).suggest(left: left, right: right)

        let request = try XCTUnwrap(fixture.state.requests.first)
        XCTAssertEqual(fixture.state.requests.count, 1)
        let content = try chatContent(request)
        let images = try visionImages(content)
        XCTAssertEqual(images.count, 2)
        guard images.count == 2 else { return }
        XCTAssertEqual(images[0].cgImage?.width, 512)
        XCTAssertEqual(images[0].cgImage?.height, 256)
        XCTAssertEqual(images[1].cgImage?.width, 256)
        XCTAssertEqual(images[1].cgImage?.height, 512)
        XCTAssertEqual(try dominantChannel(images[0]), 0, "The first vision image is the red left reference")
        XCTAssertEqual(try dominantChannel(images[1]), 2, "The second vision image is the blue right reference")
        let descriptions = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
        XCTAssertFalse(descriptions.contains("Content: (empty screen)"))
    }

    func testPreviewIncludesSinglePhotoBesideNotesWithoutCallingItEmpty() async throws {
        let photo = SurfaceSnapshot(kind: .photo, title: "Room photo", image: image(color: .red))
        let notes = SurfaceSnapshot(kind: .notes, title: "Instructions", text: "Keep the rug.")
        for (left, right) in [(photo, notes), (notes, photo)] {
            let fixture = try makeFixture(response: chatResponse(["suggestions": []]))
            defer { fixture.close() }

            _ = try await IntentPreviewer(client: fixture.client).suggest(left: left, right: right)

            let content = try chatContent(XCTUnwrap(fixture.state.requests.first))
            XCTAssertEqual(try visionImages(content).count, 1)
            let descriptions = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
            XCTAssertTrue(descriptions.contains("Title: Room photo"))
            XCTAssertTrue(descriptions.contains("Keep the rug."))
            XCTAssertFalse(descriptions.contains("Content: (empty screen)"))
        }
    }

    func testPreviewKeepsTextOnlyPairsFreeOfImagePayloads() async throws {
        let fixture = try makeFixture(response: chatResponse(["suggestions": []]))
        defer { fixture.close() }

        _ = try await IntentPreviewer(client: fixture.client).suggest(
            left: SurfaceSnapshot(kind: .notes, title: "Draft", text: "Hello"),
            right: SurfaceSnapshot(kind: .notes, title: "Guidance", text: "Make this concise")
        )

        let content = try chatContent(XCTUnwrap(fixture.state.requests.first))
        XCTAssertTrue(try visionImages(content).isEmpty)
        XCTAssertTrue(content.allSatisfy { $0["type"] as? String == "text" })
    }

    func testRouterAuthenticationFailureDoesNotExposeServerEchoedKey() async throws {
        let fixture = makeFixture(status: 401, response: Data("server-echoed-secret".utf8))
        defer { fixture.close() }
        do {
            _ = try await fixture.client.chatJSON(system: "System", parts: [.text("Compare these")])
            XCTFail("Expected authentication failure")
        } catch let error as OpenAIClient.ClientError {
            guard case .http(let status, let message) = error else { return XCTFail("Expected HTTP error") }
            XCTAssertEqual(status, 401)
            XCTAssertTrue(message.contains("Authentication failed"))
            XCTAssertFalse(error.localizedDescription.contains("server-echoed-secret"))
        }
    }

    private func image(color: UIColor, size: CGSize = CGSize(width: 8, height: 8), scale: CGFloat = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func imageResponse(_ bytes: Data) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["data": [["b64_json": bytes.base64EncodedString()]]])
    }

    private func chatResponse(_ object: [String: Any]) throws -> Data {
        let content = String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
        return try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content]]]])
    }

    private func chatContent(_ request: URLRequest) throws -> [[String: Any]] {
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        return try XCTUnwrap(messages.last?["content"] as? [[String: Any]])
    }

    private func visionImages(_ content: [[String: Any]]) throws -> [UIImage] {
        try content.filter { $0["type"] as? String == "image_url" }.map { item in
            let imageURL = try XCTUnwrap(item["image_url"] as? [String: String])
            let url = try XCTUnwrap(imageURL["url"])
            XCTAssertTrue(url.hasPrefix("data:image/jpeg;base64,"))
            let encoded = try XCTUnwrap(url.split(separator: ",", maxSplits: 1).last)
            let bytes = try XCTUnwrap(Data(base64Encoded: String(encoded)))
            return try XCTUnwrap(UIImage(data: bytes))
        }
    }

    private func dominantChannel(_ image: UIImage) throws -> Int {
        let pixels = try XCTUnwrap(image.cgImage)
        var rgba = [UInt8](repeating: 0, count: 4)
        return try rgba.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                                bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(pixels, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            let bytes = buffer.bindMemory(to: UInt8.self)
            return try XCTUnwrap((0..<3).max { bytes[$0] < bytes[$1] })
        }
    }

    private struct Fixture {
        let id: String
        let state: ImageStubState
        let session: URLSession
        let client: OpenAIClient

        func close() {
            session.invalidateAndCancel()
            ImageStubProtocol.registry.remove(id)
        }
    }

    private func makeFixture(status: Int = 200, response: Data) -> Fixture {
        makeFixture(routes: ["*": ImageStubResponse(status: status, data: response)])
    }

    private func makeFixture(responses: [String: Data]) -> Fixture {
        makeFixture(routes: responses.mapValues { ImageStubResponse(status: 200, data: $0) })
    }

    private func makeFixture(routes: [String: ImageStubResponse]) -> Fixture {
        let id = UUID().uuidString
        let state = ImageStubState(routes: routes)
        ImageStubProtocol.registry.register(state, id: id)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageStubProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Fuse-Test-ID": id]
        let session = URLSession(configuration: configuration)
        return Fixture(id: id, state: state, session: session,
                       client: OpenAIClient(apiKey: "unit-test-key", model: "unused-test-chat-model", session: session))
    }

    private struct MultipartPart {
        let name: String
        let filename: String?
        let data: Data
        var text: String? { String(data: data, encoding: .utf8) }
    }

    private func multipartParts(_ request: URLRequest) throws -> [MultipartPart] {
        let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
        let boundary = try XCTUnwrap(contentType.components(separatedBy: "boundary=").last)
        let body = try XCTUnwrap(request.httpBody)
        let separator = Data("--\(boundary)".utf8)
        let headerSeparator = Data("\r\n\r\n".utf8)
        var parts: [MultipartPart] = []
        var cursor = body.startIndex
        while let start = body.range(of: separator, in: cursor..<body.endIndex),
              let end = body.range(of: separator, in: start.upperBound..<body.endIndex) {
            let section = body.subdata(in: start.upperBound..<end.lowerBound)
            let headerEnd = try XCTUnwrap(section.range(of: headerSeparator))
            let header = String(decoding: section[..<headerEnd.lowerBound], as: UTF8.self)
            func attribute(_ name: String) -> String? {
                guard let range = header.range(of: "\(name)=\"") else { return nil }
                return header[range.upperBound...].split(separator: "\"", maxSplits: 1).first.map(String.init)
            }
            let payloadEnd = section.endIndex - 2 // Exclude the framing CRLF after the payload.
            parts.append(MultipartPart(name: try XCTUnwrap(attribute("name")), filename: attribute("filename"),
                                       data: section.subdata(in: headerEnd.upperBound..<payloadEnd)))
            cursor = end.lowerBound
        }
        return parts
    }
}

/// Each URLSession uses a unique fixture ID. Parallel tests never replace one global handler.
private final class ImageStubRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var states: [String: ImageStubState] = [:]

    func register(_ state: ImageStubState, id: String) {
        lock.lock()
        defer { lock.unlock() }
        states[id] = state
    }

    func state(for id: String) -> ImageStubState? {
        lock.lock()
        defer { lock.unlock() }
        return states[id]
    }

    func remove(_ id: String) {
        lock.lock()
        defer { lock.unlock() }
        states.removeValue(forKey: id)
    }
}

private struct ImageStubResponse: Sendable {
    let status: Int
    let data: Data
}

private final class ImageStubState: @unchecked Sendable {
    private let routes: [String: ImageStubResponse]
    private let lock = NSLock()
    private var capturedRequests: [URLRequest] = []

    init(routes: [String: ImageStubResponse]) {
        self.routes = routes
    }

    func response(for path: String) -> ImageStubResponse? {
        routes[path] ?? routes["*"]
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequests
    }

    func record(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        capturedRequests.append(request)
    }
}

private final class ImageStubProtocol: URLProtocol, @unchecked Sendable {
    static let registry = ImageStubRegistry()

    // Always intercept this isolated session: a missing fixture fails instead of using real networking.
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let id = request.value(forHTTPHeaderField: "X-Fuse-Test-ID"),
              let state = Self.registry.state(for: id),
              let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        var captured = request
        if captured.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            let bufferSize = 4096
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            while true {
                let count = stream.read(&buffer, maxLength: bufferSize)
                if count < 0 {
                    client?.urlProtocol(self, didFailWithError: stream.streamError ?? URLError(.cannotDecodeRawData))
                    return
                }
                if count == 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            captured.httpBody = data
        }
        state.record(captured)
        guard let stub = state.response(for: url.path),
              let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
