# UnsafeContext — Unity project template

The single source of truth for how UnsafeContext Unity projects are structured and styled. Start every new game from this template so the lint, the architecture, the version-control rules, and the Claude Code rules are identical across projects — without copy-pasting them each time.

The git repository wraps the project: the Unity project lives in `unity/`, with documentation, Claude rules, and config at the root.

## Start a new project

1. On GitHub, click **Use this template → Create a new repository**.
2. Clone it. Open the **`unity/`** folder in Unity Hub (Unity 6 / URP), not the repo root.
3. Find-replace the placeholder assembly prefix `Game` with your project name in the `.asmdef` files under `unity/Assets/_Project/Scripts/` (and adjust each `rootNamespace`).
4. Rename the title line in `CLAUDE.md`. Run `git lfs install` once if you haven't.
5. Add the in-house **PrisVas** UI package to `unity/Packages/manifest.json` (it's not on a public registry — see [ARCHITECTURE.md §9](documentation/ARCHITECTURE.md)):

   ```json
   "com.unsafecontext.prisvas": "https://github.com/priscillavasconcelos/prisvas.git?path=/Packages/com.unsafecontext.prisvas#1.0.0"
   ```
6. Done — `.editorconfig`, `.gitignore`, `.gitattributes`, and `CLAUDE.md` are already active.

## Layout

```
.
├── .editorconfig                      # lint + Microsoft naming — at repo root, covers the whole repo
├── .gitignore                         # Unity + tooling ignores (paths scoped to unity/)
├── .gitattributes                     # Git LFS for binary assets; LF for Unity YAML
├── CLAUDE.md                          # Claude Code entry — imports the standards below
├── global-CLAUDE.md.example           # copy to ~/.claude/CLAUDE.md (once per machine)
├── README.md
├── .claude/
│   └── standards/
│       ├── csharp.md                  # universal C# craft (naming, fields, async)
│       └── unity-architecture.md      # archetypes, layers, stack, input, folders, safety
├── documentation/
│   └── ARCHITECTURE.md                # full human reference (renders on GitHub, mermaid)
└── unity/                             # the Unity project (open THIS in Unity Hub)
    └── Assets/_Project/Scripts/
        ├── Core/            Game.Core.asmdef
        ├── Infrastructure/  Game.Infrastructure.asmdef   (refs Core)
        ├── Gameplay/        Game.Gameplay.asmdef          (refs Core, Infrastructure)
        ├── UI/              Game.UI.asmdef                (refs Core, Infrastructure, Gameplay)
        └── Editor/          Game.Editor.asmdef            (Editor-only; refs all)
```

The asmdefs encode the one-way dependency flow `Core → Infrastructure → Gameplay → UI → Editor`. A reference pointing the wrong way will not compile — the architecture is enforced by the compiler, not just by convention.

## How the rules load

- **`.editorconfig`** sits at the repo root (with `root = true`) and covers the whole repository. The IDE finds it by walking up the filesystem from each `.cs` file in `unity/`, so it applies even though the Unity solution lives in the subfolder. It must be a file in the repo — there is no remote version a tool can consult.
- **`CLAUDE.md`** is loaded automatically by Claude Code at the start of every session (run from the repo root, where `.claude/` lives). It pulls in the shared standards through `@` imports, relative to `CLAUDE.md`:

  ```
  @.claude/standards/csharp.md
  @.claude/standards/unity-architecture.md
  ```

  You never tell Claude to "go read" anything — the rules are already in context.
- **`documentation/ARCHITECTURE.md`** is the human reference and renders on GitHub (mermaid included). It's also where the GDD lives. Mirror it into Notion if you like reading conventions next to your design docs — but git is the source, Notion is a copy.

## Version control

- The Unity project is in `unity/`, so the `.gitignore` paths are scoped with the `unity/` prefix (e.g. `unity/[Ll]ibrary/`). `ProjectSettings/` and `Packages/manifest.json` are intentionally **not** ignored — they must be committed.
- **Git LFS** tracks binary assets via `.gitattributes` (textures, audio, models, fonts, PDFs). Run `git lfs install` once per machine. Do **not** also ignore those extensions in `.gitignore` — tracking and ignoring the same file fight each other, and the ignore wins, silently dropping the asset.

## MCP servers (per machine, not in the repo)

Notion and the Unity MCP are tools you want in **every** project, so they're configured once per machine at **user scope** (`~/.claude.json`), not committed as a project `.mcp.json`. A local `.mcp.json` is gitignored as a safety net so machine-specific configs or keys can never be committed.

Configure once per machine (Windows and macOS):

```bash
# Notion — remote HTTP server, OAuth (no key in any file)
claude mcp add --transport http notion --scope user https://mcp.notion.com/mcp
# then run /mcp inside a session to authenticate Notion in the browser

# Unity MCP — depends on which server you run (most are stdio, launched via npx/node,
# connecting to the open Unity Editor). Add it the same way at user scope, e.g.:
# claude mcp add unity --scope user -- npx -y <your-unity-mcp-package>
```

Any server that needs a secret keeps it out of the repo: pass it with `-e KEY=value`, or reference an environment variable as `${KEY}` in a project `.mcp.json` (Claude Code expands it at launch). Verify with `claude mcp list`.

## Global vs project split

Two scopes, both loaded automatically by Claude Code:

- **Project (this repo):** Unity- and game-specific rules — archetypes, the stack, input, folders. Versioned with the project, inherited by every new game through the template.
- **Global (`~/.claude/CLAUDE.md`):** your engine/language-agnostic baseline. Copy the contents of `global-CLAUDE.md.example` into `~/.claude/CLAUDE.md` once per machine. It applies to **every** Claude Code session — including projects that did not come from this template (old repos, quick experiments, Flutter/Kotlin work).

Precedence: a project `CLAUDE.md` overrides the global file on conflict, so the global is your default and each repo overrides only where it must.

Cross-machine (Windows + macOS): keep `~/.claude/` in a small dotfiles repo so both machines share one global baseline instead of drifting.

## Updating conventions

The template repo is the source. Improve a rule here and new projects inherit it. Existing projects keep the rules they shipped with — that is reproducibility, not staleness. To pull an update into an old project, copy the changed file from `.claude/standards/` across. This is rare, not per-project.

## Extending to non-Unity work

Same mechanism. A Flutter or Kotlin project starts from its own template whose `CLAUDE.md` imports a matching standards file (e.g. `dart.md` + `flutter-architecture.md`) instead of the Unity ones. The global baseline and the template flow stay identical.
