# C# craft standards (UnsafeContext)

Universal C# rules — apply to every C# project regardless of engine. Unity-specific rules live in `unity-architecture.md`.

## Naming (Microsoft C#)

- `PascalCase`: types, methods, properties, constants, public members.
- `_camelCase`: private instance fields · `s_camelCase`: private statics · `camelCase`: locals, parameters.
- Interfaces `I`-prefixed · type parameters `T`-prefixed · async methods end in `Async` · booleans `Is`/`Has`/`Can` · events `On` + verb.

Reference: <https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/identifier-names>, which adopts the .NET Runtime team's coding style — including the `_` prefix for private instance fields and `s_` for private statics. The `.editorconfig` enforces the enforceable parts.

## Fields & files

- No `public` fields; expose via property if it must be public.
- `readonly` for fields set only in the constructor; `const` for compile-time constants, `static readonly` for runtime ones.
- One type per file; file name matches type name.
- Allman braces. File-scoped namespaces in new files.

## Async hygiene

- Always thread a `CancellationToken`; cancel work that outlives its owner.
- No `async void` except top-level event handlers that cannot be changed.
- Never swallow exceptions (no empty `catch`); log with context and either handle meaningfully or rethrow.
