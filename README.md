[![codecov](https://codecov.io/github/Tucker-Adkison/micro-lsp-client/graph/badge.svg?token=MAU1JJAOKG)](https://codecov.io/github/Tucker-Adkison/micro-lsp-client)

# lspClient: an LSP client for micro

lspClient is a plugin for the [micro text editor](https://micro-editor.github.io/). It connects micro to a language server that uses the [Language Server Protocol](https://microsoft.github.io/language-server-protocol/) (LSP). The language server sends code completions, and the plugin shows them in a list below the file.

## Features

- A completion list that opens while you type. Each entry shows the name and, if the language server sends it, the type.
- Parameter stops for functions. After you insert a function, Tab moves the cursor to the next parameter.
- Document sync. The plugin tells the language server when you open, change, save, and close each file.
- A correct startup. The plugin waits for the reply to `initialize` before it sends other messages to the language server.
- More than one language server. Each file type can use a different language server, and the language servers run at the same time.

## Limits

- The plugin shows completions only. Diagnostics, hover text, and go to definition are not available.
- The plugin talks to the language server through standard input and output. Some language servers need an argument to use standard input and output, for example `--stdio`. `lsp.server` cannot hold arguments, so these language servers do not start. See [Settings](#settings) for the arguments that the plugin adds.
- Development and testing use macOS and micro 2.0.15.

## Requirements

- micro 2.0.0 or later.
- A language server on your `PATH` for each file type that you configure. Install the language server with the package manager of your system or of the language.

## Installation

lspClient is not in the official micro plugin channel. Add the `repo.json` file of this repository as a plugin source. Then install the plugin.

1. Open `~/.config/micro/settings.json`.
2. Add this plugin source:

   ```json
   "pluginrepos": ["https://raw.githubusercontent.com/Tucker-Adkison/micro-lsp-client/main/repo.json"]
   ```

3. Install the plugin:

   ```bash
   micro -plugin install lspClient
   ```

To install from Git, clone the repository into a folder with the name `lspClient`. The plugin loads its files from that folder.

```bash
git clone https://github.com/Tucker-Adkison/micro-lsp-client ~/.config/micro/plug/lspClient
```

If you use a different micro configuration folder, replace `~/.config/micro` with that folder.

## Settings

Set `lsp.server` in `settings.json`. The value is a list of `filetype=command` pairs, separated by commas.

```json
{
  "lsp.server": "filetype=command"
}
```

- `filetype` is the micro file type. To see the file type of the current file, run `show filetype` in the micro command bar (Ctrl-e).
- `command` is the program that starts the language server. The program must be on your `PATH`.

Examples of language servers that use standard input and output when they start without arguments:

| File type | Setting |
| --- | --- |
| C | `c=clangd` |
| Go | `go=gopls` |
| Lua | `lua=lua-language-server` |
| Python | `python=pylsp` |
| Rust | `rust=rust-analyzer` |

To use more than one language server, separate the pairs with commas:

```json
{
  "lsp.server": "c=clangd,c++=clangd,lua=lua-language-server"
}
```

The plugin starts a language server when you open the first file of its file type. File types with the same command use one language server. In this example, C and C++ files use one clangd.

The plugin reads `lsp.server` when micro starts. Restart micro after you change it.

The plugin adds arguments for some language servers:

| Command | Arguments that the plugin adds |
| --- | --- |
| `clangd` | `--completion-parse=always` |
| `gopls` | `-logfile=auto -debug=:0 -remote.debug=:0 -rpc.trace` |
| `jdtls` | `-data` and the working folder |

## Usage

1. Open a file of a configured file type. The plugin starts the language server.
2. Type in the file. The completion list opens below the file.
3. Press Down to move into the completion list.
4. Press Up or Down to select an entry.
5. Press Enter to insert the entry.
6. If the entry is a function with parameters, press Tab to move to the next parameter.

| Key | Action |
| --- | --- |
| Down | Move from the file into the completion list |
| Up, Down | Select an entry in the completion list |
| Enter | Insert the selected entry |
| Esc | Close the completion list |
| Tab | After you insert a function, move to the next parameter. At other times, insert a tab. |

The plugin binds Tab to `lua:lspClient.nextParam|InsertTab` when your `bindings.json` has no binding for Tab. This binding replaces the default Tab actions of micro, `Autocomplete` and `IndentSelection`.

## Known problems

- Down also moves the cursor in the file down by one line.
- When you close a split, the plugin sends `shutdown` to the language server of that file. The plugin sends it even when other files of that language server are open. Some language servers continue to send completions after this message. Other language servers stop.
- If a language server stops, the plugin does not start it again. Restart micro.

## Troubleshooting

### The language server does not start

1. Make sure that the command is on your `PATH`. Run `which` and the command, for example `which gopls`.
2. Make sure that `lsp.server` uses the micro file type and the format `filetype=command`.
3. Start micro with `micro -debug file.c`. micro writes `log.txt` in the current folder.
4. Search the log for the lines of the plugin with `grep "lsp " log.txt`.

Each line starts with `lsp` and the command of the language server, for example `lsp clangd`. The line `lsp clangd starting` shows the arguments that the plugin used. The other lines show each message to and from the language server. To see the lines of one language server, search for its command, for example `grep "lsp clangd" log.txt`.

If a language server stops, the log shows a line such as `lsp clangd exited`.

### The first completions are empty

Many language servers read the project after they start. Until the language server has read the project, it can send an empty completion list. Wait one or two seconds, then type again.

### Completions do not include symbols from other files of the project

Some language servers need a project file to find the other files and their dependencies. Examples are `compile_commands.json` for clangd, `go.mod` for gopls, and `Cargo.toml` for rust-analyzer. The plugin uses the folder where you started micro as the project folder. Start micro in the folder that contains the project file.

## Development

| File | Content |
| --- | --- |
| `main.lua` | The micro callbacks for open, typing, save, close, and keys. One client for each language server. The completion list. |
| `lsp.lua` | The LSP messages: `initialize`, document sync, and completion. The server state and the message queue. |
| `server.lua` | The language server process. It reads messages, matches replies to requests, and answers requests from the server. |
| `completion.lua` | The completion entries, the text that the plugin inserts, and the parameter stops. |
| `utils.lua` | Arguments for each language server, the `initialize` parameters, the file text, and the list of open files. |
| `json.lua` | The JSON encoder and decoder from [rxi/json.lua](https://github.com/rxi/json.lua). |

The tests in `tests/` use [busted](https://lunarmodules.github.io/busted/):

```bash
luarocks install busted
busted tests
```

GitHub Actions runs the tests for each push and pull request.

To release a version, add an entry for it to `Versions` in `repo.json`. Use the URL `https://github.com/Tucker-Adkison/micro-lsp-client/archive/<version>.zip`. When you push this change to `main` and the tests pass, GitHub Actions creates the tag and the GitHub release for the newest version in `repo.json`. If that tag exists already, GitHub Actions does not create a release.

## Contributing

1. Fork the repository.
2. Create a feature branch.
3. Make your changes and run `busted tests`.
4. Open a pull request.

## License

MIT License. See the LICENSE file.

## Author

Tucker Adkison

## Acknowledgments

- The [micro text editor](https://micro-editor.github.io/) community
- The [Language Server Protocol](https://microsoft.github.io/language-server-protocol/) specification
