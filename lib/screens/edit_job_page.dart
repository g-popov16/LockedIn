import 'package:flutter/material.dart';
import '../sql.dart';
// 1. Import AppLocalizations
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EditJobPage extends StatefulWidget {
  final int jobId;
  final String initialTitle;
  final String initialCompany;
  final String initialDescription;
  final VoidCallback onJobUpdated;

  const EditJobPage({
    super.key,
    required this.jobId,
    required this.initialTitle,
    required this.initialCompany,
    required this.initialDescription,
    required this.onJobUpdated,
  });

  @override
  _EditJobPageState createState() => _EditJobPageState();
}

class _EditJobPageState extends State<EditJobPage> {
  final PostgresDB db = PostgresDB();

  late TextEditingController _titleController;
  late TextEditingController _companyController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _companyController = TextEditingController(text: widget.initialCompany);
    _descriptionController = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    // Get l10n instance and ScaffoldMessenger safely
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final updatedTitle = _titleController.text.trim();
    final updatedCompany = _companyController.text.trim();
    final updatedDescription = _descriptionController.text.trim();

    if (updatedTitle.isEmpty || updatedCompany.isEmpty || updatedDescription.isEmpty) {
      // Use localized error
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.editJobFieldsRequiredError)));
      return;
    }

    try {
      await db.updateJob(
        jobId: widget.jobId,
        title: updatedTitle,
        description: updatedDescription,
        company: updatedCompany,
      );
      // Check mounted before SnackBar, callback, and pop
      if (!mounted) return;
      // Use localized success message
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.editJobUpdateSuccess)));
      widget.onJobUpdated(); // Call refresh callback
      if (mounted) Navigator.pop(context); // Pop only if still mounted
    } catch (e) {
      print("Error updating job: $e");
      // Check mounted before SnackBar
      if (!mounted) return;
      // Use localized error message
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.editJobUpdateFailedError)));
    }
  }

  Future<void> _deleteJob() async {
    // Get l10n instance and ScaffoldMessenger safely
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Optional: Add confirmation dialog before deleting
      // bool confirmDelete = await showDialog(...) ?? false;
      // if (!confirmDelete || !mounted) return;

      await db.deleteJob(widget.jobId);
      // Check mounted before SnackBar, callback, and pop
      if (!mounted) return;
      // Use localized success message
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.editJobDeleteSuccess)));
      widget.onJobUpdated(); // Call refresh callback
      if (mounted) Navigator.pop(context); // Pop only if still mounted
    } catch (e) {
      print("Error deleting job: $e");
      // Check mounted before SnackBar
      if (!mounted) return;
      // Use localized error message
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.editJobDeleteFailedError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. Get AppLocalizations instance
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context); // Keep theme reference

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Use theme background
      appBar: AppBar(
        // 3. Use localized title
        title: Text(l10n.editJobTitle, style: theme.appBarTheme.titleTextStyle), // Use theme style
        backgroundColor: theme.appBarTheme.backgroundColor, // Use theme color
        iconTheme: theme.appBarTheme.iconTheme, // Use theme icon theme
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // Wrap with SingleChildScrollView if content might overflow on smaller screens
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Job Title
              TextField(
                controller: _titleController,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  // 3. Use localized labels/hints
                  labelText: l10n.jobTitleLabel,
                  labelStyle: theme.textTheme.bodyLarge,
                  hintText: l10n.jobTitleHint,
                  hintStyle: theme.textTheme.bodyMedium,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white70)),
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                ),
              ),
              const SizedBox(height: 10),

              // Company Name
              TextField(
                controller: _companyController,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  // 3. Use localized labels/hints
                  labelText: l10n.companyNameLabel,
                  labelStyle: theme.textTheme.bodyLarge,
                  hintText: l10n.companyNameHint,
                  hintStyle: theme.textTheme.bodyMedium,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white70)),
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                ),
              ),
              const SizedBox(height: 10),

              // Job Description
              TextField(
                controller: _descriptionController,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  // 3. Use localized labels/hints
                  labelText: l10n.jobDescriptionLabel,
                  labelStyle: theme.textTheme.bodyLarge,
                  hintText: l10n.jobDescriptionHint,
                  hintStyle: theme.textTheme.bodyMedium,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white70)),
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _deleteJob, // Keep logic
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    // 3. Use localized button text
                    child: Text(l10n.deleteJobButton),
                  ),
                  ElevatedButton(
                    onPressed: _saveChanges, // Keep logic
                    style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor),
                    // 3. Use localized button text
                    child: Text(l10n.saveChangesButton),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}