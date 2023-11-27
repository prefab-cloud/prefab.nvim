local attach_func = function() end

local attach = function() attach_func() end

local default_get_input = function(_, req, _, _)
    local input = vim.fn.input(req.title .. ": ", req.defaultValue or "")

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
        local api_key = args.prefab_api_key or os.getenv("PREFAB_API_KEY")
        local api_url = args.prefab_api_url or os.getenv("PREFAB_API_URL")

        if not api_key then
            print("Prefab API key not found. Please set PREFAB_API_KEY.")
            return
        end

        local capabilities = vim.lsp.protocol.make_client_capabilities()

        if not skip_responsiveness_handlers then
            capabilities.workspace.diagnostics = {refreshSupport = true}
            capabilities.workspace.codeLens = {refreshSupport = true}
        end

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
            settings = {
                prefab = {
                    apiKey = api_key,
                    optIn = opt_in,
                    alpha = args.alpha,
                    apiUrl = api_url
                }
            }
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
