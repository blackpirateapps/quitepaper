use crate::markdown;
use pulldown_cmark::{Event, LinkType, Parser, Tag};
use std::ops::Range;

#[derive(Debug)]
pub struct ImagePath {
    pub range: Range<usize>,
    pub target: String,
}

fn destination(source: &str, offset: usize, angle: bool) -> Option<Range<usize>> {
    let bytes = source.as_bytes();
    let mut start = offset;
    while bytes.get(start).is_some_and(u8::is_ascii_whitespace) {
        start += 1;
    }
    if angle && bytes.get(start) == Some(&b'<') {
        start += 1;
        return Some(start..start + source[start..].find('>')?);
    }
    let mut end = start;
    let mut depth = 0usize;
    while let Some(&byte) = bytes.get(end) {
        match byte {
            b'\\' if end + 1 < bytes.len() => {
                end += 2;
                continue;
            }
            b'(' => depth += 1,
            b')' if depth == 0 => break,
            b')' => depth -= 1,
            b if b.is_ascii_whitespace() => break,
            _ => {}
        }
        end += 1;
    }
    (end > start).then_some(start..end)
}

pub fn is_local(target: &str) -> bool {
    !target.is_empty()
        && !target.starts_with('#')
        && !target.starts_with("//")
        && match url::Url::parse(target) {
            Ok(uri) => uri.scheme() == "file",
            Err(url::ParseError::RelativeUrlWithoutBase) => true,
            _ => false,
        }
}

pub fn find(source: &str) -> Vec<ImagePath> {
    let fm = markdown::frontmatter(source);
    let base = fm.end;
    let body = fm.body;
    let parser = Parser::new(body);
    let definitions = parser
        .reference_definitions()
        .iter()
        .map(|(id, def)| (id.to_lowercase(), (def.span.clone(), def.dest.to_string())))
        .collect::<std::collections::BTreeMap<_, _>>();
    let mut paths = std::collections::BTreeMap::new();
    for (event, span) in parser.into_offset_iter() {
        let Event::Start(Tag::Image {
            link_type,
            dest_url,
            id,
            ..
        }) = event
        else {
            continue;
        };
        if !is_local(&dest_url) {
            continue;
        }
        let range = if link_type == LinkType::Inline {
            // Match the closing alt bracket, allowing nested/escaped brackets.
            let snippet = &body[span.clone()];
            let bytes = snippet.as_bytes();
            let mut index = 2;
            let mut depth = 1usize;
            while index < bytes.len() && depth > 0 {
                match bytes[index] {
                    b'\\' => {
                        index += 2;
                        continue;
                    }
                    b'[' => depth += 1,
                    b']' => depth -= 1,
                    _ => {}
                }
                index += 1;
            }
            if bytes.get(index) != Some(&b'(') {
                continue;
            }
            destination(body, span.start + index + 1, true)
        } else {
            definitions.get(&id.to_lowercase()).and_then(|(range, _)| {
                let text = &body[range.clone()];
                let start = range.start + text.find("]:")? + 2;
                destination(body, start, true)
            })
        };
        if let Some(range) = range {
            paths.insert(range.start, (range, dest_url.to_string()));
        }
    }
    paths
        .into_values()
        .map(|(range, target)| ImagePath {
            range: range.start + base..range.end + base,
            target,
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn images_only_and_preserve_source_ranges() {
        let text="---\ntitle: '![x](front.png)'\n---\n`![x](code.png)`\n```md\n![x](fence.png)\n```\n\\![x](escaped.png)\n![remote](https://a/b)\n![asset](qp://asset/id)\n![photo](<photo with spaces.png> \"Title\")\n![nested](photo(1).png)\n![ref][yes]\n[ordinary][no]\n\n[yes]: reference.png\n[no]: other.md\n";
        let found = find(text);
        assert_eq!(
            found.iter().map(|p| p.target.as_str()).collect::<Vec<_>>(),
            ["photo with spaces.png", "photo(1).png", "reference.png"]
        );
        for path in found {
            assert_eq!(&text[path.range], path.target);
        }
    }
}
