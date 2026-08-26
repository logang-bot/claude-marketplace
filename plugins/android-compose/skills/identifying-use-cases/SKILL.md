---
name: identifying-use-cases
description: When deciding whether a piece of logic in a ViewModel or Repository belongs in a UseCase instead
paths: "**/*.kt"
---

In this project we follow clean architecture. Use cases live in `domain/usecase/` and are the only place where business logic should be orchestrated.

## Create a use case when the logic…

1. **Coordinates more than one repository** — if you touch two or more repositories to complete a single action, it belongs in a use case (e.g., `RecordSaleUseCase` writes a `Sale` and updates `Product` stock).

2. **Enforces a domain rule** — any rule that belongs to the business, not the UI (e.g., "a sale cannot have quantity ≤ 0", "a custom product is auto-created if it doesn't exist yet").

3. **Would be duplicated across ViewModels** — if two screens need the same logic, extract it into a use case rather than copying it.

4. **Has side effects beyond a single write** — actions that trigger cascading changes (create + update, delete + restock, etc.) need a use case to keep ViewModels thin.

5. **Performs domain-level calculations** — profit margin, stock thresholds, totals that are business concepts, not display formatting.

## Do NOT create a use case when…

- The operation is a plain CRUD pass-through with no logic (a ViewModel can call the repository directly).
- The logic is purely presentational (formatting currency, sorting a list for display) — that belongs in the ViewModel or UI layer.
- There is only one repository call and no rule to enforce.

## Naming convention

`<Verb><Noun>UseCase` — verb describes the action, noun describes the domain concept.
Examples: `RecordSaleUseCase`, `GetSalesHistoryUseCase`, `RestockProductUseCase`.

## Implementation pattern

```kotlin
class MyUseCase @Inject constructor(
    private val fooRepository: FooRepository,
    private val barRepository: BarRepository
) {
    suspend operator fun invoke(...) {
        // orchestration and domain rules here
    }
}
```

ViewModels inject and call the use case; they never hold repository references for logic that qualifies under the rules above.
