# tasknv.nvim

A [taskwarrior] assistant for NeoVim, heavily inspired by [tjabej/taskwiki].

### Compatability

- [x] taskwarrior 3.x
- [ ] taskwarrior 2.7 (untested)


## Usage

### Commands

| Command | Description | Notes   |
| ------- | ----------- | ------- |
| Item1.1 | Item2.1     | Item3.1 |

### Keymaps

### Misc

I recommend using the [render-markdown] extension in combination with tasknv, which will hide metadata by default unless editing that line, keeping your files nice and clean looking (for the most part).

## Installation

Use your favourite package manager.

### [lazy.nvim]()

```lua
return {
    "Pete-hamlin/tasknv.nvim"
    ft = "markdown",
    opts = {},
}
```

### Default Config

See [here](./lua/tasknv/config.lua) for full config options:

```lua
{

}
```



## Alternatives

## Acknowledgements

- [tbabej/taskwiki]
- [m_taskwarrior_d]
- [ThePrimeagen/refactoring.nvim]()
