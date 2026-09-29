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

Claude writes a self-contained prompt covering only that thread and shows it in the chat as a single code block. Copy it into a new session to continue from there. The prompt covers:

- the goal,
- the context: repo, branch, environment,
- decisions made and why,
- the current state,
- relevant files,
- next steps,
- gotchas and open questions.

Run `/ship` without arguments and Claude lists the threads of the conversation and asks which one to ship.

The skill only runs when you invoke it. Claude never triggers it on its own.
