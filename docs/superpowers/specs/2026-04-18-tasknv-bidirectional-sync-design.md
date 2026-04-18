# tasknv.nvim Design Specification

## Project Overview

**Name:** tasknv.nvim
**Type:** Neovim plugin (Lua)
**Core Functionality:** Bidirectional sync between markdown task lists and taskwarrior, using treesitter for parsing and preserving UUID references to track tasks across edits.
**Target Users:** Neovim users who want todo list management backed by taskwarrior.

---

## Architecture

### Components

1. **Parser** — Treesitter-based markdown parsing to extract headings, filters, tasks, and metadata
2. **Sync Engine** — Core logic for reconciling markdown state with taskwarrior state
3. **Task Interface** — Wrapper around taskwarrior CLI (`task add`, `task mod`, `task uuid:<id>`)
4. **Configuration** — User-configurable options for sync behavior
5. **Autocmd Integration** — Trigger sync on file save (configurable)

### Data Flow

```
Markdown File → Treesitter Parse → Task List with Metadata
                                              ↓
                    ┌─────────────────────────┴─────────────────────────┐
                    ↓                                                   ↓
            Query Taskwarrior                                   Push to Taskwarrior
            (filter matches)                                    (create/update)
                    ↓                                                   ↓
                    └─────────────────────────┬─────────────────────────┘
                                              ↓
                              Merge → Updated Markdown with UUIDs
```

---

## Feature Specification

### 1. Filtered Headings (Viewports/Preset Headers)

**Syntax:** `## Heading | filter expression`

- Filter expression uses taskwarrior native syntax (e.g., `project:Home +work due:today`)
- Heading must have a filter to be considered a "sync point" — tasks under headings without filters are ignored
- Filter also acts as defaults for new tasks created under this heading

**Example:**
```markdown
## Work | project:Work +urgent
* [ ] Fix critical bug
* [ ] Review PR

## Home | project:Home
* [ ] Buy groceries
```

### 2. Task Metadata Storage

**Inline (visible):**
- Description
- Due date: `due:2024-01-15`
- Priority: `!!!` (high), `!!` (medium), `!` (low)
- Recurrence: `recur:weekly`

**Hidden (comment-based):**
- UUID: `<!--uuid:abc-123-->`
- Additional attributes: `<!--project:Work +urgent-->`
- Stored inline after task text, hidden via conceal

**Example:**
```markdown
* [ ] Fix critical bug due:2024-01-15 !!! <!--uuid:f47ac11b-58cc-4372-a567-0e02b2c3d479-->
```

### 3. Sync Behavior

**Trigger:** File save (via autocmd, configurable via `sync_on_save`)

**Per-heading sync:**
1. Parse markdown tasks under filtered heading
2. Query taskwarrior for tasks matching filter
3. Merge according to conflict resolution strategy

**Conflict Resolution Strategies:**
- `markdown` — Prefer markdown version (user's file is source of truth)
- `taskwarrior` — Prefer taskwarrior version (CLI is source of truth)
- `newer` — Use whichever was modified more recently
- `ask` — Prompt user per conflict (not implemented in v1)

**Override at call time:** Sync command accepts optional conflict strategy argument.

### 4. Bidirectional Sync Logic

| Scenario | Action |
|----------|--------|
| Markdown task has UUID, matching TW task exists | Update TW task from markdown |
| Markdown task has UUID, no matching TW task | Re-create in TW |
| Markdown task has no UUID | Create new in TW, write UUID comment |
| TW task matches filter, not in markdown | Add task to markdown with UUID |
| TW task matches filter, also in markdown | Handle via conflict resolution |

### 5. Configuration

```lua
require("tasknv").setup({
  sync_on_save = true,           -- Auto-sync on buffer write
  conflict_resolution = "markdown",  -- Default conflict strategy
  default_project = nil,        -- Fallback project if no filter
  metadata = {
    prefix = "<!--",
    suffix = "-->",
    uuid_pattern = "%x%x%x%x%x%x%x%x-%x%x%x%x-%x%x%x%x-%x%x%x%x-%x%x%x%x%x%x%x%x%x%x",
  },
  task_status = {
    [" "] = "pending",
    [">"] = "active",
    ["x"] = "completed",
    ["~"] = "deleted",
  },
  -- Override at call time: :Sync markdown taskwarrior
  -- Per-command override: :Sync markdown
})
```

### 6. Commands

- `:TaskNvSync` — Run sync for current buffer
- `:TaskNvSync markdown` — Force markdown as source of truth
- `:TaskNvSync taskwarrior` — Force taskwarrior as source of truth
- `:TaskNvEnable` — Enable auto-sync for current buffer
- `:TaskNvDisable` — Disable auto-sync for current buffer

### 7. Ignored Tasks

Tasks under headings **without** a filter expression are not synced. This allows mixing taskwarrior-managed tasks with regular notes:

```markdown
## Shopping
* [ ] Milk
* [ ] Eggs

## Personal | project:Personal
* [ ] Call mom
```

`Milk` and `Eggs` are ignored; `Call mom` syncs to `project:Personal`.

---

## Edge Cases

1. **Circular dependencies** — If two headings have overlapping filters, tasks may appear twice. Not handled in v1.

2. **External modifications** — If taskwarrior modified externally between parse and sync, conflict resolution handles it.

3. **Malformed metadata comments** — Silently ignored, task treated as new.

4. **Empty filter** — Heading with `|` but no filter expression is invalid. Skip syncing.

5. **Deleted tasks** — If markdown task is deleted (line removed), v1 does not delete from taskwarrior. Consider adding `orphan_strategy` in future.

---

## Testing Strategy

1. **Unit tests for parser** — Ensure treesitter query captures all task variations
2. **Integration tests for sync** — Real markdown + taskwarrior instance
3. **Mock tests** — For taskwarrior CLI wrapper (if needed)

---

## Future Considerations (Out of Scope for v1)

- Task modification commands in vim (start, stop, annotate)
- Report splits (info, summary)
- Recursive preset headers (inherit filters from parent)
- Grid view integration
- Tagbar integration