import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/seasonality_service.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController fruitNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  File? selectedImage;
  String? base64Image;
  String? selectedStatus;

  double? latitude;
  double? longitude;
  String? locationName;

  DateTime reportedDate = DateTime.now();
  DateTime? predictedNextHarvest;

  bool isLoading = false;
  bool isGettingLocation = false;

  final List<String> ripenessStatuses = [
    'Belum Matang',
    'Matang Sebagian',
    'Siap Panen',
    'Sudah Dipetik',
    'Tidak Berbuah',
  ];

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );

    if (image == null) return;

    final File imageFile = File(image.path);

    final Uint8List? compressedBytes =
        await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          minWidth: 600,
          minHeight: 600,
          quality: 45,
          format: CompressFormat.jpeg,
        );

    if (compressedBytes == null) {
      showMessage('Gagal mengompres gambar');
      return;
    }

    final String encodedImage = base64Encode(compressedBytes);

    if (encodedImage.length > 900000) {
      showMessage(
        'Ukuran foto masih terlalu besar. Pilih foto yang lebih kecil.',
      );
      return;
    }

    setState(() {
      selectedImage = imageFile;
      base64Image = encodedImage;
    });
  }

  Future<void> getCurrentLocation() async {
    setState(() {
      isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        showMessage(
          'GPS belum aktif. Silakan aktifkan lokasi terlebih dahulu.',
        );
        setState(() {
          isGettingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        showMessage('Izin lokasi ditolak.');
        setState(() {
          isGettingLocation = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        showMessage(
          'Izin lokasi ditolak permanen. Aktifkan melalui pengaturan.',
        );
        setState(() {
          isGettingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String address = 'Lokasi tidak diketahui';

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address =
              '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}';
        }
      } catch (_) {
        address = 'Lat: ${position.latitude}, Long: ${position.longitude}';
      }

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
        locationName = address;
      });
    } catch (e) {
      showMessage('Gagal mengambil lokasi: $e');
    }

    setState(() {
      isGettingLocation = false;
    });
  }

  void calculatePrediction() {
    if (fruitNameController.text.trim().isEmpty) {
      predictedNextHarvest = null;
      return;
    }

    predictedNextHarvest = SeasonalityService.predictNextHarvest(
      fruitName: fruitNameController.text.trim(),
      reportedDate: reportedDate,
    );
  }

  Future<void> savePost() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('User belum login');
      return;
    }

    if (base64Image == null) {
      showMessage('Foto pohon atau buah wajib dipilih');
      return;
    }

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

    if (latitude == null || longitude == null) {
      showMessage('Lokasi GPS wajib diambil');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      calculatePrediction();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final userName = userData?['name'] ?? user.email ?? 'Pengguna';

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'userName': userName,
        'userEmail': user.email,
        'fruitName': fruitNameController.text.trim(),
        'description': descriptionController.text.trim(),
        'imageBase64': base64Image,
        'ripenessStatus': selectedStatus,
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName ?? 'Lokasi tidak diketahui',
        'reportedDate': Timestamp.fromDate(reportedDate),
        'predictedNextHarvest': predictedNextHarvest != null
            ? Timestamp.fromDate(predictedNextHarvest!)
            : null,
        'seasonDescription': SeasonalityService.getSeasonDescription(
          fruitNameController.text.trim(),
        ),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      clearForm();
      showMessageSuccess('Posting berhasil ditambahkan');
    } catch (e) {
      showMessage('Gagal menyimpan posting: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  void clearForm() {
    fruitNameController.clear();
    descriptionController.clear();

    setState(() {
      selectedImage = null;
      base64Image = null;
      selectedStatus = null;
      latitude = null;
      longitude = null;
      locationName = null;
      reportedDate = DateTime.now();
      predictedNextHarvest = null;
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void showMessageSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
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
    calculatePrediction();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text('Tambah Postingan'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 210,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.green),
                ),
                child: selectedImage == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            size: 50,
                            color: Colors.green,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Pilih Foto Pohon/Buah',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(
                          selectedImage!,
                          width: double.infinity,
                          height: 210,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: fruitNameController,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                setState(() {
                  calculatePrediction();
                });
              },
              decoration: InputDecoration(
                labelText: 'Nama Buah',
                hintText: 'Contoh: Mangga, Rambutan, Pisang',
                prefixIcon: const Icon(Icons.eco),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Deskripsi',
                hintText:
                    'Contoh: Pohon mangga di pinggir jalan sedang berbuah...',
                prefixIcon: const Icon(Icons.description),
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
                prefixIcon: const Icon(Icons.spa),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: ripenessStatuses.map((status) {
                return DropdownMenuItem(value: status, child: Text(status));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedStatus = value;
                });
              },
            ),

            const SizedBox(height: 16),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lokasi GPS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(locationName ?? 'Lokasi belum diambil'),
                    if (latitude != null && longitude != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Latitude: $latitude\nLongitude: $longitude',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isGettingLocation
                            ? null
                            : getCurrentLocation,
                        icon: isGettingLocation
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                          isGettingLocation
                              ? 'Mengambil Lokasi...'
                              : 'Ambil Lokasi Saat Ini',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              color: Colors.green.shade50,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        predictedNextHarvest == null
                            ? 'Prediksi panen akan muncul setelah nama buah diisi.'
                            : 'Prediksi panen berikutnya: ${DateFormat('dd MMMM yyyy', 'id_ID').format(predictedNextHarvest!)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : savePost,
                icon: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  isLoading ? 'Menyimpan...' : 'Simpan Postingan',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
