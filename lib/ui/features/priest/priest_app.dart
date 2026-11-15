import '../../../domain/appointments/appointment_repository.dart';
import 'package:flutter/material.dart';

import 'priest_theme.dart';
import 'priest_welcome_screen.dart';

class PriestApp extends StatelessWidget {
  const PriestApp({super.key, required this.repository, this.forPriest});

  final AppointmentRepository repository;
  final AppointmentRepository Function(String)? forPriest;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: Color(0xFFDAD8D4)),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'يوميات الكاهن',
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      theme: ThemeData(
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(seedColor: gold, primary: charcoal),
        scaffoldBackgroundColor: paper,
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: Color(0xFFE8E1D8)),
          ),
        ),
        datePickerTheme: const DatePickerThemeData(
          backgroundColor: paper,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          headerBackgroundColor: charcoal,
          headerForegroundColor: Colors.white,
          todayBorder: BorderSide(color: gold),
        ),
        timePickerTheme: const TimePickerThemeData(
          backgroundColor: paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          dialBackgroundColor: Color(0xFFF5ECDD),
          dialHandColor: charcoal,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: paper,
          showDragHandle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: gold),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        ),
      ),
      home: PriestWelcome(repository: repository, forPriest: forPriest),
    );
  }
}
