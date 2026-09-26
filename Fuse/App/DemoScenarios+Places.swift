import Foundation
import UIKit

// MARK: - Thing + Place -> Plan
//
// Every scenario here has a map on one side and something concrete on the other.
// The result is always something you can act on: an itinerary, an event, or a checklist.

extension DemoScenario {
    static let places: [DemoScenario] = [
        DemoScenario(
            id: "places-restaurant-shortlist",
            title: "Pick the restaurant",
            subtitle: "Five restaurants + Orlando pin → booking and route",
            symbol: "fork.knife",
            left: .init(kind: .notes, preset: .text("""
                Friday dinner shortlist, party of 4, one vegetarian, budget about $40 a head
                Reservation for 7:30 PM. We are staying near Lake Eola downtown.

                1. Kabooki Sushi, 3122 E Colonial Dr, Orlando, FL 32803
                   omakase and rolls, loud, books out fast, good veg rolls
                2. Se7en Bites, 617 N Primrose Dr, Orlando, FL 32803
                   Southern comfort, brunch and lunch only, closes 3 PM
                3. Black Rooster Taqueria, 1323 N Mills Ave, Orlando, FL 32803
                   tacos, casual, no reservations, walk-in line on weekends
                4. Domu, 3201 Corrine Dr, Orlando, FL 32803 (inside East End Market)
                   ramen, vegan miso option, takes reservations, dinner till 10
                5. The Ravenous Pig, 565 W Fairbanks Ave, Winter Park, FL 32789
                   gastropub, pricier, tasting plates, reservations recommended
                """)),
            right: .init(kind: .maps, preset: .place(name: "Lake Eola Park, Orlando", latitude: 28.5437, longitude: -81.3727)),
            instruction: "Pick the one to book for 7:30 tonight, say why the others lose, and give me the drive route and leave-by time from the pin."
        ),
        DemoScenario(
            id: "places-apartment-commute",
            title: "Commute check",
            subtitle: "Apartment listing + UF pin → commute verdict",
            symbol: "house",
            left: .init(kind: .notes, preset: .text("""
                Listing saved from the housing board

                2 bed / 2 bath, 950 sq ft, second floor
                3705 SW 27th St, Gainesville, FL 32608
                $1,375 per month, water included, electric not included
                12 month lease starting Aug 1, $500 deposit
                Parking: one assigned space, no campus decal included
                Transit: RTS Route 12 and Route 35 stop at the entrance
                Bike: paved path most of the way to Archer Rd
                Washer and dryer in unit, pets under 30 lb ok
                Showing: Saturday 11:00 AM, ask for Denise at the leasing office

                My schedule: first class 9:35 AM MWF, lab till 6 PM Tuesdays, no car
                """)),
            right: .init(kind: .maps, preset: .place(name: "University of Florida", latitude: 29.6436, longitude: -82.3549)),
            instruction: "Give me a commute verdict for this listing as a checklist: bus, bike, and walk times to campus, what to confirm at the Saturday showing, and a yes or no."
        ),
        DemoScenario(
            id: "places-concert-leave-by",
            title: "Leave-by plan",
            subtitle: "Ticket email + Kia Center pin → leave-by plan",
            symbol: "music.note",
            left: .init(kind: .notes, preset: .text("""
                From: tickets@venue-mail.example
                Subject: Your tickets are ready: Saturday at Kia Center

                Kia Center, 400 W Church St, Orlando, FL 32801
                Saturday, doors 7:00 PM, show 8:00 PM
                Section 112, Row K, Seats 7 and 8, mobile entry only
                Bag policy: clear bags 12 x 6 x 12 or smaller
                Parking: venue garages open at 5:30 PM, $25, card only
                Arrive early: security lines are longest 7:15 to 7:45 PM

                Leaving from: 500 N Park Ave, Winter Park (dinner first, done by 6:15)
                Two of us, driving, want to be inside before opener at 8
                """)),
            right: .init(kind: .maps, preset: .place(name: "Kia Center", latitude: 28.5392, longitude: -81.3839)),
            instruction: "Build a leave-by plan working backward from the 8 PM start: drive time, parking, security line, and a calendar event with alerts."
        ),
        DemoScenario(
            id: "places-syllabus-walk",
            title: "Walking schedule",
            subtitle: "Syllabus + UF pin → walking schedule",
            symbol: "graduationcap",
            left: .init(kind: .notes, preset: .text("""
                Fall schedule, Monday Wednesday Friday

                MAC 2313 Calculus 3
                Period 3, 9:35 to 10:25 AM, Little Hall (LIT) room 101

                COP 3502 Programming Fundamentals 2
                Period 4, 10:40 to 11:30 AM, Carleton Auditorium (CAR)

                PHY 2048 Physics with Calculus 1
                Period 6, 12:50 to 1:40 PM, New Physics Building (NPB) room 1001

                Office hours: Wednesdays 3:00 PM, Turlington Hall (TUR) room 2318
                Lunch: anywhere near the Reitz Union, 30 minutes is enough
                """)),
            right: .init(kind: .maps, preset: .place(name: "University of Florida", latitude: 29.6436, longitude: -82.3549)),
            instruction: "Turn this into a Wednesday walking schedule: building to building with walk minutes, where lunch fits, and which gap is tight."
        ),
        DemoScenario(
            id: "places-grocery-route",
            title: "Grocery run",
            subtitle: "Grocery list + Publix pin → aisle order",
            symbol: "cart",
            left: .init(kind: .notes, preset: .text("""
                Sunday meal prep, 4 lunches and 3 dinners

                chicken thighs 2 lb
                salmon fillets 2
                eggs 12
                greek yogurt large
                spinach bag
                broccoli 2 heads
                sweet potatoes 4
                bell peppers 3
                bananas
                blueberries
                brown rice
                olive oil
                canned black beans 2
                tortillas
                sparkling water 12 pack
                dish soap

                Have 45 minutes total including the drive back. Bringing a cooler bag.
                """)),
            right: .init(kind: .maps, preset: .place(name: "Publix, Butler Plaza, Gainesville", latitude: 29.6207, longitude: -82.3780)),
            instruction: "Reorder the list into a store walk order (produce, aisles, cold, checkout), then give me the timed route home to 29.6436, -82.3549."
        ),
        DemoScenario(
            id: "places-sf-afternoon",
            title: "SF afternoon",
            subtitle: "City guide + Ferry Building pin → 3 stops",
            symbol: "map",
            left: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/San_Francisco")!)),
            right: .init(kind: .maps, preset: .place(name: "Ferry Building, San Francisco", latitude: 37.7955, longitude: -122.3937)),
            instruction: "Plan a 3-stop afternoon from 1 to 6 PM starting at the pin, on foot and transit only, with times and how to get between stops."
        ),
        DemoScenario(
            id: "places-parking-sign",
            title: "Move the car",
            subtitle: "Parking sign + curb pin → move-by event",
            symbol: "car",
            left: .init(kind: .notes, preset: .text("""
                Sign at the curb, read top to bottom

                NO PARKING
                TUESDAY 8 AM TO 10 AM
                STREET CLEANING

                2 HOUR PARKING
                9 AM TO 6 PM
                MONDAY THROUGH SATURDAY
                EXCEPT VEHICLES WITH AREA Q PERMIT

                TOW AWAY
                NO STOPPING 4 PM TO 6 PM
                MONDAY THROUGH FRIDAY

                I parked here Tuesday at 2:40 PM. No permit.
                """)),
            right: .init(kind: .maps, preset: .place(name: "Valencia St and 20th St, San Francisco", latitude: 37.7587, longitude: -122.4216)),
            instruction: "Tell me exactly when I have to move the car and why, then make a calendar event with a 15-minute alert."
        ),
        DemoScenario(
            id: "places-last-train",
            title: "Last train home",
            subtitle: "BART timetable + Fox Theater pin → last train",
            symbol: "tram",
            left: .init(kind: .notes, preset: .text("""
                Tonight, 19th St Oakland station, last departures (from the station board)

                Toward San Francisco and Daly City
                11:19 PM, 11:39 PM, 11:59 PM, 12:19 AM (last)

                Toward Berryessa
                11:33 PM, 11:53 PM, 12:13 AM (last)

                Toward Richmond
                11:27 PM, 11:47 PM, 12:07 AM (last)

                Show at the Fox: headliner on at 9:15, usually about 90 minutes plus encore
                Home is near Balboa Park station in SF
                Walk from the Fox to 19th St is short but the crowd exits slowly
                """)),
            right: .init(kind: .maps, preset: .place(name: "Fox Theater, Oakland", latitude: 37.8081, longitude: -122.2706)),
            instruction: "Pick the train I should aim for and the last one I can make, then create a leave-the-venue event with an alert."
        ),
        DemoScenario(
            id: "places-stanford-visit",
            title: "Campus visit",
            subtitle: "Stanford page + campus pin → visit plan",
            symbol: "building.columns",
            left: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/Stanford_University")!)),
            right: .init(kind: .maps, preset: .place(name: "Stanford University", latitude: 37.4275, longitude: -122.1697)),
            instruction: "Plan a half-day campus visit from 10 AM to 3 PM around the pin: landmarks in walking order, where to eat, and what to ask at the CS building."
        ),
        DemoScenario(
            id: "places-yosemite-loop",
            title: "Yosemite day",
            subtitle: "Park page + valley pin → one-day loop",
            symbol: "leaf",
            left: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/Yosemite_National_Park")!)),
            right: .init(kind: .maps, preset: .place(name: "Yosemite Valley", latitude: 37.7456, longitude: -119.5936)),
            instruction: "Build a one-day loop from the valley pin for two moderate hikers: start time, stops in order, drive and hike minutes, and a packing checklist."
        ),
        DemoScenario(
            id: "places-moma-route",
            title: "Two hours at MoMA",
            subtitle: "Museum page + MoMA pin → 2-hour route",
            symbol: "paintpalette",
            left: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/Museum_of_Modern_Art")!)),
            right: .init(kind: .maps, preset: .place(name: "Museum of Modern Art", latitude: 40.7614, longitude: -73.9776)),
            instruction: "Give me a 2-hour route through the museum floor by floor, the works not to miss, and a coffee stop within a 5-minute walk of the pin after."
        ),
    ]
}
