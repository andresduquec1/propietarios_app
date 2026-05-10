import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_page.dart';
import 'search_page.dart';
import 'residents_page.dart';
import 'history_page.dart';
import 'admin_page.dart';

class HomePage extends StatefulWidget {
  final String userEmail;
  const HomePage({super.key, required this.userEmail});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _historyEnabled = false;
  bool _isAdmin = false;
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Por defecto es falso si no existe la llave
      _historyEnabled = prefs.getBool('history_enabled') ?? false;
      _isAdmin = prefs.getBool('is_admin') ?? false;
      _isLoadingPermissions = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> _getPages() {
    List<Widget> pages = [
      ProfilePage(userEmail: widget.userEmail),
      const SearchPage(),
      const ResidentsPage(),
    ];
    
    // Solo añadimos la página de historial si está habilitada o si es admin
    if (_historyEnabled || _isAdmin) {
      pages.add(const HistoryPage());
    }

    if (_isAdmin) {
      pages.add(const AdminPage());
    }
    
    return pages;
  }

  List<BottomNavigationBarItem> _getNavItems() {
    List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Mi Perfil',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.search),
        label: 'Consulta',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.groups_rounded),
        label: 'Mi Apto',
      ),
    ];

    if (_historyEnabled || _isAdmin) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.history),
        label: 'Historial',
      ));
    }

    if (_isAdmin) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.admin_panel_settings),
        label: 'Admin',
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPermissions) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = _getPages();
    final navItems = _getNavItems();

    // Asegurarse de que el índice seleccionado no sea mayor al número de páginas
    // (por si los permisos cambian dinámicamente)
    int safeIndex = _selectedIndex >= pages.length ? 0 : _selectedIndex;

    return Scaffold(
      body: pages[safeIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.indigo,
        type: BottomNavigationBarType.fixed,
        items: navItems,
      ),
    );
  }
}
