import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class MultiWorkspaceChatScreen extends StatefulWidget {
  const MultiWorkspaceChatScreen({super.key});

  @override
  State<MultiWorkspaceChatScreen> createState() => _MultiWorkspaceChatScreenState();
}

class _MultiWorkspaceChatScreenState extends State<MultiWorkspaceChatScreen> {
  bool _isScopeExpanded = true;
  bool _engChecked = true;
  bool _marketingChecked = true;
  bool _feedbackChecked = true;
  final bool _hrChecked = false;

  int _getSelectedCount() {
    int count = 0;
    if (_engChecked) count++;
    if (_marketingChecked) count++;
    if (_feedbackChecked) count++;
    if (_hrChecked) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCount = _getSelectedCount();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, size: 18, color: colors.textSecondary),
          tooltip: 'All Workspaces',
          onPressed: () => context.go('/'),
        ),
        title: Text(
          'Universal Search',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colors.divider),
        ),
      ),
      body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                children: [
                  // Universal Search Scope Header Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF202020) : Colors.white,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // Card Header Row
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isScopeExpanded = !_isScopeExpanded;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.manage_search_rounded, size: 18, color: colors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Universal Search Scope',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF1F1EF),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$selectedCount Selected',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  _isScopeExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                  size: 18,
                                  color: colors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Expanded grid panel
                        if (_isScopeExpanded) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 12,
                              childAspectRatio: 4.5,
                              children: [
                                // Checkbox 1
                                _buildScopeCheckbox(
                                  context: context,
                                  value: _engChecked,
                                  title: 'Engineering Docs',
                                  subtitle: 'Last updated 2h ago',
                                  hasLock: true,
                                  onChanged: (val) {
                                    setState(() {
                                      _engChecked = val ?? false;
                                    });
                                  },
                                ),
                                // Checkbox 2
                                _buildScopeCheckbox(
                                  context: context,
                                  value: _marketingChecked,
                                  title: 'Q3 Marketing Plans',
                                  subtitle: 'Last updated yesterday',
                                  onChanged: (val) {
                                    setState(() {
                                      _marketingChecked = val ?? false;
                                    });
                                  },
                                ),
                                // Checkbox 3
                                _buildScopeCheckbox(
                                  context: context,
                                  value: _feedbackChecked,
                                  title: 'Customer Feedback 2023',
                                  subtitle: '14,203 records',
                                  onChanged: (val) {
                                    setState(() {
                                      _feedbackChecked = val ?? false;
                                    });
                                  },
                                ),
                                // Checkbox 4 (HR - Restricted)
                                _buildScopeCheckbox(
                                  context: context,
                                  value: _hrChecked,
                                  title: 'HR Policies',
                                  subtitle: 'Restricted access',
                                  hasLock: true,
                                  isDisabled: true,
                                  onChanged: null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Kivo Copilot Message Block
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'K',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Kivo Copilot',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Comparison response box
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF202020) : Colors.white,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Based on the documents across your selected workspaces, there is a slight misalignment between the technical implementation and the public messaging regarding the v2 API.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: colors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Quote Block 1: Engineering
                        _buildQuoteBlock(
                          context: context,
                          color: colors.primary,
                          title: 'Engineering Implementation',
                          content: 'The Engineering Docs indicate that the v2 API will primarily support REST protocols initially, with GraphQL support delayed to Q4.',
                          tags: ['ENG-12', 'ENG-45'],
                        ),
                        const SizedBox(height: 14),

                        // Quote Block 2: Marketing
                        _buildQuoteBlock(
                          context: context,
                          color: Colors.orange.shade300,
                          title: 'Marketing Messaging',
                          content: 'However, the Q3 Marketing Plans highlight "Full GraphQL Support from Day 1" as a core selling point for the enterprise tier.',
                          tags: ['MKT-03'],
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'Customer feedback from 2023 suggests that 68% of enterprise clients requested GraphQL [FB-102], which likely drove the marketing push, but engineering timelines have since shifted.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: colors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Sources used row
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'SOURCES USED: ',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontFamily: 'IBM Plex Mono',
                                fontWeight: FontWeight.w700,
                                color: colors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildSourcePill(context, 'API_v2_Roadmap.md'),
                            const SizedBox(width: 8),
                            _buildSourcePill(context, 'Enterprise_Launch_Deck.pdf'),
                            const SizedBox(width: 8),
                            _buildSourcePill(context, 'Survey_Results_23.csv'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Chat Input Box
            Container(
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF202020) : const Color(0xFFFBFBFA),
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.attach_file_rounded, size: 18, color: colors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Ask across all selected workspaces...',
                          hintStyle: TextStyle(color: colors.textMuted, fontSize: 13.5),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Scope Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.layers_outlined, size: 12, color: colors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Universal Scope',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.white),
                      onPressed: () {},
                      style: IconButton.styleFrom(
                        backgroundColor: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildScopeCheckbox({
    required BuildContext context,
    required bool value,
    required String title,
    required String subtitle,
    bool hasLock = false,
    bool isDisabled = false,
    required ValueChanged<bool?>? onChanged,
  }) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: value,
            onChanged: isDisabled ? null : onChanged,
            activeColor: colors.primary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDisabled ? colors.textMuted : colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasLock) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock_outline_rounded, size: 12, color: colors.textMuted),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteBlock({
    required BuildContext context,
    required Color color,
    required String title,
    required String content,
    required List<String> tags,
  }) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              ...tags.map((t) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF1F1EF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'IBM Plex Mono',
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePill(BuildContext context, String filename) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFFBFBFA),
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 12, color: colors.textSecondary),
          const SizedBox(width: 6),
          Text(
            filename,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
