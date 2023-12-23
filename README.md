# nvim-stacktrace
A UI companion to [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) enabling highlighting and navigating java stack traces.

Tested on version `NVIM v0.9.1`.

### Installation
Install with any plugin manager alongside [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) and
[nvim-dap](https://github.com/mfussenegger/nvim-dap).

Eg packer.
```
use "mfussenegger/nvim-dap"
use "rcarriga/nvim-dap-ui"
use "dorin-suletea/nvim-stacktrace.nvim"
```

### Configuration
```
require("nvim-stacktrace").setup()
```

### Advanced configuration
```
require("nvim-stacktrace").setup({
    win_picker_blacklist = { 
        "dap%-repl", 
        "dap%-terminal", 
        "DAP Stacks"
    },                       -- when jumping to source never consider these buffer names as candidates
    highlight_group = "Tag", -- highlighting for jumpable locations. Check ":hi" for default groups.
    jump_key = "<CR>",       -- key for jumping to source. 
})
```

### Usage
The plugin parsers `dap-repl` or `dap-terminal` whenever the contents of said buffer change
and highlights paths in your current workspace that are not gitignored.

Pressing the `jump_key` on any highlighted buffer will jump to its source.

If multiple buffers can be used to open the source code you will be promoted to select which buffer to use. 
candidates for this can be blacklisted via `win_picker_blacklist`


