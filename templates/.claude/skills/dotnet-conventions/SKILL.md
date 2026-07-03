---
name: dotnet-conventions
description: Repo-tailored C#/.NET coding standards. Consult before writing or editing C# code so the output matches this repo's TargetFramework (pinned in CLAUDE.md) and avoids the classic async, DI-lifetime, and EF Core mistakes.
---

# .NET conventions

CLAUDE.md pins this repo's TFM — trust it; check the .csproj only if it's
missing. **Match the repo's established style** (controllers vs minimal APIs,
`Startup.cs` vs top-level `Program.cs`) — don't introduce the other mid-task.

## Every version

- Async all the way: never `.Result`/`.Wait()`; no `async void` outside event
  handlers; thread `CancellationToken` through from the entry point.
- DI lifetimes: a singleton must never capture a scoped service (`DbContext`
  is scoped) — the captive-dependency bug.
- EF Core: `AsNoTracking()` on reads; project with `Select` or `Include`
  deliberately (no N+1 in loops); async EF methods on request paths.
- Options pattern (`IOptions<T>`) over scattered `IConfiguration["..."]`;
  `HttpClient` via `IHttpClientFactory`, never `new HttpClient()` per call.
- Honor nullable annotations (no `!` to silence real warnings); `record` for
  DTOs; `ILogger` message templates, not string interpolation; `using`/`await
  using`; never an empty `catch`.

## Version gates (C# ceiling by TFM)

| TFM | May use | Must NOT use |
|---|---|---|
| net6 | minimal hosting/APIs, file-scoped namespaces, global usings, records | `required` members, raw strings, primary ctors, collection expressions |
| net7 | `required` members, raw strings, route groups, `TypedResults` | primary ctors, collection expressions, keyed DI |
| net8 | primary ctors, collection expressions `[..]`, keyed DI, `TimeProvider`, `IExceptionHandler` | `params` collections, `System.Threading.Lock` |
| net9+ | `params` collections, `System.Threading.Lock` | — |

(.NET Framework 4.x: C# 7.3 era — no records, no minimal hosting; match existing code.)

## Reject

- Blocking on async; captive scoped-in-singleton; `new HttpClient()` per request.
- Sync or tracking EF calls on read-only request paths; N+1 loads in loops.
- `IConfiguration["key"]` sprinkled through logic; swallowed exceptions.
- C# syntax above the TFM's ceiling — it won't compile.
