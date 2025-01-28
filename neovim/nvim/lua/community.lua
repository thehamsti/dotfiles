-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",

  -- Language packs
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.typescript-all-in-one" },
  { import = "astrocommunity.pack.tailwindcss" },
  { import = "astrocommunity.pack.terraform" },
  { import = "astrocommunity.pack.python-ruff" },
  { import = "astrocommunity.pack.swift" },
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
  { import = "astrocommunity.editing-support.refactoring-nvim" },

  -- AI stuff
  { import = "astrocommunity.completion.supermaven-nvim" },
  -- {
  --   import = "astrocommunity.completion.avante-nvim",
  --   opts = {
  --     provider = "ollama",
  --     vendors = {
  --       ollama = {
  --         __inherited_from = "openai",
  --         api_key_name = "",
  --         endpoint = "http://127.0.0.1:11434/v1",
  --         model = "deepseek-r1:14b",
  --       },
  --     },
  --   },
  -- },

  -- Misc
  { import = "astrocommunity.game.leetcode-nvim" },
  { import = "astrocommunity.media.codesnap-nvim" },
  { import = "astrocommunity.workflow.precognition-nvim" },
  -- import/override with your plugins folder
}
