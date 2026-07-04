---
name: dotnet-testing
description: Writing or editing a .NET test — xUnit/NUnit, WebApplicationFactory integration tests, EF Core DB strategy, mocking — matched to the repo's frameworks.
---

# .NET testing

The workflow requires one test per task covering exactly what you changed — no
backfills. This skill is how to make that test good in .NET.

## Step 1 — Match the repo's framework and style

1. Find the test project(s) and check the framework: **xUnit** (most common),
   **NUnit**, or **MSTest**. Attributes and lifecycle differ (`[Fact]`/`[Theory]`
   vs `[Test]`/`[TestCase]`). Match it.
2. Check the mocking and assertion libraries already in use — **Moq** vs
   **NSubstitute**, plain `Assert` vs **FluentAssertions** — and follow them.
   Copy a neighboring test's setup. Don't introduce a new library.
3. If no test project exists yet, creating one is part of the task (workflow rule
   3): a single `*.Tests.csproj` referencing the SUT, the runner
   (`Microsoft.NET.Test.Sdk` + xUnit), and one real test. Keep it minimal.

## Step 2 — Pick the right level for what changed

- **Service / business logic:** plain unit test. Construct the class with mocked
  dependencies, exercise the method, assert the result. Use `[Theory]` +
  `[InlineData]` for input variations instead of copy-pasted `[Fact]`s.
- **Controller / minimal API endpoint (integration):**
  `WebApplicationFactory<Program>` gives a real in-memory server + `HttpClient`.
  Hit the route, assert status + deserialized body. For a top-level `Program.cs`,
  expose it with `public partial class Program { }` at the file's end (or
  `[assembly: InternalsVisibleTo]`) so the factory can reference it.
  Override registrations with `WithWebHostBuilder(b => b.ConfigureServices(...))`
  to swap real dependencies (DB, external HTTP) for test doubles.
- **EF Core query/persistence:** see the DB strategy below.

## Step 3 — Get the details right

- **Async:** test methods return `Task` and `await` the call — never `.Result`
  or `.Wait()` in a test either. Pass `CancellationToken.None` (or a real token
  if cancellation is what you're testing).
- **EF Core DB strategy** — pick deliberately:
  - **SQLite in-memory** (`Microsoft.Data.Sqlite`, a kept-open connection) —
    preferred default; it enforces relational constraints and real SQL.
  - **Testcontainers** (real SQL Server/Postgres) when behavior depends on the
    actual database engine.
  - **EF Core InMemory** only for trivial cases — it does **not** enforce
    constraints, unique indexes, or real SQL, so it hides bugs. Don't reach for
    it by default.
  - Give each test a fresh context/database; don't share state across tests.
- **Mocking:** stub collaborators and assert the interaction that matters
  (`mock.Verify(x => x.Save(It.IsAny<Order>()), Times.Once)`), not every call.
  Don't mock types you own and can construct cheaply.
- **Time/randomness:** inject `TimeProvider` (net8+) or an abstraction and feed a
  fixed value — never assert against `DateTime.Now`.

## Test behavior, not internals

- Assert on observable outcomes: return values, thrown exceptions
  (`await Assert.ThrowsAsync<T>`), HTTP status/body, rows persisted — not private
  state.
- Name tests for the behavior (`Method_Condition_ExpectedResult`), one behavior
  per test.
- Cover the branch you actually changed, plus its obvious failure/edge case.

## Anti-patterns to reject

- A tautological test (asserting a mock returns what you told it to, exercising
  no real logic).
- EF Core InMemory used where the change depends on constraints or SQL semantics.
- Blocking on async (`.Result`/`.Wait()`) inside tests.
- Tests sharing a database/context and passing only in a specific order.
- Introducing a second test framework, mocking library, or assertion library
  alongside the existing one.
