# denguledansker-plugin

Personal Claude Code skills. Skills are invoked as `/denguledansker-plugin:<skill>`, or just type `/<skill>` and pick it from autocomplete.

## Installation

```
/plugin marketplace add DenGuleDansker/skills
/plugin install denguledansker-plugin@skills
```

## Skills

### ship

Hand off one part of a conversation to a new Claude Code session, while the current session keeps going.

```
/ship the login refactor
```

Claude writes a self-contained prompt covering only that thread and shows it in the chat as a single code block. Then it asks whether you want to copy it yourself, or have Claude start a new session with it. A new session opens in a new terminal tab (Windows Terminal, macOS Terminal, tmux or common Linux terminals) in the same project. The prompt covers:

- the goal,
- the context: repo, branch, environment,
- decisions made and why,
- the current state,
- relevant files,
- next steps,
- gotchas and open questions.

Run `/ship` without arguments and Claude lists the threads of the conversation and asks which one to ship.

The skill only runs when you invoke it. Claude never triggers it on its own.
