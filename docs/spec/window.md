# Viewer window

Session ML-01. Window at 1280 × 720 (the size it already had). Diagram:
[diagrams/viewer-layout.svg](diagrams/viewer-layout.svg).

## Columns

| Part | Geometry (from the window's top-left corner) | Notes |
| --- | --- | --- |
| Window | 1280 × 720; **minimum 751 × 200** | a smaller size request is clamped |
| Window buttons | hit areas 16 × 16 at x 18, 41, 64, y 18 | they sit over the sidebar, which runs the full window height |
| Toolbar | **52** tall, full width | unified with the title; its controls are glass capsules floating over the content |
| Sidebar | **208** wide (x 0–208), its list starts under the toolbar row | |
| Message list | x 208–533, **325** wide | overlay scroller 19 wide |
| Reader | x 534–1280, 746 wide | |

- With nothing selected the reader shows `noSelection`, centred, in large light gray text.
- At the minimum width the toolbar folds most of its buttons into a "»" overflow button and
  keeps a search button.

## Toolbar

Left to right, with hit-area widths:

| Item | Width | Notes |
| --- | --- | --- |
| Sidebar toggle | 40 × 52 at x 164 | inside the sidebar column |
| Title block | 235 | mailbox name in bold, under it `messageCountUnread` in small gray text |
| Filter + more ("…") | 41 + more | one shared capsule; filter is a toggle with a menu |
| New Message | 40 | |
| Reply · Reply All · Forward | 38 · 40 · 39 | one capsule, 119 wide |
| Archive · Delete · Junk | 38 · 35 · 42 | one capsule, 121 wide |
| Move | folder glyph and chevron | pop-up |
| Flag | 38 + chevron | capsule 77; the flag turns orange when the selected message is flagged |
| Search field | **299 × 38** at y 7 | magnifier and the placeholder `search` |

- Buttons that need a selection are dimmed when nothing is selected.

## Inactive window

Covered under [message-list.md](message-list.md) (the selection colour is what changes).
