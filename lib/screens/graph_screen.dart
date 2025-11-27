import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/record_provider.dart';
import '../providers/theme_provider.dart';
import '../models/daily_record.dart';

enum GraphTab {
  week,
  month,
  day,
  calendar,
}

enum GraphMetric {
  weight,
  bodyFat,
}

class GraphScreen extends StatefulWidget {
  final int? initialTab;
  const GraphScreen({super.key, this.initialTab});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  GraphTab _selectedTab = GraphTab.day;
  GraphMetric _selectedMetric = GraphMetric.weight;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab == 3) {
      _selectedTab = GraphTab.calendar;
    }
    _scrollController.addListener(_updateVisibleRange);
  }
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;
    final provider = Provider.of<RecordProvider>(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        automaticallyImplyLeading: false, // Hide default back button
        elevation: 0,
        title: Text(
          'Trends',
          style: TextStyle(color: theme.text),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: theme.text),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        bottom: _selectedTab != GraphTab.calendar
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTabItem('Day', GraphTab.day, theme),
                      _buildTabItem('Week', GraphTab.week, theme),
                      _buildTabItem('Month', GraphTab.month, theme),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: _selectedTab == GraphTab.calendar
            ? _buildCalendar(provider, theme)
            : _buildGraphView(provider, theme),
      ),
    );
  }

  Widget _buildTabItem(String label, GraphTab tab, AppTheme theme) {
    final isSelected = _selectedTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tab;
          // Reset dynamic range on tab change
          _dynamicMinY = null;
          _dynamicMaxY = null;
        });
        // Trigger update after layout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            // Reset scroll position to end (latest data)
            _scrollController.jumpTo(0); 
            _updateVisibleRange();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.accent : theme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricSelector(AppTheme theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMetricOption('Weight', GraphMetric.weight, theme),
          const SizedBox(width: 4),
          _buildMetricOption('Body Fat', GraphMetric.bodyFat, theme),
        ],
      ),
    );
  }

  Widget _buildMetricOption(String label, GraphMetric metric, AppTheme theme) {
    final isSelected = _selectedMetric == metric;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMetric = metric;
          // Reset dynamic range on metric change
          _dynamicMinY = null;
          _dynamicMaxY = null;
        });
        // Trigger update after layout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _updateVisibleRange();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.background : theme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildGraphView(RecordProvider provider, AppTheme theme) {
    final data = _getProcessedData(provider);
    
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: theme.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        _buildMetricSelector(theme),
        const SizedBox(height: 8),
        _buildStatsRow(data, theme),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 8, bottom: 16),
            child: _buildMainChart(data, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar(RecordProvider provider, AppTheme theme) {
    // Optimize: Create a map for O(1) lookup
    final recordsMap = {
      for (var record in provider.getAllRecords())
        DateTime(record.date.year, record.date.month, record.date.day): record
    };

    final daysInMonth = DateUtils.getDaysInMonth(_focusedDay.year, _focusedDay.month);
    final midPoint = 16; // Split point

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        
        // Threshold for swipe velocity to prevent accidental triggers
        if (details.primaryVelocity! > 300) {
          // Swipe Right -> Previous Month
          setState(() {
            _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
          });
        } else if (details.primaryVelocity! < -300) {
          // Swipe Left -> Next Month
          setState(() {
            _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
          });
        }
      },
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: theme.textSecondary),
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                      });
                    },
                  ),
                  Text(
                    DateFormat('yyyy / MM').format(_focusedDay),
                    style: TextStyle(
                      color: theme.text, 
                      fontSize: 16, 
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: theme.textSecondary),
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          // Body
          Expanded(
            child: Row(
              children: [
                // Left Column (1-16)
                Expanded(
                  child: _buildDayColumn(1, midPoint, recordsMap, theme),
                ),
                VerticalDivider(width: 1, color: theme.divider),
                // Right Column (17-End)
                Expanded(
                  child: _buildDayColumn(midPoint + 1, daysInMonth, recordsMap, theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(int startDay, int endDay, Map<DateTime, DailyRecord> recordsMap, AppTheme theme) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedDay.year, _focusedDay.month);
    final isLastColumn = endDay == daysInMonth;
    
    return Column(
      children: [
        for (int i = startDay; i <= endDay; i++)
          Expanded(
            child: _buildDayRow(i, recordsMap, theme),
          ),
        
        // Show Average Sleep below the last day
        if (isLastColumn)
          Expanded(
            child: _buildAverageSleepRow(recordsMap, theme),
          ),

        // Fill remaining space
        // Subtract 1 for the average row if it's shown
        if (16 - (endDay - startDay + 1) - (isLastColumn ? 1 : 0) > 0)
           for (int i = 0; i < 16 - (endDay - startDay + 1) - (isLastColumn ? 1 : 0); i++)
             const Spacer(),
      ],
    );
  }

  Widget _buildAverageSleepRow(Map<DateTime, DailyRecord> recordsMap, AppTheme theme) {
    double totalSleep = 0;
    int sleepCount = 0;
    int totalMoodScore = 0;
    int moodCount = 0;
    final daysInMonth = DateUtils.getDaysInMonth(_focusedDay.year, _focusedDay.month);

    // Mood stamp scoring (0-4 scale, with 2 as neutral)
    final moodScores = {
      '☹️': 0,  // Bad
      '😐': 2,  // Neutral (middle)
      '🙂': 3,  // Good
      '😀': 4,  // Great
    };

    for (int i = 1; i <= daysInMonth; i++) {
      final date = DateTime(_focusedDay.year, _focusedDay.month, i);
      final record = recordsMap[date];
      
      // Calculate sleep average
      if (record?.sleepTime != null) {
        totalSleep += record!.sleepTime!;
        sleepCount++;
      }

      // Calculate mood score
      if (record != null) {
        for (var stamp in record.stamps) {
          if (moodScores.containsKey(stamp)) {
            totalMoodScore += moodScores[stamp]!;
            moodCount++;
            break; // Only count one mood per day
          }
        }
      }
    }

    final avgSleep = sleepCount > 0 ? totalSleep / sleepCount : 0.0;
    
    // Format Average Sleep Time
    String sleepText = '';
    if (avgSleep > 0) {
      int hours = avgSleep.floor();
      int minutes = ((avgSleep - hours) * 60).round();
      if (minutes == 0) {
        sleepText = '${hours}h';
      } else {
        sleepText = '${hours}h${minutes.toString().padLeft(2, '0')}m';
      }
    }

    // Format Mood Score (average)
    String moodScoreText = '';
    if (moodCount > 0) {
      final avgScore = totalMoodScore / moodCount;
      moodScoreText = avgScore.toStringAsFixed(1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.accent.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: theme.divider.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          // "Avg." prefix
          Text(
            'Avg.',
            style: TextStyle(
              color: theme.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 12),
          // Sleep section
          if (sleepText.isNotEmpty) ...[
            Text(
              'Sleep',
              style: TextStyle(
                color: theme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              sleepText,
              style: TextStyle(
                color: theme.graphSleep,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(width: 12),
          // Mood section
          if (moodScoreText.isNotEmpty) ...[
            Text(
              'Mood',
              style: TextStyle(
                color: theme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              moodScoreText,
              style: TextStyle(
                color: theme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayRow(int day, Map<DateTime, DailyRecord> recordsMap, AppTheme theme) {
    final date = DateTime(_focusedDay.year, _focusedDay.month, day);
    final record = recordsMap[date];
    final isToday = isSameDay(date, DateTime.now());
    final weekday = date.weekday; // 1 = Monday, 7 = Sunday
    final isSaturday = weekday == 6;
    final isSunday = weekday == 7;
    final isHoliday = _isJapaneseHoliday(date);

    // Filter and Sort stamps
    final provider = Provider.of<RecordProvider>(context, listen: false);
    final moodStamps = ['☹️', '😐', '🙂', '😀'];
    final exerciseStamps = ['🏋️‍♂️', '🚶‍♂️', '🏃‍♂️'];
    final validStamps = {...moodStamps, ...exerciseStamps, '✔️', '💊', ...provider.customStamps};
    
    List<String> displayStamps = [];
    if (record != null) {
        displayStamps = record.stamps.where((s) => validStamps.contains(s)).toList();
        
        // Sort: Mood -> Exercise -> Custom -> Pill
        final priorityList = [...moodStamps, ...exerciseStamps];
        displayStamps.sort((a, b) {
          if (a == '💊') return 1;
          if (b == '💊') return -1;

          int indexA = priorityList.indexOf(a);
          int indexB = priorityList.indexOf(b);
          
          if (indexA != -1 && indexB != -1) {
            return indexA.compareTo(indexB);
          } else if (indexA != -1) {
            return -1; // a is priority, b is custom
          } else if (indexB != -1) {
            return 1; // b is priority, a is custom
          } else {
            return a.compareTo(b); // both custom
          }
        });
    }

    // Format Sleep Time
    String sleepText = '';
    if (record?.sleepTime != null) {
      int hours = record!.sleepTime!.floor();
      int minutes = ((record!.sleepTime! - hours) * 60).round();
      if (minutes == 0) {
        sleepText = '${hours}h';
      } else {
        sleepText = '${hours}h${minutes.toString().padLeft(2, '0')}m';
      }
    }

    // Determine date color based on weekday/holiday
    Color dateColor;
    if (isToday) {
      dateColor = theme.accent;
    } else {
      dateColor = theme.text;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Reduced horizontal padding
      margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
      decoration: BoxDecoration(
        color: isToday ? theme.accent.withOpacity(0.1) : theme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Date
          SizedBox(
            width: 24,
            child: Text(
              '$day',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: dateColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8), // Reduced spacing
          
          // Sleep Time
          if (sleepText.isNotEmpty) ...[
            SizedBox(
              width: 45, // Slightly reduced fixed width
              child: Text(
                sleepText,
                style: TextStyle(
                  color: theme.graphSleep,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 4), // Reduced spacing
          ],
          
          // Stamps
          Expanded(
            child: displayStamps.isNotEmpty
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: displayStamps.map((s) => Padding(
                        padding: const EdgeInsets.only(right: 1), // Reduced padding
                        child: Text(s, style: const TextStyle(fontSize: 13)), // Slightly reduced font size
                      )).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  List<GraphDataPoint> _getProcessedData(RecordProvider provider) {
    final allRecords = provider.getAllRecords();
    if (allRecords.isEmpty) return [];

    allRecords.sort((a, b) => a.date.compareTo(b.date));

    if (_selectedTab == GraphTab.week) {
      // Filter to last 3 months (90 days) for week view
      final cutoff = DateTime.now().subtract(const Duration(days: 90));
      final filteredRecords = allRecords.where((r) => r.date.isAfter(cutoff)).toList();
      return _aggregateByWeek(filteredRecords);
    } else if (_selectedTab == GraphTab.day) {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      return allRecords
          .where((r) => r.date.isAfter(cutoff))
          .map((r) => GraphDataPoint(r.date, r.weight, r.bodyFat, r.sleepTime))
          .toList();
    } else if (_selectedTab == GraphTab.month) {
      return _aggregateByMonth(allRecords);
    }
    return [];
  }

  List<GraphDataPoint> _aggregateByWeek(List<DailyRecord> source) {
    final Map<String, List<DailyRecord>> grouped = {};
    for (var r in source) {
      // Find start of week (Monday)
      final startOfWeek = r.date.subtract(Duration(days: r.date.weekday - 1));
      final key = '${startOfWeek.year}-${startOfWeek.month}-${startOfWeek.day}';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    final List<GraphDataPoint> result = [];
    grouped.forEach((key, list) {
      final parts = key.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      
      double? avgWeight = _avg(list.map((e) => e.weight).where((v) => v != null && v > 0.1).cast<double>());
      double? avgFat = _avg(list.map((e) => e.bodyFat).where((v) => v != null && v > 0.1).cast<double>());
      double? avgSleep = _avg(list.map((e) => e.sleepTime).where((v) => v != null && v > 0.1).cast<double>());

      result.add(GraphDataPoint(
        date,
        avgWeight,
        avgFat,
        avgSleep,
      ));
    });
    
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  List<GraphDataPoint> _aggregateByMonth(List<DailyRecord> source) {
    final Map<String, List<DailyRecord>> grouped = {};
    for (var r in source) {
      final key = '${r.date.year}-${r.date.month}';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    final List<GraphDataPoint> result = [];
    grouped.forEach((key, list) {
      final parts = key.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      
      double? avgWeight = _avg(list.map((e) => e.weight).where((v) => v != null && v > 0.1).cast<double>());
      double? avgFat = _avg(list.map((e) => e.bodyFat).where((v) => v != null && v > 0.1).cast<double>());
      double? avgSleep = _avg(list.map((e) => e.sleepTime).where((v) => v != null && v > 0.1).cast<double>());

      result.add(GraphDataPoint(
        date,
        avgWeight,
        avgFat,
        avgSleep,
      ));
    });
    
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  double? _avg(Iterable<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Widget _buildStatsRow(List<GraphDataPoint> data, AppTheme theme) {
    if (data.isEmpty) return const SizedBox.shrink();

    // Data is already sorted by date in _getProcessedData
    double? startVal;
    double? endVal;
    String unit = '';
    Color color = theme.accent;  // Default to accent color

    if (_selectedMetric == GraphMetric.weight) {
      startVal = data.firstWhere((e) => e.weight != null && e.weight! > 0, orElse: () => data.first).weight;
      endVal = data.lastWhere((e) => e.weight != null && e.weight! > 0, orElse: () => data.last).weight;
      unit = 'kg';
      color = theme.accent;
    } else {
      startVal = data.firstWhere((e) => e.bodyFat != null && e.bodyFat! > 0, orElse: () => data.first).bodyFat;
      endVal = data.lastWhere((e) => e.bodyFat != null && e.bodyFat! > 0, orElse: () => data.last).bodyFat;
      unit = '%';
      color = const Color(0xFF6B8E23);  // Olive green for body fat
    }

    if (startVal == null || endVal == null) return const SizedBox.shrink();

    return Column(
      children: [
        Text(
          _selectedMetric == GraphMetric.weight ? 'Weight Trend' : 'Body Fat Trend',
          style: TextStyle(color: theme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${startVal.toStringAsFixed(1)}',
              style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(Icons.arrow_forward, size: 16, color: theme.textSecondary),
            ),
            Text(
              '${endVal.toStringAsFixed(1)} $unit',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ],
    );
  }

  final ScrollController _scrollController = ScrollController();
  double? _dynamicMinY;
  double? _dynamicMaxY;

  @override
  void dispose() {
    _scrollController.removeListener(_updateVisibleRange);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateVisibleRange() {
    final provider = Provider.of<RecordProvider>(context, listen: false);
    final data = _getProcessedData(provider);
    if (data.isEmpty) return;

    double itemWidth = 50.0;
    if (_selectedTab == GraphTab.week || _selectedTab == GraphTab.month) {
      itemWidth = 60.0;
    }

    final viewportWidth = MediaQuery.of(context).size.width - 32 - 55;
    final padding = 24.0;
    final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;

    // Calculate visible indices (Reverse scroll: 0 is at the end of the list)
    // List: [0, 1, ... N]
    // Visual (Reverse): [ ... 1, 0] -> Right side is end of list
    
    // Distance from the "end" (right side)
    final distFromRight = scrollOffset;
    
    // Index at the right edge of the viewport
    // rightIndex = (data.length - 1) - (distFromRight / itemWidth)
    // We add padding adjustment
    int rightIndex = (data.length - 1) - ((distFromRight - padding) / itemWidth).floor();
    
    // Index at the left edge of the viewport
    int leftIndex = rightIndex - (viewportWidth / itemWidth).ceil();

    // Clamp indices
    rightIndex = rightIndex.clamp(0, data.length - 1);
    leftIndex = leftIndex.clamp(0, data.length - 1);

    if (leftIndex > rightIndex) {
      final temp = leftIndex;
      leftIndex = rightIndex;
      rightIndex = temp;
    }

    // Calculate Min/Max for visible range
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    final isWeight = _selectedMetric == GraphMetric.weight;

    for (int i = leftIndex; i <= rightIndex; i++) {
      final val = isWeight ? data[i].weight : data[i].bodyFat;
      if (val != null && val > 0) { // Ignore 0 or null
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }

    if (minVal == double.infinity) return;

    // Apply buffer
    double minY, maxY;
    if (isWeight) {
      double buffer = 1.0; // Tighter buffer for dynamic view
      minY = (minVal - buffer).floorToDouble();
      maxY = (maxVal + buffer).ceilToDouble();
    } else {
      double dataRange = maxVal - minVal;
      if (dataRange <= 2.0) {
        double buffer = 0.2;
        minY = ((minVal - buffer) * 10).floor() / 10;
        maxY = ((maxVal + buffer) * 10).ceil() / 10;
      } else {
        double buffer = 2.0;
        minY = (minVal - buffer).floorToDouble();
        maxY = (maxVal + buffer).ceilToDouble();
      }
    }

    if (maxY <= minY) maxY = minY + 1;

    if (_dynamicMinY != minY || _dynamicMaxY != maxY) {
      setState(() {
        _dynamicMinY = minY;
        _dynamicMaxY = maxY;
      });
    }
  }

  Widget _buildMainChart(List<GraphDataPoint> data, AppTheme theme) {
    final isWeight = _selectedMetric == GraphMetric.weight;
    // Olive green color (#6B8E23) for body fat - calm and distinguishable from weight blue
    final color = isWeight ? theme.accent : const Color(0xFF6B8E23);

    // Ensure range is updated when data changes or view is rebuilt
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateVisibleRange());

    // Use dynamic values or fallback to global (which will be updated quickly)
    // Fallback: Calculate global min/max just in case
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    for (var p in data) {
      final val = isWeight ? p.weight : p.bodyFat;
      if (val != null && val > 0) {
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }
    if (minVal == double.infinity) { minVal = 0; maxVal = 100; }
    
    double minY = _dynamicMinY ?? (minVal - 2).floorToDouble();
    double maxY = _dynamicMaxY ?? (maxVal + 2).ceilToDouble();
    
    // Ensure range
    if (maxY <= minY) maxY = minY + 1;

    // Determine interval based on range
    double range = maxY - minY;
    double interval = 1.0;
    
    if (isWeight) {
      if (range <= 5) {
        interval = 0.5;
      } else if (range <= 10) {
        interval = 1.0;
      } else {
        interval = 2.0;
      }
    } else {
      if (range <= 1.0) {
        interval = 0.1;
      } else if (range <= 3.0) {
        interval = 0.2;
      } else if (range <= 5.0) {
        interval = 0.5;
      } else if (range <= 10.0) {
        interval = 1.0;
      } else {
        interval = 2.0;
      }
    }

    // Calculate width for scrollable chart
    // Ensure sufficient width for padding (24 + 24 = 48)
    double minWidth = MediaQuery.of(context).size.width - 32 - 55;
    double chartWidth = minWidth;
    
    if (_selectedTab == GraphTab.day) {
      chartWidth = data.length * 50.0 + 48; 
    } else if (_selectedTab == GraphTab.week) {
      chartWidth = data.length * 60.0 + 48;
    } else if (_selectedTab == GraphTab.month) {
       chartWidth = data.length * 60.0 + 48;
    }
    
    if (chartWidth < minWidth) {
      chartWidth = minWidth;
    }

    // Shared Axis Configuration
    final axisTitles = AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 55,
        interval: interval,
        getTitlesWidget: (value, meta) {
          if (value == minY || value == maxY) return const SizedBox.shrink();
          
          String text;
          if (interval % 1 == 0) {
             text = value.toStringAsFixed(0);
          } else {
             text = value.toStringAsFixed(1);
          }
          // Add unit
          text += isWeight ? ' kg' : ' %';
          
          return Text(
            text,
            style: TextStyle(color: theme.textSecondary, fontSize: 10),
          );
        },
      ),
    );

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Container(
              width: chartWidth,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LineChart(
                LineChartData(
                  clipData: const FlClipData.all(),
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.divider,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1, 
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index < 0 || index >= data.length) return const SizedBox.shrink();
                          
                          final date = data[index].date;
                          String text = '';
                          
                          if (_selectedTab == GraphTab.week) {
                            // Show start of week
                            text = DateFormat('MM/dd').format(date);
                          } else if (_selectedTab == GraphTab.day) {
                             text = DateFormat('MM/dd').format(date);
                          } else if (_selectedTab == GraphTab.month) {
                            bool showYear = false;
                            if (index == 0) {
                              showYear = true;
                            } else {
                              final prevDate = data[index - 1].date;
                              if (prevDate.year != date.year) {
                                showYear = true;
                              }
                            }
                            
                            if (showYear) {
                              text = DateFormat('yy\nMM').format(date);
                            } else {
                              text = '\n${DateFormat('MM').format(date)}';
                            }
                          }
                          
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              text,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.textSecondary, fontSize: 10),
                            ),
                          );
                        },
                        reservedSize: 52,
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide right titles on main chart
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: _buildLineBarsData(data, isWeight, color, theme),
                  showingTooltipIndicators: _getTooltipIndicators(data, isWeight, color, theme),
                  lineTouchData: LineTouchData(
                    enabled: false,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.transparent,
                      tooltipPadding: const EdgeInsets.all(0),
                      tooltipMargin: 16, // Increased margin to avoid overlap
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          final textStyle = TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          );
                          return LineTooltipItem(
                            touchedSpot.y.toStringAsFixed(1),
                            textStyle,
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
        // Fixed Axis
        Container(
          width: 55,
          margin: const EdgeInsets.only(right: 8),
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(show: false), // Hide grid on axis
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, 
                    reservedSize: 52, // Match main chart
                    getTitlesWidget: (value, meta) => const SizedBox.shrink(),
                  ),
                ),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: axisTitles, // Use shared axis configuration
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                // Empty bar data to render axis
                 LineChartBarData(
                  spots: [FlSpot(0, minY)], // Dummy spot
                  color: Colors.transparent,
                  dotData: FlDotData(show: false),
                 ),
              ],
              lineTouchData: LineTouchData(enabled: false),
            ),
          ),
        ),
      ],
    );
  }

  List<ShowingTooltipIndicators> _getTooltipIndicators(
      List<GraphDataPoint> data, bool isWeight, Color color, AppTheme theme) {
    final bars = _buildLineBarsData(data, isWeight, color, theme);
    final List<ShowingTooltipIndicators> indicators = [];

    for (int barIndex = 0; barIndex < bars.length; barIndex++) {
      final bar = bars[barIndex];
      for (int spotIndex = 0; spotIndex < bar.spots.length; spotIndex++) {
        indicators.add(ShowingTooltipIndicators([
          LineBarSpot(bar, barIndex, bar.spots[spotIndex]),
        ]));
      }
    }
    return indicators;
  }

  List<LineChartBarData> _buildLineBarsData(
      List<GraphDataPoint> data, bool isWeight, Color color, AppTheme theme) {
    List<LineChartBarData> bars = [];
    List<FlSpot> currentSegment = [];

    for (int i = 0; i < data.length; i++) {
      final val = isWeight ? data[i].weight : data[i].bodyFat;
      
      if (val != null && val > 0.1) {
        currentSegment.add(FlSpot(i.toDouble(), val));
      } else {
        if (currentSegment.isNotEmpty) {
          bars.add(_createLineChartBarData(currentSegment, color, theme));
          currentSegment = [];
        }
      }
    }

    if (currentSegment.isNotEmpty) {
      bars.add(_createLineChartBarData(currentSegment, color, theme));
    }

    return bars;
  }

  LineChartBarData _createLineChartBarData(
      List<FlSpot> spots, Color color, AppTheme theme) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 3.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 5,
            color: theme.background,
            strokeWidth: 2.5,
            strokeColor: color,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      shadow: Shadow(
        color: color.withOpacity(0.2),
        offset: const Offset(0, 3),
        blurRadius: 8,
      ),
    );
  }

  // Japanese holiday detector (simplified - includes major fixed holidays)
  bool _isJapaneseHoliday(DateTime date) {
    final year = date.year;
    final month = date.month;
    final day = date.day;

    // Fixed holidays
    if (month == 1 && day == 1) return true; // New Year's Day
    if (month == 2 && day == 11) return true; // National Foundation Day
    if (month == 2 && day == 23) return true; // Emperor's Birthday
    if (month == 4 && day == 29) return true; // Showa Day
    if (month == 5 && day == 3) return true; // Constitution Day
    if (month == 5 && day == 4) return true; // Greenery Day
    if (month == 5 && day == 5) return true; // Children's Day
    if (month == 8 && day == 11) return true; // Mountain Day
    if (month == 11 && day == 3) return true; // Culture Day
    if (month == 11 && day == 23) return true; // Labor Thanksgiving Day

    // Monday holidays (simplified calculation)
    final weekday = date.weekday;
    if (month == 1 && weekday == 1 && day >= 8 && day <= 14) return true; // Coming of Age Day (2nd Monday)
    if (month == 7 && weekday == 1 && day >= 15 && day <= 21) return true; // Marine Day (3rd Monday)
    if (month == 9 && weekday == 1 && day >= 15 && day <= 21) return true; // Respect for the Aged Day (3rd Monday)
    if (month == 10 && weekday == 1 && day >= 8 && day <= 14) return true; // Sports Day (2nd Monday)

    return false;
  }
}

class GraphDataPoint {
  final DateTime date;
  final double? weight;
  final double? bodyFat;
  final double? sleepTime;

  GraphDataPoint(this.date, this.weight, this.bodyFat, this.sleepTime);
}
