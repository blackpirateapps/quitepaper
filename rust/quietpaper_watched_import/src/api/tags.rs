//! Pure, deterministic tag ranking. No note content or filesystem access.
use std::collections::HashSet;

#[derive(Clone, Debug)]
pub struct TagSuggestionInput {
    pub name: String,
    pub note_count: u32,
    pub pinned: bool,
    pub pinned_order: i32,
    /// Zero is most recent; -1 means this tag has never been used locally.
    pub recent_order: i32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TagSuggestionOrder {
    Suggested,
    Pinned,
    Recent,
    MostUsed,
}

/// The Flutter caller supplies canonical names, a normalized query, and valid
/// exclusions. A trailing slash is an unfinished path, not a create candidate.
pub fn rank_tag_suggestions(
    tags: Vec<TagSuggestionInput>,
    query: String,
    excluded: Vec<String>,
    order: TagSuggestionOrder,
    limit: u32,
) -> Vec<String> {
    let excluded: HashSet<_> = excluded.into_iter().collect();
    let mut seen = HashSet::new();
    let mut ranked: Vec<_> = tags
        .into_iter()
        .filter(|t| !excluded.contains(&t.name) && seen.insert(t.name.clone()))
        .filter(|t| match order {
            TagSuggestionOrder::Pinned => t.pinned,
            TagSuggestionOrder::Recent => t.recent_order >= 0,
            TagSuggestionOrder::MostUsed => t.note_count > 0,
            TagSuggestionOrder::Suggested => true,
        })
        .filter_map(|t| {
            let score = match_score(&t.name, &query);
            (score > 0).then_some((t, score))
        })
        .collect();
    ranked.sort_by(|(a, a_score), (b, b_score)| {
        let recent = |t: &TagSuggestionInput| {
            if t.recent_order < 0 {
                i32::MAX
            } else {
                t.recent_order
            }
        };
        b_score
            .cmp(a_score)
            .then_with(|| match order {
                TagSuggestionOrder::Suggested => b
                    .pinned
                    .cmp(&a.pinned)
                    .then_with(|| {
                        if a.pinned && b.pinned {
                            a.pinned_order.cmp(&b.pinned_order)
                        } else {
                            std::cmp::Ordering::Equal
                        }
                    })
                    .then_with(|| recent(a).cmp(&recent(b)))
                    .then_with(|| b.note_count.cmp(&a.note_count)),
                TagSuggestionOrder::Pinned => a.pinned_order.cmp(&b.pinned_order),
                TagSuggestionOrder::Recent => recent(a).cmp(&recent(b)),
                TagSuggestionOrder::MostUsed => b.note_count.cmp(&a.note_count),
            })
            .then_with(|| a.name.cmp(&b.name))
    });
    ranked
        .into_iter()
        .take(limit.min(100) as usize)
        .map(|(t, _)| t.name)
        .collect()
}

fn match_score(name: &str, query: &str) -> u16 {
    if query.is_empty() {
        return 1;
    }
    if name == query {
        return 1000;
    }
    // Scope nested searches to their full parent path. Prefer direct children.
    if let Some((parent, _)) = query.rsplit_once('/') {
        if !name.starts_with(&format!("{parent}/")) {
            return 0;
        }
        return if name.starts_with(query) {
            if name[parent.len() + 1..].contains('/') {
                800
            } else {
                900
            }
        } else {
            0
        };
    }
    if name.starts_with(query) {
        return 800;
    }
    if name
        .rsplit('/')
        .next()
        .is_some_and(|leaf| leaf.starts_with(query))
    {
        return 700;
    }
    if name.contains(query) {
        return 400;
    }
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tag(name: &str, count: u32, pinned: bool, recent_order: i32) -> TagSuggestionInput {
        TagSuggestionInput {
            name: name.into(),
            note_count: count,
            pinned,
            pinned_order: 0,
            recent_order,
        }
    }

    #[test]
    fn suggestions_use_pins_then_actual_recency_then_usage() {
        let tags = vec![
            tag("popular", 90, false, -1),
            tag("recent", 1, false, 0),
            tag("pin", 0, true, -1),
        ];
        assert_eq!(
            rank_tag_suggestions(
                tags.clone(),
                "".into(),
                vec![],
                TagSuggestionOrder::Suggested,
                15
            ),
            vec!["pin", "recent", "popular"]
        );
        assert_eq!(
            rank_tag_suggestions(
                tags.clone(),
                "".into(),
                vec![],
                TagSuggestionOrder::Recent,
                15
            ),
            vec!["recent"]
        );
        assert_eq!(
            rank_tag_suggestions(
                tags.clone(),
                "".into(),
                vec![],
                TagSuggestionOrder::MostUsed,
                15
            ),
            vec!["popular", "recent"]
        );
        assert_eq!(
            rank_tag_suggestions(tags, "".into(), vec![], TagSuggestionOrder::Pinned, 15),
            vec!["pin"]
        );
    }

    #[test]
    fn nested_search_scopes_parent_and_prefers_direct_children() {
        let tags = vec![
            tag("work/project/deep", 50, true, 0),
            tag("home/project", 1, false, -1),
            tag("work/project", 1, false, -1),
        ];
        assert_eq!(
            rank_tag_suggestions(
                tags.clone(),
                "work/".into(),
                vec![],
                TagSuggestionOrder::Suggested,
                15
            ),
            vec!["work/project", "work/project/deep"]
        );
        assert_eq!(
            rank_tag_suggestions(
                tags,
                "proj".into(),
                vec![],
                TagSuggestionOrder::Suggested,
                15
            ),
            vec!["home/project", "work/project", "work/project/deep"]
        );
    }

    #[test]
    fn excludes_deduplicates_and_limits_without_splitting_unicode_paths() {
        let tags = vec![
            tag("বাংলা/নোট", 1, false, -1),
            tag("বাংলা/নোট", 1, false, -1),
            tag("বাংলা/কাজ", 1, false, -1),
        ];
        assert_eq!(
            rank_tag_suggestions(
                tags.clone(),
                "বাংলা/".into(),
                vec!["বাংলা/কাজ".into()],
                TagSuggestionOrder::Suggested,
                15
            ),
            vec!["বাংলা/নোট"]
        );
        assert!(
            rank_tag_suggestions(tags, "".into(), vec![], TagSuggestionOrder::Suggested, 0)
                .is_empty()
        );
    }
}
