# Kimi Handoff

**Updated:** 16 July 2026  
**Branch:** `kimi/workforce-domain`  
**Mission:** KL-WORKFORCE-001

## Scope

Isolierte, production-testable Swift domain foundation for shift planning and
time tracking per PRODUCT_BLUEPRINT section 9. No UI, persistence, cloud,
notifications or legal rules were added.

## Completed

- `kitchenlink/Features/Workforce/WorkforceDomain.swift`: identifiers, roles,
  qualifications, stations, employee profile, venue assignment, time range,
  validation errors.
- `kitchenlink/Features/Workforce/WorkforceTimeModels.swift`: local time,
  availability, leave, shift template, planned shift, venue operating shift,
  swap request, clock events, break entry, correction request, audit entry.
- `kitchenlink/Features/Workforce/WorkforceShiftLifecycle.swift`: explicit
  state machines and validated transitions for planned shifts, swap requests and
  correction requests.
- `kitchenlink/Features/Workforce/WorkforceValidators.swift`: pure validators
  for availability, leave, planned shifts, station staffing, time entries and
  breaks.
- `kitchenlink/Features/Workforce/WorkforceFixtures.swift`: deterministic
  sandbox week fixture for a restaurant with service, kitchen and bar stations;
  five employees; four published Monday shifts; overnight venue shift.
- `kitchenlinkTests/KitchenLinkWorkforceDomainTests.swift`: 33 focused Swift
  Testing tests including state machines, validators, DST transitions, overnight
  shifts and fixture consistency.
- `docs/domain/WORKFORCE_MODEL.md`: invariant, object boundary, time model and
  future seam documentation.

## Files Changed

- New: `kitchenlink/Features/Workforce/WorkforceDomain.swift`
- New: `kitchenlink/Features/Workforce/WorkforceTimeModels.swift`
- New: `kitchenlink/Features/Workforce/WorkforceShiftLifecycle.swift`
- New: `kitchenlink/Features/Workforce/WorkforceValidators.swift`
- New: `kitchenlink/Features/Workforce/WorkforceFixtures.swift`
- New: `kitchenlinkTests/KitchenLinkWorkforceDomainTests.swift`
- New: `docs/domain/WORKFORCE_MODEL.md`
- Updated: `docs/collaboration/handoffs/KIMI.md`

No existing app target, test or domain file was modified.

## Verification

Command used:

```bash
xcodebuild test -project kitchenlink.xcodeproj -scheme kitchenlink \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -skipMacroValidation
```

Result: **TEST SUCCEEDED**.

Focused workforce suite:

```bash
xcodebuild test -project kitchenlink.xcodeproj -scheme kitchenlink \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing kitchenlinkTests/KitchenLinkWorkforceDomainTests \
  -skipMacroValidation
```

Result: **TEST SUCCEEDED**, 33/33 tests passed.

## Known Risks And Open Work

- The validators use a simple in-memory context. Integration with a repository
  and the offline/sync event log (GLM KL-OFFLINE-003) is future work.
- No custom permission system is modelled yet; `WorkforceRole` covers only the
  sandbox standard roles.
- Legal working-time rules are intentionally not encoded; they must become
  configurable policy later, reviewed for German labour law.
- The fixture creates only Monday shifts. Week-long templates and recurring
  patterns are covered by the model but not fully exercised by tests yet.
- Time-entry duplicate detection currently uses a one-second tolerance. A
  production store should use sub-second or UUID-based deduplication.
