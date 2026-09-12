import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeConfig {
  // 색상 팔레트 — 차분한 서재 톤
  static const Color primaryColor = Color(0xFF4A3728); // 짙은 브라운 (책장 나무색)
  static const Color secondaryColor = Color(0xFF2C3A47); // 짙은 네이비
  static const Color accentColor = Color(0xFFC9A66B); // 무광 골드 (책 금박 느낌)
  static const Color backgroundColor = Color(0xFFF7F2E7); // 크림/베이지
  static const Color cardColor = Color(0xFFFFFDF9); // 따뜻한 오프화이트
  static const Color textPrimaryColor = Color(0xFF3B2F2A); // 짙은 세피아
  static const Color textSecondaryColor = Color(0xFF8A7A68);
  static const Color successColor = Color(0xFF5B7A5B); // 채도 낮춘 그린
  static const Color errorColor = Color(0xFFA6483C); // 채도 낮춘 레드
  static const Color warningColor = Color(0xFFB68A3C); // 채도 낮춘 앰버

  // 제목용 세리프 서체 (Gowun Batang — 고서 느낌)
  static TextStyle get _serif => GoogleFonts.gowunBatang();

  // 텍스트 스타일
  static TextStyle get headingLarge => _serif.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimaryColor,
  );

  static TextStyle get headingMedium => _serif.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimaryColor,
  );

  static TextStyle get headingSmall => _serif.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textPrimaryColor,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: textPrimaryColor,
    fontFamily: 'Pretendard',
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: textSecondaryColor,
    fontFamily: 'Pretendard',
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: textSecondaryColor,
    fontFamily: 'Pretendard',
  );

  // 테마 데이터
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        surface: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: headingSmall,
        iconTheme: const IconThemeData(color: textPrimaryColor),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: primaryColor.withValues(alpha: 0.08)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: cardColor,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  // 그림자 (은은하게)
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.2),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}
