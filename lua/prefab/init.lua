local attach_func = function() end

local attach = function() attach_func() end

-- This function lets us get synchronous input from the user while still
-- using any custom ui they've configured for vim.ui.input.
--
-- Since vim.ui.input is asynchronous, we have to use a timer to wait for
-- the user to enter something or cancel.
--
-- You may override this with the get_input_func option in `setup` but your
-- function must be synchronous.
local default_get_input = function(_, req, _, _)
    -- we look at this rather than nil because the user may have canceled
    -- and rather than an empty string because the user may have typed
    -- an empty string
    local NO_VALUE = "-~<THERE_IS_NO_VALUE>~-"
    local input = NO_VALUE
    local timeout = 10

    vim.ui.input({prompt = req.title .. ": "}, function(str) input = str end)

    -- wait until the user has entered something or canceled
    local timer = vim.uv.new_timer()
    timer:start(timeout, timeout,
                function() if input ~= NO_VALUE then timer:close() end end)

    return {input = input, params = req.params}
end

local setup = function(args)
    args = args or {}

    local opt_in = args.opt_in or {}
    local on_attach = args.on_attach or function(client, bufnr) end
    local file_pattern = args.file_pattern or {
        "*.js", "*.jsx", "*.ts", "*.tsx", "*.mjs", "*.cjs", "*.rb", "*.java",
        "*.erb", "*.py", "*.yml", "*.yaml"
    }

    local skip_responsiveness_handlers =
        args.skip_responsiveness_handlers or false

    vim.lsp.handlers["$/prefab.getInput"] =
        args.get_input_func or default_get_input

    attach_func = function()
        local api_key = os.getenv("PREFAB_API_KEY") or args.prefab_api_key

        if not api_key then
            print("Prefab API key not found. Please set PREFAB_API_KEY.")
            return
        end

        local capabilities = vim.lsp.protocol.make_client_capabilities()

        vim.lsp.start {
            name = "Prefab Language Server",
            cmd = args.cmd or {"prefab-ls", "--stdio"},
            capabilities = capabilities,
            on_attach = function(client, bufnr)
                if not skip_responsiveness_handlers then
                    if client.supports_method("textDocument/codeLens") then
                        vim.api.nvim_create_autocmd({
                            'BufEnter', 'BufWritePre', 'CursorHold'
                        }, {
                            buffer = bufnr,

                            callback = function()
                                vim.lsp.codelens.refresh()
                            end
                        })
                    end
                end

                on_attach(client, bufnr)
            end,
            init_options = {customHandlers = {"$/prefab.getInput"}},
            settings = {prefab = {apiKey = api_key, optIn = opt_in}}
        }
    end

    vim.api.nvim_create_autocmd({'BufEnter', 'BufWinEnter'}, {
        pattern = file_pattern,
        callback = function() attach_func() end
    })

    if not skip_responsiveness_handlers then
        local orig_codelens_refresh =
            vim.lsp.handlers["workspace/codeLens/refresh"] or
                function() return {} end
        vim.lsp.handlers["workspace/codeLens/refresh"] =
            function(err, result, ctx, config)
                vim.lsp.codelens.refresh()
                return orig_codelens_refresh(err, result, ctx, config)
            end

        local orig_diagnostic_refresh =
            vim.lsp.handlers["workspace/diagnostic/refresh"] or
                function() return {} end
        vim.lsp.handlers["workspace/diagnostic/refresh"] =
            function(err, result, ctx, config)
                vim.diagnostic.reset()
                return orig_diagnostic_refresh(err, result, ctx, config)
            end

        local orig_inlay_refresh =
            vim.lsp.handlers["workspace/inlayHint/refresh"] or
                function() return {} end
        vim.lsp.handlers["workspace/inlayHint/refresh"] =
            function(err, result, ctx, config)
                local client_id = ctx.client_id

                -- iterate over the attached buffers and toggle inlay hints to refresh them
                for _, bufnr in
                    pairs(vim.lsp.get_buffers_by_client_id(client_id)) do

                    -- We call this two different ways since the api changed
                    -- https://github.com/neovim/neovim/commit/448907f65d6709fa234d8366053e33311a01bdb9
                    pcall(function()
                        vim.lsp.inlay_hint.enable(bufnr, false)
                        vim.lsp.inlay_hint.enable(bufnr, true)
                    end)

                    pcall(function()
                        vim.lsp.inlay_hint(bufnr, false)
                        vim.lsp.inlay_hint(bufnr, true)
                    end)
                end

                return orig_inlay_refresh(err, result, ctx, config)
            end
    end
end

return {setup = setup, attach = attach}
