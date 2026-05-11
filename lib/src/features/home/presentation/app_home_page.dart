import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/wicara_colors.dart';
import '../../../core/widgets/gradient_button.dart';

enum _HomeTab { home, queue, progress, profile }

enum _QueueTab { recommended, tracks }

class AppHomePage extends StatefulWidget {
  const AppHomePage({super.key});

  @override
  State<AppHomePage> createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage> {
  _HomeTab _selectedTab = _HomeTab.home;
  _QueueTab _queueTab = _QueueTab.recommended;

  void _openQueue([_QueueTab tab = _QueueTab.recommended]) {
    setState(() {
      _queueTab = tab;
      _selectedTab = _HomeTab.queue;
    });
  }

  void _openHome() {
    setState(() => _selectedTab = _HomeTab.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pageWidth = math.min(constraints.maxWidth, 430.0);

            return Center(
              child: SizedBox(
                width: pageWidth,
                child: Stack(
                  children: [
                    Positioned.fill(child: _tabView(constraints)),
                    Positioned(
                      left: 28,
                      right: 28,
                      bottom: 18,
                      child: _ShortcutBar(
                        selectedTab: _selectedTab,
                        onSelected: (tab) => setState(() => _selectedTab = tab),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tabView(BoxConstraints constraints) {
    return switch (_selectedTab) {
      _HomeTab.home => _HomeDashboard(
        constraints: constraints,
        onOpenQueue: () => _openQueue(),
        onOpenTracks: () => _openQueue(_QueueTab.tracks),
      ),
      _HomeTab.queue => _LearningQueue(
        constraints: constraints,
        selectedTab: _queueTab,
        onTabChanged: (tab) => setState(() => _queueTab = tab),
        onBack: _openHome,
      ),
      _HomeTab.progress => _ProgressHub(
        constraints: constraints,
        onBack: _openHome,
      ),
      _HomeTab.profile => _ProfilePage(
        constraints: constraints,
        onBack: _openHome,
      ),
    };
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.constraints,
    required this.onOpenQueue,
    required this.onOpenTracks,
  });

  final BoxConstraints constraints;
  final VoidCallback onOpenQueue;
  final VoidCallback onOpenTracks;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 136),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MiniWordmark(),
            const SizedBox(height: 38),
            Text(
              'Welcome back, Aisha 👋',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 23, height: 1.12),
            ),
            const SizedBox(height: 7),
            Text(
              'Your path adapts. You grow.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 35),
            _ExploreTracksCard(onOpenTracks: onOpenTracks),
            const SizedBox(height: 20),
            _TodayQueueCard(onViewAll: onOpenQueue),
            const SizedBox(height: 25),
            const _StreakCard(),
            const SizedBox(height: 24),
            const _DailyEvaluationCard(),
            const SizedBox(height: 24),
            const _MasteryOverviewCard(),
          ],
        ),
      ),
    );
  }
}

class _LearningQueue extends StatelessWidget {
  const _LearningQueue({
    required this.constraints,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onBack,
  });

  final BoxConstraints constraints;
  final _QueueTab selectedTab;
  final ValueChanged<_QueueTab> onTabChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 132),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QueueHeader(onBack: onBack),
            const SizedBox(height: 42),
            Text(
              'Calculus I',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 24, height: 1.12),
            ),
            const SizedBox(height: 9),
            Text(
              "Your current big topic. WICARA recommends the next steps inside this track.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 28),
            _QueueTabs(selectedTab: selectedTab, onChanged: onTabChanged),
            const SizedBox(height: 28),
            if (selectedTab == _QueueTab.recommended)
              const _RecommendedQueueContent()
            else
              const _TracksQueueContent(),
          ],
        ),
      ),
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left_rounded),
          iconSize: 33,
          color: WicaraColors.ink,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        ),
      ],
    );
  }
}

class _TodayQueueCard extends StatelessWidget {
  const _TodayQueueCard({required this.onViewAll});

  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's learning queue",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View all',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: WicaraColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SoftBadge('Next up'),
                    const SizedBox(height: 11),
                    Text(
                      'Limits from graphs',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Calculus I',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Estimated 18 min   •   Medium',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.softMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const _LessonGlyph(text: 'lim', size: 73),
            ],
          ),
          const SizedBox(height: 24),
          GradientButton(label: 'Continue session', onPressed: () {}),
        ],
      ),
    );
  }
}

class _ExploreTracksCard extends StatelessWidget {
  const _ExploreTracksCard({required this.onOpenTracks});

  final VoidCallback onOpenTracks;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: WicaraColors.secondarySoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.explore_outlined,
              color: WicaraColors.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Want to learn something new?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Explore tracks you have created or start another one.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onOpenTracks,
            style: TextButton.styleFrom(
              foregroundColor: WicaraColors.secondary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Explore'),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(19, 18, 19, 18),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current streak',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '7 days',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 166, child: _WeekDots()),
        ],
      ),
    );
  }
}

class _DailyEvaluationCard extends StatefulWidget {
  const _DailyEvaluationCard();

  @override
  State<_DailyEvaluationCard> createState() => _DailyEvaluationCardState();
}

class _DailyEvaluationCardState extends State<_DailyEvaluationCard> {
  int? _score = 3;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Daily evaluation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            "Today's topic: Calculus I. Pick a confidence score if you want, then take your daily check.",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 21),
          Row(
            children: [
              for (var score = 1; score <= 5; score++) ...[
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _score = score),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 39,
                      decoration: BoxDecoration(
                        color: score == _score
                            ? WicaraColors.secondary
                            : WicaraColors.speechBlue,
                        borderRadius: BorderRadius.circular(10),
                        border: score == _score
                            ? null
                            : Border.all(color: WicaraColors.line),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$score',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: score == _score
                              ? Colors.white
                              : WicaraColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                if (score < 5) const SizedBox(width: 11),
              ],
            ],
          ),
          const SizedBox(height: 17),
          SizedBox(
            height: 16,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Not confident',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Very confident',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(label: 'Take Daily Evaluation', onPressed: () {}),
        ],
      ),
    );
  }
}

class _MasteryOverviewCard extends StatelessWidget {
  const _MasteryOverviewCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 21),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mastery overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'View details',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: WicaraColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _MasteryRow(
            label: 'Algebra',
            value: 0.72,
            percent: '72%',
            status: 'Good',
          ),
          const SizedBox(height: 17),
          const _MasteryRow(
            label: 'Calculus',
            value: 0.58,
            percent: '58%',
            status: 'Growing',
          ),
          const SizedBox(height: 17),
          const _MasteryRow(
            label: 'Functions',
            value: 0.84,
            percent: '84%',
            status: 'Strong',
          ),
        ],
      ),
    );
  }
}

class _QueueTabs extends StatelessWidget {
  const _QueueTabs({required this.selectedTab, required this.onChanged});

  final _QueueTab selectedTab;
  final ValueChanged<_QueueTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _QueueTabButton(
              label: 'Recommended',
              isSelected: selectedTab == _QueueTab.recommended,
              onTap: () => onChanged(_QueueTab.recommended),
            ),
          ),
          Expanded(
            child: _QueueTabButton(
              label: 'Tracks',
              isSelected: selectedTab == _QueueTab.tracks,
              onTap: () => onChanged(_QueueTab.tracks),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueTabButton extends StatelessWidget {
  const _QueueTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSelected ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: WicaraColors.shadowBlue.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isSelected ? WicaraColors.text : WicaraColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendedQueueContent extends StatelessWidget {
  const _RecommendedQueueContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PriorityCallout(),
        SizedBox(height: 22),
        _QueueLessonCard(
          index: '1',
          badge: 'Next up',
          title: 'Limits from graphs',
          subject: 'Calculus I',
          reason:
              'Why now? This unlocks continuity and\nfirst derivative intuition.',
          meta: '18 min   •   Medium',
          action: 'Continue',
          iconText: 'lim',
          isPrimary: true,
        ),
        SizedBox(height: 20),
        _QueueLessonCard(
          index: '2',
          title: 'Derivative rules',
          subject: 'Calculus',
          reason:
              "Why now? You're ready after limits and\nslope interpretation.",
          meta: '24 min   •   Hard',
          action: 'Continue',
          iconText: 'd\ndx',
        ),
        SizedBox(height: 20),
        _QueueLessonCard(
          index: '3',
          title: 'Function composition review',
          subject: 'Prerequisite',
          reason:
              'Why now? Needed before chain rule and\nimplicit differentiation.',
          meta: '12 min   •   Easy',
          action: 'Review',
          iconData: Icons.event_note_outlined,
        ),
      ],
    );
  }
}

class _TracksQueueContent extends StatelessWidget {
  const _TracksQueueContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NewTrackCard(),
        SizedBox(height: 22),
        _TrackCard(
          title: 'Continue Calculus I',
          subtitle: 'Limits, derivatives, applications',
          meta: 'Current track   •   58% complete',
          icon: Icons.show_chart_rounded,
          color: WicaraColors.secondary,
        ),
        SizedBox(height: 12),
        _TrackCard(
          title: 'Linear Algebra',
          subtitle: 'Vectors, matrices, transformations',
          meta: 'Created track   •   12% complete',
          icon: Icons.grid_4x4_rounded,
          color: WicaraColors.primary,
        ),
        SizedBox(height: 12),
        _TrackCard(
          title: 'Discrete Math',
          subtitle: 'Logic, sets, graphs, counting',
          meta: 'Created track   •   ready to continue',
          icon: Icons.hub_outlined,
          color: WicaraColors.accentCoral,
        ),
      ],
    );
  }
}

class _PriorityCallout extends StatelessWidget {
  const _PriorityCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(19, 18, 19, 18),
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: WicaraColors.secondary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.wb_sunny_outlined,
            color: WicaraColors.secondary,
            size: 21,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "Recommended for Calculus I based on\nyour current gaps and readiness.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w600,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueLessonCard extends StatelessWidget {
  const _QueueLessonCard({
    required this.index,
    required this.title,
    required this.subject,
    required this.reason,
    required this.meta,
    required this.action,
    this.badge,
    this.iconText,
    this.iconData,
    this.isPrimary = false,
  });

  final String index;
  final String title;
  final String subject;
  final String reason;
  final String meta;
  final String action;
  final String? badge;
  final String? iconText;
  final IconData? iconData;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (index.isNotEmpty) ...[
                      _NumberBadge(index),
                      const SizedBox(width: 10),
                    ],
                    if (badge != null) _SoftBadge(badge!),
                  ],
                ),
                if (index.isNotEmpty || badge != null)
                  const SizedBox(height: 11),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 18, height: 1.15),
                ),
                const SizedBox(height: 7),
                Text(
                  subject,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    reason,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meta,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: WicaraColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (action.isNotEmpty)
                      _SmallActionButton(label: action, filled: isPrimary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          _LessonGlyph(text: iconText, icon: iconData, size: 64),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({required this.label, required this.filled});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      width: 112,
      decoration: BoxDecoration(
        color: filled ? WicaraColors.secondary : Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: filled
            ? null
            : Border.all(
                color: WicaraColors.secondary.withValues(alpha: 0.34),
                width: 1.4,
              ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: filled ? Colors.white : WicaraColors.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.text,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: _TrackActionButton(filled: title == 'Continue Calculus I'),
          ),
        ],
      ),
    );
  }
}

class _TrackActionButton extends StatelessWidget {
  const _TrackActionButton({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 39,
      constraints: const BoxConstraints(minWidth: 154),
      padding: const EdgeInsets.symmetric(horizontal: 17),
      decoration: BoxDecoration(
        color: filled ? WicaraColors.secondary : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: filled
            ? null
            : Border.all(
                color: WicaraColors.secondary.withValues(alpha: 0.34),
                width: 1.4,
              ),
      ),
      alignment: Alignment.center,
      child: Text(
        'Continue Learning',
        maxLines: 1,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: filled ? Colors.white : WicaraColors.secondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NewTrackCard extends StatelessWidget {
  const _NewTrackCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: WicaraColors.glowPeach,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: WicaraColors.accentCoral,
                  size: 29,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learn something new',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Create a new track outside your current list.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerRight,
            child: _NewTrackActionButton(),
          ),
        ],
      ),
    );
  }
}

class _NewTrackActionButton extends StatelessWidget {
  const _NewTrackActionButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 39,
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 17),
      decoration: BoxDecoration(
        color: WicaraColors.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        'New track',
        maxLines: 1,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShortcutBar extends StatelessWidget {
  const _ShortcutBar({required this.selectedTab, required this.onSelected});

  final _HomeTab selectedTab;
  final ValueChanged<_HomeTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: WicaraColors.line, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          _ShortcutItem(
            tab: _HomeTab.home,
            selectedTab: selectedTab,
            icon: Icons.home_rounded,
            label: 'Home',
            onSelected: onSelected,
          ),
          _ShortcutItem(
            tab: _HomeTab.queue,
            selectedTab: selectedTab,
            icon: Icons.format_list_bulleted_rounded,
            label: 'Queue',
            onSelected: onSelected,
          ),
          _ShortcutItem(
            tab: _HomeTab.progress,
            selectedTab: selectedTab,
            icon: Icons.bar_chart_rounded,
            label: 'Progress',
            onSelected: onSelected,
          ),
          _ShortcutItem(
            tab: _HomeTab.profile,
            selectedTab: selectedTab,
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  const _ShortcutItem({
    required this.tab,
    required this.selectedTab,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final _HomeTab tab;
  final _HomeTab selectedTab;
  final IconData icon;
  final String label;
  final ValueChanged<_HomeTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = tab == selectedTab;
    final color = isSelected ? WicaraColors.secondary : WicaraColors.muted;

    return Expanded(
      child: InkWell(
        onTap: () => onSelected(tab),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.constraints, required this.onBack});

  final BoxConstraints constraints;
  final VoidCallback onBack;

  void _logout(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 136),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QueueHeader(onBack: onBack),
            const SizedBox(height: 38),
            Text(
              'Profile',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 24, height: 1.12),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your learning preferences and account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            const _ProfileHeaderCard(),
            const SizedBox(height: 22),
            const _ProfileSection(
              title: 'Learning setup',
              children: [
                _ProfileSettingTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Full name',
                  value: 'Aisyah Putri',
                ),
                _ProfileSettingTile(
                  icon: Icons.public_rounded,
                  label: 'Country',
                  value: 'Indonesia',
                ),
                _ProfileSettingTile(
                  icon: Icons.school_outlined,
                  label: 'Grade level',
                  value: 'Grade 11 (SMA Kelas 2)',
                ),
                _ProfileSettingTile(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  value: 'Bahasa Indonesia',
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _ProfileSection(
              title: 'Preferences',
              children: [
                _ProfileSettingTile(
                  icon: Icons.menu_book_outlined,
                  label: 'Subjects',
                  value: 'Math, Physics, Chemistry, Biology',
                ),
                _ProfileSettingTile(
                  icon: Icons.track_changes_rounded,
                  label: 'Study goal',
                  value: 'Improve understanding',
                ),
                _ProfileSettingTile(
                  icon: Icons.schedule_rounded,
                  label: 'Daily study time',
                  value: '30-60 minutes',
                ),
              ],
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => _logout(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WicaraColors.line, width: 1.4),
                foregroundColor: const Color(0xFFE57373),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: WicaraColors.secondarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              'AP',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: WicaraColors.secondaryDeep,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aisyah Putri',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Learner',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileSettingTile extends StatelessWidget {
  const _ProfileSettingTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: WicaraColors.speechBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: WicaraColors.secondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: WicaraColors.softMuted,
            size: 24,
          ),
        ],
      ),
    );
  }
}

class _ProgressHub extends StatelessWidget {
  const _ProgressHub({required this.constraints, required this.onBack});

  final BoxConstraints constraints;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 136),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QueueHeader(onBack: onBack),
            const SizedBox(height: 38),
            Text(
              'Progress',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 24, height: 1.12),
            ),
            const SizedBox(height: 8),
            Text(
              'Start with your learning report, then explore the knowledge map.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 28),
            const _LearningReportOption(),
            const SizedBox(height: 22),
            const _KnowledgeMapOption(),
          ],
        ),
      ),
    );
  }
}

class _LearningReportOption extends StatelessWidget {
  const _LearningReportOption();

  @override
  Widget build(BuildContext context) {
    return _ProgressOptionPanel(
      icon: Icons.analytics_outlined,
      iconColor: WicaraColors.secondary,
      iconBackground: WicaraColors.secondarySoft,
      title: 'Learning Report',
      subtitle: 'Weekly performance, fixed gaps, unlocked concepts.',
      action: 'View report',
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'May 12 - May 18, 2025',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WicaraColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _SoftBadge('+4 fixed'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                _ReportBarGroup(label: 'Overall', before: 0.72, after: 0.88),
                SizedBox(width: 18),
                _ReportBarGroup(
                  label: 'Application',
                  before: 0.65,
                  after: 0.85,
                ),
                SizedBox(width: 18),
                _ReportBarGroup(label: 'Analysis', before: 0.58, after: 0.82),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Expanded(
                child: _ReportMetric(
                  label: 'Fixed gaps',
                  value: '12',
                  delta: '+4 this week',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _ReportMetric(
                  label: 'Remaining gaps',
                  value: '5',
                  delta: '-2 this week',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KnowledgeMapOption extends StatelessWidget {
  const _KnowledgeMapOption();

  @override
  Widget build(BuildContext context) {
    return _ProgressOptionPanel(
      icon: Icons.account_tree_outlined,
      iconColor: WicaraColors.primaryDeep,
      iconBackground: WicaraColors.primarySoft,
      title: 'Knowledge Map',
      subtitle: 'Visualize prerequisites, gaps, and next concepts.',
      action: 'Open map',
      child: SizedBox(
        height: 230,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _KnowledgeMapPainter()),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: _ConceptNode(
                label: 'Number\nSystem',
                status: 'MASTERED',
                color: WicaraColors.biology,
              ),
            ),
            const Positioned(
              left: 0,
              top: 78,
              child: _ConceptNode(
                label: 'Integers',
                status: 'MASTERED',
                color: WicaraColors.biology,
              ),
            ),
            const Positioned(
              right: 0,
              top: 78,
              child: _ConceptNode(
                label: 'Decimals',
                status: 'MASTERED',
                color: WicaraColors.biology,
              ),
            ),
            const Align(
              alignment: Alignment.center,
              child: _ConceptNode(
                label: 'Fractions',
                status: 'IN PROGRESS',
                color: WicaraColors.secondary,
                isActive: true,
              ),
            ),
            const Positioned(
              left: 32,
              bottom: 4,
              child: _ConceptNode(
                label: 'Ratios',
                status: 'REVIEW',
                color: WicaraColors.accentAmber,
              ),
            ),
            const Positioned(
              right: 32,
              bottom: 4,
              child: _ConceptNode(
                label: 'Functions',
                status: 'READY',
                color: WicaraColors.accentLilac,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressOptionPanel extends StatelessWidget {
  const _ProgressOptionPanel({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final String action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(19, 18, 19, 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: WicaraColors.softMuted,
                size: 25,
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              action,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: WicaraColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportBarGroup extends StatelessWidget {
  const _ReportBarGroup({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final double before;
  final double after;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ReportBar(value: before, color: WicaraColors.primaryLight),
                  const SizedBox(width: 6),
                  _ReportBar(value: after, color: WicaraColors.secondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportBar extends StatelessWidget {
  const _ReportBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: value,
      child: Container(
        width: 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
        ),
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final String delta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: WicaraColors.pageBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WicaraColors.line),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 23, height: 1),
          ),
          const SizedBox(height: 6),
          Text(
            delta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.accentMint,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConceptNode extends StatelessWidget {
  const _ConceptNode({
    required this.label,
    required this.status,
    required this.color,
    this.isActive = false,
  });

  final String label;
  final String status;
  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isActive ? 112 : 96,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isActive ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withValues(alpha: isActive ? 0.72 : 0.34),
          width: isActive ? 1.7 : 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.text,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeMapPainter extends CustomPainter {
  const _KnowledgeMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = WicaraColors.secondaryLight.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final top = Offset(size.width / 2, 46);
    final center = Offset(size.width / 2, size.height / 2 + 8);
    final left = Offset(size.width * 0.19, 104);
    final right = Offset(size.width * 0.81, 104);
    final lowerLeft = Offset(size.width * 0.31, size.height - 38);
    final lowerRight = Offset(size.width * 0.69, size.height - 38);

    canvas.drawLine(top, center, line);
    canvas.drawLine(left, center, line);
    canvas.drawLine(right, center, line);
    canvas.drawLine(center, lowerLeft, line);
    canvas.drawLine(center, lowerRight, line);

    final dotPaint = Paint()..color = WicaraColors.secondary;
    for (final point in [top, left, right, center, lowerLeft, lowerRight]) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: WicaraColors.line, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.12),
            blurRadius: 17,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniWordmark extends StatelessWidget {
  const _MiniWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CustomPaint(size: Size(51, 31), painter: _MiniMarkPainter()),
        const SizedBox(width: 13),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: 'WICARA'
              .split('')
              .map(
                (letter) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.7),
                  child: Text(
                    letter,
                    style: const TextStyle(
                      color: WicaraColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MiniMarkPainter extends CustomPainter {
  const _MiniMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paints = [
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = size.height * 0.45
        ..color = WicaraColors.secondary.withValues(alpha: 0.34),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = size.height * 0.45
        ..color = WicaraColors.secondaryLight.withValues(alpha: 0.62),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = size.height * 0.45
        ..color = WicaraColors.primary.withValues(alpha: 0.26),
    ];

    for (var i = 0; i < 3; i++) {
      final offset = i * size.width * 0.22;
      final path = Path()
        ..moveTo(size.width * 0.08 + offset, size.height * 0.24)
        ..cubicTo(
          size.width * 0.15 + offset,
          size.height * 0.65,
          size.width * 0.25 + offset,
          size.height * 0.75,
          size.width * 0.34 + offset,
          size.height * 0.72,
        )
        ..cubicTo(
          size.width * 0.43 + offset,
          size.height * 0.69,
          size.width * 0.45 + offset,
          size.height * 0.37,
          size.width * 0.52 + offset,
          size.height * 0.24,
        );
      canvas.drawPath(path, paints[i]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LessonGlyph extends StatelessWidget {
  const _LessonGlyph({this.text, this.icon, this.size = 64});

  final String? text;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: WicaraColors.secondary, size: size * 0.43)
          : Text(
              text ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: WicaraColors.secondary,
                fontSize: size * 0.32,
                fontWeight: FontWeight.w600,
                height: 0.9,
              ),
            ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: WicaraColors.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(13),
      ),
      alignment: Alignment.center,
      child: Text(
        value,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: WicaraColors.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WeekDots extends StatelessWidget {
  const _WeekDots();

  @override
  Widget build(BuildContext context) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    const alphas = [0.18, 0.28, 0.38, 0.5, 0.62, 0.78, 0.94];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < labels.length; i++)
          SizedBox(
            width: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: WicaraColors.secondary.withValues(alpha: alphas[i]),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({
    required this.label,
    required this.value,
    required this.percent,
    required this.status,
  });

  final String label;
  final double value;
  final String percent;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              color: WicaraColors.secondary,
              backgroundColor: WicaraColors.line,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 92,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '$percent   •   $status',
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
