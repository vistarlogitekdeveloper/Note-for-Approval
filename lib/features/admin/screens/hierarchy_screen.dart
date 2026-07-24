import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/notes/models/note.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';

final hierarchyProvider = FutureProvider<List<HierarchyRole>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return [
    const HierarchyRole(id: '1', level: 1, name: 'Department Head', description: 'HOD of initiator\'s department'),
    const HierarchyRole(id: '2', level: 2, name: 'General Manager', description: 'GM of the business unit'),
    const HierarchyRole(id: '3', level: 3, name: 'Vice President', description: 'VP Operations'),
    const HierarchyRole(id: '4', level: 4, name: 'Senior VP', description: 'Senior Vice President'),
    const HierarchyRole(id: '5', level: 5, name: 'Director', description: 'Director of Operations'),
    const HierarchyRole(id: '6', level: 6, name: 'Chief Operating Officer', description: 'COO'),
    const HierarchyRole(id: '7', level: 7, name: 'Chief Executive Officer', description: 'CEO'),
    const HierarchyRole(id: '8', level: 8, name: 'Managing Director', description: 'MD / Board'),
  ];
});

class HierarchyScreen extends ConsumerWidget {
  const HierarchyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hierarchyAsync = ref.watch(hierarchyProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Approval Hierarchy',
                      style: GoogleFonts.bricolageGrotesque(
                        color: context.c.txt,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      )),
                  Text('Define and reorder the sequential approval levels',
                      style: TextStyle(color: context.c.txt3, fontSize: 14)),
                ],
              ),
              const Spacer(),
              GradientButton(
                label: 'Add Level',
                icon: Icons.add_rounded,
                onPressed: () => _showLevelDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: context.c.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.c.info.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.c.info, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Notes flow sequentially through these levels. Drag to reorder. Minimum 8 levels required.',
                    style: TextStyle(color: context.c.txt2, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: hierarchyAsync.when(
              data: (roles) => _HierarchyList(roles: roles),
              loading: () => ListView(
                children: List.generate(8,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: ShimmerCard(height: 70),
                    )),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: TextStyle(color: context.c.bad)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLevelDialog(BuildContext context, [HierarchyRole? role]) {
    final nameCtrl = TextEditingController(text: role?.name);
    final descCtrl = TextEditingController(text: role?.description);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(role == null ? 'Add Hierarchy Level' : 'Edit Level'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: context.c.txt),
                decoration: const InputDecoration(labelText: 'Role Name *'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descCtrl,
                style: TextStyle(color: context.c.txt),
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          GradientButton(
            label: role == null ? 'Add' : 'Save',
            small: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _HierarchyList extends StatefulWidget {
  const _HierarchyList({required this.roles});
  final List<HierarchyRole> roles;

  @override
  State<_HierarchyList> createState() => _HierarchyListState();
}

class _HierarchyListState extends State<_HierarchyList> {
  late List<HierarchyRole> _roles;

  @override
  void initState() {
    super.initState();
    _roles = List.from(widget.roles);
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _roles.removeAt(oldIndex);
          _roles.insert(newIndex, item);
        });
      },
      itemCount: _roles.length,
      itemBuilder: (ctx, i) {
        final role = _roles[i];
        return Padding(
          key: ValueKey(role.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: _HierarchyCard(role: role, index: i, dragIndex: i),
        );
      },
    );
  }
}

class _HierarchyCard extends StatelessWidget {
  const _HierarchyCard({
    required this.role,
    required this.index,
    required this.dragIndex,
  });
  final HierarchyRole role;
  final int index;
  final int dragIndex;

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      child: Row(
        children: [
          // Level badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.ribbon,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: GoogleFonts.bricolageGrotesque(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.name,
                  style: TextStyle(
                    color: context.c.txt,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (role.description != null)
                  Text(
                    role.description!,
                    style: TextStyle(
                        color: context.c.txt3, fontSize: 13),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: role.isActive
                  ? context.c.ok.withValues(alpha: 0.1)
                  : context.c.surface3,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              role.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: role.isActive ? context.c.ok : context.c.txt3,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: Icon(Icons.edit_outlined,
                color: context.c.txt3, size: 18),
            onPressed: () {},
          ),
          ReorderableDragStartListener(
            index: dragIndex,
            child: Icon(
              Icons.drag_handle_rounded,
              color: context.c.txt3,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
