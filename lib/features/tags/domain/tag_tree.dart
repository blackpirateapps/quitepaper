import 'package:flutter/foundation.dart';

import '../../../core/utils/tag_parser.dart';
import 'tag_model.dart';
import 'tag_path.dart';

/// A single node in the derived tag hierarchy.
class TagTreeNode {
  TagTreeNode({
    required this.tag,
    required this.path,
    List<TagTreeNode>? children,
  }) : children = children ?? <TagTreeNode>[];

  Tag tag;
  final TagPath? path;
  final List<TagTreeNode> children;

  bool get hasChildren => children.isNotEmpty;
  bool get isImplicit => tag.isImplicit;

  /// Total note count for this node and its descendants.
  int get totalNoteCount {
    var count = tag.noteCount;
    var childSum = 0;
    for (final child in children) {
      childSum += child.totalNoteCount;
    }
    return count > childSum ? count : childSum;
  }

  /// The leaf shown in compact surfaces (falls back to the raw name for
  /// malformed legacy paths).
  String get displayName => path?.leaf ?? tag.name;

  /// Full token for accessibility/tooltips.
  String get displayPath => path?.token ?? '#${tag.name}';
}

/// Immutable hierarchy derived from the flat tag list.
///
/// Full paths are the source of truth. Missing ancestors are synthesized as
/// implicit nodes so nested tags always have a place in the tree, even when a
/// legacy database or an out-of-order remote pull only contains the child.
@immutable
class TagTree {
  const TagTree._(this.roots, this.nodesByPath);

  final List<TagTreeNode> roots;
  final Map<String, TagTreeNode> nodesByPath;

  bool get isEmpty => roots.isEmpty;
  bool get isNotEmpty => roots.isNotEmpty;

  TagTreeNode? nodeFor(String path) =>
      nodesByPath[TagParser.normalizeTag(path)];

  /// Builds a hierarchy from [tags].
  ///
  /// [compare] orders siblings. By default tags are ordered pinned-first then
  /// alphabetically, matching the tag browser's default presentation.
  factory TagTree.build(Iterable<Tag> tags, {Comparator<Tag>? compare}) {
    final byPath = <String, Tag>{};
    for (final tag in tags) {
      final path = TagPath.tryParse(tag.name);
      if (path == null) continue;
      byPath[path.value] = tag;
    }

    // Materialize missing ancestors as implicit tags.
    final now = DateTime.now();
    final allTags = <String, Tag>{...byPath};
    for (final entry in byPath.entries) {
      final path = TagPath.parse(entry.key);
      for (final ancestor in path.ancestors) {
        allTags.putIfAbsent(
          ancestor.value,
          () => Tag(
            id: TagParser.deterministicTagId(ancestor.value),
            name: ancestor.value,
            createdAt: now,
            updatedAt: now,
            isImplicit: true,
          ),
        );
      }
    }

    final nodes = <String, TagTreeNode>{};
    for (final entry in allTags.entries) {
      final path = TagPath.tryParse(entry.key);
      nodes[entry.key] = TagTreeNode(tag: entry.value, path: path);
    }

    final roots = <TagTreeNode>[];
    for (final entry in nodes.entries) {
      final node = entry.value;
      final parentPath = node.path?.parent;
      final parent = parentPath == null ? null : nodes[parentPath.value];
      if (parent != null) {
        parent.children.add(node);
      } else {
        roots.add(node);
      }
    }

    // Preserve legacy malformed tags as top-level entries rather than dropping
    // them from navigation.
    for (final tag in tags) {
      final parsed = TagPath.tryParse(tag.name);
      if (parsed != null) continue;
      nodes[tag.name] = TagTreeNode(tag: tag, path: null);
      roots.add(nodes[tag.name]!);
    }

    // Ensure all ancestor nodes reflect their subtree's total note count so implicit
    // or parent tags accurately display the total number of notes in their hierarchy.
    int computeSubtreeCounts(TagTreeNode node) {
      var childTotal = 0;
      for (final child in node.children) {
        childTotal += computeSubtreeCounts(child);
      }
      final total = node.tag.noteCount > childTotal
          ? node.tag.noteCount
          : childTotal;
      if (node.tag.noteCount < total) {
        node.tag = node.tag.copyWith(noteCount: total);
      }
      return total;
    }

    for (final root in roots) {
      computeSubtreeCounts(root);
    }

    final effectiveCompare = compare ?? _defaultCompare;
    void sortNodes(List<TagTreeNode> list) {
      list.sort((a, b) => effectiveCompare(a.tag, b.tag));
      for (final node in list) {
        if (node.children.isNotEmpty) sortNodes(node.children);
      }
    }

    sortNodes(roots);
    return TagTree._(List.unmodifiable(roots), Map.unmodifiable(nodes));
  }

  /// Default comparator ordering tags pinned-first, then alphabetically by name.
  static int compareByName(Tag a, Tag b) => _defaultCompare(a, b);

  /// Comparator ordering tags pinned-first, then by note count descending (most used first),
  /// then alphabetically by name.
  static int compareByUsage(Tag a, Tag b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    if (a.isPinned && b.isPinned) {
      final order = a.pinnedOrder.compareTo(b.pinnedOrder);
      if (order != 0) return order;
    }
    final count = b.noteCount.compareTo(a.noteCount);
    if (count != 0) return count;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static int _defaultCompare(Tag a, Tag b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    if (a.isPinned && b.isPinned) {
      final order = a.pinnedOrder.compareTo(b.pinnedOrder);
      if (order != 0) return order;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  /// Flattens the tree, including children of expanded nodes only.
  /// If [roots] is provided, only those roots and their descendants are flattened.
  static List<({TagTreeNode node, int depth})> flatten(
    TagTree tree, {
    required Set<String> expandedPaths,
    Iterable<TagTreeNode>? roots,
  }) {
    final result = <({TagTreeNode node, int depth})>[];
    void visit(TagTreeNode node, int depth) {
      result.add((node: node, depth: depth));
      final path = node.path?.value ?? node.tag.name;
      if (node.children.isEmpty || !expandedPaths.contains(path)) return;
      for (final child in node.children) {
        visit(child, depth + 1);
      }
    }

    final effectiveRoots = roots ?? tree.roots;
    for (final root in effectiveRoots) {
      visit(root, 0);
    }
    return result;
  }

  /// Every node in deterministic tree order, regardless of expansion.
  static List<TagTreeNode> allNodes(TagTree tree) {
    final result = <TagTreeNode>[];
    void visit(TagTreeNode node) {
      result.add(node);
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final root in tree.roots) {
      visit(root);
    }
    return result;
  }
}
