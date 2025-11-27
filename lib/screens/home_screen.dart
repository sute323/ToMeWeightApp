import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:characters/characters.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/record_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/csv_helper.dart';
import '../widgets/custom_number_pad.dart';
import 'graph_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Controllers to keep text fields in sync
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _sleepController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  // Track which controller is currently active for the keypad
  TextEditingController? _activeController;
  bool _shouldOverwrite = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _fatController.dispose();
    _sleepController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  // ... (existing methods)

  Widget _buildStampSelector(RecordProvider provider, AppTheme theme) {
    final exerciseStamps = ['🏋️‍♂️', '🚶‍♂️', '🏃‍♂️'];
    final otherStamps = ['💊', '✔️', ...provider.customStamps];
    
    final currentStamps = provider.currentRecord.stamps;

    Widget buildSection(String title, List<String> stamps, {bool isOther = false}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: TextStyle(color: theme.textSecondary, fontSize: 13),
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ...stamps.map((stamp) {
                final isSelected = currentStamps.contains(stamp);
                return GestureDetector(
                  onTap: () {
                    _dismissKeypad();
                    provider.toggleStamp(stamp);
                  },
                  onLongPress: isOther && stamp != '✔️' && stamp != '💊' ? () {
                    // Option to remove custom stamp
                    _showRemoveCustomStampDialog(context, provider, stamp);
                  } : null,
                  child: Opacity(
                    opacity: isSelected ? 1.0 : 0.3,
                    child: Text(stamp, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }),
            ],
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Exercise and Custom stamps (centered)
          Center(
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
              ...exerciseStamps.map((stamp) {
                final isSelected = currentStamps.contains(stamp);
                return GestureDetector(
                  onTap: () {
                    _dismissKeypad();
                    provider.toggleStamp(stamp);
                  },
                  child: Opacity(
                    opacity: isSelected ? 1.0 : 0.3,
                    child: Text(stamp, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }),
              ...otherStamps.map((stamp) {
                final isSelected = currentStamps.contains(stamp);
                return GestureDetector(
                  onTap: () {
                    _dismissKeypad();
                    provider.toggleStamp(stamp);
                  },
                  onLongPress: stamp != '✔️' && stamp != '💊' ? () {
                    _showRemoveCustomStampDialog(context, provider, stamp);
                  } : null,
                  child: Opacity(
                    opacity: isSelected ? 1.0 : 0.3,
                    child: Text(stamp, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Divider before memo
          Divider(color: theme.divider, height: 1),
          // Memo section
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: 20, bottom: 12),
            child: GestureDetector(
              onTap: () {
                _dismissKeypad();
                _showMemoDialog(context, provider, theme);
              },
              onLongPress: provider.currentRecord.memos.isNotEmpty && provider.currentRecord.memos[0].isNotEmpty
                  ? () {
                      Clipboard.setData(ClipboardData(text: provider.currentRecord.memos[0]));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('メモをコピーしました'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: theme.accent,
                        ),
                      );
                    }
                  : null,
              child: provider.currentRecord.memos.isNotEmpty && provider.currentRecord.memos[0].isNotEmpty
                  ? Text(
                      provider.currentRecord.memos[0],
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text(
                      'タップしてメモを追加',
                      style: TextStyle(
                        color: theme.textSecondary.withOpacity(0.5),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateControllers(RecordProvider provider) {
    final record = provider.currentRecord;
    // Only update if we are NOT currently editing that specific field (or if values mismatch significantly)
    // Actually, to keep it simple and safe: if the record value changes from outside (e.g. date change), we update.
    // We compare with parsed value to avoid overwriting "5." with "5.0" while typing.
    
    if (record.weight != double.tryParse(_weightController.text)) {
      _weightController.text = record.weight?.toString() ?? '';
    }
    if (record.bodyFat != double.tryParse(_fatController.text)) {
      _fatController.text = record.bodyFat?.toString() ?? '';
    }
    if (record.sleepTime != _timeStrToHours(_sleepController.text)) {
      _sleepController.text = _hoursToTimeStr(record.sleepTime);
    } else if (_activeController != _sleepController) {
      // Force normalization if not editing (e.g. "81.0" -> "81")
      final formatted = _hoursToTimeStr(record.sleepTime);
      if (_sleepController.text != formatted) {
        _sleepController.text = formatted;
      }
    }
    
    // Update memo controller
    final currentMemo = record.memos.isNotEmpty ? record.memos[0] : '';
    if (_memoController.text != currentMemo) {
      _memoController.text = currentMemo;
    }
  }

  String _hoursToTimeStr(double? hours) {
    if (hours == null) return '';
    int h = hours.floor();
    int m = ((hours - h) * 60).round();
    
    if (m == 60) {
      h += 1;
      m = 0;
    }
    
    final mTens = m ~/ 10;
    // Return format like "63" for 6h30m, "120" for 12h00m
    return '$h$mTens';
  }

  double? _timeStrToHours(String timeStr) {
    if (timeStr.isEmpty) return null;
    try {
      // Logic:
      // Starts with '1':
      //   Len < 3: Just hours (e.g. "1", "12")
      //   Len == 3: First 2 digits hours, 3rd digit minute tens (e.g. "123" -> 12h 30m)
      // Other:
      //   Len < 2: Just hours (e.g. "6")
      //   Len == 2: First 1 digit hour, 2nd digit minute tens (e.g. "63" -> 6h 30m)

      if (timeStr.startsWith('1')) {
        if (timeStr.length < 3) {
          return double.parse(timeStr);
        }
        final hStr = timeStr.substring(0, 2);
        final mTensStr = timeStr.substring(2);
        final m = double.parse(mTensStr) * 10;
        return double.parse(hStr) + (m / 60);
      } else {
        if (timeStr.length < 2) {
          return double.parse(timeStr);
        }
        final hStr = timeStr.substring(0, 1);
        final mTensStr = timeStr.substring(1);
        final m = double.parse(mTensStr) * 10;
        return double.parse(hStr) + (m / 60);
      }
    } catch (e) {
      return null;
    }
  }

  void _onKeypadInput(String value) {
    if (_activeController == null) return;
    
    if (_shouldOverwrite) {
      _activeController!.clear();
      _shouldOverwrite = false;
    }

    final text = _activeController!.text;
    
    // Prevent multiple decimals
    if (value == '.' && text.contains('.')) return;
    
    // Block decimal for sleep controller
    if (_activeController == _sleepController && value == '.') return;
    
    // Prevent too many decimal places (limit to 1)
    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length > 1 && parts[1].length >= 1) return; 
    } else {
      // Limit integer part length
      if (value != '.') {
        if (_activeController == _weightController && text.length >= 3) return;
        if (_activeController == _fatController && text.length >= 2) return;
        if (_activeController == _sleepController) {
          if (text.startsWith('1')) {
            // Max 3 digits (HHM)
            if (text.length >= 3) return;
            // If entering 3rd digit (minute tens), must be 0-5
            if (text.length == 2) {
              final digit = int.tryParse(value);
              if (digit == null || digit > 5) return;
            }
          } else {
            // Max 2 digits (HM)
            if (text.length >= 2) return;
            // If entering 2nd digit (minute tens), must be 0-5
            if (text.length == 1) {
              final digit = int.tryParse(value);
              if (digit == null || digit > 5) return;
            }
          }
        }
      }
    }

    _activeController!.text += value;
    _triggerSave();
  }

  void _onKeypadClear() {
    if (_activeController == null) return;
    _activeController!.clear();
    _triggerSave();
  }
  
  void _triggerSave() {
    final provider = Provider.of<RecordProvider>(context, listen: false);
    if (_activeController == _weightController) {
      provider.saveWeight(double.tryParse(_weightController.text));
    } else if (_activeController == _fatController) {
      provider.saveBodyFat(double.tryParse(_fatController.text));
    } else if (_activeController == _sleepController) {
      provider.saveSleepTime(_timeStrToHours(_sleepController.text));
    }
  }

  void _formatActiveController() {
    if (_activeController != null) {
      final text = _activeController!.text;
      final val = double.tryParse(text);
      if (val != null) {
        _activeController!.text = val.toStringAsFixed(1);
        _triggerSave();
      }
    }
  }

  void _dismissKeypad() {
    _formatActiveController();
    setState(() {
      _activeController = null;
    });
  }

  Future<void> _saveMemo(RecordProvider provider, String value) async {
    print('=== _saveMemo called with value: "$value"');
    final record = provider.currentRecord;
    print('=== Current record memos before save: ${record.memos}');
    
    if (record.memos.isEmpty) {
      print('=== Calling addMemo');
      await provider.addMemo(value);
    } else {
      print('=== Calling updateMemo');
      await provider.updateMemo(0, value);
    }
    
    print('=== After save, current record memos: ${provider.currentRecord.memos}');
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RecordProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;
    
    if (provider.error != null) {
      return Scaffold(
        backgroundColor: theme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error loading data:\n${provider.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    if (!provider.isLoaded) {
      return Scaffold(
        backgroundColor: theme.background,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    _updateControllers(provider);

    return Scaffold(
      backgroundColor: theme.background,
      resizeToAvoidBottomInset: false, // Prevent keyboard from pushing up content (though we use custom keypad)
      appBar: AppBar(
        backgroundColor: theme.background,
        leading: null,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            color: theme.text,
            onPressed: () {
              _dismissKeypad();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GraphScreen(initialTab: 3)), // Calendar tab
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.show_chart),
            color: theme.text,
            onPressed: () {
              _dismissKeypad();
              _dismissKeypad();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GraphScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            color: theme.text,
            onPressed: () {
              _dismissKeypad();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          _dismissKeypad();
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          
          // Threshold for swipe velocity to prevent accidental triggers
          if (details.primaryVelocity! > 300) {
            // Swipe Right -> Previous Day
            _dismissKeypad();
            provider.updateDate(provider.selectedDate.subtract(const Duration(days: 1)));
          } else if (details.primaryVelocity! < -300) {
            // Swipe Left -> Next Day
            _dismissKeypad();
            provider.updateDate(provider.selectedDate.add(const Duration(days: 1)));
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            // Scrollable Content (Date + Inputs)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Date Navigation
                    _buildDateHeader(provider, theme),
                    
                    // Fixed Inputs and Stamps
                    Container(
                      color: theme.surface, // Unified background
                      child: Column(
                        children: [
                          _buildInputRow('', 'kg', _weightController, Colors.transparent, theme),
                          Divider(color: theme.divider, height: 1),
                          _buildInputRow('', '%', _fatController, Colors.transparent, theme),
                          Divider(color: theme.divider, height: 1),
                          _buildInputRow(
                            '',
                            '',
                            _sleepController,
                            Colors.transparent,
                            theme,
                            customValueBuilder: (val, active) => _buildSleepValue(val, active, theme),
                          ),
                          Divider(color: theme.divider, height: 1),
                          _buildMoodRow(provider, theme),
                          Divider(color: theme.divider, height: 1),
                          _buildStampSelector(provider, theme),

                          // Full-width divider
                          Divider(color: theme.divider, height: 1, thickness: 1),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Custom Keypad (visible when an input is active)
            if (_activeController != null)
              GestureDetector(
                onTap: () {}, // Absorb taps to prevent dismissal
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  color: theme.background, // Ensure it looks like part of the keypad
                  child: CustomNumberPad(
                    onNumber: _onKeypadInput,
                    onClear: _onKeypadClear,
                    // Note: CustomNumberPad might need theming too, but for now assuming it's dark or we update it later.
                    // Let's check CustomNumberPad later.
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(RecordProvider provider, AppTheme theme) {
    final date = provider.selectedDate;
    final yearStr = DateFormat('yyyy').format(date);
    final dateStr = DateFormat('MM.dd').format(date);
    final dayStr = DateFormat('E').format(date).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      color: theme.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 20, color: theme.textSecondary),
            onPressed: () {
              _dismissKeypad();
              provider.updateDate(date.subtract(const Duration(days: 1)));
            },
          ),
          GestureDetector(
            onTap: () async {
              _dismissKeypad();
              await _showCustomDatePicker(context, provider, theme);
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  yearStr,
                  style: GoogleFonts.oswald(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: theme.text,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  dateStr,
                  style: GoogleFonts.oswald(
                    fontSize: 40,
                    fontWeight: FontWeight.w500,
                    color: theme.text,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  dayStr,
                  style: GoogleFonts.oswald(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: theme.text,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, size: 20, color: theme.textSecondary),
            onPressed: () {
              _dismissKeypad();
              provider.updateDate(date.add(const Duration(days: 1)));
            },
          ),
        ],
      ),
    );
  }
  String _formatSleepDisplay(String val) {
    if (val.isEmpty) return '--';
    
    if (val.startsWith('1')) {
      // Starts with '1'
      if (val.length == 1) return '1h';
      if (val.length == 2) return '${val}h';
      // Len 3
      final h = val.substring(0, 2);
      final m = val.substring(2);
      if (m == '0') return '${h}h';
      return '${h}h${m}0m';
    } else {
      // Other
      if (val.length == 1) return '${val}h';
      // Len 2
      final h = val.substring(0, 1);
      final m = val.substring(1);
      if (m == '0') return '${h}h';
      return '${h}h${m}0m';
    }
  }

  Widget _buildSleepValue(String rawText, bool isActive, AppTheme theme) {
    final text = _formatSleepDisplay(rawText);
    if (text == '--') {
      return Text(
        text,
        style: GoogleFonts.oswald(
          fontSize: 56, 
          fontWeight: FontWeight.w400,
          color: isActive ? theme.accent : theme.text,
        ),
      );
    }

    // Split by 'h' and 'm' to style parts
    // Example: "6h30m" -> ["6", "h", "30", "m"]
    // Example: "6h" -> ["6", "h"]
    
    final List<InlineSpan> spans = [];
    final numberStyle = GoogleFonts.oswald(
      fontSize: 56, 
      fontWeight: FontWeight.w400,
      color: isActive ? theme.accent : theme.text,
    );
    final unitStyle = GoogleFonts.oswald(
      fontSize: 24, 
      color: theme.textSecondary,
      fontWeight: FontWeight.w400
    );

    // Regex to capture numbers and units
    final RegExp regex = RegExp(r'(\d+)|([hm])');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      // Add spacing before every element except the first one
      if (spans.isNotEmpty) {
        spans.add(const WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SizedBox(width: 6),
        ));
      }

      final str = match.group(0)!;
      if (int.tryParse(str) != null) {
        spans.add(TextSpan(text: str, style: numberStyle));
      } else {
        spans.add(TextSpan(text: str, style: unitStyle));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildInputRow(
    String label, 
    String unit, 
    TextEditingController controller, 
    Color backgroundColor,
    AppTheme theme,
    {
      String Function(String)? displayFormatter,
      Widget Function(String value, bool isActive)? customValueBuilder,
    }
  ) {
    final isActive = _activeController == controller;
    final rawText = controller.text;
    
    return GestureDetector(
      onTap: () {
        if (isActive) {
          _dismissKeypad();
        } else {
          // Format previous controller before switching
          _formatActiveController();
          setState(() {
            _activeController = controller;
            _shouldOverwrite = true;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        color: isActive ? theme.divider : backgroundColor, // Use passed background color
        child: Row(
          children: [
            if (label.isNotEmpty)
              SizedBox(
                width: 60,
                child: Text(
                  label, 
                  style: TextStyle(
                    fontSize: 18, 
                    color: theme.textSecondary,
                    fontWeight: FontWeight.w400
                  )
                ),
              ),
            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (customValueBuilder != null)
                      customValueBuilder(rawText, isActive)
                    else ...[
                      Text(
                        displayFormatter != null 
                            ? displayFormatter(rawText)
                            : (rawText.isEmpty ? '--' : rawText),
                        style: GoogleFonts.oswald(
                          fontSize: 56, 
                          fontWeight: FontWeight.w400,
                          color: isActive ? theme.accent : theme.text,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (unit.isNotEmpty)
                        Text(
                          unit, 
                          style: GoogleFonts.oswald(
                            fontSize: 24, 
                            color: theme.textSecondary,
                            fontWeight: FontWeight.w400
                          )
                        ),
                    ],
                  ],
                ),
              ),
            ),
            if (label.isNotEmpty)
              const SizedBox(width: 60), // Balance the left label only when there is a label
          ],
        ),
      ),
    );
  }



  void _showRemoveCustomStampDialog(BuildContext context, RecordProvider provider, String stamp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Stamp'),
        content: Text('Delete custom stamp "$stamp"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.removeCustomStamp(stamp);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodRow(RecordProvider provider, AppTheme theme) {
    final moodStamps = ['☹️', '😐', '🙂', '😀'];
    final currentStamps = provider.currentRecord.stamps;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.transparent,
      child: Row(
        children: [

          // Mood stamps - centered
          Expanded(
            child: Center(
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: moodStamps.map((stamp) {
                  final isSelected = currentStamps.contains(stamp);
                  return GestureDetector(
                    onTap: () {
                      _dismissKeypad();
                      provider.toggleStamp(stamp, exclusiveGroup: moodStamps);
                    },
                    child: Opacity(
                      opacity: isSelected ? 1.0 : 0.3,
                      child: Text(stamp, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMemoDialog(BuildContext context, RecordProvider provider, AppTheme theme) {
    final memoText = provider.currentRecord.memos.isNotEmpty ? provider.currentRecord.memos[0] : '';
    final controller = TextEditingController(text: memoText);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'メモ',
                      style: GoogleFonts.oswald(
                        color: theme.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.backspace, color: theme.textSecondary),
                      onPressed: () {
                        controller.clear();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'クリア',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.divider.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.divider,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: 6,
                    autofocus: true,
                    style: TextStyle(color: theme.text, fontSize: 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'フリーメモを入力...',
                      hintStyle: TextStyle(color: theme.textSecondary.withOpacity(0.5)),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('キャンセル', style: TextStyle(color: theme.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await _saveMemo(provider, controller.text);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accent,
                        foregroundColor: theme.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCustomDatePicker(BuildContext context, RecordProvider provider, AppTheme theme) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return _DatePickerDialog(initialDate: provider.selectedDate, theme: theme);
      },
    );

    if (picked != null && picked != provider.selectedDate) {
      provider.updateDate(picked);
    }
  }
}

class _DatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final AppTheme theme;

  const _DatePickerDialog({required this.initialDate, required this.theme});

  @override
  State<_DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<_DatePickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  final int _minYear = 2020;
  final int _maxYear = 2030;

  @override
  void initState() {
    super.initState();
    _initDate(widget.initialDate);
  }

  void _initDate(DateTime date) {
    _selectedYear = date.year;
    _selectedMonth = date.month;
    _selectedDay = date.day;

    _yearController = FixedExtentScrollController(initialItem: _selectedYear - _minYear);
    _monthController = FixedExtentScrollController(initialItem: _selectedMonth - 1);
    _dayController = FixedExtentScrollController(initialItem: _selectedDay - 1);
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _onTodayPressed() {
    final now = DateTime.now();
    setState(() {
      _selectedYear = now.year;
      _selectedMonth = now.month;
      _selectedDay = now.day;
      
      // Use existing controllers to jump to the new date
      if (_yearController.hasClients) {
        _yearController.jumpToItem(_selectedYear - _minYear);
      }
      if (_monthController.hasClients) {
        _monthController.jumpToItem(_selectedMonth - 1);
      }
      if (_dayController.hasClients) {
        _dayController.jumpToItem(_selectedDay - 1);
      }
    });
  }

  int _getDaysInMonth(int year, int month) {
    return DateUtils.getDaysInMonth(year, month);
  }

  void _validateDay() {
    int days = _getDaysInMonth(_selectedYear, _selectedMonth);
    if (_selectedDay > days) {
      _selectedDay = days;
      if (_dayController.hasClients) {
        _dayController.jumpToItem(_selectedDay - 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.theme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 480,
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '日付設定',
                  style: GoogleFonts.oswald(
                    color: widget.theme.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ElevatedButton(
                  onPressed: _onTodayPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.theme.text.withOpacity(0.15),
                    foregroundColor: widget.theme.text,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text('TODAY', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Pickers
            Expanded(
              child: Row(
                children: [
                  // Year
                  Expanded(child: _buildPicker(
                    controller: _yearController,
                    itemCount: _maxYear - _minYear + 1,
                    itemBuilder: (context, index) => Center(child: Text('${_minYear + index}')),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedYear = _minYear + index;
                        _validateDay();
                      });
                    },
                  )),
                  // Month
                  Expanded(child: _buildPicker(
                    controller: _monthController,
                    itemCount: 12,
                    itemBuilder: (context, index) => Center(child: Text('${index + 1}')),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedMonth = index + 1;
                        _validateDay();
                      });
                    },
                  )),
                  // Day
                  Expanded(child: _buildPicker(
                    controller: _dayController,
                    itemCount: 31, // Always 31 items, but we might snap back if invalid? 
                    // Better: Dynamic item count? CupertinoPicker requires fixed child count or builder.
                    // If we change itemCount, it might crash if index is out of bounds.
                    // Strategy: Show 31 days, but if user picks 31 on Feb, snap back.
                    itemBuilder: (context, index) => Center(child: Text('${index + 1}')),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedDay = index + 1;
                        // We don't validate immediately to allow scrolling, but we should validate on finish?
                        // Or just let them pick and validate on OK?
                        // Let's validate strictly.
                        int days = _getDaysInMonth(_selectedYear, _selectedMonth);
                        if (_selectedDay > days) {
                           // This might cause a jump loop if we are not careful.
                           // For now, let's just update _selectedDay.
                           // If it's invalid, we can handle it or just let it be (and clamp on OK).
                           // But visual feedback is good.
                        }
                      });
                    },
                  )),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Footer Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56, // Increased height
                    child: ElevatedButton(
                      onPressed: () {
                        // Final validation
                        int days = _getDaysInMonth(_selectedYear, _selectedMonth);
                        int finalDay = _selectedDay.clamp(1, days);
                        
                        Navigator.pop(context, DateTime(_selectedYear, _selectedMonth, finalDay));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.theme.text.withOpacity(0.1),
                        foregroundColor: widget.theme.text,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                      ),
                      child: const Text('OK', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 56, // Increased height
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.theme.text.withOpacity(0.1),
                        foregroundColor: widget.theme.text,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                      ),
                      child: const Text('キャンセル', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPicker({
    required FixedExtentScrollController controller,
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    return CupertinoPicker.builder(
      scrollController: controller,
      itemExtent: 50,
      childCount: itemCount,
      useMagnifier: true,
      magnification: 1.1,
      itemBuilder: (context, index) {
        return Center(
          child: DefaultTextStyle(
            style: GoogleFonts.oswald(
              color: widget.theme.text, 
              fontSize: 32,
              fontWeight: FontWeight.w500,
            ),
            child: itemBuilder(context, index),
          ),
        );
      },
      onSelectedItemChanged: onSelectedItemChanged,
      selectionOverlay: Container(
        decoration: BoxDecoration(
          color: widget.theme.text.withOpacity(0.05),
          border: Border.symmetric(
            horizontal: BorderSide(color: widget.theme.text.withOpacity(0.4), width: 1.5),
          ),
        ),
      ),
    );
  }

}
