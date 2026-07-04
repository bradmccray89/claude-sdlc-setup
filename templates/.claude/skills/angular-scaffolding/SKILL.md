---
name: angular-scaffolding
description: Before adding or moving an Angular component, service, pipe, directive, guard, or module (new or existing project) — use `ng generate` rather than hand-writing the files.
---

# Angular scaffolding

Applies to **new and existing** projects: any time you're about to create an
Angular building block, a generator does it more consistently than hand-writing.

## Default to `ng generate`

`ng g <schematic> <name>` for component, service, directive, pipe, guard,
interceptor, resolver, module. It creates the files **and its spec**, and wires
declarations/imports the way this repo is configured — standalone vs NgModule,
style extension, change-detection default — because it reads `angular.json`
schematics. That's the point: it matches the project automatically, so you don't
guess the conventions.

- `--dry-run` first to preview what it will create/modify.
- Don't pass flags that fight the repo's schematic defaults (e.g. forcing
  `--standalone` in an NgModule app, or vice versa) — let the project's config
  decide unless the user asks otherwise.
- Generate at the right path so it lands in the correct feature folder.

## After generating

Wire the new piece into the feature module / route / standalone `imports`, then
fill in the logic. Generation gives you a correct, empty shell — the task isn't
done until it's connected and covered (see angular-testing for the spec it
created).

## Moving or renaming

`ng g` doesn't move existing files. Either regenerate at the new location and
delete the old, or move by hand — but then update every import, declaration, and
route that referenced it. A half-moved artifact (file relocated, registrations
stale) is worse than not moving it.

## Don't

- Hand-create a component's four files when `ng g component` produces them
  consistently.
- Skip the generated spec to "save time" — you owe a test regardless.
- Override schematic defaults just because a flag exists; match the repo.
