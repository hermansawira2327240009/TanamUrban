import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../post/edit_post_screen.dart';

class DetailScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const DetailScreen({
    super.key,
    required this.postId,
    required this.postData,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final TextEditingController commentController = TextEditingController();

  bool isSendingComment = false;
  bool isFavorite = false;
  bool isFavoriteLoading = true;

  String? replyingToCommentId;
  String? replyingToUserName;

  @override
  void initState() {
    super.initState();
    checkFavoriteStatus();
  }

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
      await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );
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
        'parentCommentId': replyingToCommentId,
        'replyingToUserName': replyingToUserName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      commentController.clear();

      setState(() {
        replyingToCommentId = null;
        replyingToUserName = null;
      });
    } catch (e) {
      showMessage('Gagal mengirim komentar: $e');
    }

    if (mounted) {
      setState(() {
        isSendingComment = false;
      });
    }
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

    if (mounted) {
      setState(() {
        isFavorite = favoriteDoc.exists;
        isFavoriteLoading = false;
      });
    }
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Dihapus dari favorit'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } else {
        await favoriteRef.set({
          'postId': widget.postId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          isFavorite = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ditambahkan ke favorit'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
    } catch (e) {
      showMessage('Gagal mengubah favorit: $e');
    }
  }

  Future<void> confirmDeletePost() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Postingan'),
          content: const Text(
            'Apakah kamu yakin ingin menghapus postingan ini? Komentar pada postingan juga akan ikut dihapus.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      deletePost();
    }
  }

  Future<void> deletePost() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('User belum login');
      return;
    }

    if (widget.postData['userId'] != user.uid) {
      showMessage('Kamu hanya bisa menghapus postingan milik sendiri');
      return;
    }

    try {
      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.postId);

      final commentsSnapshot = await postRef.collection('comments').get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(postRef);

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Posting berhasil dihapus'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      showMessage('Gagal menghapus posting: $e');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
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

    final User? currentUser = FirebaseAuth.instance.currentUser;
    final bool isOwner =
        currentUser != null && data['userId'] == currentUser.uid;

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

          if (isOwner)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              onSelected: (value) async {
                if (value == 'edit') {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditPostScreen(
                        postId: widget.postId,
                        postData: widget.postData,
                      ),
                    ),
                  );

                  if (result == true && mounted) {
                    Navigator.pop(context);
                  }
                }

                if (value == 'delete') {
                  confirmDeletePost();
                }
              },
              itemBuilder: (context) {
                return [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit Postingan'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Hapus Postingan',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              },
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
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08),
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
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.08),
                    child: Icon(
                      Icons.eco,
                      size: 70,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
          ),

          const SizedBox(height: 16),

          if (isOwner)
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.06),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Ini adalah postingan milik kamu. Kamu bisa mengedit atau menghapus melalui tombol titik tiga di kanan atas.',
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (isOwner) const SizedBox(height: 12),

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
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Diposting oleh $userName'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                    ),
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(locationName),
                      ),
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
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.06),
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          if (replyingToCommentId != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Membalas komentar dari $replyingToUserName',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        replyingToCommentId = null;
                        replyingToUserName = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: commentController,
                  decoration: InputDecoration(
                    hintText: replyingToCommentId == null
                        ? 'Tulis komentar...'
                        : 'Tulis balasan...',
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
                .orderBy('createdAt', descending: false)
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
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Belum ada komentar. Jadilah yang pertama berkomentar.',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                );
              }

              final comments = snapshot.data!.docs;

              final mainComments = comments.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['parentCommentId'] == null;
              }).toList();

              final replies = comments.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['parentCommentId'] != null;
              }).toList();

              return Column(
                children: mainComments.map((doc) {
                  final comment = doc.data() as Map<String, dynamic>;
                  final commentId = doc.id;

                  final commentReplies = replies.where((replyDoc) {
                    final replyData =
                        replyDoc.data() as Map<String, dynamic>;
                    return replyData['parentCommentId'] == commentId;
                  }).toList();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: Icon(
                                Icons.person,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            title: Text(
                              comment['userName'] ?? 'Pengguna',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(comment['commentText'] ?? ''),
                          ),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  replyingToCommentId = commentId;
                                  replyingToUserName =
                                      comment['userName'] ?? 'Pengguna';
                                });
                              },
                              icon: const Icon(Icons.reply, size: 18),
                              label: const Text('Balas'),
                            ),
                          ),

                          if (commentReplies.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 36,
                                top: 4,
                              ),
                              child: Column(
                                children: commentReplies.map((replyDoc) {
                                  final reply = replyDoc.data()
                                      as Map<String, dynamic>;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 15,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          child: Icon(
                                            Icons.person,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                reply['userName'] ??
                                                    'Pengguna',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                reply['commentText'] ?? '',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
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
}