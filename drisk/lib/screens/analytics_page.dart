import 'package:drisk/models/dream_model.dart';
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
        title: const Text('Dream Analytics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Dream>('dreams').listenable(),
        builder: (context, Box<Dream> box, _) {
          // Show page if there is at least one dream
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildQuickStats(context, dreams),
                const SizedBox(height: 40),
                _buildMoodCalendar(context, dreams),
                const SizedBox(height: 40),

                // Conditionally show the line chart or a placeholder
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
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, List<Dream> dreams) {
    final totalDreams = dreams.length;
    final avgClarity =
        dreams.map((d) => d.clarity).reduce((a, b) => a + b) / totalDreams;
    final avgThrill =
        dreams.map((d) => d.thrillLevel).reduce((a, b) => a + b) / totalDreams;

    return Column(
      children: [
        _buildSectionTitle("At a Glance"),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatCard(title: 'Total Dreams', value: totalDreams.toString()),
            _StatCard(
              title: 'Avg. Clarity',
              value: avgClarity.toStringAsFixed(1),
            ),
            _StatCard(
              title: 'Avg. Thrill',
              value: avgThrill.toStringAsFixed(1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodCalendar(BuildContext context, List<Dream> dreams) {
    final Map<DateTime, int> moodMap = {};
    for (var dream in dreams) {
      moodMap[DateTime(dream.date.year, dream.date.month, dream.date.day)] =
          DreamMood.values.indexOf(dream.mood) + 1;
    }

    return Column(
      children: [
        _buildSectionTitle("Mood Calendar"),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: HeatMap(
              datasets: moodMap,
              colorMode: ColorMode.opacity,
              showText: false,
              scrollable: true,
              colorsets: const {
                1: Colors.red, // nightmare
                2: Colors.orange, // bad
                3: Colors.grey, // neutral
                4: Colors.lightBlue, // good
                5: Colors.yellow, // excellent
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClarityThrillLineChart(
    BuildContext context,
    List<Dream> dreams,
  ) {
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
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 1,
                  maxY: 10,
                  lineBarsData: [
                    LineChartBarData(
                      spots: claritySpots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.secondary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: thrillSpots,
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
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
                              color: spot.bar.color,
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
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Indicator(
              color: Theme.of(context).colorScheme.secondary,
              text: 'Clarity',
            ),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections:
                          moodCounts.entries.map((entry) {
                            final moodIndex = DreamMood.values.indexOf(
                              entry.key,
                            );
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
                                  Shadow(color: Colors.black, blurRadius: 2),
                                ],
                              ),
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
                  children:
                      moodCounts.keys.map((mood) {
                        final index = DreamMood.values.indexOf(mood);
                        return _Indicator(
                          color: moodColors[index],
                          text: mood.toString().split('.').last,
                        );
                      }).toList(),
                ),
              ],
            ),
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
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups:
                      typeCounts.entries.map((entry) {
                        final typeIndex = DreamType.values.indexOf(entry.key);
                        return BarChartGroupData(
                          x: typeIndex,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.toDouble(),
                              color: Theme.of(context).primaryColor,
                              width: 16,
                              borderRadius: BorderRadius.circular(4),
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
                          if (index < 0 || index >= DreamType.values.length) {
                            return const Text('');
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DreamType.values[index]
                                  .toString()
                                  .split('.')
                                  .last,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) {
                            return const Text('');
                          }
                          return Text(value.toInt().toString());
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
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
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: Colors.grey[400])),
            ],
          ),
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
      child: Card(
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
