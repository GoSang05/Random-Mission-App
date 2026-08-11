import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

enum _PeriodOption { day, week, month, custom }

class MagazineScreen extends StatefulWidget {
  const MagazineScreen({super.key});

  @override
  State<MagazineScreen> createState() => _MagazineScreenState();
}

class _MagazineScreenState extends State<MagazineScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];
  _PeriodOption _period = _PeriodOption.week;
  DateTimeRange? _customRange;
  bool _isCreating = false;
  bool _showPreview = false;

  String get _periodLabel => switch (_period) {
        _PeriodOption.day => '오늘 하루',
        _PeriodOption.week => '최근 7일',
        _PeriodOption.month => '최근 한 달',
        _PeriodOption.custom => _customRange == null
            ? '기간을 선택해 주세요'
            : '${_dateText(_customRange!.start)} — ${_dateText(_customRange!.end)}',
      };

  String _dateText(DateTime date) => '${date.month}.${date.day}';

  Future<void> _selectPeriod(_PeriodOption option) async {
    if (option == _PeriodOption.custom) {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
        initialDateRange: _customRange ?? DateTimeRange(
          start: now.subtract(const Duration(days: 6)), end: now,
        ),
        helpText: '매거진에 담을 기간 선택',
      );
      if (range == null || !mounted) return;
      setState(() { _period = option; _customRange = range; });
      return;
    }
    setState(() => _period = option);
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 88);
    if (!mounted || images.isEmpty) return;
    setState(() {
      for (final image in images) {
        if (!_photos.any((photo) => photo.path == image.path)) _photos.add(image);
      }
      _showPreview = false;
    });
  }

  Future<void> _takePhoto() async {
    final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 88);
    if (!mounted || image == null) return;
    setState(() { _photos.add(image); _showPreview = false; });
  }

  Future<void> _createMagazine() async {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('매거진에 담을 사진을 한 장 이상 추가해 주세요.')));
      return;
    }
    if (_period == _PeriodOption.custom && _customRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('먼저 기간을 선택해 주세요.')));
      return;
    }
    setState(() => _isCreating = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() { _isCreating = false; _showPreview = true; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text('나의 순간을,\n한 권의 매거진으로.', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.2)),
            const SizedBox(height: 10),
            const Text('AI가 사진의 분위기와 흐름을 읽어 감도 있는 이야기를 엮어드려요.', style: TextStyle(color: Color(0xFF6D6875))),
            const SizedBox(height: 28),
            const _SectionTitle(number: '01', title: '기록할 시간'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: _PeriodOption.values.map((option) => ChoiceChip(
              label: Text(_optionText(option)), selected: _period == option,
              onSelected: (_) => _selectPeriod(option),
            )).toList()),
            const SizedBox(height: 10),
            Row(children: [const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF6750E8)), const SizedBox(width: 7), Text(_periodLabel, style: const TextStyle(fontWeight: FontWeight.w700))]),
            const SizedBox(height: 30),
            const _SectionTitle(number: '02', title: '사진 모으기'),
            const SizedBox(height: 7),
            Text('${_photos.length}장의 사진이 선택되었어요', style: const TextStyle(color: Color(0xFF6D6875))),
            const SizedBox(height: 13),
            SizedBox(height: 118, child: ListView(scrollDirection: Axis.horizontal, children: [
              _PhotoAddCard(icon: Icons.photo_library_outlined, label: '갤러리', onTap: _pickImages),
              const SizedBox(width: 10),
              _PhotoAddCard(icon: Icons.camera_alt_outlined, label: '카메라', onTap: _takePhoto),
              for (var i = 0; i < _photos.length; i++) ...[const SizedBox(width: 10), _SelectedPhoto(photo: _photos[i], index: i, onRemove: () => setState(() { _photos.removeAt(i); _showPreview = false; }))],
            ])),
            const SizedBox(height: 30),
            const _SectionTitle(number: '03', title: 'AI 에디터에게 맡기기'),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: const Color(0xFF24212B), borderRadius: BorderRadius.circular(22)), child: const Row(children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD580)), SizedBox(width: 12), Expanded(child: Text('사진의 색감 · 장소 · 감정을 분석해\n표지, 카피, 페이지 순서를 제안해요.', style: TextStyle(color: Colors.white, height: 1.45, fontWeight: FontWeight.w600))),
            ])),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('createMagazineButton'), onPressed: _isCreating ? null : _createMagazine,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: const Color(0xFF6750E8)),
              icon: _isCreating ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded),
              label: Text(_isCreating ? 'AI가 매거진을 편집하고 있어요...' : 'AI 매거진 만들기'),
            ),
            if (_showPreview) ...[const SizedBox(height: 28), _MagazinePreview(photos: _photos, period: _periodLabel)],
          ],
        ),
      ),
    );
  }

  String _optionText(_PeriodOption option) => switch (option) {
    _PeriodOption.day => '하루동안', _PeriodOption.week => '일주일동안',
    _PeriodOption.month => '한달동안', _PeriodOption.custom => '직접 선택',
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title});
  final String number; final String title;
  @override
  Widget build(BuildContext context) => Row(children: [Text(number, style: const TextStyle(color: Color(0xFF6750E8), fontWeight: FontWeight.w900)), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))]);
}

class _PhotoAddCard extends StatelessWidget {
  const _PhotoAddCard({required this.icon, required this.label, required this.onTap});
  final IconData icon; final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: const Color(0xFFECE9F5), borderRadius: BorderRadius.circular(18), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: SizedBox(width: 96, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: const Color(0xFF6750E8)), const SizedBox(height: 7), Text(label, style: const TextStyle(fontWeight: FontWeight.w800))]))));
}

class _SelectedPhoto extends StatelessWidget {
  const _SelectedPhoto({required this.photo, required this.index, required this.onRemove});
  final XFile photo; final int index; final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => Stack(children: [
    ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(File(photo.path), width: 112, height: 118, fit: BoxFit.cover)),
    Positioned(top: 6, left: 6, child: CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)))),
    Positioned(top: 4, right: 4, child: Material(color: Colors.white, shape: const CircleBorder(), child: InkWell(onTap: onRemove, customBorder: const CircleBorder(), child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.close, size: 15))))),
  ]);
}

class _MagazinePreview extends StatelessWidget {
  const _MagazinePreview({required this.photos, required this.period});
  final List<XFile> photos; final String period;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('AI가 만든 첫 페이지', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 12),
    Container(height: 300, decoration: BoxDecoration(color: const Color(0xFF201D28), borderRadius: BorderRadius.circular(26)), clipBehavior: Clip.antiAlias, child: Stack(fit: StackFit.expand, children: [
      Opacity(opacity: .56, child: Image.file(File(photos.first.path), fit: BoxFit.cover)),
      DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: .88)]))),
      Positioned(left: 22, right: 22, bottom: 23, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(period.toUpperCase(), style: const TextStyle(color: Color(0xFFFFD580), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)), const SizedBox(height: 5),
        const Text('작지만 선명했던\n우리의 장면들', style: TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900, height: 1.03, letterSpacing: -1)), const SizedBox(height: 9),
        Text('${photos.length} photos · AI editorial', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
      ])),
    ])),
  ]);
}
