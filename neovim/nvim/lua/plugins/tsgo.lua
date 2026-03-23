local disabled_ts_servers = { "denols", "ts_ls", "vtsls" }

local function resolve_tsgo_cmd()
  local tsgo_bin = vim.fn.exepath "tsgo"
  local node_bin = vim.fn.exepath "node"

  if tsgo_bin ~= "" and node_bin ~= "" then return { node_bin, tsgo_bin, "--lsp", "-stdio" } end

  local node_candidates = vim.fn.glob(vim.fn.expand "~/.vite-plus/js_runtime/node/*/bin/node", true, true)
  local tsgo_candidates = vim.fn.glob(
    vim.fn.expand "~/.vite-plus/js_runtime/node/*/lib/node_modules/@typescript/native-preview/bin/tsgo.js",
    true,
    true
  )

  table.sort(node_candidates)
  table.sort(tsgo_candidates)

  local fallback_node = node_candidates[#node_candidates]
  local fallback_tsgo = tsgo_candidates[#tsgo_candidates]
  if fallback_node and fallback_tsgo then return { fallback_node, fallback_tsgo, "--lsp", "-stdio" } end

  if tsgo_bin ~= "" then return { tsgo_bin, "--lsp", "-stdio" } end

  return { "tsgo", "--lsp", "-stdio" }
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = function(_, opts)
      if opts.ensure_installed ~= "all" then
        opts.ensure_installed = require("astrocore").list_insert_unique(
          opts.ensure_installed or {},
          { "javascript", "typescript", "tsx", "jsdoc" }
        )
      end
    end,
  },
  {
    "AstroNvim/astrolsp",
    optional = true,
    init = function()
      if vim.lsp and vim.lsp.enable then vim.lsp.enable(disabled_ts_servers, false) end
    end,
    opts = function(_, opts)
      local lspconfig = require "lspconfig"
      local root_pattern = lspconfig.util.root_pattern("tsconfig.json", "jsconfig.json", "package.json", ".git")

      opts.servers = require("astrocore").list_insert_unique(opts.servers or {}, { "tsgo" })
      opts.handlers = vim.tbl_extend("force", opts.handlers or {}, {
        vtsls = false,
        denols = false,
        ts_ls = false,
      })
      opts.config = vim.tbl_deep_extend("force", opts.config or {}, {
        tsgo = {
          cmd = resolve_tsgo_cmd(),
          filetypes = {
            "javascript",
            "javascriptreact",
            "javascript.jsx",
            "typescript",
            "typescriptreact",
            "typescript.tsx",
          },
          root_dir = function(fname) return root_pattern(fname) or vim.fs.dirname(fname) end,
          single_file_support = true,
        },
      })
    end,
  },
}
