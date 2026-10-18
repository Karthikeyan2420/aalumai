import 'package:flutter/material.dart';

/// Root navigator key shared by the router and non-widget services (such as the
/// notification tap handler) so alarms can be surfaced from outside the widget
/// tree.
final rootNavigatorKey = GlobalKey<NavigatorState>();
