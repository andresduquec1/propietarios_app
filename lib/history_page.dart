import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_repository.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final DataRepository _repository = DataRepository();
  int? _userId;
  bool _isAdmin = false;
  
  List<dynamic> _myConsultations = [];
  List<dynamic> _othersConsultations = [];
  bool _isLoading = true;

  // Pagination state
  int _myPage = 1;
  int _othersPage = 1;
  bool _myHasMore = true;
  bool _othersHasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore) {
        if (_tabController.index == 0 && _myHasMore) {
          _loadMoreMy();
        } else if (_tabController.index == 1 && _othersHasMore) {
          _loadMoreOthers();
        }
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _myPage = 1;
      _othersPage = 1;
      _myHasMore = true;
      _othersHasMore = true;
    });
    
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    _isAdmin = prefs.getBool('is_admin') ?? false;

    if (_userId != null) {
      try {
        final myResponse = await _repository.getMyConsultations(_userId!, page: 1);
        final othersResponse = await _repository.getOthersConsultations(_userId!, page: 1);
        
        if (mounted) {
          setState(() {
            _myConsultations = myResponse['data'] ?? [];
            _othersConsultations = othersResponse['data'] ?? [];
            _myHasMore = myResponse['next_page_url'] != null;
            _othersHasMore = othersResponse['next_page_url'] != null;
          });
        }
      } catch (e) {
        debugPrint('Error loading history: $e');
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreMy() async {
    if (_isLoadingMore || !_myHasMore || _userId == null) return;
    setState(() => _isLoadingMore = true);
    
    try {
      final nextPage = _myPage + 1;
      final response = await _repository.getMyConsultations(_userId!, page: nextPage);
      final newData = response['data'] ?? [];
      
      if (mounted) {
        setState(() {
          _myConsultations.addAll(newData);
          _myPage = nextPage;
          _myHasMore = response['next_page_url'] != null;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadMoreOthers() async {
    if (_isLoadingMore || !_othersHasMore || _userId == null) return;
    setState(() => _isLoadingMore = true);
    
    try {
      final nextPage = _othersPage + 1;
      final response = await _repository.getOthersConsultations(_userId!, page: nextPage);
      final newData = response['data'] ?? [];
      
      if (mounted) {
        setState(() {
          _othersConsultations.addAll(newData);
          _othersPage = nextPage;
          _othersHasMore = response['next_page_url'] != null;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  // Helper para parsear la fecha asegurando que se interprete como UTC antes de convertir a local
  DateTime _parseDateTime(String dateStr) {
    // Si la fecha no termina en Z o no tiene info de zona horaria, asumimos que el server la envió en UTC
    if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
      return DateTime.parse('${dateStr.replaceFirst(' ', 'T')}Z').toLocal();
    }
    return DateTime.parse(dateStr).toLocal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HISTORIAL', 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 18)
        ),
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.indigo,
              border: Border(bottom: BorderSide(color: Colors.white24, width: 0.5))
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFFC5CAE9), // Indigo claro sólido
              indicatorColor: Colors.white,
              indicatorWeight: 4,
              indicatorSize: TabBarIndicatorSize.tab,
              // Usamos el mismo estilo para ambos estados para evitar que el motor de Flutter 
              // intente animar el peso de la fuente, lo que causa el efecto borroso/dañado.
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800, 
                fontSize: 13, 
                letterSpacing: 0.5,
                fontFamily: 'Roboto', // Forzamos una fuente estándar
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w800, 
                fontSize: 13, 
                letterSpacing: 0.5,
                fontFamily: 'Roboto',
              ),
              tabs: const [
                Tab(text: 'Mis Consultas'),
                Tab(text: 'A mi Vehículo'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyConsultationsList(),
                  _buildOthersConsultationsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildMyConsultationsList() {
    if (_myConsultations.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text('No has realizado consultas aún.')),
        ],
      );
    }
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _myConsultations.length + (_myHasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _myConsultations.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = _myConsultations[index];
        final vehicle = item['vehicle'];
        final date = _parseDateTime(item['created_at']);
        final formattedDate = DateFormat('dd/MM/yyyy hh:mm a').format(date);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search, color: Colors.blue, size: 24),
            ),
            title: Text(
              'Placa: ${vehicle['plate']}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Vehículo: ${vehicle['brand']} (${vehicle['color']})',
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Fecha: $formattedDate',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey[600], fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOthersConsultationsList() {
    if (_othersConsultations.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text('Nadie ha consultado tus vehículos aún.')),
        ],
      );
    }
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _othersConsultations.length + (_othersHasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _othersConsultations.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = _othersConsultations[index];
        final user = item['user'];
        final vehicle = item['vehicle'];
        final date = _parseDateTime(item['created_at']);
        final formattedDate = DateFormat('dd/MM/yyyy hh:mm a').format(date);

        // Privacy logic for the title: show location only if admin
        String locationInfo = '';
        if (_isAdmin) {
          final tower = user['tower'] ?? 'N/A';
          final apt = user['apartment'] ?? 'N/A';
          locationInfo = ' (T$tower - A$apt)';
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.visibility, color: Colors.orange, size: 24),
            ),
            title: Text(
              'Consultado por: ${user['name']}$locationInfo',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Tu vehículo: ${vehicle['plate']} - ${vehicle['brand']}',
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Fecha: $formattedDate',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey[600], fontWeight: FontWeight.w400),
                ),
              ],
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.indigo),
                onPressed: () {
                  _showUserDetail(user);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showUserDetail(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalle del Contacto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre: ${user['name']}'),
            Text('Torre: ${user['tower'] ?? 'N/A'}'),
            Text('Apto: ${_isAdmin ? (user['apartment'] ?? 'N/A') : 'Privado'}'),
            Text('Teléfono: ${user['phone'] ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
