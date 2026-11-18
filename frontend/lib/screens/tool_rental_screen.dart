import 'package:flutter/material.dart';

import 'package:jeevandhara2/models/tool.dart';
import 'package:jeevandhara2/services/listings_service.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/layout.dart';
import 'package:jeevandhara2/widgets/ui/app_modal.dart';
import 'package:jeevandhara2/widgets/ui/buttons.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';
import 'package:jeevandhara2/widgets/ui/states.dart';

class ToolRentalScreen extends StatefulWidget {
  final ListingsService? service;

  const ToolRentalScreen({super.key, this.service});

  @override
  State<ToolRentalScreen> createState() => _ToolRentalScreenState();
}

class _ToolRentalScreenState extends State<ToolRentalScreen> {
  late final ListingsService _service =
      widget.service ?? ListingsService();
  final List<Tool> _tools = [];
  bool _loading = true;
  String? _error;
  String _category = 'All';

  List<String> get _categories {
    final cats = <String>{};
    for (final t in _tools) {
      cats.add(t.category);
    }
    return ['All', ...cats];
  }

  List<Tool> get _filtered => _category == 'All'
      ? _tools
      : _tools.where((t) => t.category == _category && t.category.isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = _tools.isEmpty;
      _error = null;
    });
    try {
      final tools = await _service.tools();
      if (!mounted) return;
      setState(() {
        _tools
          ..clear()
          ..addAll(tools);
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openDetails(Tool tool) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ToolDetailScreen(tool: tool)),
    );
  }

  Future<void> _listATool() async {
    await showAppModal(
      context: context,
      title: 'List your tool',
      child: _ListToolForm(onDone: () async {
        Navigator.of(context).pop();
        await _reload();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load tools',
        subtitle: _error!,
        actionLabel: 'Try again',
        onAction: _reload,
      );
    }
    return Column(
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
                        label:
                            Text(cat, style: const TextStyle(fontSize: 12.5)),
                        selected: _category == cat,
                        onSelected: (_) => setState(() => _category = cat),
                        selectedColor: c.primaryLight,
                        side: BorderSide(
                            color: _category == cat ? c.primary : c.border),
                        labelStyle: TextStyle(
                          color: _category == cat
                              ? c.primaryDark
                              : c.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? EmptyState(
                  icon: Icons.agriculture,
                  title: 'No tools listed yet',
                  subtitle:
                      'Tools are listed by real farmers. Be the first in your area to rent one out.',
                  actionLabel: 'List your tool',
                  onAction: _listATool,
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 900) {
                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          physics: const AlwaysScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
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
                        physics: const AlwaysScrollableScrollPhysics(),
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
        ),
        if (_tools.isNotEmpty)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.divider)),
              ),
              child: AppTonalButton(
                label: 'List your tool',
                icon: Icons.add_business_outlined,
                height: 44,
                onPressed: _listATool,
              ),
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
                child: Center(
                    child:
                        Text(tool.emoji, style: const TextStyle(fontSize: 28))),
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
                      '${tool.category} \u2022 ${tool.location.isNotEmpty ? tool.location : 'Location not shared'}',
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Listed by ${tool.owner}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5, color: c.textSecondary),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
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
                    '\u20B9${tool.pricePerDay.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: c.primary,
                    ),
                  ),
                  Text('/day',
                      style: TextStyle(fontSize: 11, color: c.textSecondary)),
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

  double get _total => widget.tool.pricePerDay * _duration + 200;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent a Tool'),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: ThemeToggle())
        ],
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
                child: Center(
                    child: Text(widget.tool.emoji,
                        style: const TextStyle(fontSize: 32))),
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
                      '${widget.tool.category} \u2022 ${widget.tool.location.isNotEmpty ? widget.tool.location : 'Location not shared'}',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Listed by ${widget.tool.owner}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Text(
              widget.tool.description.isNotEmpty
                  ? widget.tool.description
                  : 'No description shared by the owner.',
              style: TextStyle(
                  fontSize: 13.5, color: c.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Select rental dates',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.textPrimary),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final range = await showDateRangePicker(
                context: context,
                firstDate: now,
                lastDate: now.add(const Duration(days: 90)),
                initialDateRange: _range ??
                    DateTimeRange(
                        start: now, end: now.add(const Duration(days: 2))),
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
              for (final slot in [
                '07:00 \u2013 11:00 AM',
                '11:00 AM \u2013 03:00 PM',
                '03:00 \u2013 07:00 PM'
              ])
                ChoiceChip(
                  label: Text(slot, style: const TextStyle(fontSize: 11.5)),
                  selected: _timeSlot == slot,
                  onSelected: (_) => setState(() => _timeSlot = slot),
                  selectedColor: c.primaryLight,
                  side: BorderSide(
                      color: _timeSlot == slot ? c.primary : c.border),
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
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.textPrimary),
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
                  'Tool will be delivered to your farm and picked up after use (\u20B9200 delivery per trip). The owner confirms each booking personally.',
                  style: TextStyle(
                      fontSize: 12.5, color: c.textSecondary, height: 1.4),
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
                const _BillRow(
                    label: '\u20B9200 delivery fee', value: '\u20B9200'),
                const Divider(height: 1),
                _BillRow(
                    label: 'Total',
                    value: '\u20B9${_total.toStringAsFixed(0)}',
                    bold: true),
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
                      const SnackBar(
                          content: Text('Please select rental dates first')),
                    );
                  }
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
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
                          _BillRow(
                              label: 'Total',
                              value: '\u20B9${_total.toStringAsFixed(0)}',
                              bold: true),
                        ],
                      ),
                    );
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text(
                              'Booking request sent to ${widget.tool.owner}. Delivery: $_address. They will confirm soon.')),
                    );
                    navigator.pop();
                  },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ListToolForm extends StatefulWidget {
  final VoidCallback onDone;
  const _ListToolForm({required this.onDone});

  @override
  State<_ListToolForm> createState() => _ListToolFormState();
}

class _ListToolFormState extends State<_ListToolForm> {
  final ListingsService _service = ListingsService();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _category = TextEditingController(text: 'Tillage');
  final TextEditingController _price = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _emoji = TextEditingController(text: '\u{1FA9C}');
  bool _saving = false;
  String? _error;

  static const _categories = [
    'Tillage',
    'Irrigation',
    'Sowing',
    'Harvesting',
    'Spraying',
    'Transport',
    'Other',
  ];

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _price.dispose();
    _description.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Give the tool a name');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a daily price, e.g. 400');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.createTool(
        name: name,
        category: _category.text.trim(),
        pricePerDay: price,
        description: _description.text.trim(),
        emoji: _emoji.text.trim(),
      );
      if (!mounted) return;
      widget.onDone();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _error!,
              style: TextStyle(color: c.danger, fontSize: 13),
            ),
          ),
        TextField(
          controller: _name,
          style: TextStyle(color: c.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Tool name',
            hintText: 'e.g. Power tiller',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _category,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            labelText: 'Category',
            hintText: 'Choose a category',
            prefixIcon: const Icon(Icons.category_outlined),
            suffixIcon: PopupMenuButton<String>(
              itemBuilder: (_) => [
                for (final cat in _categories)
                  PopupMenuItem(value: cat, child: Text(cat)),
              ],
              onSelected: (v) => setState(() => _category.text = v),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.arrow_drop_down),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _price,
          style: TextStyle(color: c.textPrimary),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Rent per day (\u20B9)',
            hintText: 'e.g. 400',
            prefixIcon: Icon(Icons.currency_rupee),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _description,
          style: TextStyle(color: c.textPrimary),
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Short description (optional)',
            hintText: 'Brand, power, what it is good for',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emoji,
          style: TextStyle(color: c.textPrimary, fontSize: 20),
          decoration: const InputDecoration(
            labelText: 'Icon (emoji)',
            hintText: '\u{1FA9C}',
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppTonalButton(
                label: 'Cancel',
                onPressed:
                    _saving ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppPrimaryButton(
                label: _saving ? 'Posting\u2026' : 'List tool',
                icon: Icons.check,
                onPressed: _saving ? null : _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _BillRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.textPrimary;
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