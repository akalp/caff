# caff – Smart `caffeinate` Wrapper for Zsh / Oh My Zsh

`caff` is a tiny but featureful wrapper around macOS `caffeinate` with:

* Shorthand sleep flags via `disu` syntax (`d`/`i`/`s`/`u`)
* Human-friendly durations like `2h`, `30m`
* Named presets: `short`, `medium`, `long`, `night`/`overnight`
* Optional command execution via `-- command ...`
* Interactive countdown bar or spinner
* Start/finish messages and proper exit-code propagation
* Quiet mode for scripts

It’s designed for Zsh and works great with Oh My Zsh.


## Features

* **Shorthand flags** – Use `d`, `i`, `s`, `u` (e.g. `disu` → `-d -i -s -u`).
* **Human durations** – `2h`, `30m`, `45m`, etc. are converted to seconds.
* **Presets** – Semantic time aliases:

  * `short` → 15 minutes
  * `medium` → 1 hour
  * `long` → 3 hours
  * `night`, `overnight` → 8 hours
* **Command mode** – Anything after `--` runs *under* `caffeinate`.
* **Interactive UI** (when no command given):

  * Known duration → countdown progress bar
  * Unknown duration → spinner
* **Ctrl+C handling** – Cleanly stops both UI and `caffeinate`.
* **Notifications** – Start/finish messages with duration and flags.
* **Quiet mode** – No UI and no messages (for scripting).
* **Exit code propagation** – When wrapping a command, `caff` returns that command’s exit status.
* **Built-in help** – `caff --help` or `caff help`.


## Installation

### Oh My Zsh (recommended)

1. **Clone or copy** the plugin into your custom plugins directory, e.g.:

```bash
mkdir -p "$ZSH_CUSTOM/plugins/caff"
cp caff.plugin.zsh "$ZSH_CUSTOM/plugins/caff/caff.plugin.zsh"
```

2. **Enable the plugin** in your `~/.zshrc`:

```zsh
plugins=(
  # other plugins...
  caff
)
```

3. **Reload Zsh**:

```zsh
source ~/.zshrc
```

You now have the `caff` function and the short alias `cf` available.

### Plain Zsh (without Oh My Zsh)

1. Place the script somewhere in your config, e.g. `~/.zsh/caff.zsh`.
2. Source it from your `~/.zshrc`:

```zsh
source ~/.zsh/caff.zsh
```

3. Restart your shell or run `source ~/.zshrc`.


## Usage

Basic syntax:

```text
caff [options] [disu|flags...] [duration] [-- command ...]
```

### Examples

```zsh
# Keep display, idle, system, and user activity awake for 2 hours
caff disu 2h

# Prevent display + idle sleep for a short preset (15 minutes)
caff di short

# Keep everything awake for 1 hour while running a command
caff dis medium -- brew upgrade

# Quiet mode (no UI, no start/finish messages) for 30 minutes
caff -q disu 30m -- long-running-command

# Infinite caffeinate with spinner UI until Ctrl+C
caff disu

# Built-in help
caff --help
```


## Flag shorthand (`disu` syntax)

Instead of spelling out `-d -i -s -u`, you can use packed letters:

* `d` → `-d` (prevent **display** sleep)
* `i` → `-i` (prevent **idle** sleep)
* `s` → `-s` (prevent **system** sleep)
* `u` → `-u` (declare user is active)

Any combination is allowed as long as it’s only these letters, for example:

* `d` → `-d`
* `di` → `-d -i`
* `dis` → `-d -i -s`
* `disu` → `-d -i -s -u`

These expand into the corresponding `caffeinate` flags under the hood.


## Durations

`caff` understands multiple ways to specify how long to stay awake.

### Human durations

* `2h` → 2 hours
* `30m` → 30 minutes
* `90m` → 90 minutes

These are converted to seconds and passed as `-t <seconds>` to `caffeinate`.

### Manual seconds

You can also specify the `caffeinate -t` value directly:

* `t=3600` → `-t 3600` (1 hour)

### Presets

Named presets are shortcuts for common durations:

* `short` → 15 minutes
* `medium` → 1 hour
* `long` → 3 hours
* `night`, `overnight` → 8 hours

These also resolve to `-t <seconds>` internally.

If no duration is provided, `caffeinate` runs without `-t` (i.e. until interrupted).


## Meta options

Special options handled by `caff` itself:

* `-q`, `--quiet`, `quiet` – Run without UI and without start/finish messages.
* `-h`, `--help`, `help` – Show the built-in help text.

These can be combined with other arguments:

```zsh
caff -q disu 1h -- ./server
caff help
```


## Behavior & UI

`caff` behaves differently depending on whether a command and/or duration is provided.

### With a command

If you pass `-- command ...`:

* `caffeinate` wraps your command.
* No interactive UI is shown.
* Start and finish messages are printed (unless `--quiet`).
* The *command’s* exit code is propagated as `caff`’s exit code.

Example:

```zsh
# `caff` exits with the same status as `pytest`
caff disu 2h -- pytest
```

### Without a command

If you don’t pass any command after `--` (or don’t use `--` at all):

* `caffeinate` is started on its own.
* If a duration is known (`2h`, `short`, etc.), a **countdown bar** is shown.
* If no duration is known, a **spinner** is shown.
* Pressing **Ctrl+C** stops both the UI and `caffeinate` and returns exit code `130`.

Example:

```zsh
# Countdown bar for 45 minutes
caff disu 45m

# Spinner until you manually stop it
caff disu
```

### Quiet mode

With `-q`/`--quiet`/`quiet`:

* No UI is shown (even if no command is provided).
* No start or finish messages.
* Intended for scripts, CI, or when you don’t want extra noise.

Example:

```zsh
caff --quiet disu long -- ./build.sh
```


## Notifications and exit status

* On start, `caff` prints a line like:

  ```text
  [caff] starting: duration=2h, flags: -d -i -s -u, command: brew upgrade
  ```

* On finish, it prints:

  ```text
  [caff] finished with status 0.
  ```

* If you interrupt via Ctrl+C in UI mode, it prints:

  ```text
  [caff] interrupted, caffeinate stopped.
  ```

  and exits with status `130`.

* When a command is executed, its exit code is returned by `caff` (so your scripts can check success/failure as usual).


## Alias

The plugin also defines a short alias:

```zsh
alias cf="caff"
```

So all examples above work with `cf` as well:

```zsh
cf disu medium -- yarn test
cf short
```


## Requirements & Limitations

* **macOS only** – Uses the `caffeinate` command provided by macOS.
* **Zsh** – Written for Zsh (tested with Oh My Zsh, but works in plain Zsh).
* Should work fine in both interactive terminals and inside tmux.


## Troubleshooting

* If `caff` is not found, ensure the plugin is loaded and your shell session is restarted:

  * Oh My Zsh: is `caff` in your `plugins=(...)` list?
  * Plain Zsh: did you `source` the script in `~/.zshrc`?
* If the UI looks garbled, make sure your terminal supports ANSI escape sequences and your `$TERM` is set correctly (e.g. `xterm-256color`).
* Use `--quiet` if you’re running `caff` in scripts where interactive output is not desired.


## License

MIT
