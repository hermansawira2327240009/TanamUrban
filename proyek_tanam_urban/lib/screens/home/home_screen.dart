import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../detail/detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String formatStatus(String status) {
    switch (status) {
      case 'belum_matang':
        return 'Belum Matang';
      case 'matang_sebagian':
        return 'Matang Sebagian';
      case 'siap_panen':
        return 'Siap Panen';
      case 'sudah_dipetik':
        return 'Sudah Dipetik';
      case 'tidak_berbuah':
        return 'Tidak Berbuah';

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
      case 'belum_matang':
      case 'Belum Matang':
        return Colors.orange;

      case 'matang_sebagian':
      case 'Matang Sebagian':
        return Colors.amber;

      case 'siap_panen':
      case 'Siap Panen':
        return Colors.green;

      case 'sudah_dipetik':
      case 'Sudah Dipetik':
        return Colors.grey;

      case 'tidak_berbuah':
      case 'Tidak Berbuah':
        return Colors.brown;

      default:
        return Colors.blueGrey;
    }
  }

  String formatDate(dynamic timestamp) {
    if (timestamp == null) return '-';

    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy', 'id_ID').format(timestamp.toDate());
    }

    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'TanamUrban',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Terjadi kesalahan saat mengambil data'),
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
                      'Belum ada posting',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tambahkan lokasi pohon buah atau hasil kebun pertama kamu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final postDoc = posts[index];
              final data = postDoc.data() as Map<String, dynamic>;

              final String postId = postDoc.id;
              final String fruitName = data['fruitName'] ?? 'Tanpa Nama';
              final String description = data['description'] ?? '';
              final String imageBase64 = data['imageBase64'] ?? '';
              final String ripenessStatus = data['ripenessStatus'] ?? '';
              final String locationName =
                  data['locationName'] ?? 'Lokasi tidak diketahui';
              final String userName = data['userName'] ?? 'Pengguna';
              final String postingDate = formatDate(data['createdAt']);

              return Card(
                margin: const EdgeInsets.only(bottom: 18),
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
                          postId: postId,
                          postData: data,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          if (imageBase64.isNotEmpty)
                            Image.memory(
                              base64Decode(imageBase64),
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.08),
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 50,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                );
                              },
                            )
                          else
                            Container(
                              height: 200,
                              width: double.infinity,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.08),
                              child: Center(
                                child: Icon(
                                  Icons.eco,
                                  size: 60,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),

                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: getStatusColor(ripenessStatus),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                formatStatus(ripenessStatus),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fruitName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 17,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                height: 1.4,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    locationName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Divider(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withValues(alpha: 0.4),
                            ),

                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  postingDate == '-'
                                      ? 'Tanggal tidak tersedia'
                                      : postingDate,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                                ),

                                const Spacer(),

                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('posts')
                                      .doc(postId)
                                      .collection('comments')
                                      .snapshots(),
                                  builder: (context, commentSnapshot) {
                                    int commentCount = 0;

                                    if (commentSnapshot.hasData) {
                                      commentCount =
                                          commentSnapshot.data!.docs.length;
                                    }

                                    return Row(
                                      children: [
                                        Icon(
                                          Icons.comment,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '$commentCount Komentar',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetailScreen(
                                        postId: postId,
                                        postData: data,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.visibility),
                                label: const Text('Lihat Detail'),
                              ),
                            ),
                          ],
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