# Unity architecture standards (UnsafeContext)

Applies to Unity game projects. Pairs with `csharp.md`. Full rationale: `docs/ARCHITECTURE.md`.

## Stack

Unity 6 / URP. DI: VContainer · UI: MVVM with R3 + PrisVas · Async: UniTask · Tween: DOTween · Messaging: MessagePipe · Content: ScriptableObjects · Input: New Input System only.

## Layers (depend downward only)

`UI → Gameplay → Data`. Gameplay never references UI — it emits events/messages, UI listens. PrisVas stays in UI only.

## Archetype first — name it before writing the class

- **Model** — state/data (POCO) or ScriptableObject (content).
- **ViewModel** — UI only. Adapts a model to one screen via R3. No `Tick`/physics/AI.
- **View** — humble `MonoBehaviour` for **UI**. Renders + forwards input. No decisions.
- **Actor** — humble `MonoBehaviour` for **gameplay** (the View-equivalent in the game world). Binds to a Controller, applies position/animation. No decisions.
- **Controller** — one gameplay actor's logic. Plain C#, testable. State machine, `Tick`, emits events. **Never** named `ViewModel`.
- **System** — rules across many entities. Ticked by the loop.
- **Coordinator** — orchestrates one scene/mode; owns the per-frame tick of its actors; applies cross-actor effects.
- **Service / Provider** — injectable capability behind an interface.
- Never write a `Manager`. Resolve it to Controller / System / Coordinator / Service.

Pairings: UI = `View` + `ViewModel`. Gameplay = `Actor` + `Controller`.

## DI (no Service Locator)

- No singletons / `static Instance` / `FindObjectOfType` / `GameObject.Find` for wiring. Inject via VContainer (constructor injection default; method injection for `MonoBehaviour`s).
- No Service Locator — including injecting the resolver and calling `Resolve<T>()` in business logic. Touch the container only at the composition root and in factories.
- Runtime creation goes through injected factory interfaces.

## Async

- UniTask, not `Task`/`Coroutine`, for logic flows. `CancellationToken` always (`GetCancellationTokenOnDestroy` for `MonoBehaviour`s).

## Input

- New Input System only. Never `Input.GetKey` / `Input.GetAxis` / `UnityEngine.Input`. Controllers read intents, never devices.

## Fail loud, not silent

- `Debug.LogError` on broken invariants, with locating context — never a silent `return`.
- `LogError` = invariant violated · `LogWarning` = recoverable-but-suspicious · `Log` = trace behind a verbosity flag.
- Throw on a null required dependency at construction. `default`/`null`/`0` on an error path is not error handling — log it.

## Hard rules

- No gameplay logic in a View or Actor. No rendering in a Controller.
- A Coordinator/System ticks the simulation — never a View or Actor.
- No `public` fields.
- Data-drive variation (one `Enemy` + `EnemyData`); do not subclass per content type.
- Dispose R3 subscriptions with their scope (`AddTo` / `CancellationToken`).

## Folders & assemblies

Per-feature, layered inside. One-way asmdef flow: `Core → Infrastructure → Gameplay → UI → Editor`. Namespace mirrors path: `UnsafeContext.<Project>.<Layer>.<Feature>`. Gameplay feature folders split into `Data/`, `Controllers/`, `Actors/`, `Systems/`, plus the `<Feature>Coordinator`.

## Unity edit safety

- Scene/prefab changes: use MCP directly when available; otherwise generate a self-deleting Editor script under a `Tools` menu. Do not hand-edit `.unity` / `.prefab` files (GUID fragility).
