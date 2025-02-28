import 'package:flutter/material.dart';
import '../sql.dart';

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
    final updatedTitle = _titleController.text.trim();
    final updatedCompany = _companyController.text.trim();
    final updatedDescription = _descriptionController.text.trim();

    if (updatedTitle.isEmpty || updatedCompany.isEmpty || updatedDescription.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields must be filled!")),
      );
      return;
    }

    try {
      await db.updateJob(
        jobId: widget.jobId,
        title: updatedTitle,
        description: updatedDescription,
        company: updatedCompany,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Job updated successfully!")),
      );
      widget.onJobUpdated();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update the job.")),
      );
    }
  }

  Future<void> _deleteJob() async {
    try {
      await db.deleteJob(widget.jobId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Job deleted successfully!")),
      );
      widget.onJobUpdated();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete the job.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Job", style: theme.textTheme.titleLarge),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Job Title
            TextField(
              controller: _titleController,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: "Job Title",
                labelStyle: theme.textTheme.bodyLarge,
                hintText: "Enter job title",
                hintStyle: theme.textTheme.bodyMedium,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white70),
                ),
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
                labelText: "Company Name",
                labelStyle: theme.textTheme.bodyLarge,
                hintText: "Enter company name",
                hintStyle: theme.textTheme.bodyMedium,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white70),
                ),
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
                labelText: "Job Description",
                labelStyle: theme.textTheme.bodyLarge,
                hintText: "Enter job description",
                hintStyle: theme.textTheme.bodyMedium,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white70),
                ),
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
                  onPressed: _deleteJob,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Delete Job"),
                ),
                ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor),
                  child: const Text("Save Changes"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
