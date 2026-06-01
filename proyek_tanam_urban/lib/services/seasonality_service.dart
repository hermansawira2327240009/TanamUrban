class SeasonalityService {
  static final Map<String, int> fruitSeasonCycle = {
    'Mangga': 12,
    'Rambutan': 12,
    'Durian': 12,
    'Duku': 12,
    'Alpukat': 12,
    'Jambu': 6,
    'Pisang': 4,
    'Pepaya': 3,
    'Nanas': 6,
    'Jeruk': 8,
  };

  static DateTime predictNextHarvest({
    required String fruitName,
    required DateTime reportedDate,
  }) {
    final cycleMonth = fruitSeasonCycle[fruitName] ?? 12;

    return DateTime(
      reportedDate.year,
      reportedDate.month + cycleMonth,
      reportedDate.day,
    );
  }

  static String getSeasonDescription(String fruitName) {
    final cycleMonth = fruitSeasonCycle[fruitName] ?? 12;

    if (cycleMonth <= 4) {
      return 'Buah ini memiliki siklus panen cepat sekitar $cycleMonth bulan.';
    } else if (cycleMonth <= 8) {
      return 'Buah ini memiliki siklus panen sedang sekitar $cycleMonth bulan.';
    } else {
      return 'Buah ini umumnya memiliki musim panen tahunan sekitar $cycleMonth bulan.';
    }
  }
}