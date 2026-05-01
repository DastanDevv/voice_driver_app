/// Короткая дата для карточек: «12 апр».
String formatRuShortDayMonth(DateTime d) {
  const months = [
    '',
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];
  return '${d.day} ${months[d.month]}';
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
