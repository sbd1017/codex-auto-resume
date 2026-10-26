# codex-auto-resume

Resumes an unfinished **Codex Desktop** task (the Codex side of the ChatGPT app on macOS) after
your usage limit resets, so a long task carries on without you watching the clock.

You **arm** one Codex thread. A small background helper watches it, and if its latest turn ends
with a usage-limit error, it waits for the limit to reset and sends a continuation message into
that thread. Codex then picks up where it stopped. It stops by itself when the task is done, when
you disarm it, or after a safety cap of resumes.

```console
$ codex-auto-resume threads
$ codex-auto-resume arm                  # the most recent thread (or give an id, id prefix or exact name)
$ codex-auto-resume status
$ codex-auto-resume check                # dry run: what it would decide right now (sends nothing)
$ codex-auto-resume disarm
```

## How it works

Everything goes through Codex's own local interfaces; there's no UI automation.

- **Reading state:** a short-lived private `codex app-server` (JSON-RPC over stdio) is asked for
  the thread, its turns, any thread goal, and your account's rate limits.
- **Spotting the limit:** a usage limit is recognised from the structured turn error
  (`codexErrorInfo == usageLimitExceeded`), or from a thread goal in status `usageLimited`.
- **Resuming:** it runs `codex queue --thread <id> --message <prompt>`. That is Codex's own
  per-thread message queue, drained by whichever Codex process owns the thread, normally the
  desktop app. For goal threads it also flips the goal back to `active`, so Codex's own goal loop
  continues.
- **Loading the thread:** if the thread isn't loaded anywhere, `open -g codex://threads/<id>` asks
  the desktop app to load it first.

Only one thread can be armed at a time. Nothing is ever sent unless the armed thread's latest turn
ended with a usage-limit error, or you run `resume-now` yourself.

**When it resumes:** it waits for the reset time Codex reports, plus a 90-second grace. If no
reset time is known, or a resume hits the limit again, it backs off: 10, 20, 40, 60, then 120
minutes.

**Checking it worked:** after queueing, it watches for the continuation to start, and tries again
if it doesn't within 4 minutes.

**Keeping the Mac awake:** it prevents idle sleep while the armed task is working. While waiting
for a reset it does the same, but only on mains power and only if the reset is less than 6 hours
away.

**Notifications:** macOS notifications tell you when the limit is reached, when the task resumes, and when it finishes or stops.

## Install

Needs macOS with the ChatGPT app (Codex Desktop) and `/usr/bin/python3` (run
`xcode-select --install` if it's missing). No other dependencies.

```sh
git clone https://github.com/sbd1017/codex-auto-resume.git
cd codex-auto-resume
./install.sh
```

`install.sh` puts the script in `~/Library/Application Support/CodexAutoResume/bin/` and loads a
launchd agent (`local.codex-auto-resume`) that runs its background loop. It also links a
`codex-auto-resume` command into `/opt/homebrew/bin` or `/usr/local/bin` if one of them is
writable, then runs `codex-auto-resume doctor`. Run it again to update.

To remove it:

```sh
~/Library/Application\ Support/CodexAutoResume/uninstall.sh            # keeps state and logs
~/Library/Application\ Support/CodexAutoResume/uninstall.sh --purge    # removes everything
```

## Commands

| Command | What it does |
| --- | --- |
| `threads [-n N]` | list recent Codex threads |
| `arm [thread] [--max-resumes N] [--checkpoint] [-y] [--force]` | arm a thread (default: the most recent) |
| `status [--json] [-n N]` | current state and recent events |
| `check [thread]` | dry run: what it would decide (sends nothing) |
| `cancel` | cancel a scheduled resume but stay armed |
| `resume-now [--force] [-y]` | send the continuation now |
| `disarm` | stop watching immediately |
| `logs [-f] [-n N]` | show (or follow) the log |
| `config [key] [value]` | show or change settings |
| `doctor` | check the installation |
| `notify-test` | send a test notification |
| `reset` | clear all stored state |

`--checkpoint` asks Codex to keep a short `.codex/resume.md` in the working directory: objective,
work done, work remaining, blockers and checks still to run. That file ends with
`Status: COMPLETE` or `Status: IN PROGRESS`, and the helper uses it as a completion signal.

## Settings

`codex-auto-resume config` shows them; `codex-auto-resume config <key> <value>` changes one. They
live in `~/Library/Application Support/CodexAutoResume/config.json`.

| Key | Default | Meaning |
| --- | --- | --- |
| `max_resumes` | 20 | safety cap per armed task |
| `reset_grace_secs` | 90 | wait after the reported reset before resuming |
| `backoff_secs` | 600 … 7200 | waits when no reset time is known or a resume hits the limit again |
| `resume_verify_secs` | 240 | how long to wait for a queued continuation to start |
| `poll_working_secs` / `poll_idle_secs` / `poll_waiting_secs` / `poll_resuming_secs` | 120 / 300 / 900 / 20 | polling cadence while armed (nothing is polled while disarmed) |
| `keep_awake_while_working` | true | prevent idle sleep while the task is working |
| `keep_awake_while_waiting_on_ac` | true | also while waiting for a reset, on mains power |
| `keep_awake_max_wait_secs` | 21600 | only if the reset is less than this far away |
| `notifications` | true | macOS notifications |
| `continuation_prompt` / `goal_continuation_prompt` | (see the script) | the messages sent to resume |
| `codex_cli` | the copy inside ChatGPT.app | path to the `codex` binary |

## Files

- Script and state: `~/Library/Application Support/CodexAutoResume/`
- Logs: `~/Library/Logs/CodexAutoResume/`
- Agent: `~/Library/LaunchAgents/local.codex-auto-resume.plist`

## See also

[AI Nudge](https://github.com/sbd1017/ai-nudge) is a macOS menu bar app that schedules messages
to Claude and Codex. Its "When Codex resets" nudges also send into a chosen Codex chat after the
limit resets.

## License

MIT. See [LICENSE](LICENSE).
