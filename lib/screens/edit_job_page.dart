import 'package:flutter/material.dart';
import '../sql.dart'; // Ensure this matches your actual import path

class EditJobPage extends StatefulWidget {
  final int jobId;
  final String initialTitle;
  final String initialCompany;
  final String initialDescription;
  final VoidCallback onJobUpdated; // Callback to notify parent to refresh

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
      widget.onJobUpdated(); // Notify the parent page to refresh
      Navigator.pop(context); // Close EditJobPage
    } catch (e) {
      print("Error saving job: $e");
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
      widget.onJobUpdated(); // Notify the parent page to refresh
      Navigator.pop(context); // Close EditJobPage
    } catch (e) {
      print("Error deleting job: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete the job.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Job"),
        backgroundColor: Colors.grey[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Job Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // Company
            TextField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: "Company Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // Description
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "Job Description",
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 20),

            // Save + Delete Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _deleteJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Delete Job"),
                ),
                ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
