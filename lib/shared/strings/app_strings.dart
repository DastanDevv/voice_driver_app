/// Централизованные строки интерфейса на русском (без хардкода в виджетах).
abstract final class AppStrings {
  static const String appTitle = 'Умный помощник по задачам';
  static const String taskListTitle = 'Мои задачи';
  static const String addTaskTooltip = 'Добавить задачу';
  static const String addTaskDialogTitle = 'Новая задача';
  static const String addTaskHint = 'Опишите задачу';
  static const String cancel = 'Отмена';
  static const String save = 'Сохранить';
  static const String emptyListTitle = 'Нет задач';
  static const String emptyListSubtitle =
      'Добавьте задачу голосом или кнопкой «+».';
  static const String filterAll = 'Все';
  static const String filterToday = 'Сегодня';
  static const String filterImportant = 'Важные';
  static const String sortByDate = 'По дате';
  static const String sortByPriority = 'По приоритету';
  static const String sectionToday = 'Сегодня';
  static const String sectionTomorrow = 'Завтра';
  static const String sectionLater = 'Позже';
  static const String moreMenu = 'Ещё';
  static const String completedLabel = 'Выполнено';
  static const String activeLabel = 'Активные';
  static const String deleteTooltip = 'Удалить';
  static const String loadingTasks = 'Загрузка…';
  static const String voiceComingSoon = 'Голос: в следующих шагах';
  static const String testCommandButton = 'Тест команды';
  static const String highPriorityLabel = 'Важно';
  static const String dueDatePrefix = 'Срок';
  static const String dueDateLabel = 'Срок выполнения';
  static const String listening = 'Слушаю…';
  static const String micUnavailable = 'Микрофон недоступен';
  static const String voiceHoldHint = 'Удерживайте для голосовой команды';
  static const String historyTitle = 'История команд';
  static const String historyEmpty = 'Пока нет распознанных команд.\nИспользуйте голос или «Демо команды».';
  static const String historyIntentLabel = 'Намерение:';
  static const String historyEntitiesLabel = 'Сущности:';
  static const String historyConfidenceLabel = 'Уверенность:';
  static const String demoCommandsButton = 'Демо команды';
  static const String processingLabel = 'Обработка…';
  static const String unknownCommandSnack = 'Не удалось распознать команду';
  static const String lowConfidenceHint = 'Низкая уверенность распознавания';
  static const String historyTooltip = 'История команд';

  // Bottom nav
  static const String navTasks = 'Задачи';
  static const String navNlpLab = 'NLP Лаб';
  static const String navAnalytics = 'Аналитика';

  // NLP Lab
  static const String nlpLabTitle = 'NLP Лаборатория';
  static const String nlpLabHint = 'Введите фразу для анализа…';
  static const String nlpLabSamples = 'Примеры команд:';

  // Analytics
  static const String analyticsTitle = 'Аналитика';
  static const String analyticsEmpty = 'Нет данных';
  static const String analyticsEmptyHint =
      'Используйте голосовые команды, чтобы увидеть статистику.';

  // Voice suggestions
  static const String voiceSuggestionsTitle = 'Попробуйте сказать:';

  // About
  static const String aboutTitle = 'О системе';
  static const String aboutTooltip = 'О системе';
}
