# lspClient

lspClient connects micro to a language server that uses the Language Server
Protocol (LSP). The language server sends code completions and the problems
that it finds in the file. The plugin shows the completions in a list below
the file and marks the problems in the file.

## Settings

`lsp.server`: a list of `filetype=command` pairs, separated by commas.
`filetype` is the micro file type. `command` is the program that starts the
language server. The program must be on your `PATH`.

Example with three file types, in `settings.json`:

```json
{
    "lsp.server": "c=clangd,c++=clangd,lua=lua-language-server"
}
```

To see the file type of the current file, run `show filetype`.

The plugin starts a language server when you open the first file of its file
type. File types with the same command use one language server. In this
example, C and C++ files use one clangd.

The plugin reads `lsp.server` when micro starts. Restart micro after you
change it.

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

Some language servers send an `#include` or `import` line with a completion.
When you insert the entry, the plugin also inserts that line.

## Errors and warnings

The language server checks the file while you type. The gutter shows `>>` on
each line with a problem, and the part with the problem is underlined. When
the cursor is on the line, the bottom bar shows the message.

To show the number of errors and warnings in the status line, add
`$(lspClient.diagnostics)` to `statusformatl`. Example, with the default of
micro 2.0.15:

```json
{
    "statusformatl": "$(filename) $(modified)$(overwrite)($(line),$(col)) $(status.paste)$(lspClient.diagnostics) | ft:$(opt:filetype) | $(opt:fileformat) | $(opt:encoding)"
}
```

The status line then shows, for example, `E2 W1` for 2 errors and 1 warning.

micro's `linter` plugin also checks some file types when you save, for
example C with `gcc`. Then each problem can show two times. To stop the C
linter, call `linter.removeLinter("gcc")` in `postinit` in
`~/.config/micro/init.lua`. See the README for more information.

## Log

1. Start micro with `micro -debug file.c`.
2. Open `log.txt` in the current folder.
3. Search for lines that start with `lsp `.

Each line starts with `lsp` and the command of the language server, for
example `lsp clangd`. The line `lsp clangd starting` shows the arguments that
the plugin used. The other lines show each message to and from the language
server. If a language server stops, the log shows `lsp clangd exited`.

## More information

See the README at https://github.com/Tucker-Adkison/micro-lsp-client
