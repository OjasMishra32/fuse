import Foundation
import UIKit

// MARK: - More scenarios
//
// Chosen from a 64-idea, three-judge pass (see docs/USE_CASES.md). Every one works with
// the surfaces that exist today, and every one only makes sense because both screens are
// live at the same time.

extension DemoScenario {
    static let more: [DemoScenario] = [
        DemoScenario(
            id: "compare-folds",
            title: "Comparison that grows",
            subtitle: "Two product pages → comparison table",
            symbol: "tablecells",
            left: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/Samsung_Galaxy_Z_Fold_6")!)),
            right: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/Pixel_9_Pro_Fold")!)),
            instruction: "Compare them: launch price, weight, inner and cover displays, battery, hinge and crease. End with a verdict row."
        ),
        DemoScenario(
            id: "recap",
            title: "Close phone, send recap",
            subtitle: "Calendar + meeting notes → recap email",
            symbol: "envelope.badge",
            left: .init(kind: .calendar, preset: .text("sample")),
            right: .init(kind: .notes, preset: .text("""
                Product sync — notes (typed during the call)

                people: me, Sam (sam@fusehq.dev), Priya (priya@fusehq.dev), Dev (dev@fusehq.dev)
                decided: ship dark mode Thursday. cover-display card first, full result view after
                Sam owns QA on the hinge-angle thresholds — needs the Duo simulator build by Wed
                Priya blocked on icons, waiting on the SF Symbols set from design
                Dev: RevenueCat paywall copy is done, wants my review before it ships
                open: cap free fuses at 3/day or 5/day? nobody agreed
                open: Supabase feed public by default or opt-in?
                next sync?? find a time, everyone was double-booked today
                """)),
            instruction: "Recap this to everyone and propose the next sync from my free time."
        ),
        DemoScenario(
            id: "slot-finder",
            title: "Slot finder",
            subtitle: "Pasted thread + calendar → one invite",
            symbol: "calendar.badge.checkmark",
            left: .init(kind: .clipboard, preset: .text("""
                #design — pasted from Slack

                Maya  9:02 AM
                can we do 30 min this week to lock the cover-display card? need everyone

                Dev  9:04 AM
                Mon or Tue work for me, mornings only

                Sam  9:05 AM
                not Mon, I'm travelling. Tue 9–12 is fine, otherwise Fri

                Jordan  9:11 AM
                anything but Tue at 10, that's my 1:1

                Priya  9:15 AM
                before 11 please, school pickup stuff after that all week

                Maya  9:16 AM
                ok someone pick a time
                """)),
            right: .init(kind: .calendar, preset: .text("sample")),
            instruction: "Find the one 30-minute slot that works for everyone and me."
        ),
        DemoScenario(
            id: "recipe-redline",
            title: "Recipe redline",
            subtitle: "Recipe page + who's coming → redline",
            symbol: "fork.knife",
            left: .init(kind: .web, preset: .url(URL(string: "https://en.wikibooks.org/wiki/Cookbook:Chicken_Tikka_Masala")!)),
            right: .init(kind: .notes, preset: .text("""
                Sunday dinner, 7 people (recipe says 4)
                Jules — vegan
                Omar — gluten-free
                Dad — hates cilantro
                the kids (2) — nothing spicy
                only one big pot + the oven
                start cooking at 5, eat at 7
                """)),
            instruction: "Make it work for everyone on this list."
        ),
        DemoScenario(
            id: "lease-reply",
            title: "Reply with the lease",
            subtitle: "Lease + landlord's text → cited reply",
            symbol: "doc.text.magnifyingglass",
            left: .init(kind: .document, preset: .text("""
                RESIDENTIAL LEASE AGREEMENT
                Premises: 1427 NW 3rd Ave, Apt 2B, Gainesville, FL 32603
                Landlord: Alachua Ridge Properties LLC ("Landlord"). Tenant: Maya Chen ("Tenant").
                Term: August 1, 2026 through July 31, 2027 (the "Initial Term").
                Excerpt: Sections 3, 4, 14, 15, 22

                3. Rent. Tenant shall pay $1,450.00 per month, due on the 1st. Rent is fixed for the Initial Term and shall not be increased during the Initial Term.

                4. Renewal. Not less than sixty (60) days before the end of the Initial Term, Landlord shall deliver written notice of any proposed renewal terms, including any change in rent. If Tenant does not accept in writing within fifteen (15) days of receiving the notice, this Lease converts to month-to-month at the then-current rent on the same terms.

                14. Rent Adjustment. Any increase in rent requires not less than sixty (60) days' written notice delivered per Section 22, and no increase may take effect before the end of the Initial Term. During any month-to-month period there shall be no more than one increase in any twelve (12) month period, not to exceed five percent (5%) of the then-current rent.

                15. Repairs. Landlord shall complete repairs affecting habitability within seven (7) days of written notice, and all other repairs within thirty (30) days.

                22. Notices. All notices under this Lease must be in writing and delivered by hand, certified mail, or email to the addresses below. Text messages do not constitute notice under this Lease.
                Landlord: leasing@alachuaridge.com · 2201 NW 13th St, Suite 400, Gainesville, FL 32609
                Tenant: at the Premises · maya.chen.dev@gmail.com
                """)),
            right: .init(kind: .clipboard, preset: .text("""
                Pasted from Messages — Rick (landlord), today 4:12 PM

                Hey Maya, heads up: rent is going to $1,700 starting Nov 1. Market's up a lot around campus. Let me know you're good with it. Thanks
                """)),
            instruction: "Reply politely and cite the lease."
        ),
        DemoScenario(
            id: "two-photos",
            title: "Two photos, one image",
            subtitle: "Portrait + painting → a new image",
            symbol: "photo.on.rectangle.angled",
            left: .init(kind: .photo, preset: .image(UIImage(named: "SamplePortrait") ?? UIImage())),
            right: .init(kind: .photo, preset: .image(UIImage(named: "SampleStyle") ?? UIImage())),
            instruction: "Repaint the portrait on the left in the style of the painting on the right, keeping the person recognizable."
        ),
        DemoScenario(
            id: "make-test",
            title: "Make me a test",
            subtitle: "Rough outline + example test → full test",
            symbol: "questionmark.circle",
            left: .init(kind: .notes, preset: .text("""
                Test outline, COP3502 module 4
                - Big O: compare O(n log n) vs O(n^2), pick the bound for nested loops
                - Recursion: base case, trace factorial/fibonacci, stack depth
                - Linked lists: insert at head vs tail, why O(1) with a tail pointer
                - Stacks and queues: which one for undo, which one for print jobs
                - Binary search: precondition (sorted), midpoint math, when it fails
                8 questions, mix of conceptual and short code reading
                """)),
            right: .init(kind: .notes, preset: .text("""
                Example test, module 3 (format to copy)

                1. Which statement about arrays in C++ is true?
                   A. Size can change after creation   B. Elements are stored contiguously   C. Index starts at 1   D. They cannot hold structs
                   Answer: B. Contiguous storage is what makes index math O(1).

                2. What does this print?
                   int a[3] = {4, 5, 6}; int* p = a; p++; cout << *p;
                   A. 4   B. 5   C. 6   D. address
                   Answer: B. p now points at a[1].

                3. Short answer: explain why passing a large struct by value is slower than by reference.
                   Answer: the whole struct is copied; a reference passes an address.
                """)),
            instruction: "Write the module 4 test in exactly this format."
        ),
        DemoScenario(
            id: "fridge",
            title: "What do I still need",
            subtitle: "Recipe page + what's in the fridge → list",
            symbol: "checklist",
            left: .init(kind: .web, preset: .url(URL(string: "https://en.wikibooks.org/wiki/Cookbook:Chicken_Tikka_Masala")!)),
            right: .init(kind: .notes, preset: .text("""
                In the fridge and pantry right now:
                chicken thighs (2 lb), plain yogurt, one onion, garlic, ginger, canned tomatoes, heavy cream,
                basmati rice, cumin, turmeric, salt, pepper, vegetable oil
                Missing anything else? Cooking for 4 tonight.
                """)),
            instruction: "Shopping list of only what I don't already have, then a 4-step cook order."
        ),
        DemoScenario(
            id: "fix-the-bug",
            title: "Fix the bug",
            subtitle: "Crash log + source file → the patch",
            symbol: "chevron.left.forwardslash.chevron.right",
            left: .init(kind: .notes, preset: .text("""
                Fatal error: Index out of range
                Thread 1: EXC_BREAKPOINT
                #0 Swift runtime failure: Index out of range
                #1 CartViewModel.total() at CartViewModel.swift:14
                #2 CartView.body.getter at CartView.swift:22
                Reproduces when the cart is empty and the user opens the cart tab.
                """)),
            right: .init(kind: .notes, preset: .text("""
                // CartViewModel.swift
                import Foundation

                struct Item { let name: String; let price: Double; let qty: Int }

                final class CartViewModel {
                    var items: [Item] = []

                    func total() -> Double {
                        var sum = 0.0
                        for i in 0...items.count {
                            sum += items[i].price * Double(items[i].qty)
                        }
                        return sum
                    }

                    func remove(at index: Int) {
                        items.remove(at: index)
                    }
                }
                """)),
            instruction: "Find the bug, explain it in one sentence, and return the corrected file."
        ),
    ]
}
