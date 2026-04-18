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

**Hidden (comment-based):**
- UUID: `<!--uuid:abc-123-->`
- Priority: `<!--priority:H-->` (taskwarrior UDA, defaults mapped to L/M/H)
- Recurrence: `<!--recur:weekly-->`
- Additional attributes: `<!--project:Work +work +urgent-->`
- Stored inline after task text, hidden via conceal

**Example:**
```markdown
* [ ] Fix critical bug due:2024-01-15 <!--uuid:f47ac11b-58cc-4372-a567-0e02b2c3d479-->
```

**Priority syntax:** Users write `!!!`, `!!`, `!` in markdown. The plugin maps these to taskwarrior priority values via config (see Configuration). The actual priority UDA value is stored in hidden metadata.

### 3. Sync Behavior

**Trigger:** File save (via autocmd, configurable via `sync_on_save`)

**Auto-sync Debounce:**
- When `sync_on_save` is enabled, a debounce timer delays execution
- If another save occurs within the debounce window, timer resets
- Default debounce: 500ms (configurable)
- This prevents spamming taskwarrior on rapid saves

**Async Execution:**
- All taskwarrior operations run asynchronously in the background
- Buffer remains fully interactive during sync — user can edit/view while sync runs
- User can trigger multiple syncs (subsequent syncs replace previous)
- No blocking of the main thread

**Visual Feedback (Virtual Text - Task List Lock):**
- While sync is in progress, the task list is replaced with virtual text:
  - Processing state: "Syncing... (0/X tasks)"
  - Progress updates: "Syncing... (3/10 tasks)"
- This prevents user edits to the task list that would be lost when the list is re-rendered
- User can still edit other parts of the file (other headings, unrelated content)
- On completion, virtual text is removed and processed task list is rendered

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
  -- Auto-sync on buffer write (runs asynchronously, does not block)
  sync_on_save = true,

  -- Debounce delay (in ms) for auto-sync. Prevents spamming taskwarrior on rapid saves.
  -- If another save occurs within this window, timer resets.
  sync_debounce_ms = 500,

  -- Default conflict strategy when markdown and taskwarrior differ.
  -- Options: "markdown" | "taskwarrior" | "newer" | "ask"
  -- Can be overridden at call time via :TaskNvSync markdown
  conflict_resolution = "markdown",

  -- Default project to use when no filter is specified on a heading.
  -- If nil, tasks without a filter will not sync.
  default_project = nil,

  -- Mapping of markdown priority syntax to taskwarrior priority UDA values.
  -- Users write !!!/!!/! in markdown, these map to TW's priority values.
  -- Can have any number of mappings (e.g., "!!!!" for critical, or custom UDA values)
  priority = {
    ["!!!"] = "H",  -- High priority
    ["!!"] = "M",   -- Medium priority
    ["!"] = "L",    -- Low priority
  },

  -- Tag syntax mapping. Users write +tag in markdown, maps to taskwarrior tags.
  -- Key is the markdown syntax (what user types), value is taskwarrior tag.
  tags = {
    ["+work"] = "work",
    ["+home"] = "home",
    -- Can be empty table {} if no mapping needed (use raw markdown syntax)
  },

  -- Task status mapping from markdown checkboxes to taskwarrior status
  task_status = {
    [" "] = "pending",   -- Unchecked [ ]
    [">"] = "active",    -- Started [>]
    ["x"] = "completed", -- Checked [x]
    ["~"] = "deleted",  -- Deleted [~]
  },

  -- Metadata comment configuration for storing UUIDs and extra attributes
  metadata = {
    -- Prefix/suffix for hidden metadata comments
    prefix = "<!--",
    suffix = "-->",
    -- UUID format pattern (UUID v4)
    uuid_pattern = "%x%x%x%x%x%x%x%x-%x%x%x%x-%x%x%x%x-%x%x%x%x-%x%x%x%x%x%x%x%x%x%x",
  },
})
```

### 6. Commands

Users can create their own keymaps using the Lua API:

```lua
-- Run sync with default conflict resolution (from config)
vim.keymap.set("n", "<leader>ms", require("tasknv").sync)

-- Run sync, force markdown as source of truth
vim.keymap.set("n", "<leader>mm", function()
  require("tasknv").sync({ conflict_resolution = "markdown" })
end)

-- Run sync, force taskwarrior as source of truth
vim.keymap.set("n", "<leader>mt", function()
  require("tasknv").sync({ conflict_resolution = "taskwarrior" })
end)
```

**Lua API:**
- `require("tasknv").sync(opts)` — Run sync for current buffer (async, returns immediately)
  - `opts.conflict_resolution` — Override default conflict strategy ("markdown" | "taskwarrior" | "newer")
  - `opts.bufnr` — Specific buffer to sync (defaults to current)
  - Returns: `{ sync_id: number }` — ID of this sync operation (replaces any in-progress sync for same buffer)

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