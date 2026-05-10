import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'locale_provider.dart';

const _navy = Color(0xFF031634);
const _blue = Color(0xFF0453CD);

/// Call this anywhere:
///   LanguagePicker.show(context);
class LanguagePicker {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _LanguagePickerSheet(),
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocaleProvider>();
    final s = provider.strings;

    final bottomPad = MediaQuery.of(context).padding.bottom +
        MediaQuery.of(context).viewInsets.bottom +
        80; // extra room above the nav bar

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 20),

        // Title
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.language_rounded, color: _blue, size: 20),
          ),
          const SizedBox(width: 12),
          Text(s.changeLanguage,
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
        ]),
        const SizedBox(height: 24),

        // Language options
        ...AppLanguage.values.map((lang) => _LanguageTile(
          lang: lang,
          isSelected: provider.language == lang,
          onTap: () {
            HapticFeedback.selectionClick();
            provider.setLanguage(lang);
            Navigator.pop(context);
          },
        )),
      ]),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final AppLanguage lang;
  final bool isSelected;
  final VoidCallback onTap;
  const _LanguageTile({
    required this.lang,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _blue.withOpacity(0.06) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _blue.withOpacity(0.4) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // Code badge instead of flag
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isSelected ? _blue : _navy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                lang.code.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(lang.displayName,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? _blue : _navy)),
          ),
          if (isSelected)
            Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
            ),
        ]),
      ),
    );
  }
}
