import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../detail/detail_screen.dart';

class FavoriteScreen extends StatelessWidget {
  const FavoriteScreen({super.key});

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

  Future<DocumentSnapshot?> getPostData(String postId) async {
    final postDoc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .get();

    if (!postDoc.exists) {
      return null;
    }

    return postDoc;
  }

  Future<void> removeFavorite(String postId, BuildContext context) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(postId)
        .delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Posting dihapus dari favorit'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Silakan login terlebih dahulu')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Favorit'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, favoriteSnapshot) {
          if (favoriteSnapshot.hasError) {
            return const Center(child: Text('Gagal memuat favorit'));
          }

          if (favoriteSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!favoriteSnapshot.hasData ||
              favoriteSnapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada posting favorit.\nTambahkan favorit dari halaman detail posting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          final favorites = favoriteSnapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final favoriteData =
                  favorites[index].data() as Map<String, dynamic>;

              final String postId = favoriteData['postId'];

              return FutureBuilder<DocumentSnapshot?>(
                future: getPostData(postId),
                builder: (context, postSnapshot) {
                  if (postSnapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (!postSnapshot.hasData || postSnapshot.data == null) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.warning,
                          color: Colors.orange,
                        ),
                        title: const Text('Posting tidak ditemukan'),
                        subtitle: const Text('Posting mungkin sudah dihapus.'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            removeFavorite(postId, context);
                          },
                        ),
                      ),
                    );
                  }

                  final postDoc = postSnapshot.data!;
                  final data = postDoc.data() as Map<String, dynamic>;

                  final fruitName = data['fruitName'] ?? 'Tanpa Nama';
                  final description = data['description'] ?? '';
                  final imageBase64 = data['imageBase64'] ?? '';
                  final ripenessStatus = data['ripenessStatus'] ?? '';
                  final locationName =
                      data['locationName'] ?? 'Lokasi tidak diketahui';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
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
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(18),
                            ),
                            child: imageBase64.isNotEmpty
                                ? Image.memory(
                                    base64Decode(imageBase64),
                                    width: 120,
                                    height: 140,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 120,
                                        height: 140,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary.withValues(alpha: 0.08),
                                        child: Icon(
                                          Icons.image_not_supported,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    width: 120,
                                    height: 140,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withValues(alpha: 0.08),
                                    child: Icon(
                                      Icons.eco,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 40,
                                    ),
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
                                          ripenessStatus,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: getStatusColor(
                                              ripenessStatus,
                                            ),
                                            fontWeight: FontWeight.w600,
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
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          locationName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.color,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          IconButton(
                            icon: Icon(
                              Icons.favorite,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () {
                              removeFavorite(postId, context);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
