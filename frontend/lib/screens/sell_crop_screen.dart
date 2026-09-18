import 'package:flutter/material.dart';
import '../models/crop.dart';
import '../theme/colors.dart';
import '../widgets/layout.dart';
import '../widgets/ui/app_input.dart';
import '../widgets/ui/buttons.dart';
import '../widgets/ui/cards.dart';

class SellCropScreen extends StatefulWidget {
  final ValueChanged<CropListing>? onPosted;

  const SellCropScreen({super.key, this.onPosted});

  @override
  State<SellCropScreen> createState() => _SellCropScreenState();
}

class _SellCropScreenState extends State<SellCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cropController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const _crops = ['Tomato', 'Wheat', 'Onion', 'Cotton', 'Groundnut', 'Potato', 'Maize', 'Chilli'];
  static const _units = ['kg', 'quintal', 'ton'];
  static const _harvestDates = ['Available now', 'In 7 days', 'In 2 weeks', 'In 1 month', 'In 2 months'];

  final List<int> _media = [1, 2, 3];
  String? _crop;
  String _unit = 'kg';
  String _harvest = 'Available now';
  bool _validateOnTap = false;

  static const _emojiFor = {
    'Tomato': '\uD83C\uDF45',
    'Wheat': '\uD83C\uDF3E',
    'Onion': '\uD83E\uDDC5',
    'Cotton': '\u2611\uFE0F',
    'Groundnut': '\uD83E\uDD5C',
    'Potato': '\uD83E\uDD54',
    'Maize': '\uD83C\uDF3D',
    'Chilli': '\uD83C\uDF36\uFE0F',
  };

  @override
  void dispose() {
    _cropController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickHarvestDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select harvest date',
    );
    if (date != null) {
      setState(() {
        _harvest = '${date.day} ${_monthName(date.month)} ${date.year}';
      });
    }
  }

  String _monthName(int m) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[m - 1];
  }

  void _postCrop() {
    setState(() => _validateOnTap = true);
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill the required fields')),
      );
      return;
    }
    final listing = CropListing(
      name: _crop ?? _cropController.text.trim(),
      emoji: _emojiFor[_crop] ?? '\uD83C\uDF3F',
      quantity: '${_quantityController.text.trim()} $_unit',
      expectedPrice: '\u20B9${_priceController.text.trim()}/$_unit',
      location: _locationController.text.trim().isEmpty ? 'Dharwad' : _locationController.text.trim(),
      listedAgo: 'Just now',
      status: 'Active',
    );
    widget.onPosted?.call(listing);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Crop posted! Traders can now see your listing.')),
    );
    Navigator.of(context).pop();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell My Crop'),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: ThemeToggle())],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              controller: _cropController,
              label: 'Crop type',
              icon: Icons.eco_outlined,
              hint: 'e.g. Tomato',
              validator: _validateOnTap ? _required : null,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _crops
                  .map((crop) => ChoiceChip(
                        label: Text(crop),
                        selected: _crop == crop,
                        onSelected: (s) {
                          setState(() {
                            _crop = s ? crop : null;
                            _cropController.clear();
                          });
                        },
                        selectedColor: c.primaryLight,
                        avatar: Text(_emojiFor[crop] ?? '\uD83C\uDF3F'),
                        side: BorderSide(color: _crop == crop ? c.primary : c.border),
                        labelStyle: TextStyle(
                          color: _crop == crop ? c.primaryDark : c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _quantityController,
                    label: 'Quantity',
                    icon: Icons.all_inbox_outlined,
                    keyboardType: TextInputType.number,
                    validator: _validateOnTap ? _required : null,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: AppDropdownField(
                    label: 'Unit',
                    icon: Icons.straighten,
                    value: _unit,
                    items: _units,
                    onChanged: (v) => setState(() => _unit = v ?? 'kg'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _priceController,
              label: 'Expected price',
              icon: Icons.currency_rupee,
              hint: 'per unit',
              keyboardType: TextInputType.number,
              validator: _validateOnTap ? _required : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _locationController,
              label: 'Location',
              icon: Icons.place_outlined,
              hint: 'Village / Taluk',
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickHarvestDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_outlined, color: c.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Harvest date',
                      style: TextStyle(color: c.textSecondary, fontSize: 14),
                    ),
                    const Spacer(),
                    Text(
                      _harvest,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: c.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _harvestDates
                  .map((h) => ActionChip(
                        label: Text(h, style: const TextStyle(fontSize: 12)),
                        onPressed: () => setState(() => _harvest = h),
                        backgroundColor: c.surface,
                        side: BorderSide(color: c.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _descriptionController,
              label: 'Description (optional)',
              icon: Icons.notes,
              hint: 'Quality, variety, special notes\u2026',
            ),
            const SizedBox(height: 20),
            Text(
              'Add photos & videos',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final id in _media)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Container(
                        width: 88,
                        decoration: BoxDecoration(
                          color: id == 3 ? c.primaryLight : c.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border),
                        ),
                        child: id == 3
                            ? InkWell(
                                onTap: () {},
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add, color: c.primary, size: 26),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: c.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: c.primaryLight.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      id == 1 ? Icons.image_outlined : Icons.videocam_outlined,
                                      color: c.primary,
                                      size: 24,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: InkWell(
                                      onTap: () => setState(() => _media.remove(id)),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Listing preview',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
            ),
            const SizedBox(height: 10),
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: c.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(_emojiFor[_crop] ?? '\uD83C\uDF3F', style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _crop ?? (_cropController.text.isEmpty ? 'Your Crop' : _cropController.text.trim()),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          '${_quantityController.text.isEmpty ? '\u2014' : '${_quantityController.text.trim()} $_unit'} \u2022 $_harvest',
                          style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _priceController.text.isEmpty ? '' : '\u20B9${_priceController.text.trim()}/$_unit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(label: 'Post Crop for Traders', icon: Icons.send, onPressed: _postCrop),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}