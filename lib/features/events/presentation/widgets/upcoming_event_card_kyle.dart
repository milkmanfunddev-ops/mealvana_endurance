import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../domain/event.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../screens/events_list_screen.dart';
import '../screens/event_detail_screen.dart';

/// Upcoming event card widget matching Kyle's design
///
/// Displays the next upcoming event with:
/// - Event icon (36px Electrolyte circle)
/// - Event name and countdown
/// - Date display on the right
///
/// Specifications:
/// - Border radius: 15px
/// - Icon: 36px circle, Electrolyte background, Blackberry icon
/// - Title: Compadre, 16px
/// - Details: Apercu, 12px
/// - Margins: 16px horizontal, 8px vertical
///
/// Example:
/// ```dart
/// UpcomingEventCardKyle(
///   upcomingEventData: (event: event, eventDate: date),
/// )
/// ```
class UpcomingEventCardKyle extends ConsumerWidget {
  final ({Event event, DateTime eventDate})? upcomingEventData;

  const UpcomingEventCardKyle({
    super.key,
    required this.upcomingEventData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Show "No upcoming events" card if no event exists
    if (upcomingEventData == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.blackberryLight : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: (isDark ? AppColors.cream : AppColors.blackberry)
                .withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const EventsListScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Event icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.cream : AppColors.blackberry)
                        .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FontAwesomeIcons.calendarDay,
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                // Event details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create an Event',
                        style: TextStyle(
                          fontFamily: 'Compadre',
                          fontSize: 16,
                          color: (isDark ? AppColors.cream : AppColors.blackberry)
                              .withValues(alpha: 0.7),
                          height: 1.3,
                        ),
                      ),
                      // const SizedBox(height: 4),
                      // Text(
                      //   'Tap to add a race event',
                      //   style: TextStyle(
                      //     fontFamily: 'Apercu',
                      //     fontSize: 12,
                      //     color: (isDark ? AppColors.cream : AppColors.blackberry)
                      //         .withValues(alpha: 0.5),
                      //     height: 1.3,
                      //   ),
                      // ),
                    ],
                  ),
                ),
                // Chevron
                Icon(
                  Icons.chevron_right,
                  color: (isDark ? AppColors.cream : AppColors.blackberry)
                      .withValues(alpha: 0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final event = upcomingEventData!.event;
    final eventDate = upcomingEventData!.eventDate;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberryLight : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: (isDark ? AppColors.cream : AppColors.blackberry)
              .withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(
                eventId: event.id,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Event icon
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.electrolyte,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FontAwesomeIcons.trophy,
                  color: AppColors.blackberry,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (event.eventName ?? event.formattedEventType).toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Compadre',
                        fontSize: 11,
                        letterSpacing: 1.0,
                        color: isDark ? AppColors.cream : AppColors.blackberry,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCountdown(eventDate),
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 10,
                        color: (isDark ? AppColors.cream : AppColors.blackberry).withValues(alpha: 0.5),
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Date display on the right
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMM').format(eventDate).toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Apercu',
                      fontSize: 8,
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                      fontWeight: FontWeight.w600,
                      height: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d').format(eventDate),
                    style: TextStyle(
                      fontFamily: 'Compadre',
                      fontSize: 20,
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                      fontWeight: FontWeight.w400,
                      height: 0.9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCountdown(DateTime eventDate) {
    final now = DateTime.now();
    final difference = eventDate.difference(now);

    if (difference.isNegative) {
      return 'Event passed';
    }

    if (difference.inDays == 0) {
      return 'Today!';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days away';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} away';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} away';
    }
  }
}
