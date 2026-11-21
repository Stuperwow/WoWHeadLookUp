# WowheadLookup

A World of Warcraft: **Forever** addon that gets Wowhead links ready to copy, straight from the game.

WoW addons can't open a web browser, so this does the next best thing: it builds the right Wowhead link and pops it up already selected — press **Ctrl+C**, then paste it into your browser.

## Install

1. Download **WowheadLookup.zip** from the [Releases](../../releases) page (not the green "Code" button).
2. Unzip it into your Forever `Interface\AddOns` folder, so you end up with `Interface\AddOns\WowheadLookup\WowheadLookup.toc`.
3. Fully restart the game.

## How to use it

- **The Wowhead window** — a small chat-style window. Type a search and press Enter, or **shift-click an item, spell, or quest link** into its box. Drag the title to move it; drag the corner to resize.
- **`/wh <anything>`** — same thing from any chat box, e.g. `/wh peacebloom` or `/wh` followed by a shift-clicked item.
- **Mouseover keybind** — set "Look up what's under the mouse" in Options → Keybindings → AddOns → WowheadLookup. Hover an item, spell, or NPC (or target an NPC) and press it.
- **History** — past lookups stay in the window. Click one to copy its link again.

Links go straight to the right page when possible (`item=`, `spell=`, `quest=`, `npc=`, `object=`); plain text becomes a Wowhead search.

## Commands

| Command | What it does |
|---|---|
| `/wh` | Show/hide the Wowhead window |
| `/wh <search or link>` | Get a Wowhead link |
| `/wh base <url>` | Change the site address (e.g. if you want a different game version's pages) |
| `/wh base reset` | Go back to `https://www.wowhead.com/` |
| `/wh clear` | Clear the history |

Not affiliated with Wowhead.
