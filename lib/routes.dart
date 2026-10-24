/// Named routes. Flow per mockups/DESIGN.md: calculator → ferment → recipe → timers → routine;
/// Settings › Flours off the calculator's flour card; saved recipes and the
/// bake log off its header; a bake is logged from the bake log or the
/// recipe's bake card.
abstract final class Routes {
  static const calculator = '/';
  static const ferment = '/ferment';
  static const recipe = '/recipe';
  static const timers = '/timers';
  static const routine = '/routine';
  static const flours = '/flours';
  static const recipes = '/recipes';
  static const bakeLog = '/bake-log';

  /// Argument: the id of the bake to edit; none logs a new one.
  static const logEntry = '/log-entry';
}
