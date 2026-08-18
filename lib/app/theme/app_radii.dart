import 'package:flutter/material.dart';

abstract final class AppRadii {
  static const double sm = 8.0;
  static const double btn = 10.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 18.0;

  static const Radius rSm = Radius.circular(sm);
  static const Radius rBtn = Radius.circular(btn);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);
  static const Radius rXl = Radius.circular(xl);

  static const BorderRadius borderSm = BorderRadius.all(rSm);
  static const BorderRadius borderBtn = BorderRadius.all(rBtn);
  static const BorderRadius borderMd = BorderRadius.all(rMd);
  static const BorderRadius borderLg = BorderRadius.all(rLg);
  static const BorderRadius borderXl = BorderRadius.all(rXl);
}
