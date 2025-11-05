-- lua/plugins.lua

return {
  -- Theme
  {
    "folke/tokyonight.nvim",
    lazy = false, -- make sure the colorscheme is loaded first
    priority = 1000, -- make sure to load this before all the other start plugins
    opts = {
      transparent = true, -- Enable this to disable background color
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme "tokyonight"
    end,
  },

  -- File Explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({})
      -- Example keymap to toggle nvim-tree
      vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', {
        noremap = true,
        silent = true,
      })
    end,
  },

  -- Status Line
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup({
        options = {
          theme = 'tokyonight'
        }
      })
    end,
  },

  -- Fuzzy Finder
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.5', -- or latest stable
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
    end,
  },

  -- Syntax Highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = "VeryLazy",
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = { "lua", "vim", "vimdoc", "bash", "python", "javascript", "typescript", "json", "yaml", "markdown" },
        sync_install = false,
        auto_install = false,
        highlight = {
          enable = true,
        },
      })
    end,
  },

  -- LSP and Autocompletion
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      -- NOTE: mason-lspconfig is removed as it was causing crashes
      'hrsh7th/nvim-cmp',
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
    },
    config = function()
      local cmp = require('cmp')
      cmp.setup({
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'buffer' },
          { name = 'path' },
        }),
        mapping = cmp.mapping.preset.insert({
          ['<C-p>'] = cmp.mapping.select_prev_item(),
          ['<C-n>'] = cmp.mapping.select_next_item(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
          ['<C-Space>'] = cmp.mapping.complete(),
        }),
      })

      local on_attach = function(client, bufnr)
        local opts = { buffer = bufnr, silent = true }
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
        vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
      end

      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      local lspconfig = require('lspconfig')

      local servers = { "lua_ls", "cssls", "html", "ts_ls", "pyright", "bashls" }

      require('mason').setup({})

      for _, server_name in ipairs(servers) do
        lspconfig[server_name].setup({
          on_attach = on_attach,
          capabilities = capabilities,
        })
      end
    end,
  },

  -- Git integration
  {
    'lewis6991/gitsigns.nvim',
    config = function()
      require('gitsigns').setup()
    end,
  },

  -- Commenting
  {
    'numToStr/Comment.nvim',
    config = function()
      require('Comment').setup()
    end,
  },
}