---
name: identifying-use-cases
description: When deciding whether a piece of logic in a ViewModel or Repository belongs in a UseCase instead
paths: "**/*.kt"
---

A use case holds business logic orchestrated in one place, independent of any screen. Put them
wherever this project already keeps them — find an existing `*UseCase.kt`, and match its package
and style before adding a new one.

## Create a use case when the logic…

1. **Coordinates more than one repository** — if you touch two or more repositories to complete a
   single action, it belongs in a use case (see `RefreshClienteDataUseCase` below).

2. **Enforces a domain rule** — any rule that belongs to the business, not the UI. "A payment can
   never exceed what is still owed" is a domain rule; greying out the button is not.

3. **Would be duplicated across ViewModels** — if two screens need the same logic, extract it into
   a use case rather than copying it.

4. **Has side effects beyond a single write** — actions that trigger cascading changes, where one
   fact recorded forces another to be recalculated and stored with it.

5. **Performs domain-level calculations** — thresholds, states, and totals that are business
   concepts rather than display formatting.

## Do NOT create a use case when…

- The operation is a plain CRUD pass-through with no logic (a ViewModel can call the repository
  directly).
- The logic is purely presentational (formatting currency, sorting a list for display) — that
  belongs in the ViewModel or UI layer.
- There is only one repository call and no rule to enforce.

## Naming convention

`<Verb><Noun>UseCase` — verb describes the action, noun describes the domain concept.

## What they look like

These are real use cases from a project using these conventions. Read them for shape, not for
domain — yours will name different things.

**Two repositories coordinated** (rule 1). The whole use case exists because these two must
refresh together:

```kotlin
/**
 * Refreshes clientes and pedidos in parallel. Both are business data and must stay in sync —
 * client status is computed from their unpaid pedidos. Returns true only if both succeed.
 */
class RefreshClienteDataUseCase @Inject constructor(
    private val clienteRepository: ClienteRepository,
    private val pedidoRepository: PedidoRepository,
) {
    suspend operator fun invoke(): Boolean = coroutineScope {
        val clientes = async { clienteRepository.refresh() }
        val pedidos  = async { pedidoRepository.refresh() }
        clientes.await() && pedidos.await()
    }
}
```

**A domain rule plus a cascading write** (rules 2 and 4). Recording a payment caps it at what is
owed and moves the order's status as a consequence — two facts that must be written together, so
neither the screen nor the repository decides them alone:

```kotlin
class RegistrarPagoUseCase @Inject constructor(
    private val pedidoRepository: PedidoRepository,
) {
    suspend operator fun invoke(pedido: Pedido, amount: Double) {
        val newPaid = (pedido.paid + amount).coerceAtMost(pedido.total)
        val newStatus = if (newPaid >= pedido.total) PedidoStatus.PAID else PedidoStatus.PARTIAL
        val pago = Pago(
            id = UUID.randomUUID().toString(),
            pedidoId = pedido.id,
            amount = amount,
            paidAt = System.currentTimeMillis(),
        )
        pedidoRepository.registrarPago(pago, newPaid, newStatus)
    }
}
```

**A domain calculation with no repository at all** (rule 5). A use case does not have to touch
storage to be one — this takes data in and returns a domain verdict:

```kotlin
class CalcularEstadoClienteUseCase @Inject constructor() {

    operator fun invoke(
        pedidos: List<Pedido>,
        umbrales: Umbrales,
        now: Long = System.currentTimeMillis(),
    ): ClientStatus {
        val enMora = pedidos.filter { it.countsTowardStatus }
        val statusBalance = enMora.sumOf { it.pending }
        if (statusBalance <= 0.0) return ClientStatus.AL_DIA
        val hasOldUnpaid = enMora.any { isOlderThan(it.createdAt, umbrales.diasMaximos, now) }
        val isCritical = hasOldUnpaid || statusBalance > umbrales.montoMaximo
        return if (isCritical) ClientStatus.CRITICO else ClientStatus.ADVERTENCIA
    }

    private val Pedido.countsTowardStatus: Boolean
        get() = status == PedidoStatus.PARTIAL && !isSaldoExtra

    private fun isOlderThan(createdAt: Long, days: Int, now: Long): Boolean =
        (now - createdAt) > days.toLong() * 24 * 60 * 60 * 1000
}
```

Note how the private helpers keep `invoke` readable, and how nothing in it needs a comment —
the same function-size and no-explanatory-comments rules the `general-code-style` plugin applies
everywhere else. `now` carries a default so tests can pin the clock; the name says that, so no
`@param` is written for it.

The DI annotation depends on the project's framework — these use Hilt's `@Inject constructor`.
Match whatever the existing use cases in the project already use.

ViewModels inject and call the use case; they never hold repository references for logic that
qualifies under the rules above.
