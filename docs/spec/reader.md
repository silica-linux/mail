# Reader

Session ML-01, light (dark: background colours only).

- Header row: the message count of the conversation (`messageCount`) in small gray text,
  and at the right a button that asks for a summary (not used in the session).
- Each message is a card with rounded corners:

| Part | Light | Dark |
| --- | --- | --- |
| Reader background | `#f8f8f8` | `#1b1b1b` |
| Card | `#ffffff` | `#272728` |

- Cards in a thread are ≈ 8 pt apart.

## Card header

- An avatar circle ≈ 32 pt with the sender's initials on a gray-blue gradient.
- Sender in bold, then the subject, then the recipients line (`to`) in gray.
- The date at the right (`dateTime`, or the time alone for today).
- When the message lives in a different mailbox from the selected one, its mailbox name
  appears with a folder glyph.
- A paper-clip glyph under the date when there are attachments.
- A 1 pt separator under the header.

## Attachments

- Shown inline in the body: an image at its own size, a PDF as its first page rendered in
  place. No separate attachment row was seen for these types.
- Other types: *unmeasured*.

## Remote content

The banner for blocked remote content was not observed (*unmeasured*); the app's own
text is `remoteContentBlocked`.
