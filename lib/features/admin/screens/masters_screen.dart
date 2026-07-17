import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/notes/models/note.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';

final purposesMasterProvider = FutureProvider<List<PurposeMaster>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  return [
    const PurposeMaster(id: '1', name: 'Capital Expenditure', isActive: true),
    const PurposeMaster(id: '2', name: 'Operational Expenditure', isActive: true),
    const PurposeMaster(id: '3', name: 'Policy Change', isActive: true),
    const PurposeMaster(id: '4', name: 'Process Improvement', isActive: true),
    const PurposeMaster(id: '5', name: 'Vendor Empanelment', isActive: true),
    const PurposeMaster(id: '6', name: 'Hiring Approval', isActive: true),
    const PurposeMaster(id: '7', name: 'IT Infrastructure', isActive: false),
    const PurposeMaster(id: '8', name: 'Regulatory Compliance', isActive: true),
  ];
});

class MastersScreen extends ConsumerWidget {
  const MastersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purposesAsync = ref.watch(purposesMasterProvider);

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
                  Text('Purpose Masters',
                      style: GoogleFonts.bricolageGrotesque(
                        color: AppColors.txt,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      )),
                  const Text('Manage Purpose/Objective dropdown values',
                      style: TextStyle(color: AppColors.txt3, fontSize: 14)),
                ],
              ),
              const Spacer(),
              GradientButton(
                label: 'Add Purpose',
                icon: Icons.add_rounded,
                onPressed: () => _showPurposeDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: purposesAsync.when(
              data: (items) => _PurposesList(items: items),
              loading: () => Column(
                children: List.generate(8,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: ShimmerCard(height: 56),
                    )),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: AppColors.bad)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPurposeDialog(BuildContext context, [PurposeMaster? item]) {
    final nameCtrl = TextEditingController(text: item?.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item == null ? 'Add Purpose' : 'Edit Purpose'),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: nameCtrl,
            autofocus: true,
            style: const TextStyle(color: AppColors.txt),
            decoration: const InputDecoration(labelText: 'Purpose Name *'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          GradientButton(
            label: item == null ? 'Add' : 'Save',
            small: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _PurposesList extends StatelessWidget {
  const _PurposesList({required this.items});
  final List<PurposeMaster> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header
            Container(
              color: AppColors.surface2,
              child: const Row(
                children: [
                  Expanded(child: _TH('Purpose Name')),
                  SizedBox(width: 100, child: _TH('Status')),
                  SizedBox(width: 80, child: _TH('')),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Text(item.name,
                                style: const TextStyle(
                                    color: AppColors.txt, fontSize: 14)),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Switch(
                              value: item.isActive,
                              onChanged: (_) {},
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18, color: AppColors.txt3),
                              onPressed: () {},
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TH extends StatelessWidget {
  const _TH(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.txt3,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
