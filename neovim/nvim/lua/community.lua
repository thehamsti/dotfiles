-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

local has_tree_sitter = vim.fn.executable("tree-sitter") == 1

---@type LazySpec
local spec = {
  "AstroNvim/astrocommunity",

  -- Language packs
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.typescript-all-in-one" },
  { import = "astrocommunity.pack.tailwindcss" },
  { import = "astrocommunity.pack.terraform" },
  { import = "astrocommunity.pack.python-ruff" },
  { import = "astrocommunity.pack.zig" },
  { import = "astrocommunity.pack.yaml" },
  { import = "astrocommunity.pack.toml" },
  { import = "astrocommunity.pack.markdown" },
  { import = "astrocommunity.pack.bash" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.rust" },
  { import = "astrocommunity.pack.go" },
  { import = "astrocommunity.pack.docker" },

  -- UI stuff
  { import = "astrocommunity.indent.indent-rainbowline" },
  { import = "astrocommunity.project.linear-nvim" },
  { import = "astrocommunity.markdown-and-latex.peek-nvim" },

  -- Editing stuff
  { import = "astrocommunity.editing-support.multiple-cursors-nvim" },
  { import = "astrocommunity.editing-support.refactoring-nvim" },

  -- AI stuff
  { import = "astrocommunity.completion.supermaven-nvim" },

  -- Misc
  { import = "astrocommunity.game.leetcode-nvim" },
  { import = "astrocommunity.media.codesnap-nvim" },
  { import = "astrocommunity.workflow.precognition-nvim" },
}

if has_tree_sitter then
  table.insert(spec, 8, { import = "astrocommunity.pack.swift" })
end

return spec
