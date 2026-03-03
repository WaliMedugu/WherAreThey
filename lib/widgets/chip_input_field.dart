import 'package:flutter/material.dart';

class ChipInputField extends StatefulWidget {
  final String labelText;
  final String hintText;
  final List<String> initialChips;
  final ValueChanged<List<String>> onChanged;

  const ChipInputField({
    super.key,
    required this.labelText,
    required this.hintText,
    required this.initialChips,
    required this.onChanged,
  });

  @override
  State<ChipInputField> createState() => _ChipInputFieldState();
}

class _ChipInputFieldState extends State<ChipInputField> {
  late List<String> _chips;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chips = List.from(widget.initialChips);
  }

  @override
  void didUpdateWidget(ChipInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialChips != oldWidget.initialChips) {
      setState(() {
        _chips = List.from(widget.initialChips);
      });
    }
  }

  void _addChip(String value) {
    final trimValue = value.trim();
    if (trimValue.isNotEmpty && !_chips.contains(trimValue)) {
      setState(() {
        _chips.add(trimValue);
        widget.onChanged(_chips);
      });
      _controller.clear();
    }
  }

  void _removeChip(String value) {
    setState(() {
      _chips.remove(value);
      widget.onChanged(_chips);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
          ),
          onFieldSubmitted: _addChip,
          onChanged: (val) {
            if (val.endsWith(',') || val.endsWith(' ')) {
              _addChip(val.substring(0, val.length - 1));
            }
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _chips.map((chip) {
            return Chip(
              label: Text(chip),
              onDeleted: () => _removeChip(chip),
            );
          }).toList(),
        ),
      ],
    );
  }
}
