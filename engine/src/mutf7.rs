//! IMAP mailbox names travel in "modified UTF-7" (RFC 3501 §5.1.3): `Entw&APw-rfe` is
//! `Entwürfe`. The store keeps the server's name for commands and shows the decoded one.

use base64::Engine as _;
use base64::alphabet::IMAP_MUTF7;
use base64::engine::GeneralPurpose;
use base64::engine::general_purpose::NO_PAD;

const ENGINE: GeneralPurpose = GeneralPurpose::new(&IMAP_MUTF7, NO_PAD);

/// Decodes a modified UTF-7 name; invalid sequences are kept as they are.
pub fn decode(name: &str) -> String {
    let mut out = String::with_capacity(name.len());
    let mut rest = name;
    while let Some(start) = rest.find('&') {
        out.push_str(rest.get(..start).unwrap_or(""));
        let after = rest.get(start + 1..).unwrap_or("");
        let Some(end) = after.find('-') else {
            out.push_str(rest.get(start..).unwrap_or(""));
            return out;
        };
        let encoded = after.get(..end).unwrap_or("");
        if encoded.is_empty() {
            out.push('&');
        } else {
            let decoded = ENGINE.decode(encoded).ok().and_then(|bytes| {
                let units: Vec<u16> = bytes
                    .as_chunks::<2>()
                    .0
                    .iter()
                    .map(|c| u16::from_be_bytes(*c))
                    .collect();
                String::from_utf16(&units).ok()
            });
            match decoded {
                Some(text) => out.push_str(&text),
                None => {
                    out.push('&');
                    out.push_str(encoded);
                    out.push('-');
                }
            }
        }
        rest = after.get(end + 1..).unwrap_or("");
    }
    out.push_str(rest);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decodes_names() {
        assert_eq!(decode("INBOX"), "INBOX");
        assert_eq!(decode("Entw&APw-rfe"), "Entwürfe");
        assert_eq!(decode("Tom &- Jerry"), "Tom & Jerry");
        assert_eq!(decode("&ZeVnLIqe-"), "日本語");
        assert_eq!(decode("broken &!!-"), "broken &!!-");
        assert_eq!(decode("open &AAA"), "open &AAA");
    }
}
