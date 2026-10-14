# Mail · public specification

This folder describes how the mail app of the reference system (macOS 27) looks and
behaves, as observed by measurement. Silica follows a clean-room process: the observations
were made on a real machine and are restated here in our own words, with the numbers that
came out of them. The raw material (screenshots, screen recordings, accessibility dumps,
session notes) stays in the private repository `silica-reference` and is not reproduced here.

## Conventions

- **IDs.** `ML-01` names the measurement session of this app; every value here comes from
  it.
- **Units.** Lengths are points at 1× (1 pt = 1 px on the reference display). Positions are
  measured from the top-left corner of the window unless a table says otherwise.
- **Colours.** sRGB hex. Neutral grays were read directly; saturated colours were converted
  from the display profile to sRGB, and only the sRGB value is given.
- **Timing.** Recorded at 75 Hz: one frame is 13.3 ms, which is also the precision of every
  time given here. Times are counted from the input event named in each table.
- **Status.** Values marked *provisional* are estimates or single readings that need a
  second look; items marked *unmeasured* were not observed at all.
- **Labels.** English, matching `app/lib/l10n/app_en.arb` where the app already has a string.
  They name controls; they are not quotations of the reference interface.

## Reference conditions

Display 2560 × 1440 at 1×, 75 Hz, solid mid-gray wallpaper. Only generated test data was
used: a local mailbox with twelve made-up messages (two threads, one image and one PDF
attachment, dates from an hour to over a year old, one very long subject). No real account
content was observed. Nothing was sent.

Light was captured for every state; dark only for some (each file says which).

## Files

| File | Covers |
| --- | --- |
| [window.md](window.md) | Viewer window: columns, toolbar, minimum size |
| [sidebar.md](sidebar.md) | Mailbox sidebar |
| [message-list.md](message-list.md) | Message rows, dates, threads, selection |
| [reader.md](reader.md) | Message view, thread cards, attachments |
| [composer.md](composer.md) | Composer window, fields, format bar, close alert |
| [search.md](search.md) | Search suggestions, results, tokens |
| [sheets-and-alerts.md](sheets-and-alerts.md) | Add account sheet, delete mailbox alert, empty mailbox |
| [diagrams/viewer-layout.svg](diagrams/viewer-layout.svg) | Viewer window columns and toolbar |
| [diagrams/list-row.svg](diagrams/list-row.svg) | Message row geometry |

## Not observed

- New-mail notifications (they need real incoming mail).
- Sending, and any animation of it.
- Deleting a message (it could have touched the real account's trash).
- The remote-content banner (the test messages had no remote content), the formatting
  popovers, and attachment chips for types not shown inline.
- Dark appearance of the reader, threads, attachments, inactive window, composer, search,
  account sheet, empty mailbox and delete alert.
