import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const DetailScreen({super.key, required this.postId, required this.postData});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final TextEditingController commentController = TextEditingController();
  bool isSendingComment = false;
  bool isFavorite = false;
  bool isFavoriteLoading = true;

  String formatDate(dynamic timestamp) {
    if (timestamp == null) return '-';

    if (timestamp is Timestamp) {
      return DateFormat('dd MMMM yyyy', 'id_ID').format(timestamp.toDate());
    }

    return '-';
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Belum Matang':
        return Colors.orange;
      case 'Matang Sebagian':
        return Colors.amber;
      case 'Siap Panen':
        return Colors.green;
      case 'Sudah Dipetik':
        return Colors.grey;
      case 'Tidak Berbuah':
        return Colors.brown;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> openGoogleMaps() async {
    final latitude = widget.postData['latitude'];
    final longitude = widget.postData['longitude'];

    if (latitude == null || longitude == null) {
      showMessage('Lokasi tidak tersedia');
      return;
    }

    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      showMessage('Tidak dapat membuka Google Maps');
    }
  }

  Future<void> sendComment() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('User belum login');
      return;
    }

    if (commentController.text.trim().isEmpty) {
      showMessage('Komentar tidak boleh kosong');
      return;
    }

    setState(() {
      isSendingComment = true;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final userName = userData?['name'] ?? user.email ?? 'Pengguna';

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
            'userId': user.uid,
            'userName': userName,
            'userEmail': user.email,
            'commentText': commentController.text.trim(),
            'parentCommentId': null,
            'createdAt': FieldValue.serverTimestamp(),
          });

      commentController.clear();
    } catch (e) {
      showMessage('Gagal mengirim komentar: $e');
    }

    setState(() {
      isSendingComment = false;
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.postData;

    final String fruitName = data['fruitName'] ?? 'Tanpa Nama';
    final String description = data['description'] ?? '';
    final String imageBase64 = data['imageBase64'] ?? '';
    final String ripenessStatus = data['ripenessStatus'] ?? '-';
    final String locationName =
        data['locationName'] ?? 'Lokasi tidak diketahui';
    final String userName = data['userName'] ?? 'Pengguna';
    final String seasonDescription = data['seasonDescription'] ?? '-';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Detail Postingan'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: isFavoriteLoading ? null : toggleFavorite,
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: imageBase64.isNotEmpty
                ? Image.memory(
                    base64Decode(imageBase64),
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 240,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.08),
                        child: Icon(
                          Icons.image_not_supported,
                          size: 60,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  )
                : Container(
                    height: 240,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.08),
                    child: Icon(
                      Icons.eco,
                      size: 70,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
          ),

          const SizedBox(height: 16),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fruitName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 13,
                        color: getStatusColor(ripenessStatus),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ripenessStatus,
                        style: TextStyle(
                          color: getStatusColor(ripenessStatus),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    description,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lokasi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(child: Text(locationName)),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Latitude: ${data['latitude'] ?? '-'}\nLongitude: ${data['longitude'] ?? '-'}',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: openGoogleMaps,
                      icon: const Icon(Icons.map),
                      label: const Text('Buka di Google Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tanggal laporan: ${formatDate(data['reportedDate'])}\n'
                      'Prediksi panen berikutnya: ${formatDate(data['predictedNextHarvest'])}\n\n'
                      '$seasonDescription',
                      style: const TextStyle(
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Komentar',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: commentController,
                  decoration: InputDecoration(
                    hintText: 'Tulis komentar...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: isSendingComment ? null : sendComment,
                icon: isSendingComment
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .doc(widget.postId)
                .collection('comments')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Gagal memuat komentar');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Belum ada komentar. Jadilah yang pertama berkomentar.',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                );
              }

              final comments = snapshot.data!.docs;

              return Column(
                children: comments.map((doc) {
                  final comment = doc.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      title: Text(
                        comment['userName'] ?? 'Pengguna',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(comment['commentText'] ?? ''),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    checkFavoriteStatus();
  }

  Future<void> checkFavoriteStatus() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        isFavoriteLoading = false;
      });
      return;
    }

    final favoriteDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(widget.postId)
        .get();

    setState(() {
      isFavorite = favoriteDoc.exists;
      isFavoriteLoading = false;
    });
  }

  Future<void> toggleFavorite() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('User belum login');
      return;
    }

    final favoriteRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(widget.postId);

    try {
      if (isFavorite) {
        await favoriteRef.delete();

        setState(() {
          isFavorite = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Dihapus dari favorit'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        await favoriteRef.set({
          'postId': widget.postId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          isFavorite = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ditambahkan ke favorit'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      showMessage('Gagal mengubah favorit: $e');
    }
  }
}
