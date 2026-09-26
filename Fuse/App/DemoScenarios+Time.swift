import Foundation
import UIKit

// MARK: - Thing + Time -> Commitment
//
// One side is something with dates in it (a schedule, an email, a sign, an invitation),
// the other side is the calendar. The result is an event with conflicts and travel time
// in the notes, or a checklist of calendar blocks.

extension DemoScenario {
    static let time: [DemoScenario] = [
        DemoScenario(
            id: "time-course-schedule",
            title: "Semester into blocks",
            subtitle: "Course schedule + calendar → weekly blocks",
            symbol: "calendar",
            left: .init(kind: .document, preset: .text("""
                Fall 2026 schedule, pulled from ONE.UF

                COP 3530 Data Structures and Algorithms
                  Mon / Wed / Fri 10:40 AM to 11:30 AM, CSE E119
                  Lab: Thu 1:55 PM to 3:50 PM, CSE E222

                MAC 2313 Analytic Geometry and Calculus 3
                  Tue / Thu 9:35 AM to 10:25 AM, LIT 113
                  Discussion: Fri 12:50 PM to 1:40 PM, MAT 118

                STA 3032 Engineering Statistics
                  Mon / Wed 3:00 PM to 4:55 PM, WEIM 1064

                ENC 3254 Professional Writing in the Discipline
                  Tue / Thu 4:05 PM to 5:20 PM, TUR 2333

                Office hours I want to hit: COP 3530 TA, Wed 2:00 PM to 3:00 PM, Malachowsky Hall 3rd floor.
                Walking from Weimer to Turlington is about 12 minutes. Malachowsky to Weimer is about 8 minutes.
                """)),
            right: .init(kind: .calendar, preset: .text("sample")),
            instruction: "Turn this into a checklist of weekly calendar blocks, flag anything that collides with what is already on my calendar, and add walking time between back-to-back buildings."
        ),
        DemoScenario(
            id: "time-job-deadline",
            title: "Apply before it closes",
            subtitle: "Job posting + calendar → deadline events",
            symbol: "calendar.badge.clock",
            left: .init(kind: .notes, preset: .text("""
                Software Engineering Intern, Summer 2027
                Meridian Systems, Platform Engineering
                Location: San Francisco, CA (hybrid, 3 days in office)

                Application window closes Friday, October 9, 2026 at 11:59 PM ET. Late applications are not reviewed.

                Process
                1. Online assessment (HackerRank, 90 minutes). The link is sent within 3 business days of applying and expires 7 days after it is sent.
                2. Phone screen, 30 minutes, scheduled through the candidate portal. Available windows: October 19 to October 23 and October 26 to October 30, 10:00 AM to 4:00 PM ET.
                3. Final round, one 3-hour virtual block with two engineers and a hiring manager. Windows: November 9 to November 13.

                Offers go out the week of November 30. Please have your resume, unofficial transcript, and two references ready before you apply. Questions to campus.recruiting@meridian.example.
                """)),
            right: .init(kind: .calendar, preset: .text("sample")),
            instruction: "Put the deadline and every stage on my calendar, pick the phone screen and final round windows that avoid my classes, and note the assessment expiry math."
        ),
        DemoScenario(
            id: "time-flight",
            title: "Flights onto calendar",
            subtitle: "Confirmation email + calendar → trip events",
            symbol: "airplane",
            left: .init(kind: .notes, preset: .text("""
                From: Sunward Air Reservations <noreply@sunwardair.example>
                Subject: Your trip is confirmed, MCO to SFO
                Confirmation code: KX7Q4L

                Passenger: OJAS MISHRA

                Outbound, Thursday, November 19, 2026
                Sunward 1263, Orlando (MCO) to San Francisco (SFO)
                Departs 7:05 AM ET, Terminal C, gate posted 90 minutes before departure
                Arrives 10:22 AM PT
                Nonstop, 6h 17m, seat 14A

                Return, Monday, November 23, 2026
                Sunward 1264, San Francisco (SFO) to Orlando (MCO)
                Departs 11:40 AM PT, International Terminal
                Arrives 8:05 PM ET
                Nonstop, 5h 25m, seat 9C

                Check-in opens 24 hours before departure. Please arrive at least 2 hours before a domestic flight. Baggage: 1 carry-on and 1 personal item included, checked bags $35 each way.
                """)),
            right: .init(kind: .calendar, preset: .text("sample")),
            instruction: "Add both flights with the drive from Gainesville to MCO and the airport buffer in the notes, and list what already on my calendar collides with the trip."
        ),
        DemoScenario(
            id: "time-dinner-chat",
            title: "Group chat dinner",
            subtitle: "Pasted thread + calendar → dinner event",
            symbol: "bubble.left.and.bubble.right",
            left: .init(kind: .clipboard, preset: .text("""
                Pasted from Messages, "Dinner ppl" group, today

                Nia  6:41 PM
                ok are we doing dinner this week or not

                Theo  6:42 PM
                yes. not tuesday, I have lab until 8

                Priya  6:44 PM
                wed or thu works. thu I need to be home by 9:30

                Marcus  6:45 PM
                thu is best for me, wed I have a shift

                Nia  6:47 PM
                thu then? 7?

                Theo  6:48 PM
                7 works. Satchel's or that new thai place on 13th?

                Priya  6:50 PM
                thai. Satchel's line is insane on thursdays

                Marcus  6:51 PM
                thai, 7. someone make the reservation

                Nia  6:52 PM
                you are someone
                """)),
            right: .init(kind: .calendar, preset: .text("sample")),
            instruction: "Make the dinner event, check it against my Thursday, and put who is coming, the hard stop, and a reservation reminder in the notes."
        ),
        DemoScenario(
            id: "time-braise",
            title: "Braise backwards",
            subtitle: "Recipe + Saturday calendar → timed checklist",
            symbol: "fork.knife",
            left: .init(kind: .notes, preset: .text("""
                Red wine braised short ribs
                Serves 6. Active time 40 min. Total time about 3 hours 30 min.

                4 lb bone-in short ribs
                2 tbsp olive oil, salt, pepper
                1 onion, 2 carrots, 2 celery stalks, diced
                4 garlic cloves, smashed
                2 tbsp tomato paste
                2 cups dry red wine
                3 cups beef stock
                2 bay leaves, 4 sprigs thyme

                1. Season ribs, sear in batches, 4 min per side. (15 min)
                2. Cook vegetables until soft, stir in tomato paste. (10 min)
                3. Add wine, reduce by half. Add stock and herbs, bring to a simmer. (15 min)
                4. Cover and braise at 325 F for 2 hours. Turn the ribs once at the halfway point. (2 hours)
                5. Rest 20 minutes, skim fat, reduce the sauce on the stove. (20 min)

                Serve with mashed potatoes, which take 40 minutes and can overlap the braise.
                Saturday dinner, guests arrive at 7:00 PM, want to sit down at 7:30. Need 30 minutes at Publix first for the ribs and wine.
                """)),
            right: .init(kind: .calendar, preset: .text("sample")),
            instruction: "Work backward from a 7:30 PM Saturday dinner and build a timed checklist of kitchen blocks around whatever is already on my calendar that afternoon."
        ),
        DemoScenario(
            id: "time-doctor",
            title: "After visit reminders",
            subtitle: "Doctor's note + calendar → meds and follow-up",
            symbol: "cross.case",
            left: .init(kind: .document, preset: .text("""
                AFTER VISIT SUMMARY
                UF Health Student Care, Gainesville
                Visit date: today. Provider: Dr. Elena Ruiz, MD

                Diagnosis: acute bacterial sinusitis

                Medications
                Amoxicillin-clavulanate 875 mg, take 1 tablet by mouth twice daily with food for 10 days. Start tonight. Finish the entire course even if you feel better.
                Fluticasone nasal spray, 2 sprays in each nostril once daily in the morning, for 30 days.

                Instructions
                Return in 2 weeks for a follow-up visit. Book through MyChart or call 352-555-0140. If symptoms worsen, fever above 101.5 F, or no improvement in 5 days, call sooner.
                Rest, fluids, and no strenuous exercise for the next 3 days.

                Pharmacy: CVS, 3711 SW Archer Rd. Prescription sent electronically, ready for pickup after 5:00 PM today. Bring your student ID.
                """)),
            right: .init(kind: .calendar, preset: .text("sample")),
            instruction: "Schedule the pharmacy pickup, the twice daily medication reminders for 10 days, and the follow-up, and note anything on my calendar the no-exercise rule affects."
        ),
        DemoScenario(
            id: "time-newsletter",
            title: "Newsletter to events",
            subtitle: "School newsletter + calendar → six events",
            symbol: "book",
            left: .init(kind: .document, preset: .text("""
                Glen Springs Elementary, Family Newsletter, week of September 28

                1. Picture Day is Wednesday, September 30. Order forms went home Friday, online orders close Tuesday night at 9:00 PM.
                2. Early release Friday, October 2. Dismissal at 1:15 PM, no after-care that day. Please plan pickup accordingly.
                3. Book Fair runs Monday, October 5 through Friday, October 9 in the media center. Family Night is Thursday, October 8, 5:30 PM to 7:00 PM.
                4. Fall Festival, Saturday, October 17, 11:00 AM to 3:00 PM on the back field. Volunteers needed for the 11 to 1 shift, sign up on the PTA page by October 12.
                5. Parent-teacher conferences, Tuesday, October 20 and Wednesday, October 21, 3:30 PM to 7:00 PM. Book a 20-minute slot on the portal by October 14.
                6. No school Monday, October 26 for teacher planning.

                Reminder: the car line moves to the north lot starting Monday. Enter from NW 39th Ave only.
                """)),
            right: .init(kind: .calendar, preset: .text("sample")),
            instruction: "Add all six as events, separate the sign-up deadlines from the dates themselves, and flag anything that collides with my calendar."
        ),
        DemoScenario(
            id: "time-parking",
            title: "Move the car",
            subtitle: "Parking sign + dinner plan → reminders",
            symbol: "car",
            left: .init(kind: .notes, preset: .text("""
                Sign on NW 4th Ave, right where the car is parked now

                NO PARKING
                STREET CLEANING
                2nd AND 4th FRIDAY
                OF EACH MONTH
                8 AM TO 12 NOON
                TOW AWAY ZONE

                2 HOUR PARKING
                8 AM TO 6 PM
                MON THRU SAT
                EXCEPT BY PERMIT
                (I do not have a permit)

                Tonight: dinner at Dragonfly on SW 2nd Ave, reservation at 7:45 PM under Mishra, party of 4. It is about a 10 minute walk from where the car is. After dinner, watch party at Ava's place across town, probably 10:00 PM, and I am the designated driver.
                """)),
            right: .init(kind: .calendar, preset: .text("sample")),
            instruction: "Tell me when I have to move the car, put a reminder on the calendar before that, and make the dinner event with the walk and the drive to Ava's in the notes."
        ),
        DemoScenario(
            id: "time-wedding",
            title: "Wedding weekend",
            subtitle: "Invitation + calendar → weekend events",
            symbol: "envelope.open",
            left: .init(kind: .document, preset: .text("""
                Together with their families
                Amara Okafor and Daniel Reyes
                request the pleasure of your company at their wedding

                Saturday, the twenty-first of November, two thousand twenty-six
                Ceremony at four o'clock in the afternoon
                Sweetwater Branch Inn, 625 E University Ave, Gainesville, Florida
                Reception to follow at six o'clock, dinner and dancing until eleven

                Welcome drinks: Friday, November 20, 7:00 PM, The Top, 30 N Main St
                Farewell brunch: Sunday, November 22, 10:00 AM, at the inn

                Kindly reply by October 24 at amaraanddaniel.example/rsvp
                Black tie optional. Hotel block at the Hampton Inn downtown, code OKAFORREYES, block releases October 31.
                Parking is limited, rideshare is encouraged.
                """)),
            right: .init(kind: .calendar, preset: .text("sample")),
            instruction: "Add the three wedding events plus the RSVP and hotel block deadlines, and tell me what already on my calendar that weekend collides."
        ),
        DemoScenario(
            id: "time-gym",
            title: "Three classes a week",
            subtitle: "Gym schedule + calendar → repeating events",
            symbol: "figure.run",
            left: .init(kind: .notes, preset: .text("""
                Southwest Rec, group fitness, fall block
                Classes are 50 minutes unless noted. Arrive 10 minutes early, spots are first come.

                Monday
                  6:30 AM Spin, Studio B
                  5:30 PM Power Yoga, Studio A
                Tuesday
                  7:00 AM HIIT, Studio B
                  6:00 PM Boxing, Studio C
                Wednesday
                  6:30 AM Spin, Studio B
                  12:15 PM Core Express, 30 min, Studio A
                Thursday
                  7:00 AM HIIT, Studio B
                  5:30 PM Power Yoga, Studio A
                Friday
                  6:30 AM Spin, Studio B
                  4:30 PM Climbing Intro, 90 min, the wall, sign-up required
                Saturday
                  9:00 AM Long Run Club, meets at the front desk
                Sunday
                  10:00 AM Yin Yoga, Studio A

                Goal: 3 sessions a week, at least one strength and one yoga. Southwest Rec is a 15 minute bike ride from my apartment.
                """)),
            right: .init(kind: .calendar, preset: .text("sample")),
            instruction: "Pick three classes a week that fit around my calendar, add them as repeating events, and put the bike time and the arrive-early rule in the notes."
        ),
        DemoScenario(
            id: "time-library",
            title: "Library due dates",
            subtitle: "Due-date email + calendar → return reminders",
            symbol: "books.vertical",
            left: .init(kind: .notes, preset: .text("""
                From: UF Libraries <circulation@uflib.example>
                Subject: Items due soon and a hold ready for pickup

                Hi Ojas,

                The following items are due soon. Renew online unless another patron has placed a hold.

                Due Friday, October 2
                  Designing Data-Intensive Applications, Kleppmann. Renewable once.
                  The Pragmatic Programmer, Hunt and Thomas. Not renewable, another patron has a hold.

                Due Thursday, October 8
                  Introduction to Algorithms, 4th ed. Course reserve, 7 day loan. Not renewable.

                Hold ready for pickup
                  Crafting Interpreters, Nystrom. Pick up at Library West by Wednesday, September 30, 6:00 PM, or the hold is released to the next patron.

                Fines are $0.50 per day per item. Library West is open until midnight Sunday through Thursday and until 10:00 PM Friday and Saturday.
                """)),
            right: .init(kind: .calendar, preset: .text("sample")),
            instruction: "Make return and pickup reminders that fit around my classes, and group them so I only make one trip to Library West if possible."
        ),
    ]
}
