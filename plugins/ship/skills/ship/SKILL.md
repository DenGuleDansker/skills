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

## 4. Output

Show the prompt in the chat as **one fenced code block** so it copies cleanly. If the prompt itself contains ``` fences, wrap the whole thing in a longer fence (````) so it does not break. Put nothing else inside the block.

After the block, add one short line saying which thread was shipped and anything you deliberately left out. Do not write files, copy to the clipboard or start other work unless the user asks.
