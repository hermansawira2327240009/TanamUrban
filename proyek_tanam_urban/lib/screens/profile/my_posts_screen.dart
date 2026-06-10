import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../detail/detail_screen.dart';

class MyPostsScreen extends StatelessWidget {
  const MyPostsScreen({super.key});

  String formatDate(dynamic timestamp) {
    if (timestamp == null) return '-';

    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy', 'id_ID').format(timestamp.toDate());
    }

    return '-';
  }

  String formatStatus(String status) {
    switch (status) {
      case 'Belum Matang':
      case 'Matang Sebagian':
      case 'Siap Panen':
      case 'Sudah Dipetik':
      case 'Tidak Berbuah':
        return status;
      default:
        return status.isEmpty ? 'Status tidak diketahui' : status;
    }
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

  int compareCreatedAt(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
    final aData = a.data() as Map<String, dynamic>;
    final bData = b.data() as Map<String, dynamic>;

    final aCreatedAt = aData['createdAt'];
    final bCreatedAt = bData['createdAt'];

    if (aCreatedAt is Timestamp && bCreatedAt is Timestamp) {
      return bCreatedAt.compareTo(aCreatedAt);
    }

    if (aCreatedAt == null && bCreatedAt != null) return 1;
    if (aCreatedAt != null && bCreatedAt == null) return -1;

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('User belum login'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Postingan Saya'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat postingan.\n\nCoba periksa koneksi internet atau Firestore Rules.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.eco,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum ada postingan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Postingan yang kamu buat akan tampil di halaman ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final posts = snapshot.data!.docs;
          posts.sort(compareCreatedAt);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final postDoc = posts[index];
              final data = postDoc.data() as Map<String, dynamic>;

              final String fruitName = data['fruitName'] ?? 'Tanpa Nama';
              final String description = data['description'] ?? '';
              final String imageBase64 = data['imageBase64'] ?? '';
              final String ripenessStatus = data['ripenessStatus'] ?? '';
              final String locationName =
                  data['locationName'] ?? 'Lokasi tidak diketahui';
              final String createdAt = formatDate(data['createdAt']);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailScreen(
                          postId: postDoc.id,
                          postData: data,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      imageBase64.isNotEmpty
                          ? Image.memory(
                              base64Decode(imageBase64),
                              width: 120,
                              height: 145,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 120,
                                  height: 145,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.08),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                );
                              },
                            )
                          : Container(
                              width: 120,
                              height: 145,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.08),
                              child: Icon(
                                Icons.eco,
                                size: 40,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fruitName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 6),

                              Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 11,
                                    color: getStatusColor(ripenessStatus),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      formatStatus(ripenessStatus),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: getStatusColor(ripenessStatus),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 15,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      locationName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    createdAt,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}