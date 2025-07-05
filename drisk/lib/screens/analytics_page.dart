import 'dart:math';
import 'dart:ui';
import 'package:drisk/models/dream_model.dart';
import 'package:drisk/widgets/frosted_glass_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Dream Analytics',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Dream>('dreams').listenable(),
        builder: (context, Box<Dream> box, _) {
          if (box.values.isEmpty) {
            return const Center(
              child: Text(
                "No data for analytics yet.\nLog a dream to begin!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          final dreams = box.values.toList();
          // Sort oldest to newest for charts that depend on chronology
          dreams.sort((a, b) => a.date.compareTo(b.date));
          final allTags = dreams.expand((d) => d.tags).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildQuickStats(context, dreams),
                const SizedBox(height: 40),

                // NEW: Tag Cloud
                if (allTags.isNotEmpty) ...[
                  _buildTagCloud(context, allTags),
                  const SizedBox(height: 40),
                ],

                // NEW: Mood & Metrics Chart
                _buildMoodMetricsChart(context, dreams),
                const SizedBox(height: 40),

                _buildMoodCalendar(context, dreams),
                const SizedBox(height: 40),

                // NEW: Day of the Week Chart
                _buildDayOfWeekChart(context, dreams),
                const SizedBox(height: 40),

                if (dreams.length > 1)
                  _buildClarityThrillLineChart(context, dreams)
                else
                  const _ChartPlaceholder(
                    message: "Log one more dream to see your trends over time.",
                  ),
                const SizedBox(height: 40),

                _buildMoodPieChart(context, dreams),
                const SizedBox(height: 40),

                _buildDreamTypeBarChart(context, dreams),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- UPDATED & NEW WIDGETS ---

  int _calculateLongestStreak(List<Dream> dreams) {
    if (dreams.isEmpty) return 0;

    // Get unique dates and sort them
    final uniqueDates = dreams
        .map((d) => DateTime(d.date.year, d.date.month, d.date.day))
        .toSet()
        .toList();
    uniqueDates.sort();

    if (uniqueDates.length <= 1) return uniqueDates.length;

    int longestStreak = 1;
    int currentStreak = 1;

    for (int i = 1; i < uniqueDates.length; i++) {
      if (uniqueDates[i].difference(uniqueDates[i - 1]).inDays == 1) {
        currentStreak++;
      } else {
        currentStreak = 1;
      }
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
    }
    return longestStreak;
  }

  Widget _buildQuickStats(BuildContext context, List<Dream> dreams) {
    final totalDreams = dreams.length;
    final avgClarity =
        dreams.map((d) => d.clarity).reduce((a, b) => a + b) / totalDreams;
    final avgThrill =
        dreams.map((d) => d.thrillLevel).reduce((a, b) => a + b) / totalDreams;
    final longestStreak = _calculateLongestStreak(dreams);

    return Column(
      children: [
        _buildSectionTitle("At a Glance"),
        Row(
          children: [
            _StatCard(title: 'Total Dreams', value: totalDreams.toString()),
            const SizedBox(width: 12),
            _StatCard(
              title: 'Longest Streak',
              value: '$longestStreak ${longestStreak == 1 ? 'day' : 'days'}',
              isSmallText: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(
              title: 'Avg. Clarity',
              value: avgClarity.toStringAsFixed(1),
            ),
            const SizedBox(width: 12),
            _StatCard(
              title: 'Avg. Thrill',
              value: avgThrill.toStringAsFixed(1),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildTagCloud(BuildContext context, List<String> allTags) {
    // Count occurrences of each tag
    final Map<String, int> tagCounts = {};
    for (final tag in allTags) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }

    // Find min and max counts for scaling font size
    final counts = tagCounts.values;
    final minCount = counts.isEmpty ? 1 : counts.reduce(min);
    final maxCount = counts.isEmpty ? 1 : counts.reduce(max);

    // Create a sorted list of tag entries
    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        _buildSectionTitle("Common Themes"),
        FrostedGlassCard(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12.0,
            runSpacing: 4.0,
            children: sortedTags.take(20).map((entry) {
              // Limit to top 20 tags
              // Linearly interpolate font size between 14 and 28
              final fontSize = lerpDouble(
                  14, 28, (entry.value - minCount) / (maxCount - minCount + 1));
              return Text(
                entry.key,
                style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodMetricsChart(BuildContext context, List<Dream> dreams) {
    // 1. Group values by mood
    final Map<DreamMood, List<double>> clarityValues = {};
    final Map<DreamMood, List<double>> thrillValues = {};

    for (final dream in dreams) {
      (clarityValues[dream.mood] ??= []).add(dream.clarity);
      (thrillValues[dream.mood] ??= []).add(dream.thrillLevel);
    }

    // 2. Calculate averages
    final Map<DreamMood, double> avgClarity = {};
    final Map<DreamMood, double> avgThrill = {};

    for (final mood in DreamMood.values) {
      if (clarityValues.containsKey(mood) && clarityValues[mood]!.isNotEmpty) {
        avgClarity[mood] = clarityValues[mood]!.reduce((a, b) => a + b) /
            clarityValues[mood]!.length;
        avgThrill[mood] = thrillValues[mood]!.reduce((a, b) => a + b) /
            thrillValues[mood]!.length;
      }
    }

    final barGroups = avgClarity.entries.map((entry) {
      final mood = entry.key;
      final clarity = entry.value;
      final thrill = avgThrill[mood]!;

      return BarChartGroupData(
        x: DreamMood.values.indexOf(mood),
        barRods: [
          BarChartRodData(
              toY: clarity,
              color: Theme.of(context).colorScheme.secondary,
              width: 15,
              borderRadius: BorderRadius.circular(4)),
          BarChartRodData(
              toY: thrill,
              color: Theme.of(context).primaryColor,
              width: 15,
              borderRadius: BorderRadius.circular(4)),
        ],
      );
    }).toList();

    return Column(
      children: [
        _buildSectionTitle("Mood vs. Metrics"),
        SizedBox(
          height: 250,
          child: FrostedGlassCard(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: BarChart(
              BarChartData(
                  barGroups: barGroups,
                  alignment: BarChartAlignment.spaceAround,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final mood = DreamMood.values[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(mood.name.substring(0, 3).toUpperCase(),
                                style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 28)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(touchTooltipData:
                      BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label = rodIndex == 0 ? "Clarity" : "Thrill";
                    return BarTooltipItem(
                        '$label\n',
                        const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                              text: rod.toY.toStringAsFixed(1),
                              style: TextStyle(color: rod.color))
                        ]);
                  }))),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Indicator(
                color: Theme.of(context).colorScheme.secondary,
                text: 'Clarity'),
            const SizedBox(width: 16),
            _Indicator(color: Theme.of(context).primaryColor, text: 'Thrill'),
          ],
        ),
      ],
    );
  }

  Widget _buildDayOfWeekChart(BuildContext context, List<Dream> dreams) {
    final List<int> dayCounts = List.filled(7, 0);
    for (var dream in dreams) {
      dayCounts[dream.date.weekday - 1]++; // weekday is 1-7
    }

    return Column(
      children: [
        _buildSectionTitle("Weekly Frequency"),
        SizedBox(
          height: 250,
          child: FrostedGlassCard(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (dayCounts.reduce(max).toDouble()) * 1.2,
                barGroups: List.generate(7, (i) {
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: dayCounts[i].toDouble(),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).colorScheme.secondary
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 22,
                      borderRadius: BorderRadius.circular(6),
                    )
                  ]);
                }),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun'
                        ];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(days[value.toInt()],
                              style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0 && value != 0) return const Text('');
                        return Text(value.toInt().toString());
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- EXISTING WIDGETS ---

  Widget _buildMoodCalendar(BuildContext context, List<Dream> dreams) {
    final Map<DateTime, int> moodMap = {};
    for (var dream in dreams) {
      moodMap[DateTime(dream.date.year, dream.date.month, dream.date.day)] =
          DreamMood.values.indexOf(dream.mood) + 1;
    }

    return Column(
      children: [
        _buildSectionTitle("Mood Calendar"),
        FrostedGlassCard(
          padding: const EdgeInsets.all(16),
          child: HeatMap(
            datasets: moodMap,
            colorMode: ColorMode.opacity,
            showText: false,
            scrollable: true,
            colorsets: const {
              1: Colors.red,
              2: Colors.orange,
              3: Colors.grey,
              4: Colors.lightBlue,
              5: Colors.yellow,
            },
            defaultColor: Colors.white.withOpacity(0.1),
            textColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildClarityThrillLineChart(
      BuildContext context, List<Dream> dreams) {
    final claritySpots = <FlSpot>[];
    final thrillSpots = <FlSpot>[];
    for (int i = 0; i < dreams.length; i++) {
      claritySpots.add(FlSpot(i.toDouble(), dreams[i].clarity));
      thrillSpots.add(FlSpot(i.toDouble(), dreams[i].thrillLevel));
    }

    return Column(
      children: [
        _buildSectionTitle("Trends Over Time"),
        SizedBox(
          height: 250,
          child: FrostedGlassCard(
            padding: const EdgeInsets.fromLTRB(8, 24, 16, 12),
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 32)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 1,
                maxY: 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: claritySpots,
                    isCurved: true,
                    gradient: LinearGradient(colors: [
                      Theme.of(context).colorScheme.secondary,
                      Colors.tealAccent.shade100
                    ]),
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: thrillSpots,
                    isCurved: true,
                    gradient: LinearGradient(colors: [
                      Theme.of(context).primaryColor,
                      Colors.purpleAccent.shade100
                    ]),
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final dream = dreams[spot.spotIndex];
                        String title =
                            spot.barIndex == 0 ? 'Clarity' : 'Thrill';
                        return LineTooltipItem(
                          '$title: ${spot.y.toStringAsFixed(1)}\n${dream.title}',
                          TextStyle(
                            color: spot.bar.gradient?.colors.first ??
                                spot.bar.color!,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Indicator(
                color: Theme.of(context).colorScheme.secondary,
                text: 'Clarity'),
            const SizedBox(width: 16),
            _Indicator(color: Theme.of(context).primaryColor, text: 'Thrill'),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodPieChart(BuildContext context, List<Dream> dreams) {
    Map<DreamMood, int> moodCounts = {};
    for (var dream in dreams) {
      moodCounts[dream.mood] = (moodCounts[dream.mood] ?? 0) + 1;
    }
    final List<Color> moodColors = [
      Colors.red[800]!,
      Colors.orange[800]!,
      Colors.grey[600]!,
      Colors.lightBlue[300]!,
      Colors.yellow[300]!,
    ];

    return Column(
      children: [
        _buildSectionTitle("Mood Distribution"),
        FrostedGlassCard(
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: moodCounts.entries.map((entry) {
                      final moodIndex = DreamMood.values.indexOf(entry.key);
                      return PieChartSectionData(
                        color: moodColors[moodIndex],
                        value: entry.value.toDouble(),
                        title:
                            '${(entry.value / dreams.length * 100).toStringAsFixed(0)}%',
                        radius: 80,
                        titleStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 2)
                            ]),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children: moodCounts.keys.map((mood) {
                  final index = DreamMood.values.indexOf(mood);
                  return _Indicator(
                      color: moodColors[index],
                      text: mood.toString().split('.').last);
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDreamTypeBarChart(BuildContext context, List<Dream> dreams) {
    Map<DreamType, int> typeCounts = {};
    for (var dream in dreams) {
      typeCounts[dream.type] = (typeCounts[dream.type] ?? 0) + 1;
    }

    return Column(
      children: [
        _buildSectionTitle("Dream Type Frequency"),
        SizedBox(
          height: 250,
          child: FrostedGlassCard(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: typeCounts.entries.map((entry) {
                  final typeIndex = DreamType.values.indexOf(entry.key);
                  return BarChartGroupData(
                    x: typeIndex,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.toDouble(),
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).colorScheme.secondary
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 22,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= DreamType.values.length)
                          return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                              DreamType.values[index]
                                  .toString()
                                  .split('.')
                                  .last,
                              style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0 && value != 0) return const Text('');
                        return Text(value.toInt().toString());
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- HELPER WIDGETS ---

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final bool isSmallText;

  const _StatCard(
      {required this.title, required this.value, this.isSmallText = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FrostedGlassCard(
        padding: const EdgeInsets.all(16),
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.secondary,
                  Theme.of(context).primaryColor,
                ],
              ).createShader(bounds),
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSmallText ? 22 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;
  final bool isSquare;
  final double size;

  const _Indicator({
    required this.color,
    required this.text,
    this.isSquare = false,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final String message;
  const _ChartPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.5,
      child: FrostedGlassCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
