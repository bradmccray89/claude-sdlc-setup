---
name: dotnet-api-design
description: Creating or changing an HTTP API surface — controller, endpoint, DTO, or error shape. Covers status codes, ProblemDetails, DTO separation, validation, versioning, and contract-safety.
---

# .NET API design

Applies to **new and existing** endpoints. General C# style — controllers vs
minimal APIs, async, DTO records — is owned by dotnet-conventions; this skill is
the API-surface layer on top. The rules split by whether you're adding surface or
changing surface others already depend on.

## Every endpoint

- **Typed results:** `ActionResult<T>` / `Results<Ok<T>, NotFound, …>` /
  `TypedResults` — not bare objects or `IActionResult` with untyped returns.
- **Right status codes:** 200 read, 201 + `Location` on create, 204 no-content,
  400 validation, 401/403 auth, 404 missing, 409 conflict, 422 unprocessable.
- **DTOs at the boundary, never entities.** Accept and return dedicated `record`
  DTOs; exposing EF entities leaks the schema, invites over-posting, and
  serializes lazy-loaded graphs. Map in one place.
- **Validate** with DataAnnotations or FluentValidation; return 400 with the
  errors, don't let bad input reach the domain.
- **Errors as `ProblemDetails`** (RFC 7807) so every failure has one shape.
- Async + `CancellationToken` threaded through (see dotnet-conventions).
- Resource-noun routes (`/orders/{id}`), plural collections, no verbs in paths.
- Paginate collections — never return an unbounded list.

## Creating an endpoint

Wire it into the repo's existing routing/controller registration, apply the
project's auth policy, and give it a DTO in and a DTO out even if they mirror the
entity today — the indirection is what lets the model and the contract move
independently later.

## Changing an existing endpoint (the contract is a promise)

- **Additive and non-breaking by default:** add *optional/nullable* fields; never
  repurpose, rename, or change the type/meaning of a field consumers already read.
- **Don't** remove a field, tighten request validation, or change a status-code's
  meaning without versioning — those break live clients silently.
- **If a breaking change is unavoidable, version it** (URL `/v2/…` or a version
  header per the repo's convention) and keep the old version per policy.
- Widen what you accept, keep stable what you return.
- Change the DTO, not the entity, and update the mapping — don't "fix" it by
  exposing a new entity field straight through.

## Don't

- Return or bind EF entities directly.
- Put business logic in the controller/endpoint (it belongs in a service).
- Invent a bespoke error shape when `ProblemDetails` exists.
- Break an existing contract in place instead of versioning.
