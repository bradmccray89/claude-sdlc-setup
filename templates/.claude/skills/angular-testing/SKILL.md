---
name: angular-testing
description: How to write the one test each task must leave behind in this Angular repo — TestBed, HttpTestingController, harnesses, fakeAsync, signals — matched to the repo's existing runner. Consult before writing or editing any .spec.ts.
---

# Angular testing

The workflow requires one test per task covering exactly what you changed — no
backfills. This skill is how to make that test good in Angular.

## Step 1 — Match the repo's runner and style

1. Check `angular.json`'s `test` target and `package.json` for the runner:
   **Karma + Jasmine** (Angular default), **Jest**, or a newer
   `@web/test-runner`/Vitest setup. Write in whatever is already there — spies,
   matchers, and config differ (`jasmine.createSpyObj` vs `jest.fn()`).
2. Copy the setup of a neighboring `.spec.ts` next to the code you changed. Don't
   introduce a new runner or a new mocking library.
3. Ensure the run is non-interactive (the verify gate needs it to exit):
   `--watch=false --browsers=ChromeHeadless` for Karma. This is already wired in
   the repo's verify config — don't add a watch-mode test invocation.

## Step 2 — Pick the right level for what changed

- **Service (no HTTP):** instantiate via `TestBed.inject(Svc)`, provide mocked
  dependencies. Assert on returned values / emitted observables / signals.
- **Service with HTTP:** `HttpClientTestingModule` + `HttpTestingController`
  (v14–), or `provideHttpClient()` + `provideHttpClientTesting()` (v15+, match
  the app's provider style). `httpMock.expectOne(url)`, flush a response, assert,
  then `httpMock.verify()` in `afterEach`.
- **Component:** `TestBed.configureTestingModule`. For **standalone** components
  put them in `imports`; for NgModule-based, declare them and import the module.
  Set `@Input`s, trigger change detection with `fixture.detectChanges()`, assert
  on rendered output and emitted `@Output`s.
- **Guard / interceptor (functional):** call the function inside
  `TestBed.runInInjectionContext(() => ...)` so `inject()` resolves.
- **Pipe:** pure unit test — `new MyPipe().transform(input)`; no TestBed needed.

## Step 3 — Get the details right

- **Prefer component harnesses** (`@angular/cdk/testing`,
  `HarnessLoader.getHarness`) or `data-testid` queries over brittle CSS/DOM
  drilling.
- **Async:**
  - `fakeAsync` + `tick()` / `flush()` for timers and microtasks — deterministic.
  - `waitForAsync` + `fixture.whenStable()` when you can't fake the clock.
  - Never assert synchronously right after an async trigger without one of these.
- **Signals (v16+):** call the signal to read it (`expect(cmp.total()).toBe(3)`);
  for a `computed`, set its source signals and assert the derived value. Flush an
  `effect` with `TestBed.flushEffects()` (or `fixture.detectChanges()`).
- **RxJS:** for simple cases subscribe and assert the emitted value; for complex
  streams use marble testing (`TestScheduler`) only if the repo already does.
- **Spies:** stub collaborators, then assert the interaction that matters
  (`expect(spy).toHaveBeenCalledWith(...)`) — not every internal call.

## Test behavior, not internals

- Assert on what a consumer observes: rendered DOM, emitted outputs, returned
  values, HTTP requests made — not private fields or call order that doesn't
  matter.
- One meaningful behavior per `it`, named for the behavior.
- Cover the branch you actually changed, plus its obvious failure/edge case.

## Anti-patterns to reject

- A test that passes without exercising your change (asserting a constant, or
  mocking the very method under test).
- Snapshot tests of entire rendered templates as the only coverage — they break
  on unrelated markup and prove little.
- `setTimeout`/real delays in tests instead of `fakeAsync`/`tick`.
- Forgetting `httpMock.verify()`, leaving unmatched requests unasserted.
- Introducing a second test runner or mocking library alongside the existing one.
