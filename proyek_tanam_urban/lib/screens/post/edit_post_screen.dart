import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/seasonality_service.dart';

class EditPostScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const EditPostScreen({
    super.key,
    required this.postId,
    required this.postData,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final TextEditingController fruitNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  String? selectedStatus;
  bool isLoading = false;

  final List<String> ripenessStatuses = [
    'Belum Matang',
    'Matang Sebagian',
    'Siap Panen',
    'Sudah Dipetik',
    'Tidak Berbuah',
  ];

  @override
  void initState() {
    super.initState();

    fruitNameController.text = widget.postData['fruitName'] ?? '';
    descriptionController.text = widget.postData['description'] ?? '';
    selectedStatus = widget.postData['ripenessStatus'];
  }

  DateTime getReportedDate() {
    final reportedDate = widget.postData['reportedDate'];

    if (reportedDate is Timestamp) {
      return reportedDate.toDate();
    }

    return DateTime.now();
  }

  Future<void> updatePost() async {
    if (fruitNameController.text.trim().isEmpty) {
      showMessage('Nama buah wajib diisi');
      return;
    }

    if (descriptionController.text.trim().length < 10) {
      showMessage('Deskripsi minimal 10 karakter');
      return;
    }

    if (selectedStatus == null) {
      showMessage('Status kematangan wajib dipilih');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final String fruitName = fruitNameController.text.trim();
      final DateTime reportedDate = getReportedDate();

      final DateTime predictedNextHarvest =
          SeasonalityService.predictNextHarvest(
        fruitName: fruitName,
        reportedDate: reportedDate,
      );

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({
        'fruitName': fruitName,
        'description': descriptionController.text.trim(),
        'ripenessStatus': selectedStatus,
        'predictedNextHarvest': Timestamp.fromDate(predictedNextHarvest),
        'seasonDescription': SeasonalityService.getSeasonDescription(fruitName),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Posting berhasil diperbarui'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      showMessage('Gagal memperbarui posting: $e');
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  void dispose() {
    fruitNameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String imageBase64 = widget.postData['imageBase64'] ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Edit Postingan'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.info,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Pada halaman ini, foto dan lokasi tidak diubah. Yang diedit adalah nama buah, deskripsi, dan status kematangan.',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: fruitNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nama Buah',
                prefixIcon: Icon(
                  Icons.eco,
                  color: Theme.of(context).colorScheme.primary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Deskripsi',
                prefixIcon: Icon(
                  Icons.description,
                  color: Theme.of(context).colorScheme.primary,
                ),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: selectedStatus,
              decoration: InputDecoration(
                labelText: 'Status Kematangan',
                prefixIcon: Icon(
                  Icons.spa,
                  color: Theme.of(context).colorScheme.primary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: ripenessStatuses.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedStatus = value;
                });
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : updatePost,
                icon: isLoading
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  isLoading ? 'Menyimpan...' : 'Simpan Perubahan',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            if (imageBase64.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Catatan: Foto posting tetap memakai foto lama.',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}