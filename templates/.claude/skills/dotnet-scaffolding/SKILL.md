---
name: dotnet-scaffolding
description: Before adding a project, reference, controller, or EF migration (new or existing solution) — use `dotnet new`/`sln`/`add`/`ef` rather than hand-editing csproj/sln.
---

# .NET scaffolding

Applies to **new and existing** solutions: prefer the SDK's commands over
hand-editing `.csproj`/`.sln` XML or hand-writing boilerplate. They target the
right SDK (respecting `global.json`) and keep the solution graph consistent.

## Use the CLI

- **New project or item:** `dotnet new <template>` (`classlib`, `xunit`,
  `webapi`, `console`, `gitignore`, …). Then register and wire it with commands,
  not manual edits:
  - `dotnet sln add <path>` — add the project to the solution.
  - `dotnet add <proj> reference <otherproj>` — project references.
  - `dotnet add <proj> package <name>` — NuGet packages (resolves a compatible
    version for the TFM instead of you guessing).
- **Controllers / API scaffolding:** `dotnet aspnet-codegenerator` in repos set
  up for it; otherwise match how the repo adds endpoints (often just a class).
  Design the surface per dotnet-api-design.
- **EF migrations:** always `dotnet ef migrations add` — never hand-write a
  migration file. Follow the ef-core-migrations skill for the rules.

## After generating

Register the new piece where it belongs — DI container, routing, the test
runner's discovery — and fill in the logic. A generated project that nothing
references, or a class that isn't registered, isn't wired.

## Don't

- Hand-author a `.csproj` or edit `.sln` XML when `dotnet new` / `dotnet sln add`
  does it correctly.
- Hand-write an EF migration or `ModelSnapshot` — scaffold it.
- Pin a package version by hand when `dotnet add package` would resolve one that
  matches the target framework.
