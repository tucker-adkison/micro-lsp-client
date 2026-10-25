# lspClient

lspClient connects micro to a language server that uses the Language Server
Protocol (LSP). The language server sends code completions, and the plugin
shows them in a list below the file.

## Settings

`lsp.server`: a list of `filetype=command` pairs, separated by commas.
`filetype` is the micro file type. `command` is the program that starts the
language server. The program must be on your `PATH`.

Example for C with clangd, in `settings.json`:

```json
{
    "lsp.server": "c=clangd"
}
```

To see the file type of the current file, run `show filetype`.

The plugin reads `lsp.server` when micro starts. Restart micro after you
change it.

The plugin starts one language server for each micro session. Configure one
file type in `lsp.server`.

## Keys

| Key      | Action                                                        |
| -------- | ------------------------------------------------------------- |
| Down     | Move from the file into the completion list                   |
| Up, Down | Select an entry in the completion list                        |
| Enter    | Insert the selected entry                                     |
| Esc      | Close the completion list                                     |
| Tab      | After you insert a function, move to the next parameter       |

At other times, Tab inserts a tab. The plugin binds Tab to
`lua:lspClient.nextParam|InsertTab` when your `bindings.json` has no binding
for Tab.

## Log

1. Start micro with `micro -debug file.c`.
2. Open `log.txt` in the current folder.
3. Search for lines that start with `lsp `.

The line `lsp starting` shows the command that the plugin ran. The other
lines show each message to and from the language server.

## More information

See the README at https://github.com/Tucker-Adkison/micro-lsp-client
