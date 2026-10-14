# Message list

Session ML-01. Row geometry: [diagrams/list-row.svg](diagrams/list-row.svg).

## Row

| Element | Geometry (from the row's top-left) | Value |
| --- | --- | --- |
| Row | **276 × 80**, at x 16 inside the list, pitch 80 | 1 pt separators between rows, starting at the sender's x |
| Unread dot | 13 × 10 hit area at x −1, y 11 | blue **`#0088ff`** |
| Sender | x 17, y 7, 18 tall, bold | 13 pt class |
| Date | right-aligned to the row's right edge, y 9, 16 tall, gray | see Dates |
| Subject | y 26, 16 tall | cut with an ellipsis |
| Preview | y 43, **two lines**, 30 tall, gray | |
| Thread count | at the right end of the subject line, blue: the count and a circled chevron (24 × 16 hit area) | the sender line lists the participants (`twoSenders`) |
| Flag | small orange flag at the right of the subject line | |

## Dates

| Age | Shown as |
| --- | --- |
| Today | time only |
| Yesterday | `yesterday` |
| Older (already from three days back) | short numeric date (`dateNumeric`) |
| Thread children, two days back | `dayBeforeYesterday` |

The session ran with a day-first locale; Silica follows the user's locale for the order.

## Selection

| State | Light | Dark |
| --- | --- | --- |
| Active window | filled rounded rectangle, **`#0171e1`**, white text | `#026ed1`, white text |
| Inactive window | `#dcdcdc`, text keeps its colours | `#464646` |

- Rows have **no hover** state.
- Arrow keys move the selection with no animation; the reader swaps its content at once.

## Threads

- Right arrow or a click on the count expands a thread. The child rows are shorter
  (sender and one preview line, ≈ 45 tall) and sit on a tinted block (light `#edf3fb`, dark
  `#253244`) that joins the selected parent row into one rounded shape.
- Expanding: the list starts changing ≈ 76 ms after button up and settles in
  **≈ 190–240 ms**. Collapsing takes ≈ 210 ms.

## Colours

| Part | Light | Dark |
| --- | --- | --- |
| List background | `#ffffff` | `#272728` |
| List / reader separator | `#e6e6e6` | `#3c3c3d` |

## Moving

- Dragging a message onto another mailbox removes its row; the rows below move up to close
  the gap (timing *unmeasured*).
