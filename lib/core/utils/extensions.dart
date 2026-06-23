import 'package:flutter/material.dart';

extension ContextExtensions on BuildContext {
  ThemeData get appTheme => Theme.of(this);
  TextTheme get appTextTheme => Theme.of(this).textTheme;
}
