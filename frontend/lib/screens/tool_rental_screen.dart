import 'package:flutter/material.dart';
import '../models/tool.dart';
import '../theme/colors.dart';
import '../widgets/layout.dart';
import '../widgets/ui/app_modal.dart';
import '../widgets/ui/buttons.dart';
import '../widgets/ui/cards.dart';
import '../widgets/ui/states.dart';

class ToolRentalScreen extends StatefulWidget {
  const ToolRentalScreen({super.key});

  @override
  State<ToolRentalScreen> createState() => _ToolRentalScreenState();
}

class _ToolRentalScreenState extends State<ToolRentalScreen> {
  final List<Tool> _tools = Tool.sampleData();
  String _category = 'All';

  List<String> get _categories {
    final cats = <String>{};
    for (final t in _tools) {
      cats.add(t.category);
    }
    return ['All', ...cats];
  }

  List<Tool> get _filtered =>
      _category == 'All' ? _tools : _tools.where((t) => t.category == _category).toList();

  void _openDetails(Tool tool) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ToolDetailScreen(tool: tool)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _tools.isEmpty
        ? const EmptyState(
            icon: Icons.agriculture,
            title: 'No tools available',
            subtitle: 'Tools listed by nearby farmers will appear here.',
          )
        : Column(
            children: [
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: _categories
                      .map((cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(cat, style: const TextStyle(fontSize: 12.5)),
                              selected: _category == cat,
                              onSelected: (_) => setState(() => _category = cat),
                              selectedColor: c.primaryLight,
                              side: BorderSide(color: _category == cat ? c.primary : c.border),
                              labelStyle: TextStyle(
                                color: _category == cat ? c.primaryDark : c.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 900) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 340,
                          mainAxisExtent: 170,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) => _ToolCard(
                          tool: _filtered[index],
                          onTap: () => _openDetails(_filtered[index]),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _ToolCard(
                        tool: _filtered[index],
                        onTap: () => _openDetails(_filtered[index]),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
  }
}

class _ToolCard extends StatelessWidget {
  final Tool tool;
  final VoidCallback onTap;

  const _ToolCard({required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(tool.emoji, style: const TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${tool.category} \u2022 ${tool.location}',
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          tool.ownerRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          tool.available ? Icons.check_circle : Icons.cancel,
                          size: 13,
                          color: tool.available ? c.positive : c.danger,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            tool.available ? 'Available' : 'Unavailable',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: tool.available ? c.positive : c.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '\u20B9${tool.pricePerDay}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: c.primary,
                    ),
                  ),
                  Text('/day', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  const SizedBox(height: 6),
                  Icon(Icons.chevron_right, color: c.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolDetailScreen extends StatefulWidget {
  final Tool tool;
  const _ToolDetailScreen({required this.tool});

  @override
  State<_ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends State<_ToolDetailScreen> {
  DateTimeRange? _range;
  int _duration = 1;
  String _address = 'Sangameshwar Nagar, Dharwad';
  String? _timeSlot = '07:00 \u2013 11:00 AM';

  String get _startText => _range == null
      ? 'Select dates'
      : '${_range!.start.day}/${_range!.start.month} \u2013 ${_range!.end.day}/${_range!.end.month}';

  double get _total {
    final base = widget.tool.pricePerDay * _duration + 200;
    final discount = widget.tool.ownerRating > 4.7 ? 100 : 0;
    return (base - discount).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent a Tool'),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: ThemeToggle())],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: c.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: Text(widget.tool.emoji, style: const TextStyle(fontSize: 32))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tool.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      '${widget.tool.category} \u2022 ${widget.tool.location}',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 15, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.tool.ownerRating} (12 reviews)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Text(
              widget.tool.description,
              style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Select rental dates',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final range = await showDateRangePicker(
                context: context,
                firstDate: now,
                lastDate: now.add(const Duration(days: 90)),
                initialDateRange:
                    _range ?? DateTimeRange(start: now, end: now.add(const Duration(days: 2))),
                helpText: 'Select rental dates',
              );
              if (range != null) {
                setState(() {
                  _range = range;
                  _duration = range.end.difference(range.start).inDays + 1;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.primary.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_outlined, color: c.primary),
                  const SizedBox(width: 12),
                  Text(
                    _startText,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.edit_calendar_outlined, color: c.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final slot in ['07:00 \u2013 11:00 AM', '11:00 AM \u2013 03:00 PM', '03:00 \u2013 07:00 PM'])
                ChoiceChip(
                  label: Text(slot, style: const TextStyle(fontSize: 11.5)),
                  selected: _timeSlot == slot,
                  onSelected: (_) => setState(() => _timeSlot = slot),
                  selectedColor: c.primaryLight,
                  side: BorderSide(color: _timeSlot == slot ? c.primary : c.border),
                  labelStyle: TextStyle(
                    color: _timeSlot == slot ? c.primaryDark : c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Delivery address',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _address = v),
            style: TextStyle(color: c.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Village / Taluk address',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: c.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tool will be delivered to your farm and picked up after use (\u20B9200 delivery per trip).',
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              children: [
                _BillRow(
                  label: 'Rental ($_duration day${_duration == 1 ? '' : 's'})',
                  value: '\u20B9${widget.tool.pricePerDay * _duration}',
                ),
                const Divider(height: 1),
                const _BillRow(label: '\u20B9200 delivery fee', value: '\u20B9200'),
                if (widget.tool.ownerRating > 4.7) ...[
                  const Divider(height: 1),
                  const _BillRow(label: 'Early-bird discount', value: '-\u20B9100', highlight: true),
                ],
                const Divider(height: 1),
                _BillRow(label: 'Total', value: '\u20B9${_total.toStringAsFixed(0)}', bold: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: 'Book this tool',
            icon: Icons.confirmation_number_outlined,
            onPressed: _range == null
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select rental dates first')),
                    );
                  }
                : () async {
                    await showAppModal(
                      context: context,
                      title: 'Booking Summary',
                      child: Column(
                        children: [
                          _BillRow(label: 'Tool', value: widget.tool.name),
                          const SizedBox(height: 4),
                          _BillRow(label: 'Dates', value: _startText),
                          const SizedBox(height: 4),
                          _BillRow(label: 'Slot', value: _timeSlot ?? '-'),
                          const SizedBox(height: 4),
                          _BillRow(label: 'Total', value: '\u20B9${_total.toStringAsFixed(0)}', bold: true),
                        ],
                      ),
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Booking sent to $_address. Owner will confirm soon!')),
                    );
                    Navigator.of(context).pop();
                  },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool highlight;

  const _BillRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = highlight ? c.positive : c.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 16 : 13.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}