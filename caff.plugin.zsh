# Smart caffeinate wrapper for Zsh / Oh My Zsh
# Features:
#   - Shorthand flags: d / i / s / u (e.g. "disu" -> -d -i -s -u)
#   - Human durations: 2h, 30m, etc.
#   - Presets: short (15m), medium (1h), long (3h), overnight/night (8h)
#   - Optional command: args after "--" are run under caffeinate
#   - Interactive countdown (when duration known, no command)
#   - Spinner (when duration unknown, no command)
#   - Ctrl+C stops both the UI and caffeinate
#   - Start / finish notifications
#   - Quiet mode
#   - Exit code propagation
#   - Built-in help: caff --help / caff help

_caff_help() {
  cat <<'EOF'
caff - smart wrapper around macOS caffeinate

Usage:
  caff [options] [disu|flags...] [duration] [-- command ...]

Examples:
  caff disu 2h
  caff di short
  caff dis medium -- brew upgrade
  caff -q disu 30m -- long-running-command

Flag shorthand:
  d        -> -d  (prevent display sleep)
  i        -> -i  (prevent idle sleep)
  s        -> -s  (prevent system sleep)
  u        -> -u  (declare user is active)
  "disu"   -> -d -i -s -u

Durations:
  t=3600   -> -t 3600 (manual seconds)
  2h       -> 2 hours
  30m      -> 30 minutes

Presets:
  short    -> 15 minutes
  medium   -> 1 hour
  long     -> 3 hours
  night,
  overnight-> 8 hours

Meta options:
  -q, --quiet, quiet   Run without UI and without start/finish messages
  -h, --help, help     Show this help

Behavior:
  - If a duration is known and no command is given: shows a countdown bar
  - If no duration is known and no command is given: shows a spinner
  - If a command is given: no UI (only start/finish messages)
  - Ctrl+C interrupts both the UI and caffeinate (exit code 130)
  - When a command is passed after "--", its exit code is propagated
EOF
}

# Countdown progress bar when a duration is known (no command mode)
_caff_timer() {
  setopt localoptions localtraps
  unsetopt xtrace verbose

  # mute stderr inside this helper (hides xtrace noise)
  local __caff_stderr
  exec {__caff_stderr}>&2 2>/dev/null

  local total=$1
  local caf_pid=$2
  local elapsed=0
  local width=20

  (( total <= 0 )) && {
    exec 2>&$__caff_stderr {__caff_stderr}>&-
    return 0
  }

  local stop=0
  trap 'stop=1' INT

  while (( elapsed <= total && ! stop )); do
    if ! kill -0 "$caf_pid" 2>/dev/null; then
      break
    fi

    local remaining=$(( total - elapsed ))
    (( remaining < 0 )) && remaining=0

    local filled=$(( total > 0 ? elapsed * width / total : width ))
    local mins=$(( remaining / 60 ))
    local secs=$(( remaining % 60 ))

    # single-line progress bar
    printf "\r\033[K[caff] ["
    printf '%*s' "$filled" '' | tr ' ' '#'
    printf '%*s' "$(( width - filled ))" '' | tr ' ' '.'
    printf "] %02d:%02d remaining" "$mins" "$secs"

    sleep 1
    (( elapsed++ ))
  done

  trap - INT
  exec 2>&$__caff_stderr {__caff_stderr}>&-

  if (( stop )); then
    printf "\r\033[K[caff] interrupted by user.          \n"
    return 1
  fi

  printf "\r\033[K[caff] [####################] 00:00 done        \n"
  return 0
}

# Spinner when duration is unknown (no command mode)
_caff_spinner() {
  setopt localoptions localtraps
  unsetopt xtrace verbose

  # mute stderr inside this helper (hides xtrace noise)
  local __caff_stderr
  exec {__caff_stderr}>&2 2>/dev/null

  local caf_pid=$1
  local frames=(- \\ \| /)
  local i=0
  local n=${#frames[@]}
  local stop=0

  trap 'stop=1' INT

  while (( ! stop )); do
    if ! kill -0 "$caf_pid" 2>/dev/null; then
      break
    fi
    printf "\r\033[K[caff] %s running..." "${frames[i]}"
    (( i=(i+1)%n ))
    sleep 0.2
  done

  trap - INT
  exec 2>&$__caff_stderr {__caff_stderr}>&-

  if (( stop )); then
    printf "\r\033[K[caff] interrupted by user.          \n"
    return 1
  fi

  return 0
}

caff() {
  setopt localoptions nomonitor
  unsetopt xtrace verbose

  local pre_args=()
  local cmd_args=()
  local saw_sep=0
  local arg

  # Split arguments into:
  # - pre_args: before "--"
  # - cmd_args: after "--" (command to run under caffeinate)
  for arg in "$@"; do
    if (( ! saw_sep )) && [[ $arg == "--" ]]; then
      saw_sep=1
      continue
    fi
    if (( ! saw_sep )); then
      pre_args+=("$arg")
    else
      cmd_args+=("$arg")
    fi
  done

  local flags=()
  local duration=""
  local word
  local quiet=0
  local show_help=0

  for word in "${pre_args[@]}"; do
    local handled=0

    # 0) Meta options (help / quiet)
    case "$word" in
      -h|--help|help)
        show_help=1
        handled=1
        ;;
      -q|--quiet|quiet)
        quiet=1
        handled=1
        ;;
    esac
    (( handled )) && continue

    # 1) Packed flag sets like: d / di / disu (only characters d, i, s, u)
    if [[ "$word" != *[!disu]* && -n "$word" ]]; then
      [[ "$word" == *d* ]] && flags+=(-d)
      [[ "$word" == *i* ]] && flags+=(-i)
      [[ "$word" == *s* ]] && flags+=(-s)
      [[ "$word" == *u* ]] && flags+=(-u)
      handled=1
    fi

    # 2) Manual duration: t=3600
    if (( ! handled )) && [[ "$word" == t=* ]]; then
      duration="${word#t=}"
      handled=1
    fi

    # 3) Human duration: 2h / 30m
    if (( ! handled )) && [[ "$word" == <->h || "$word" == <->m ]]; then
      local num unit
      unit="${word[-1]}"
      num="${word%?}"
      if [[ "$unit" == "h" ]]; then
        duration=$(( num * 3600 ))
      else
        duration=$(( num * 60 ))
      fi
      handled=1
    fi

    # 4) English presets
    if (( ! handled )); then
      case "$word" in
        short)
          duration=900      # 15 minutes
          handled=1
          ;;
        medium)
          duration=3600     # 1 hour
          handled=1
          ;;
        long)
          duration=10800    # 3 hours
          handled=1
          ;;
        overnight|night)
          duration=28800    # 8 hours
          handled=1
          ;;
      esac
    fi

    # 5) Anything not handled is passed directly to caffeinate
    if (( ! handled )); then
      flags+=("$word")
    fi
  done

  # Help mode: just show help and return
  if (( show_help )); then
    _caff_help
    return 0
  fi

  # If we have a duration, translate it to -t <seconds>
  if [[ -n "$duration" ]]; then
    flags+=(-t "$duration")
  fi

  # Compute a human label for the duration (for notifications)
  local duration_label="infinite"
  if [[ -n "$duration" ]]; then
    local d=$duration
    if (( d % 3600 == 0 )); then
      duration_label="$(( d / 3600 ))h"
    elif (( d % 60 == 0 )); then
      duration_label="$(( d / 60 ))m"
    else
      duration_label="${d}s"
    fi
  fi

  # Is there a command?
  local has_cmd=0
  (( ${#cmd_args[@]} > 0 )) && has_cmd=1

  # Start notification (if not quiet)
  if (( ! quiet )); then
    local cmd_str="(no command)"
    if (( has_cmd )); then
      cmd_str="${(j: :)cmd_args}"
    fi
    printf "[caff] starting: duration=%s, flags: %s, command: %s\n" \
      "$duration_label" "${flags[*]:-<none>}" "$cmd_str"
  fi

  local ret ui_status=0

  # UI / execution logic:
  # - quiet OR has_cmd: run caffeinate in foreground (no UI)
  # - else: run caffeinate in background + progress UI
  if (( quiet || has_cmd )); then
    if (( has_cmd )); then
      caffeinate "${flags[@]}" "${cmd_args[@]}"
    else
      caffeinate "${flags[@]}"
    fi
    ret=$?
  else
    local caf_pid
    caffeinate "${flags[@]}" &
    caf_pid=$!

    if [[ -n "$duration" ]]; then
      _caff_timer "$duration" "$caf_pid"
      ui_status=$?
    else
      _caff_spinner "$caf_pid"
      ui_status=$?
    fi

    if (( ui_status != 0 )); then
      kill "$caf_pid" 2>/dev/null
      wait "$caf_pid" 2>/dev/null
      printf "[caff] interrupted, caffeinate stopped.\n"
      return 130
    fi

    wait "$caf_pid"
    ret=$?
  fi

  if (( ! quiet )); then
    printf "[caff] finished with status %d.\n" "$ret"
  fi

  return $ret
}

# Short alias
alias cf="caff"
