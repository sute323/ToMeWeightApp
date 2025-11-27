import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/record_provider.dart';
import '../utils/csv_helper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;
    final recordProvider = Provider.of<RecordProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Settings',
          style: GoogleFonts.oswald(
            color: theme.text,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: theme.text),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Data Management Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Data Management',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: Text(
              'CSVインポート',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
              ),
            ),
            trailing: null,
            onTap: () async {
              try {
                final records = await CsvHelper.pickAndParseCsv();
                if (records.isNotEmpty) {
                  await recordProvider.importData(records);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${records.length} records imported successfully'),
                        backgroundColor: theme.accent,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Import failed: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          ),
          ListTile(
            title: Text(
              'CSVエクスポート',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
              ),
            ),
            trailing: null,
            onTap: () async {
              try {
                final records = recordProvider.getAllRecords();
                if (records.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('No data to export'),
                        backgroundColor: theme.textSecondary,
                      ),
                    );
                  }
                  return;
                }

                final csvContent = CsvHelper.exportToCsv(records);
                final success = await CsvHelper.saveCsvFile(csvContent);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Exported ${records.length} records successfully'
                          : 'Export cancelled'),
                      backgroundColor: success ? theme.accent : theme.textSecondary,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Export failed: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          ),
          const Divider(height: 32, thickness: 1),
          
          // Theme Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Theme',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...themeProvider.availableThemes.map((t) {
            final isSelected = t.name == theme.name;
            return ListTile(
              title: Text(
                t.name,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 18,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check, color: theme.accent)
                  : null,
              onTap: () {
                themeProvider.setTheme(t.name);
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            );
          }).toList(),
        ],
      ),
    );
  }
}
