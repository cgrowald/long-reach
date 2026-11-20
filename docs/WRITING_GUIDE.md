# Writing guide: where the words live and how to change them

*The user wants to write for the game (2026-11-20). All story text is plain data, so you can edit it without touching code. Claude keeps it that way and never overwrites your text without asking.*

## Where the text is

| File | What's in it |
|---|---|
| `data/terminal/days.json` | The story cards between nights (work, dinner, Bruno at the gate), each day's news and new rule, and when messages arrive |
| `data/terminal/conversations.json` | Every chat: who says what, and the replies you can pick |
| `data/terminal/sites.json` | NetState pages, the forum threads, search results |
| `data/terminal/files.json` | Elena's letter, Lena's homework, the Station 4 ledger, every document on the laptop |
| `data/terminal/shell.json` | The dev console's fortunes and jokes |

Open them in any text editor. VS Code (free) is best: it colors the file and shows mistakes in red.

## The three rules of JSON (the file format)
1. Text goes **inside double quotes**: `"text": "She eats her peas."`
2. Inside text, a double quote must be written `\"`, and a new line is `\n`:
   `"text": "\"Is Uncle Pavel coming?\"\n\nMira looks at you."`
3. Items in a list are separated by commas, with **no comma after the last one**.

If the game shows an error after an edit, it's almost always one of these three. Tell Claude, and Claude finds it in seconds.

## How a story card works (days.json)
```json
{"text": "Old Bruno is at his gate.", "choices": [
	{"text": "Laugh it off.", "result": "He laughs too. His eyes don't."},
	{"text": "Bring him brandy.", "result": "Bruno likes you a little more."}
]}
```
- `text` is what's shown. `choices` are the buttons. `result` is what you see after picking.
- Leave the `do` and `set` parts alone, or ask Claude; they're the game effects.

## How a chat works (conversations.json)
```json
"hana_why": {"contact": "hana", "msgs": ["because pavel talked about you.", "said you were careful."], "replies": [
	{"text": "I'll be there.", "goto": "hana_ok"}
]}
```
- `msgs` arrive one by one. `replies` are your options. `goto` is the next chat beat.

## The voice (decided 2026-11-20)
- **The regime, its news and its forms are bleak**, with a cold bureaucratic dark humor that doesn't know it's funny (the Marshal's biography).
- **Your own people are darkly funny and warm.** You should like them. Each has a voice: lantern never uses names or capitals; Hana types short lowercase; Viktor uses emojis.
- Show, don't tell: "the empty chair" beats "you feel sad".

## A good first writing exercise
Rewrite Tuesday's dinner (days.json, day "2"), or add a new forum thread to `sites.json` in the voice of someone on the forum. Then play it.
