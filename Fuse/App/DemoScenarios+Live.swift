import Foundation
import UIKit

// MARK: - Live demo
//
// The six scenarios a presenter runs on stage, in order, with nothing to set up from a Mac.
// Each one seeds both halves (and the instruction where it helps) so the fold is the only step
// left. They are the "Demos" row on the left half's home screen and the first section of the
// Scenarios sheet. Ids are prefixed "live-" so they never collide with the catalogue below.

extension DemoScenario {
    static let live: [DemoScenario] = [
        DemoScenario(
            id: "live-theme-park",
            title: "Theme park day",
            subtitle: "Attraction page + map → itinerary",
            symbol: "map",
            left: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/Islands_of_Adventure")!)),
            right: .init(kind: .maps, preset: .place(name: "Universal Islands of Adventure", latitude: 28.4711, longitude: -81.4712)),
            instruction: nil
        ),
        DemoScenario(
            id: "live-two-photos",
            title: "Two photos, one image",
            subtitle: "Two portraits → one photo of both",
            symbol: "photo.on.rectangle.angled",
            left: .init(kind: .photo, preset: .image(UIImage(named: "DemoGarry") ?? UIImage())),
            right: .init(kind: .photo, preset: .image(UIImage(named: "DemoBrad") ?? UIImage())),
            instruction: "Make one photo of both of them together as bodybuilders posing on a competition stage, keep both faces recognizable."
        ),
        DemoScenario(
            id: "live-week",
            title: "Fold it into my week",
            subtitle: "Conference email + calendar → event",
            symbol: "calendar.badge.plus",
            left: .init(kind: .notes, preset: .text(DemoText.conferenceEmail)),
            right: .init(kind: .calendar, preset: .text("sample")),
            instruction: nil
        ),
        DemoScenario(
            id: "live-scooters",
            title: "Compare two scooters",
            subtitle: "Two Amazon listings → verdict",
            symbol: "scooter",
            left: .init(kind: .web, preset: .url(URL(string: "https://www.amazon.com/dp/B0CWVRZFXC")!)),
            right: .init(kind: .web, preset: .url(URL(string: "https://www.amazon.com/dp/B0DSMQJX1X")!)),
            instruction: "Compare these two scooters for a daily college commute: price, range, top speed, weight, hills, and pick one."
        ),
        DemoScenario(
            id: "live-grade",
            title: "Grade my practice test",
            subtitle: "Practice test + your answers → grade",
            symbol: "graduationcap",
            left: .init(kind: .notes, preset: .text(DemoText.practiceTest)),
            right: .init(kind: .notes, preset: .text(DemoText.studentAnswers)),
            instruction: nil
        ),
        DemoScenario(
            id: "live-split",
            title: "Split the bill",
            subtitle: "Receipt + who had what → table",
            symbol: "receipt",
            left: .init(kind: .notes, preset: .text("""
                THE COPPER PIG
                Table 12, server: Ana
                Sat Sep 20 2026, 8:52 PM

                1  Burrata and peaches          14.00
                1  Wings (dozen)               16.00
                1  Smash burger                 17.00
                1  Mushroom risotto             21.00
                1  Steak frites                 34.00
                1  Fish tacos (3)               18.00
                2  House red (glass)     2 x 11 22.00
                1  IPA pint                      8.00
                1  Lemonade                      4.00
                1  Sparkling water (bottle)      6.00
                1  Churros (share)              10.00

                Subtotal                       170.00
                Tax 7%                          11.90
                Total                          181.90

                Gratuity not included. Suggested: 18% 30.60 / 20% 34.00 / 22% 37.40
                """)),
            right: .init(kind: .notes, preset: .text("""
                who had what, Copper Pig

                me: steak frites, one glass of red
                Nina: mushroom risotto, the other glass of red
                Jake: smash burger, the IPA
                Priya: fish tacos, lemonade
                shared 4 ways: burrata, wings, churros, sparkling water
                tip 20%, and split the tax and tip proportional to what each person ate, not evenly
                Jake already put $40 on the card so show what everyone owes him
                round to the nearest cent
                """)),
            instruction: "Build the split as a table: one row per person with their items, subtotal, tax share, tip share, total, and what they owe Jake. Show the check math at the bottom."
        ),
    ]
}
