import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import '../theme/app_theme.dart';

/// A phone input with a country-code dropdown. The user picks the country
/// (flag + dial code) from a searchable list and types only the local number;
/// [onChanged] reports the full E.164 number (e.g. +212635123456) via
/// [PhoneNumber.completeNumber].
class PhoneNumberField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String initialCountryCode;
  final ValueChanged<PhoneNumber> onChanged;
  final String? Function(PhoneNumber?)? validator;

  const PhoneNumberField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.initialCountryCode = 'MA',
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppTheme.spacing8),
        ],
        IntlPhoneField(
          controller: controller,
          initialCountryCode: initialCountryCode,
          onChanged: onChanged,
          validator: validator,
          keyboardType: TextInputType.phone,
          flagsButtonPadding: const EdgeInsets.only(left: 8),
          dropdownIconPosition: IconPosition.trailing,
          showCountryFlag: true,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
          ),
        ),
      ],
    );
  }
}
