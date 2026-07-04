---
name: ef-core-migrations
description: Creating, reviewing, applying, or reverting EF Core migrations — after changing an entity/DbContext, or before running dotnet ef. Prevents data loss and broken history.
---

# EF Core migrations

A migration is shared, ordered, and eventually run against a real database.
Getting one wrong corrupts history or destroys data for everyone. This is the
one .NET area where the encoded rules matter more than moving fast — the repo's
CLAUDE.md says don't touch migrations unasked; this is how to do it when you are.

## The golden rule

**Never edit or delete a migration that has been applied anywhere shared**
(merged, deployed, or run on a teammate's/CI's database). Its identity is fixed
in those databases' `__EFMigrationsHistory`. To change already-shipped schema,
add a NEW migration. Only a migration that exists solely on your uncommitted
local branch is safe to remove/regenerate. (The protected-paths hook asks you to
confirm before editing anything under `Migrations/` — treat that prompt as the
reminder to check whether the migration has already shipped.)

## Creating a migration

1. Change the entity classes / `DbContext` / configurations first.
2. Build — a migration is scaffolded from the compiled model, so it must compile.
3. `dotnet ef migrations add <DescriptiveName>` (add `--project`/`--startup-project`
   and `--context` when the solution has multiple).
4. **Read the generated `Up` and `Down` before doing anything else.** The
   scaffold is a guess. Verify it matches your intent and isn't destructive by
   surprise:
   - A rename usually scaffolds as **Drop column + Add column = data loss**.
     Replace it with `migrationBuilder.RenameColumn(...)` to preserve data.
   - Column type/nullability changes on a populated table may need a data
     backfill step or a default; a bare `AlterColumn` can fail or truncate.
   - Confirm `Down` actually reverses `Up` (you'll need it to roll back).
5. Keep the paired snapshot (`*ModelSnapshot.cs`) — it's regenerated with the
   migration and must be committed **together**. A migration without its matching
   snapshot update breaks the next `add`.

## Applying / reverting

- Apply: `dotnet ef database update` (or `<MigrationName>` to go to a specific
  point). In apps that call `Database.Migrate()` at startup, applying happens on
  boot — know which model the project uses.
- Revert (local/dev only): `dotnet ef database update <PreviousMigration>` runs
  the `Down`, then `dotnet ef migrations remove` deletes the last migration
  **if it hasn't been applied elsewhere**. Never "revert" a shipped migration by
  deleting the file — write a new forward migration.
- **Generate a SQL script for anything production-bound:**
  `dotnet ef migrations script <from> <to> --idempotent` and have it reviewed.
  Don't run `database update` directly against production.

## Data-loss and safety

- EF prints "An operation was scaffolded that may result in the loss of data" for
  a reason — stop and read it, don't just proceed.
- Splitting a destructive change into two deploys (add new, backfill, then later
  drop old) is often safer than one migration that drops as it goes.
- Seeding via `HasData` is part of the migration and is diffed like schema —
  changing seed data generates schema migrations; use it only for static
  reference data.

## Troubleshooting

- "Model changed since last migration" / pending changes → you edited entities
  without scaffolding; run `migrations add`.
- Two branches each added a migration → they'll have divergent snapshots. Don't
  hand-merge the snapshot; remove one branch's migration, re-add it on top of the
  other so the chain is linear.
- Prefer fixing a bad **unshipped** migration by `migrations remove`, adjusting
  the model, and re-adding — over hand-editing the scaffold.

## Done means

- The `Up`/`Down` were read and are correct (no accidental data loss).
- Migration + `ModelSnapshot` committed together, and `dotnet ef database update`
  applied cleanly against a dev database.
- The verify gate is green (see verify-before-done). Note schema/endpoint changes
  via update-docs.

## Don't

- Edit or delete a migration that's been merged/deployed — add a new one.
- Commit a migration without its `ModelSnapshot` change.
- Accept a scaffolded rename as drop+add when it would lose data.
- Run `database update` straight at production instead of a reviewed
  `--idempotent` script.
