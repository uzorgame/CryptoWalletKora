import '../../core/services/localization_service.dart';

/// The places the rail can take you.
///
/// The order is the numbering shown beside each label, so it is also the direction a view
/// travels when the user moves between them.
enum NavDestination { portfolio, send, history, settings }

extension NavDestinationLabel on NavDestination {
  /// `01`, `02`, … — an index, not a decoration: it tells you where you are in a short list
  /// without needing the labels read.
  String get number => (index + 1).toString().padLeft(2, '0');

  /// The translation key. Kept separate from the enum so a rename in one cannot silently
  /// break the other.
  String get _key => switch (this) {
        NavDestination.portfolio => 'portfolio',
        NavDestination.send => 'send',
        NavDestination.history => 'transactions',
        NavDestination.settings => 'settings',
      };

  String get label => tr(_key).toUpperCase();
}
