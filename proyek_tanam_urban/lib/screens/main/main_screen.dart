import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home/home_screen.dart';
import '../post/add_post_screen.dart';
import '../favorite/favorite_screen.dart';
import '../profile/profile_screen.dart';
import '../../providers/theme_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  final List<Widget> pages = const [
    HomeScreen(),
    AddPostScreen(),
    FavoriteScreen(),
    ProfileScreen(),
  ];

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onItemTapped,
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        indicatorColor: isDarkMode ? Colors.green.shade900 : Colors.green.shade100,
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
            ),
            selectedIcon: Icon(Icons.home, color: Colors.green),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.add_circle_outline,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
            ),
            selectedIcon: Icon(Icons.add_circle, color: Colors.green),
            label: 'Tambah',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.favorite_border,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
            ),
            selectedIcon: const Icon(Icons.favorite, color: Colors.red),
            label: 'Favorit',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
            ),
            selectedIcon: Icon(Icons.person, color: Colors.green),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}