# Backend

The server-side modular monolith. Business capabilities belong in independently owned modules; shared technical concerns remain minimal.

- `src/modules/` — bounded business-capability modules.
- `src/shared/` — stable cross-cutting technical primitives only.
- `src/bootstrap/` — composition root and startup wiring.
- `config/` — non-secret configuration schemas and examples.
- `tests/` — unit, integration, contract, and end-to-end tests.

