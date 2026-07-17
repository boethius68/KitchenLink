# Workforce Domain Model

**Scope:** Swift domain foundation for shift planning, time tracking and
staffing (PRODUCT_BLUEPRINT section 9). No UI, persistence, cloud, notifications
or legal policy encoding.

**Owner:** Kimi, KL-WORKFORCE-001  
**Branch:** `kimi/workforce-domain`  
**Write scope:** `kitchenlink/Features/Workforce/`,
`kitchenlinkTests/KitchenLinkWorkforceDomainTests.swift`, this file,
`docs/collaboration/handoffs/KIMI.md`.

## 1. Core objects and boundaries

The domain deliberately keeps three concepts separate:

- **VenueShift** — the operating shift of the venue (open/close, cash drawer,
  tills). One per venue per business day, may span midnight.
- **WorkforcePlannedShift** — an assigned employee work block. Many planned
  shifts can exist inside one `VenueShift`. Draft / published / accepted /
  declined / swap-requested are explicit states with validated transitions.
- **Time tracking** — clock events, break entries, correction requests and the
  immutable audit entries they produce. Correction requests must be approved
  before they create an audit entry.

Employee identity is limited to the workforce profile (`WorkforceEmployee`).
Authentication, login credentials and org-wide membership belong to the
Identity & Access module.

## 2. Identifiers

`WorkforceID` is a thin `RawRepresentable` wrapper around `String`. It is
`Codable`, `Hashable`, `Sendable` and `ExpressibleByStringLiteral` so literals
work in fixtures and tests while the type prevents accidental mixing with other
string identifiers.

## 3. Roles, qualifications and stations

`WorkforceRole` covers the sandbox standard roles (owner, manager, shift lead,
service, kitchen, bar, driver, inventory, accounting). Custom roles are
explicitly out of scope for this domain layer; they will be modelled later
through a configurable permission/policy layer.

`WorkforceQualification` is a separate enum. A station can require specific
qualifications; validators reject a planned shift if the assigned employee does
not hold them.

`WorkforceStation` captures name, colour and required qualifications. It does
not know about headcount; headcount is part of the planned shift/template.

## 4. Time model

### 4.1 Explicit time zones

Every availability, leave, planned shift, venue shift and template stores its
`timeZoneIdentifier`. Durations and wall-clock times are always resolved through
an explicit `Calendar` set to that time zone. There is no implicit use of the
system time zone for business logic.

### 4.2 Local time for templates

`WorkforceLocalTime` (hour + minute) is used in `WorkforceShiftTemplate` because
a template has no date. `resolvedRange(on:calendar:)` converts it to an absolute
`WorkforceTimeRange`. If the local end time is not after the local start time,
the shift is treated as overnight and the end is moved forward by 24 hours.

### 4.3 DST handling

The template resolver is tested against both Europe/Berlin DST transitions:

- Spring 2025: a 01:00–04:00 shift on the transition Sunday resolves to a
  two-hour UTC interval because the clock jumps from 02:00 to 03:00.
- Autumn 2025: a 01:00–04:00 shift on the transition Sunday resolves to a
  four-hour UTC interval because the clock falls back from 03:00 to 02:00.

Callers must pass a `Calendar` configured with the correct time zone; the
domain never assumes the current device time zone.

### 4.4 Time range helper

`WorkforceTimeRange` provides overlap, containment, intersection and duration
calculation. It rejects invalid ranges where `endsAt < startsAt`.

## 5. State machines

### 5.1 Planned shift lifecycle

```text
draft --publish--> published --accept--> accepted
              |               |
              |               `--decline--> declined
              |
              `--requestSwap--> swapRequested --finalizeSwap(accepted:true)--> published
                                              --finalizeSwap(accepted:false)--> published
```

- Only a draft can be published.
- Only a published shift can be accepted or declined.
- A published or accepted shift can enter swap-requested state.
- `finalizeSwap` always returns to `published` so the new holder can accept.
- Managers can `revertToDraft` from any non-draft state for planning corrections.

All transitions return `Result<Void, WorkforceValidationError>`.

### 5.2 Swap request lifecycle

`pending -> accepted | rejected | withdrawn`. Only pending requests can be
accepted, rejected or withdrawn.

### 5.3 Correction request lifecycle

`draft -> submitted -> approved | rejected`. Approval produces an immutable
`WorkforceAuditEntry` with `source == .correctionApproved`.

## 6. Validators

All validators are pure functions taking a value and a
`WorkforceValidationContext` (employees, assignments, stations, planned shifts,
availabilities, leaves, time entries, break entries, venue shifts). No
validator touches persistence.

Implemented checks:

- `WorkforceAvailabilityValidator` — valid range, no overlap for the same
  employee.
- `WorkforceLeaveValidator` — valid range; approved leave must not overlap an
  already-published planned shift.
- `WorkforcePlannedShiftValidator` — valid range, active employee, venue
  assignment exists, no approved leave overlap, required qualifications present,
  explicit availability covers the full shift.
- `WorkforceStationStaffingValidator` — counts assigned shifts per station and
  range; returns an under-staffing failure when actual < target. This is a
  warning-style failure: planning may intentionally create under-staffed shifts.
- `WorkforceTimeEntryValidator` — active employee, timestamp after hire date,
  timestamp inside the linked planned shift, no duplicate event.
- `WorkforceBreakValidator` — valid range, break lies inside the linked shift,
  no overlapping breaks.

## 7. Fixture

`WorkforceSandboxWeekFixture` is a deterministic, reproducible setup for a
fictional restaurant in Lichterfelde with service, kitchen and bar stations;
five employees; and four published Monday shifts. It is used by the unit tests
and can be reused by UI previews or future integration tests.

The fixture aligns to the Monday of a reference week in Europe/Berlin. The
venue operating shift intentionally spans midnight to exercise overnight logic.

## 8. What is deliberately postponed

The following items are not encoded in this layer because they are either UI,
persistence, cloud, legal or configurable-policy concerns:

- UI screens, navigation, SwiftUI views.
- SQLite / Core Data / Supabase persistence.
- Push notifications for shift offers or reminders.
- Working-time laws, break obligations, maximum weekly hours, night-shift
  premiums, holiday entitlements or any other legal rule.
- Payroll calculation, tax logic or DATEV export.
- Configurable permission system for custom roles.
- Multi-venue scheduling optimisation or automatic roster generation.
- Conflict resolution for concurrent edits (reserved for the offline/sync
  module).

## 9. Persistence/UI seam

The intended later integration seam is:

- A repository/service owned by the Workforce module exposes CRUD-like
  operations that load/save `WorkforcePlannedShift`, `WorkforceAvailability`,
  `WorkforceLeave`, `WorkforceTimeEntry`, `WorkforceBreakEntry`,
  `WorkforceCorrectionRequest` and `WorkforceAuditEntry`.
- Validators are called by the service before mutation; the service reports
  `WorkforceValidationError` to the UI.
- The audit log is append-only; once created, `WorkforceAuditEntry` must not be
  modified.
- `WorkforceSandboxWeekFixture` can seed the repository for previews and demo
  mode.

## 10. Test summary

`KitchenLinkWorkforceDomainTests` contains focused Swift Testing tests covering:

- employee employment status;
- time range overlap and validity;
- template resolution to local time, overnight shifts and invalid local time;
- both Europe/Berlin DST transitions;
- planned-shift lifecycle state machine (publish, accept, decline, revert,
  swap, finalize);
- swap-request lifecycle;
- correction-request lifecycle and audit-entry production;
- validators for inactive employees, missing qualifications, approved-leave
  overlap, missing availability, availability overlap, station under-staffing,
  time entries before hire date, inactive employees on clock-in, breaks outside
  shifts and valid breaks;
- fixture consistency (employee/station/shift counts, published state,
  overnight venue shift).

Run with:

```bash
xcodebuild test -project kitchenlink.xcodeproj -scheme kitchenlink \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing kitchenlinkTests/KitchenLinkWorkforceDomainTests \
  -skipMacroValidation
```

## 11. References

- `PRODUCT_BLUEPRINT.md` section 9 (Personnel and Scheduling).
- Swift `Calendar`/`TimeZone` behaviour verified against system frameworks; no
  third-party date library is used.
- Apple documentation: `Date`, `Calendar`, `TimeZone`.
