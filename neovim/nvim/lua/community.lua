-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
local spec = {
  "AstroNvim/astrocommunity",

  -- Language packs
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.tailwindcss" },
  { import = "astrocommunity.pack.terraform" },
  { import = "astrocommunity.pack.python.base" },
  { import = "astrocommunity.pack.python.ruff" },
  { import = "astrocommunity.pack.zig" },
  { import = "astrocommunity.pack.yaml" },
  { import = "astrocommunity.pack.toml" },
  { import = "astrocommunity.pack.markdown" },
  { import = "astrocommunity.pack.bash" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.rust" },

  -- UI stuff
  { import = "astrocommunity.indent.indent-rainbowline" },
  { import = "astrocommunity.project.linear-nvim" },
  { import = "astrocommunity.markdown-and-latex.peek-nvim" },

  -- Editing stuff
  { import = "astrocommunity.editing-support.multiple-cursors-nvim" },

  -- AI stuff
  { import = "astrocommunity.completion.supermaven-nvim" },

  -- Misc
}

return spec
