# Agent Guide

## Scope and principles

This is a production-oriented furniture e-commerce platform built as a **modular monolith**. Prefer clear ownership, explicit contracts, secure defaults, and incremental change over premature distribution or abstraction.

Do not add application code, dependencies, or deployment resources unless the task explicitly requires them. Preserve existing user changes and avoid unrelated edits.

## Architecture rules

- Organize backend business logic by bounded capability under `backend/src/modules/` (for example: catalog, inventory, pricing, cart, checkout, orders, payments, customers, identity, shipping, and content).
- Each module owns its domain model, use cases, persistence details, tests, and public interface. Other modules may use only public interfaces or published domain events—never private files or tables.
- `backend/src/shared/` is for stable cross-cutting technical capabilities, never business logic. `backend/src/bootstrap/` wires dependencies and transports but contains no business rules.
- Frontend domain behavior belongs in `frontend/src/modules/`; `frontend/src/components/` stays presentation-focused and module-independent.
- Maintain one deployable backend until a demonstrated operational need justifies a service extraction. Every mutable record has one authoritative owning module.

## Coding standards

- Follow `.editorconfig`: UTF-8, LF endings, two-space indentation, and final newlines.
- Favor small, cohesive, readable units with explicit inputs, outputs, errors, and side effects.
- Validate external input at boundaries; authorize protected actions; use parameterized data access; never log secrets or sensitive payment data.
- Store configuration in environment variables or approved secret stores. Commit only non-secret examples.
- Add or update tests with behavior changes. Use unit tests for domain rules and integration/contract tests for module boundaries.
- Update `docs/` and add an ADR when changing module boundaries, data ownership, public APIs, security posture, or operations.

## Naming conventions

- Use lowercase `kebab-case` for directories, documentation, and configuration files unless a tool requires another format.
- Name modules for business capabilities, not technical layers; use clear, intention-revealing names and avoid unexplained abbreviations.
- Use `camelCase` for public API fields unless the selected protocol specifies otherwise; version externally consumed APIs explicitly.
- Name ADRs `NNNN-short-decision-title.md`, for example `0001-modular-monolith.md`.
- Name branches `type/short-description`, with type one of `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, or `infra`.

## Git workflow

- Work in short-lived branches from the current integration branch; keep commits focused and reversible.
- Use Conventional Commit-style messages: `type(scope): imperative summary`.
- Before committing, run relevant formatting, static analysis, tests, and security checks.
- Never commit generated dependency directories, credentials, keys, local environment files, or infrastructure state.
- Pull requests must describe the problem, solution, module impact, tests, documentation updates, security/operational considerations, and rollback plan when applicable.
- Do not rewrite shared history, force-push protected branches, or mix unrelated formatting with functional changes.

## Instructions for future agents

1. Read this file and the nearest applicable README before editing.
2. Inspect repository state first and preserve unrelated changes in a dirty worktree.
3. State assumptions and ask for direction when a meaningful product, security, data, or deployment decision is missing.
4. Make the smallest coherent change within the owning module; do not bypass module boundaries for convenience.
5. Use existing tooling and conventions. Do not introduce frameworks, dependencies, services, or external integrations without explicit need and approval.
6. Verify changes in proportion to risk; report verification and remaining limitations.
7. Update relevant README files, tests, and documentation in the same change when behavior, ownership, APIs, or operations change.

