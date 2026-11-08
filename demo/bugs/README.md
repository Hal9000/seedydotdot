# Tidex demo bug fixtures

The normal SeedyDotDot branch is intentionally correct and its full test suite
passes. Each patch in this directory introduces one narrowly scoped regression
to demonstrate Tidex presenting a single test failure for inspection.

Apply and inspect one fixture at a time:

```sh
git apply demo/bugs/conditional-exit.patch
mix test --only demo_conditional_exit
git apply -R demo/bugs/conditional-exit.patch
```

Fixtures:

| Fixture | Alleged behavior | Test selector |
| --- | --- | --- |
| `conditional-exit` | The ruby unlocks a conditional exit. | `demo_conditional_exit` |
| `once-event` | The Runtime Exception occurs only once. | `demo_once_event` |
| `inventory-location` | Taken objects leave their former room. | `demo_inventory_location` |
| `dynamic-text` | Prose reflects facts changed by an action. | `demo_dynamic_text` |
| `validation` | Invalid action effects are rejected while loading a world. | `demo_validation` |

Each patch is reversible with `git apply -R`. Do not combine them: the point is
to show one focused failure at a time.
