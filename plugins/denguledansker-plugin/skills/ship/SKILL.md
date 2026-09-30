---
name: ship
description: Turn one part of the current conversation into a self-contained handoff prompt for a new Claude Code session. Only when the user runs /ship.
argument-hint: "[the part to ship, e.g. 'the login refactor']"
disable-model-invocation: true
---

The user wants to continue one specific thread of this conversation in a **new session**, while this session keeps going. Write a prompt they can paste into that new session. The new session will have no access to this conversation, so the prompt must stand on its own.

## 1. Pick the thread

What to ship: "$ARGUMENTS"

- If that is empty, look back over the conversation and find the distinct threads of work (2–4). Ask the user which one to ship with the AskUserQuestion tool, one option per thread with a one-line description. Do not guess.
- If it is given but matches more than one thread, ask the same way.
- Ship only that thread. Leave out unrelated work, dead ends that no longer matter, and chit-chat.

## 2. Gather the facts

Base everything on what actually happened in this conversation. Where it is cheap, check the current state instead of trusting memory. For example, run `git status` or `git log -3`, or confirm that a file you mention still exists. Never invent decisions, file contents or results.

## 3. Write the prompt

Write it to the new session's Claude, in the second person ("You are continuing…"), in the language the user writes in. Include only the sections that have content:

- **Goal**: what this work is for and what "done" looks like.
- **Context**: repo/directory, branch, stack, and anything about the environment that matters (OS, shell, tools).
- **Decisions made**: what was decided and *why*, including options that were rejected, so they are not re-litigated.
- **Current state**: what is done, verified, committed or pushed. Say what is still untested.
- **Relevant files**: paths with one line each on their role. Point to files rather than pasting their contents. Include a short snippet only when it is essential and not yet saved anywhere.
- **Next steps**: a concrete, ordered list.
- **Watch out for**: gotchas found along the way, constraints, and user preferences (e.g. "ask before pushing", "commit with the work email").
- **Open questions**: things that are still undecided and should be asked, not assumed.

Keep it tight: facts and pointers, no narrative of the conversation. Aim for something the user can read in under a minute.

## 4. Show it

Show the prompt in the chat as **one fenced code block**, so the user can read it and it copies cleanly. If the prompt itself contains ``` fences, wrap the whole thing in a longer fence (````) so it does not break. Put nothing else inside the block.

After the block, add one short line saying which thread was shipped and anything you deliberately left out.

## 5. Ask how to continue

Ask with the AskUserQuestion tool:

- **Copy it myself**: done. Nothing more to do.
- **Start a new session**: open a new terminal with a Claude Code session that starts with this prompt.

For a new session:

1. Write the prompt, exactly as shown, to a new file in your scratchpad or temp directory (e.g. `ship-prompt.md`).
2. Run the launcher with the Bash tool, passing the working directory the new session should start in (normally the current project root):
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/ship/scripts/open-session.sh" <prompt-file> <working-dir>
   ```
   It opens a new Windows Terminal tab, macOS Terminal window, tmux window or Linux terminal, and starts `claude` there with the prompt as the first message. The prompt is read from the file, so quotes and newlines are safe.
3. If it exits non-zero (no supported terminal found), say so in one line and tell the user to copy the block above.

Do not start any other work in this session as part of shipping; this session simply continues.
