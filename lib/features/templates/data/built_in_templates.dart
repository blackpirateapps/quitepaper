import '../domain/note_template.dart';

// Bundled immutable data. Never inserted into note_templates.
final builtInTemplates = List<NoteTemplate>.unmodifiable([
  NoteTemplate(
    id: 'builtin.daily_planner.v1',
    displayName: 'Daily Planner',
    storageFormat: TemplateStorageFormat.markdown,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    content: r'''## Top priorities

- [ ] Priority 1
- [ ] Priority 2
- [ ] Priority 3

## Schedule

- Morning:
- Afternoon:
- Evening:

## Notes

## End-of-day reflection''',
  ),
  NoteTemplate(
    id: 'builtin.meeting_notes.v1',
    displayName: 'Meeting Notes',
    storageFormat: TemplateStorageFormat.markdown,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    content: r'''## Meeting details

**Participants:**

**Date:**

## Agenda

- 

## Discussion

## Decisions

## Action items

- [ ] Follow-up task

## Next meeting''',
  ),
  NoteTemplate(
    id: 'builtin.study_notes.v1',
    displayName: 'Study Notes',
    storageFormat: TemplateStorageFormat.markdown,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    content: r'''## Topic

## Key concepts

## Definitions

## Important formulas

## Worked examples

## Questions to revisit

- [ ] Review question

## Summary''',
  ),
  NoteTemplate(
    id: 'builtin.reading_notes.v1',
    displayName: 'Reading Notes',
    storageFormat: TemplateStorageFormat.markdown,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    content: r'''## Book or article

**Author:**

**Source:**

## Main ideas

## Notable quotations

## Personal reflections

## Questions

## Takeaways''',
  ),
  NoteTemplate(
    id: 'builtin.project_brief.v1',
    displayName: 'Project Brief',
    storageFormat: TemplateStorageFormat.markdown,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    content: r'''## Overview

## Problem

## Goals

## Scope

### Included

### Excluded

## Requirements

## Milestones

- [ ] First milestone

## Risks

## Next steps''',
  ),
  NoteTemplate(
    id: 'builtin.bug_report.v1',
    displayName: 'Bug Report',
    storageFormat: TemplateStorageFormat.markdown,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    content: r'''## Summary

## Environment

**Platform:**

**App version:**

## Steps to reproduce

1. First step
2. Second step
3. Third step

## Expected behavior

## Actual behavior

## Evidence

## Possible cause

## Resolution checklist

- [ ] Fix implemented
- [ ] Regression test added
- [ ] Verification completed''',
  ),
  NoteTemplate(
    id: 'builtin.weekly_review.v1',
    displayName: 'Weekly Review',
    storageFormat: TemplateStorageFormat.markdown,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    content: r'''## Highlights

## Completed this week

- [ ] Item

## Challenges

## Lessons learned

## Unfinished tasks

- [ ] Item

## Priorities for next week

- [ ] Priority''',
  ),
  NoteTemplate(
    id: 'builtin.decision_log.v1',
    displayName: 'Decision Log',
    storageFormat: TemplateStorageFormat.markdown,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    content: r'''## Decision

## Context

## Options considered

### Option A

### Option B

## Reasoning

## Final decision

## Trade-offs

## Follow-up actions

- [ ] Action''',
  ),
]);
