import 'package:flutter/foundation.dart';

const usesBrowserThemeTransition = false;

void transitionTheme(VoidCallback update, {required bool animate}) => update();
