---
name: dotnet-upgrade
description: Upgrade a .NET project to a newer target framework, or migrate .NET Framework to modern .NET — bumping the TFM, working through breaking changes, and updating NuGet packages in step. Consult when the user wants to move to a newer .NET, change TargetFramework, or port off .NET Framework; it is a different discipline from writing day-to-day C# code.
---

# .NET upgrade

Two very different jobs share this skill. Identify which one you're doing first,
because the process is not the same:

- **TFM bump** within modern .NET (e.g. `net6.0` → `net8.0`) — incremental, mostly
  a version change plus per-release breaking changes.
- **.NET Framework → modern .NET** (e.g. `net48` → `net8.0`) — a port, not a bump.
  Different tooling, different risk profile. See its own section below.

Read `<TargetFramework>` and `global.json` to see where you're starting.

## Ground rules (both jobs)

- **One major at a time** for TFM bumps — `net6.0` → `net8.0` is
  `6 → 7 → 8` (or at minimum verify against each intervening release's breaking
  changes). Don't leap and hope.
- **Prefer LTS targets** (net6, net8, net10 …) unless the project deliberately
  tracks STS. `dotnet --list-sdks` shows what's installed; the target SDK must be
  present or the build fails.
- **Clean, green tree before starting; commit after each successful step** so a
  regression is easy to bisect.
- Move **NuGet packages in step with the TFM** — Microsoft.* packages
  (EF Core, ASP.NET Core metapackages, extensions) are versioned to the runtime
  and must match the target major.

## TFM bump (modern → modern)

1. Update `<TargetFramework>` (and `global.json` SDK pin, if present) to the next
   major.
2. Bump framework-tied NuGet packages to the matching major (`dotnet-outdated` or
   `dotnet list package --outdated` to find them; watch EF Core, the
   `Microsoft.Extensions.*` and `Microsoft.AspNetCore.*` families).
3. `dotnet restore` then `dotnet build` — read every warning, not just errors.
   The BCL ships **analyzers and obsoletion warnings** that flag removed/changed
   APIs; treat new `SYSLIB`/`CS0618` warnings as the breaking-change checklist.
4. Check the release's "breaking changes" docs for the jump (learn.microsoft.com
   → ".NET N breaking changes") — the authoritative list; don't trust memory.
5. Build, run tests, exercise the app. Commit: `Target net<n-1> -> net<n>`.

## .NET Framework → modern .NET (a port)

This is a migration project, not a build-config change. Do not try to flip
`net48` to `net8.0` in one edit.

- **Assess first** with the **.NET Upgrade Assistant** (`upgrade-assistant analyze`)
  and/or **`try-convert`** — they report incompatible APIs and unportable
  dependencies before you commit to the work.
- **SDK-style project first.** Convert the old `.csproj` to SDK style (Upgrade
  Assistant does this) before changing the TFM — it's a prerequisite and a safe,
  reviewable first commit on its own.
- **Known unportable areas:** `System.Web` (WebForms/old MVC has no modern
  equivalent — it's a rewrite to ASP.NET Core, not a port), WCF server (use
  CoreWCF or gRPC), AppDomains, remoting, `app.config`/`web.config` → the
  configuration + options model, `HttpContext.Current` → injected `IHttpContextAccessor`.
- **Watch Windows-only dependencies** (`System.Drawing.Common`, registry, COM) —
  they may need the `-windows` TFM or a replacement package.
- Port incrementally where possible (class libraries to `netstandard2.0`/modern
  first, so both old and new can reference them), and keep each step green.

## After the upgrade

- Run the project's verification gate; done only when green (see verify-before-done).
- **Update the pinned .NET facts** — the "Stack facts" line in `CLAUDE.md` (the C#
  version ceiling) still names the old TFM. Bring it to the new target so
  day-to-day work and the dotnet-conventions skill allow the right language
  features.
- Record user-visible changes (config format, hosting, dropped endpoints) via
  update-docs.

## Don't

- Jump multiple TFM majors in one step and skip the intervening breaking changes.
- Bump the TFM but leave framework-tied NuGet packages behind (or vice versa).
- Treat a `net48 → net8.0` port as a config change — assess with the tooling first.
- Silence `SYSLIB`/obsoletion warnings to get a green build instead of addressing
  the API change they point at.
- Bundle the SDK-style conversion, the TFM bump, and feature work into one commit.
