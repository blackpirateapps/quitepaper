use serde::Deserialize;
use serde_json::value::RawValue;
use std::{collections::HashMap, ops::Range};

pub fn is_document(content: &str) -> bool {
    content.trim_start().starts_with('{') && content.contains("\"quietpaper:rich_document:v1\"")
}

#[derive(Deserialize)]
struct Document<'a> {
    #[serde(borrow)]
    blocks: Vec<&'a RawValue>,
}

#[derive(Deserialize)]
struct TextSpan {
    text: String,
}

pub struct Block<'a> {
    raw: &'a RawValue,
    fields: HashMap<String, &'a RawValue>,
}

impl<'a> Block<'a> {
    pub fn field<T: Deserialize<'a>>(&self, name: &str) -> Option<T> {
        serde_json::from_str(self.fields.get(name)?.get()).ok()
    }

    pub fn kind(&self) -> String {
        self.field("type").unwrap_or_default()
    }

    pub fn text(&self) -> String {
        self.field::<Vec<TextSpan>>("spans")
            .map(|spans| spans.into_iter().map(|span| span.text).collect())
            .or_else(|| self.field("code"))
            .or_else(|| self.field("alt"))
            .or_else(|| self.field("fileName"))
            .or_else(|| self.field("title"))
            .unwrap_or_default()
    }

    pub fn completed(&self) -> bool {
        self.field("isChecked").unwrap_or(false)
    }

    // RawValue borrows its JSON slice from the original content. Replacing that
    // range preserves the rest of the document byte for byte, including unknown fields.
    pub fn completion_range(&self, content: &str) -> (Range<usize>, bool) {
        let offset = |raw: &RawValue| raw.get().as_ptr() as usize - content.as_ptr() as usize;
        if let Some(raw) = self.fields.get("isChecked") {
            let start = offset(raw);
            (start..start + raw.get().len(), false)
        } else {
            let start = offset(self.raw) + 1;
            (start..start, true)
        }
    }
}

pub fn blocks(content: &str) -> serde_json::Result<Vec<Block<'_>>> {
    serde_json::from_str::<Document<'_>>(content)?
        .blocks
        .into_iter()
        .map(|raw| {
            Ok(Block {
                raw,
                fields: serde_json::from_str(raw.get())?,
            })
        })
        .collect()
}

pub fn plain_text(content: &str) -> String {
    blocks(content)
        .unwrap_or_default()
        .iter()
        .map(Block::text)
        .collect::<Vec<_>>()
        .join("\n")
}
