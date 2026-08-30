import 'package:flutter/material.dart';

/// Semantic category for icon organization.
enum TagIconCategory {
  objects('Objects'),
  activities('Activities'),
  places('Places'),
  symbols('Symbols'),
  work('Work'),
  education('Education'),
  technology('Technology'),
  lifestyle('Lifestyle');

  const TagIconCategory(this.displayName);
  final String displayName;
}

/// Metadata definition for an icon in the registry.
@immutable
class TagIconItem {
  const TagIconItem({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.category,
    this.keywords = const [],
  });

  final String id;
  final String displayName;
  final IconData icon;
  final TagIconCategory category;
  final List<String> keywords;
}

/// Curated registry of icons for tags in Quiet Paper.
abstract final class TagIconRegistry {
  static const List<TagIconItem> all = [
    // Objects
    TagIconItem(id: 'tag', displayName: 'Tag', icon: Icons.label_rounded, category: TagIconCategory.objects, keywords: ['label', 'tag', 'mark']),
    TagIconItem(id: 'bookmark', displayName: 'Bookmark', icon: Icons.bookmark_rounded, category: TagIconCategory.objects, keywords: ['save', 'bookmark', 'favorite']),
    TagIconItem(id: 'folder', displayName: 'Folder', icon: Icons.folder_rounded, category: TagIconCategory.objects, keywords: ['dir', 'directory', 'folder', 'archive']),
    TagIconItem(id: 'key', displayName: 'Key', icon: Icons.key_rounded, category: TagIconCategory.objects, keywords: ['password', 'secret', 'access', 'security']),
    TagIconItem(id: 'flag', displayName: 'Flag', icon: Icons.flag_rounded, category: TagIconCategory.objects, keywords: ['milestone', 'goal', 'country', 'priority']),
    TagIconItem(id: 'pin', displayName: 'Pin', icon: Icons.push_pin_rounded, category: TagIconCategory.objects, keywords: ['pinned', 'board', 'sticky']),
    TagIconItem(id: 'box', displayName: 'Archive Box', icon: Icons.inventory_2_rounded, category: TagIconCategory.objects, keywords: ['box', 'package', 'inventory', 'storage']),
    TagIconItem(id: 'camera', displayName: 'Camera', icon: Icons.photo_camera_rounded, category: TagIconCategory.objects, keywords: ['photo', 'picture', 'image']),
    TagIconItem(id: 'gift', displayName: 'Gift', icon: Icons.card_giftcard_rounded, category: TagIconCategory.objects, keywords: ['present', 'gift', 'birthday', 'holiday']),
    TagIconItem(id: 'wallet', displayName: 'Wallet', icon: Icons.account_balance_wallet_rounded, category: TagIconCategory.objects, keywords: ['money', 'finance', 'cash', 'card']),

    // Activities
    TagIconItem(id: 'run', displayName: 'Running', icon: Icons.directions_run_rounded, category: TagIconCategory.activities, keywords: ['run', 'sport', 'exercise', 'cardio']),
    TagIconItem(id: 'fitness', displayName: 'Fitness', icon: Icons.fitness_center_rounded, category: TagIconCategory.activities, keywords: ['gym', 'workout', 'weights', 'exercise', 'health']),
    TagIconItem(id: 'gamepad', displayName: 'Gaming', icon: Icons.sports_esports_rounded, category: TagIconCategory.activities, keywords: ['game', 'play', 'gaming', 'entertainment']),
    TagIconItem(id: 'music', displayName: 'Music', icon: Icons.music_note_rounded, category: TagIconCategory.activities, keywords: ['song', 'audio', 'sound', 'band', 'guitar']),
    TagIconItem(id: 'movie', displayName: 'Movie', icon: Icons.movie_rounded, category: TagIconCategory.activities, keywords: ['film', 'cinema', 'video', 'watch']),
    TagIconItem(id: 'palette', displayName: 'Art & Design', icon: Icons.palette_rounded, category: TagIconCategory.activities, keywords: ['paint', 'art', 'draw', 'design', 'creative']),
    TagIconItem(id: 'hiking', displayName: 'Hiking', icon: Icons.terrain_rounded, category: TagIconCategory.activities, keywords: ['mountain', 'hike', 'nature', 'trail', 'outdoor']),
    TagIconItem(id: 'plane', displayName: 'Travel', icon: Icons.flight_rounded, category: TagIconCategory.activities, keywords: ['flight', 'vacation', 'trip', 'travel', 'holiday']),
    TagIconItem(id: 'bike', displayName: 'Cycling', icon: Icons.directions_bike_rounded, category: TagIconCategory.activities, keywords: ['bike', 'bicycle', 'cycling', 'ride']),

    // Places
    TagIconItem(id: 'home', displayName: 'Home', icon: Icons.home_rounded, category: TagIconCategory.places, keywords: ['house', 'apartment', 'family', 'domestic']),
    TagIconItem(id: 'store', displayName: 'Store', icon: Icons.storefront_rounded, category: TagIconCategory.places, keywords: ['shop', 'market', 'store', 'retail']),
    TagIconItem(id: 'building', displayName: 'Building', icon: Icons.apartment_rounded, category: TagIconCategory.places, keywords: ['office', 'city', 'real estate', 'urban']),
    TagIconItem(id: 'school', displayName: 'School', icon: Icons.school_rounded, category: TagIconCategory.places, keywords: ['college', 'university', 'study', 'class']),
    TagIconItem(id: 'hotel', displayName: 'Hotel', icon: Icons.hotel_rounded, category: TagIconCategory.places, keywords: ['stay', 'resort', 'vacation', 'lodging']),
    TagIconItem(id: 'globe', displayName: 'World', icon: Icons.public_rounded, category: TagIconCategory.places, keywords: ['global', 'earth', 'international', 'web']),
    TagIconItem(id: 'map', displayName: 'Map', icon: Icons.map_rounded, category: TagIconCategory.places, keywords: ['location', 'place', 'guide', 'navigation']),
    TagIconItem(id: 'park', displayName: 'Park', icon: Icons.park_rounded, category: TagIconCategory.places, keywords: ['nature', 'trees', 'green', 'environment']),

    // Symbols
    TagIconItem(id: 'star', displayName: 'Star', icon: Icons.star_rounded, category: TagIconCategory.symbols, keywords: ['favorite', 'important', 'featured', 'rating']),
    TagIconItem(id: 'heart', displayName: 'Heart', icon: Icons.favorite_rounded, category: TagIconCategory.symbols, keywords: ['love', 'like', 'health', 'wellness']),
    TagIconItem(id: 'bulb', displayName: 'Idea', icon: Icons.lightbulb_rounded, category: TagIconCategory.symbols, keywords: ['idea', 'creative', 'inspiration', 'thought', 'think']),
    TagIconItem(id: 'alert', displayName: 'Urgent', icon: Icons.priority_high_rounded, category: TagIconCategory.symbols, keywords: ['urgent', 'warning', 'attention', 'critical']),
    TagIconItem(id: 'check', displayName: 'Check', icon: Icons.check_circle_rounded, category: TagIconCategory.symbols, keywords: ['done', 'complete', 'task', 'verified']),
    TagIconItem(id: 'lock', displayName: 'Locked', icon: Icons.lock_rounded, category: TagIconCategory.symbols, keywords: ['private', 'secure', 'confidential']),
    TagIconItem(id: 'sparkles', displayName: 'Sparkles', icon: Icons.auto_awesome_rounded, category: TagIconCategory.symbols, keywords: ['magic', 'new', 'special', 'polish']),
    TagIconItem(id: 'sun', displayName: 'Sun', icon: Icons.wb_sunny_rounded, category: TagIconCategory.symbols, keywords: ['day', 'summer', 'weather', 'morning']),
    TagIconItem(id: 'moon', displayName: 'Moon', icon: Icons.nightlight_round, category: TagIconCategory.symbols, keywords: ['night', 'sleep', 'evening', 'rest']),
    TagIconItem(id: 'clock', displayName: 'Clock', icon: Icons.schedule_rounded, category: TagIconCategory.symbols, keywords: ['time', 'history', 'schedule', 'reminder', 'due']),

    // Work
    TagIconItem(id: 'briefcase', displayName: 'Briefcase', icon: Icons.business_center_rounded, category: TagIconCategory.work, keywords: ['work', 'job', 'business', 'career']),
    TagIconItem(id: 'chart', displayName: 'Chart', icon: Icons.bar_chart_rounded, category: TagIconCategory.work, keywords: ['analytics', 'metrics', 'stats', 'growth', 'finance']),
    TagIconItem(id: 'calendar', displayName: 'Calendar', icon: Icons.calendar_month_rounded, category: TagIconCategory.work, keywords: ['date', 'meeting', 'event', 'planning', 'schedule']),
    TagIconItem(id: 'mail', displayName: 'Mail', icon: Icons.mail_rounded, category: TagIconCategory.work, keywords: ['email', 'letter', 'inbox', 'contact', 'communication']),
    TagIconItem(id: 'phone', displayName: 'Phone', icon: Icons.call_rounded, category: TagIconCategory.work, keywords: ['call', 'contact', 'mobile']),
    TagIconItem(id: 'receipt', displayName: 'Receipt', icon: Icons.receipt_long_rounded, category: TagIconCategory.work, keywords: ['invoice', 'bill', 'expense', 'tax', 'accounting']),
    TagIconItem(id: 'task', displayName: 'Tasks', icon: Icons.checklist_rounded, category: TagIconCategory.work, keywords: ['todo', 'action', 'plan', 'project']),

    // Education
    TagIconItem(id: 'book', displayName: 'Book', icon: Icons.book_rounded, category: TagIconCategory.education, keywords: ['read', 'novel', 'literature', 'library']),
    TagIconItem(id: 'reading', displayName: 'Reading', icon: Icons.menu_book_rounded, category: TagIconCategory.education, keywords: ['study', 'learn', 'knowledge', 'books']),
    TagIconItem(id: 'school_cap', displayName: 'Academy', icon: Icons.school_rounded, category: TagIconCategory.education, keywords: ['graduation', 'degree', 'course', 'study']),
    TagIconItem(id: 'pencil', displayName: 'Writing', icon: Icons.edit_note_rounded, category: TagIconCategory.education, keywords: ['notes', 'draft', 'journal', 'author', 'essay']),
    TagIconItem(id: 'library', displayName: 'Library', icon: Icons.local_library_rounded, category: TagIconCategory.education, keywords: ['books', 'archive', 'reference', 'research']),
    TagIconItem(id: 'science', displayName: 'Science', icon: Icons.science_rounded, category: TagIconCategory.education, keywords: ['lab', 'experiment', 'chemistry', 'research']),
    TagIconItem(id: 'article', displayName: 'Article', icon: Icons.article_rounded, category: TagIconCategory.education, keywords: ['paper', 'document', 'essay', 'blog']),

    // Technology
    TagIconItem(id: 'computer', displayName: 'Computer', icon: Icons.laptop_rounded, category: TagIconCategory.technology, keywords: ['laptop', 'pc', 'hardware', 'desktop']),
    TagIconItem(id: 'code', displayName: 'Code', icon: Icons.code_rounded, category: TagIconCategory.technology, keywords: ['programming', 'dev', 'software', 'script', 'flutter', 'dart', 'python']),
    TagIconItem(id: 'terminal', displayName: 'Terminal', icon: Icons.terminal_rounded, category: TagIconCategory.technology, keywords: ['cli', 'bash', 'shell', 'console', 'command']),
    TagIconItem(id: 'phone_android', displayName: 'Mobile', icon: Icons.phone_android_rounded, category: TagIconCategory.technology, keywords: ['android', 'ios', 'app', 'smartphone']),
    TagIconItem(id: 'database', displayName: 'Database', icon: Icons.storage_rounded, category: TagIconCategory.technology, keywords: ['sql', 'data', 'backend', 'server', 'db']),
    TagIconItem(id: 'wifi', displayName: 'Network', icon: Icons.wifi_rounded, category: TagIconCategory.technology, keywords: ['internet', 'connection', 'web', 'online']),
    TagIconItem(id: 'cpu', displayName: 'Hardware', icon: Icons.memory_rounded, category: TagIconCategory.technology, keywords: ['cpu', 'processor', 'tech', 'system']),
    TagIconItem(id: 'cloud', displayName: 'Cloud', icon: Icons.cloud_rounded, category: TagIconCategory.technology, keywords: ['hosting', 'sync', 'remote', 'aws', 'storage']),
    TagIconItem(id: 'bug', displayName: 'Bug', icon: Icons.bug_report_rounded, category: TagIconCategory.technology, keywords: ['issue', 'fix', 'error', 'testing', 'debug']),

    // Lifestyle
    TagIconItem(id: 'coffee', displayName: 'Coffee', icon: Icons.coffee_rounded, category: TagIconCategory.lifestyle, keywords: ['cafe', 'drink', 'morning', 'break']),
    TagIconItem(id: 'restaurant', displayName: 'Food & Cooking', icon: Icons.restaurant_rounded, category: TagIconCategory.lifestyle, keywords: ['recipe', 'food', 'cooking', 'dinner', 'lunch', 'kitchen']),
    TagIconItem(id: 'shopping', displayName: 'Shopping', icon: Icons.shopping_bag_rounded, category: TagIconCategory.lifestyle, keywords: ['buy', 'store', 'cart', 'goods', 'wishlist']),
    TagIconItem(id: 'pet', displayName: 'Pet', icon: Icons.pets_rounded, category: TagIconCategory.lifestyle, keywords: ['dog', 'cat', 'animal', 'puppy']),
    TagIconItem(id: 'health', displayName: 'Health', icon: Icons.medical_services_rounded, category: TagIconCategory.lifestyle, keywords: ['medical', 'doctor', 'medicine', 'hospital']),
    TagIconItem(id: 'flower', displayName: 'Nature & Garden', icon: Icons.local_florist_rounded, category: TagIconCategory.lifestyle, keywords: ['plant', 'garden', 'flower', 'botany']),
    TagIconItem(id: 'car', displayName: 'Automotive', icon: Icons.directions_car_rounded, category: TagIconCategory.lifestyle, keywords: ['drive', 'auto', 'vehicle', 'transport']),
  ];

  static TagIconItem? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    final normalized = id.toLowerCase().trim();
    for (final item in all) {
      if (item.id == normalized) return item;
    }
    return null;
  }

  static IconData getIconData(String? id, {IconData fallback = Icons.label_rounded}) {
    final item = fromId(id);
    return item?.icon ?? fallback;
  }

  /// Lightweight deterministic icon suggestion based on tag name.
  static List<TagIconItem> suggestIcons(String rawTagName) {
    final clean = rawTagName.trim().toLowerCase().replaceAll('#', '');
    if (clean.isEmpty) return const [];

    final suggestions = <TagIconItem>{};

    for (final item in all) {
      if (item.id == clean || clean.contains(item.id) || item.id.contains(clean)) {
        suggestions.add(item);
      }
      for (final kw in item.keywords) {
        if (clean == kw || clean.contains(kw) || kw.contains(clean)) {
          suggestions.add(item);
          break;
        }
      }
      if (suggestions.length >= 6) break;
    }

    return suggestions.toList();
  }
}
