import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'api_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _usersScrollController = ScrollController();
  final ScrollController _unitsScrollController = ScrollController();
  final ScrollController _searchScrollController = ScrollController();
  final ApiService _apiService = ApiService();

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ));
  }

  List<dynamic> _users = [];
  List<dynamic> _units = [];
  List<dynamic> _searchResultUsers = [];
  Map<String, dynamic> _stats = {};
  
  bool _isLoadingUsers = true;
  bool _isLoadingUnits = true;
  bool _isLoadingSearch = false;
  bool _isLoadingStats = true;
  bool _isProcessing = false;

  // Pagination state
  int _usersPage = 1;
  int _unitsPage = 1;
  int _searchPage = 1;
  bool _usersHasMore = true;
  bool _unitsHasMore = true;
  bool _searchHasMore = true;
  bool _isLoadingMore = false;
  
  // Controllers for the new search tab
  final TextEditingController _unitSearchController = TextEditingController();
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _towerSearchController = TextEditingController();
  final TextEditingController _apartmentSearchController = TextEditingController();
  int? _selectedUnitIdForSearch;
  
  String _searchCriteria = 'Nombre'; // 'Nombre', 'Unidad', 'Placa'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        if (_tabController.index == 3) {
          _fetchStats();
        }
      }
    });
    
    _usersScrollController.addListener(() => _onScroll(_usersScrollController, 0));
    _unitsScrollController.addListener(() => _onScroll(_unitsScrollController, 1));
    _searchScrollController.addListener(() => _onScroll(_searchScrollController, 2));

    _unitSearchController.addListener(_onUnitSearchChanged);
    _userSearchController.addListener(_onUserSearchChanged);
    _fetchUsers();
    _fetchUnits();
  }

  @override
  void dispose() {
    _unitSearchController.removeListener(_onUnitSearchChanged);
    _unitSearchController.dispose();
    _userSearchController.removeListener(_onUserSearchChanged);
    _userSearchController.dispose();
    _towerSearchController.dispose();
    _apartmentSearchController.dispose();
    _usersScrollController.dispose();
    _unitsScrollController.dispose();
    _searchScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoadingStats = true);
    final stats = await _apiService.getDashboardStats();
    setState(() {
      _stats = stats;
      _isLoadingStats = false;
    });
  }

  void _onScroll(ScrollController controller, int tabIndex) {
    if (controller.position.pixels >= controller.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _tabController.index == tabIndex) {
        if (tabIndex == 0 && _usersHasMore) _fetchUsers(loadMore: true);
        else if (tabIndex == 1 && _unitsHasMore) _fetchUnits(loadMore: true);
        else if (tabIndex == 2 && _searchHasMore) _performAdvancedSearch(loadMore: true);
      }
    }
  }

  void _onUnitSearchChanged() {
    _fetchUnits(name: _unitSearchController.text);
  }

  void _onUserSearchChanged() {
    String text = _userSearchController.text;
    if (_searchCriteria == 'Nombre') {
      _fetchUsers(name: text);
    } else if (_searchCriteria == 'Unidad') {
      _fetchUsers(unit: text);
    } else if (_searchCriteria == 'Placa') {
      _fetchUsers(plate: text);
    }
  }

  Future<void> _performAdvancedSearch({bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_searchHasMore) return;
      setState(() => _isLoadingMore = true);
      final nextPage = _searchPage + 1;
      final response = await _apiService.getAllUsers(
        unitId: _selectedUnitIdForSearch,
        tower: _towerSearchController.text,
        apartment: _apartmentSearchController.text,
        page: nextPage,
      );
      setState(() {
        _searchResultUsers.addAll(response['data'] ?? []);
        _searchPage = nextPage;
        _searchHasMore = response['next_page_url'] != null;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _isLoadingSearch = true;
        _searchPage = 1;
        _searchHasMore = true;
      });
      final response = await _apiService.getAllUsers(
        unitId: _selectedUnitIdForSearch,
        tower: _towerSearchController.text,
        apartment: _apartmentSearchController.text,
        page: 1,
      );
      setState(() {
        _searchResultUsers = response['data'] ?? [];
        _searchHasMore = response['next_page_url'] != null;
        _isLoadingSearch = false;
      });
    }
  }

  Future<void> _fetchUsers({String? name, String? unit, String? plate, bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_usersHasMore) return;
      setState(() => _isLoadingMore = true);
      final nextPage = _usersPage + 1;
      final response = await _apiService.getAllUsers(name: name, unit: unit, plate: plate, page: nextPage);
      setState(() {
        _users.addAll(response['data'] ?? []);
        _usersPage = nextPage;
        _usersHasMore = response['next_page_url'] != null;
        _isLoadingMore = false;
      });
    } else {
      // Si no hay búsqueda, mostramos el indicador de carga
      if ((name == null || name.isEmpty) && (unit == null || unit.isEmpty) && (plate == null || plate.isEmpty)) {
        setState(() => _isLoadingUsers = true);
      }
      
      final response = await _apiService.getAllUsers(name: name, unit: unit, plate: plate, page: 1);
      setState(() {
        _users = response['data'] ?? [];
        _usersPage = 1;
        _usersHasMore = response['next_page_url'] != null;
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _fetchUnits({String? name, bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_unitsHasMore) return;
      setState(() => _isLoadingMore = true);
      final nextPage = _unitsPage + 1;
      final response = await _apiService.getAllUnits(name: name, page: nextPage);
      setState(() {
        _units.addAll(response['data'] ?? []);
        _unitsPage = nextPage;
        _unitsHasMore = response['next_page_url'] != null;
        _isLoadingMore = false;
      });
    } else {
      // Si no hay búsqueda, mostramos el indicador de carga
      if (name == null || name.isEmpty) {
        setState(() => _isLoadingUnits = true);
      }
      
      final response = await _apiService.getAllUnits(name: name, page: 1);
      setState(() {
        _units = response['data'] ?? [];
        _unitsPage = 1;
        _unitsHasMore = response['next_page_url'] != null;
        _isLoadingUnits = false;
      });
    }
  }

  Future<void> _toggleUserHistory(int userId, bool currentStatus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final success = await _apiService.toggleUserHistory(userId, !currentStatus);
      if (success) {
        _fetchUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estado de historial actualizado para el usuario')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleUserActive(int userId, bool currentStatus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final success = await _apiService.toggleUserActive(userId, !currentStatus);
      if (success) {
        _fetchUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Usuario ${!currentStatus ? 'habilitado' : 'inhabilitado'} exitosamente')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleUnitHistory(int unitId, bool currentStatus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final success = await _apiService.toggleUnitHistory(unitId, !currentStatus);
      if (success) {
        _fetchUnits();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estado de historial actualizado para la unidad')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleUnitActive(int unitId, bool currentStatus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final success = await _apiService.toggleUnitActive(unitId, !currentStatus);
      if (success) {
        _fetchUnits();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unidad ${!currentStatus ? 'habilitada' : 'inhabilitada'} exitosamente')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteUnit(int unitId, String unitName) async {
    if (_isProcessing) return;
    // Confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Unidad'),
        content: Text('¿Estás seguro de que deseas eliminar la unidad "$unitName"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        final error = await _apiService.deleteUnit(unitId);
        if (error == null) {
          _fetchUnits();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unidad eliminada exitosamente')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _showAddUnitDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final codeController = TextEditingController(text: _generateRandomCode(6));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isDialogProcessing = false;
          return AlertDialog(
            title: const Text('Agregar Nueva Unidad'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre de la Unidad (ej: Conjunto A)'),
                    enabled: !isDialogProcessing,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    enabled: !isDialogProcessing,
                    decoration: InputDecoration(
                      labelText: 'Código Único',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: isDialogProcessing ? null : () {
                          setDialogState(() {
                            codeController.text = _generateRandomCode(6);
                          });
                        },
                        tooltip: 'Generar nuevo código',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                    enabled: !isDialogProcessing,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDialogProcessing ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: isDialogProcessing ? null : () async {
                  if (nameController.text.isNotEmpty && codeController.text.isNotEmpty) {
                    setDialogState(() => isDialogProcessing = true);
                    try {
                      final result = await _apiService.addUnit({
                        'name': nameController.text,
                        'description': descController.text,
                        'code': codeController.text,
                      });
                      if (result != null) {
                        if (mounted) Navigator.pop(context);
                        _fetchUnits();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Unidad creada exitosamente')),
                          );
                        }
                      }
                    } finally {
                      setDialogState(() => isDialogProcessing = false);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El nombre y el código son obligatorios')),
                    );
                  }
                },
                child: isDialogProcessing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditUnitDialog(dynamic unit) {
    final nameController = TextEditingController(text: unit['name']);
    final codeController = TextEditingController(text: unit['code'] ?? '');
    final descController = TextEditingController(text: unit['description'] ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isDialogProcessing = false;
          return AlertDialog(
            title: const Text('Editar Unidad'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre de la Unidad'),
                    enabled: !isDialogProcessing,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    enabled: !isDialogProcessing,
                    decoration: InputDecoration(
                      labelText: 'Código Único',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: isDialogProcessing ? null : () {
                          setDialogState(() {
                            codeController.text = _generateRandomCode(6);
                          });
                        },
                        tooltip: 'Generar nuevo código',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    enabled: !isDialogProcessing,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDialogProcessing ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: isDialogProcessing ? null : () async {
                  if (nameController.text.isNotEmpty && codeController.text.isNotEmpty) {
                    setDialogState(() => isDialogProcessing = true);
                    try {
                      final result = await _apiService.updateUnit(unit['id'], {
                        'name': nameController.text,
                        'description': descController.text,
                        'code': codeController.text,
                      });
                      if (result != null) {
                        if (mounted) Navigator.pop(context);
                        _fetchUnits();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Unidad actualizada exitosamente')),
                          );
                        }
                      }
                    } finally {
                      setDialogState(() => isDialogProcessing = false);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El nombre y el código son obligatorios')),
                    );
                  }
                },
                child: isDialogProcessing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Usuarios'),
            Tab(icon: Icon(Icons.business), text: 'Unidades'),
            Tab(icon: Icon(Icons.search_rounded), text: 'Búsqueda'),
            Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Dashboard'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersList(),
          _buildUnitsList(),
          _buildAdvancedSearch(),
          _buildDashboard(),
        ],
      ),
      floatingActionButton: _tabController.index == 1 
        ? FloatingActionButton(
            onPressed: _isProcessing ? null : _showAddUnitDialog,
            child: const Icon(Icons.add),
            tooltip: 'Agregar Unidad',
          )
        : null,
    );
  }

  Widget _buildDashboard() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stats.isEmpty) {
      return const Center(child: Text('No se pudieron cargar las estadísticas'));
    }

    final users = _stats['users'] ?? {};
    final units = _stats['units'] ?? {};
    final vehicles = _stats['vehicles'] ?? {};
    final consultations = _stats['consultations'] ?? {};
    final List<dynamic> chartData = consultations['chart_data'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(users, units, vehicles, consultations),
          const SizedBox(height: 32),
          const Text('Estado de Usuarios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildPieChart(
            active: (users['active'] ?? 0).toDouble(),
            inactive: (users['inactive'] ?? 0).toDouble(),
            activeLabel: 'Activos',
            inactiveLabel: 'Inactivos',
          ),
          const SizedBox(height: 40),
          const Text('Consultas (Últimos 7 días)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildBarChart(chartData),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map users, Map units, Map vehicles, Map consultations) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Usuarios', users['total']?.toString() ?? '0', Icons.people, Colors.blue),
        _buildStatCard('Unidades', units['total']?.toString() ?? '0', Icons.business, Colors.orange),
        _buildStatCard('Vehículos', vehicles['total']?.toString() ?? '0', Icons.directions_car, Colors.green),
        _buildStatCard('Consultas', consultations['total']?.toString() ?? '0', Icons.search, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart({required double active, required double inactive, required String activeLabel, required String inactiveLabel}) {
    final total = active + inactive;
    if (total == 0) return const Center(child: Text('Sin datos'));

    return Row(
      children: [
        SizedBox(
          height: 160,
          width: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 35,
              sections: [
                PieChartSectionData(
                  color: Colors.green,
                  value: active,
                  title: '${((active / total) * 100).toStringAsFixed(0)}%',
                  radius: 45,
                  titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                PieChartSectionData(
                  color: Colors.red,
                  value: inactive,
                  title: '${((inactive / total) * 100).toStringAsFixed(0)}%',
                  radius: 45,
                  titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 30),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegendItem(activeLabel, Colors.green, active.toInt()),
            const SizedBox(height: 12),
            _buildLegendItem(inactiveLabel, Colors.red, inactive.toInt()),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, int value) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBarChart(List<dynamic> chartData) {
    if (chartData.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('Sin actividad reciente')),
      );
    }

    // Preparar los grupos de barras
    final List<BarChartGroupData> barGroups = [];
    double maxVal = 0;

    for (int i = 0; i < chartData.length; i++) {
      double val = (chartData[i]['count'] ?? 0).toDouble();
      if (val > maxVal) maxVal = val;
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: Colors.indigo,
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    // Calcular intervalo dinámico para evitar amontonamiento
    double maxY = maxVal < 5 ? 5 : maxVal;
    double interval = 1;
    if (maxY > 10) interval = 2;
    if (maxY > 20) interval = 5;
    if (maxY > 50) interval = 10;
    if (maxY > 100) interval = 20;
    if (maxY > 200) interval = 50;
    if (maxY > 500) interval = 100;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.grey[200]!)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cantidad de Consultas', style: TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: (maxY + (interval / 2)).ceilToDouble(),
                gridData: FlGridData(
                  show: true, 
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.indigo.withOpacity(0.9),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String dateStr = chartData[group.x.toInt()]['date'] ?? '';
                      DateTime dt = DateTime.tryParse(dateStr) ?? DateTime.now();
                      String formattedDate = DateFormat('dd MMM').format(dt);
                      return BarTooltipItem(
                        '$formattedDate\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toInt()} consultas',
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text('Fecha (Día/Mes)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx >= 0 && idx < chartData.length) {
                          String dateStr = chartData[idx]['date'] ?? '';
                          DateTime dt = DateTime.tryParse(dateStr) ?? DateTime.now();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(DateFormat('dd/MM').format(dt), style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 35,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: interval, 
                      getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSearch() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                value: _selectedUnitIdForSearch,
                decoration: const InputDecoration(labelText: 'Seleccionar Unidad'),
                items: [
                  const DropdownMenuItem<int>(value: null, child: Text('Todas las unidades')),
                  ..._units.map((u) => DropdownMenuItem<int>(value: u['id'], child: Text(u['name']))),
                ],
                onChanged: (val) => setState(() => _selectedUnitIdForSearch = val),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _towerSearchController,
                      decoration: const InputDecoration(labelText: 'Torre', hintText: 'Ej: 1'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _apartmentSearchController,
                      decoration: const InputDecoration(labelText: 'Apartamento', hintText: 'Ej: 101'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingSearch ? null : _performAdvancedSearch,
                  icon: _isLoadingSearch 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search),
                  label: const Text('BUSCAR RESIDENTES'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoadingSearch
            ? const Center(child: CircularProgressIndicator())
            : _searchResultUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_rounded, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No se encontraron resultados', style: TextStyle(color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _searchScrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: _searchResultUsers.length + (_searchHasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _searchResultUsers.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final user = _searchResultUsers[index];
                    final bool isActive = user['active'] == true || user['active'] == 1;
                    final List<dynamic> vehicles = user['vehicles'] ?? [];
                    final List<dynamic> contacts = user['emergency_contacts'] ?? user['emergencyContacts'] ?? [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive ? Colors.green[50] : Colors.red[50],
                          child: Icon(Icons.person, color: isActive ? Colors.green : Colors.red),
                        ),
                        title: Text('${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'),
                        subtitle: Text('T: ${user['tower'] ?? '-'} | A: ${user['apartment'] ?? '-'} | ${user['unit']?['name'] ?? ''}'),
                        children: [
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Email: ${user['email'] ?? 'N/A'}', style: const TextStyle(fontSize: 13)),
                                Text('Teléfono: ${user['phone'] ?? 'N/A'}', style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 12),
                                const Text('Vehículos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                if (vehicles.isEmpty) 
                                  const Text('Sin vehículos', style: TextStyle(fontSize: 12, color: Colors.grey))
                                else
                                  ...vehicles.map((v) => Text('• ${v['brand']} - ${v['plate']}', style: const TextStyle(fontSize: 12))),
                                const SizedBox(height: 12),
                                const Text('Contactos de Emergencia:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                if (contacts.isEmpty) 
                                  const Text('Sin contactos', style: TextStyle(fontSize: 12, color: Colors.grey))
                                else
                                  ...contacts.map((c) => Text('• ${c['name']}: ${c['phone']}', style: const TextStyle(fontSize: 12))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUsersList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _searchCriteria,
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  items: ['Nombre', 'Unidad', 'Placa']
                      .map((label) => DropdownMenuItem(
                            value: label,
                            child: Text(label, style: const TextStyle(fontSize: 14)),
                          ))
                      .toList(),
                  onChanged: _isProcessing ? null : (value) {
                    setState(() {
                      _searchCriteria = value!;
                      _userSearchController.clear();
                      _fetchUsers();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _userSearchController,
                  enabled: !_isProcessing,
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _userSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _userSearchController.clear();
                              _fetchUsers();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingUsers && _users.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(child: Text('No hay usuarios registrados'))
                  : ListView.builder(
                      controller: _usersScrollController,
                      itemCount: _users.length + (_usersHasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _users.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final user = _users[index];
                        final bool isHistoryEnabled = user['history_enabled'] == true || user['history_enabled'] == 1;
                        final bool isActive = user['active'] == true || user['active'] == 1;
                        final List<dynamic> vehicles = user['vehicles'] ?? [];
                        // En Laravel con camelCase por defecto para relaciones
                        final List<dynamic> contacts = user['emergency_contacts'] ?? user['emergencyContacts'] ?? [];

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: ExpansionTile(
                            leading: Stack(
                              children: [
                                const CircleAvatar(child: Icon(Icons.person)),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.green : Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text('${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim().isEmpty ? (user['name'] ?? 'Usuario') : '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'),
                            subtitle: Text('Unidad: ${user['unit']?['name'] ?? 'N/A'} - Apt: ${user['apartment'] ?? 'N/A'}'),
                            children: [
                              const Divider(),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 20,
                                      runSpacing: 10,
                                      children: [
                                        // Switch de Cuenta Activa
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Cuenta: ${isActive ? 'Activa' : 'Inactiva'}', 
                                              style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.green : Colors.red, fontSize: 13)),
                                            const SizedBox(width: 4),
                                            Transform.scale(
                                              scale: 0.8,
                                              child: Switch(
                                                value: isActive,
                                                activeColor: Colors.green,
                                                onChanged: _isProcessing ? null : (value) => _toggleUserActive(user['id'], isActive),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Switch de Historial
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('Historial: ', 
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            Transform.scale(
                                              scale: 0.8,
                                              child: Switch(
                                                value: isHistoryEnabled,
                                                onChanged: _isProcessing ? null : (value) => _toggleUserHistory(user['id'], isHistoryEnabled),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Email: ${user['email'] ?? 'N/A'}', style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                                    const SizedBox(height: 12),
                                    const Text('Vehículos:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    if (vehicles.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8.0, top: 4.0),
                                        child: Text('No tiene vehículos registrados', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                      )
                                    else
                                      ...vehicles.map((v) {
                                        final String brand = v['brand'] ?? '';
                                        final String model = v['model'] ?? '';
                                        final String plate = v['plate'] ?? 'N/A';
                                        final String vehicleInfo = '${brand} ${model}'.trim();
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                                          child: Text('• ${vehicleInfo.isEmpty ? 'Vehículo' : vehicleInfo} - Placa: $plate', style: const TextStyle(fontSize: 12)),
                                        );
                                      }),
                                    
                                    const SizedBox(height: 12),
                                    const Text('Contactos de Emergencia:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    if (contacts.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8.0, top: 4.0),
                                        child: Text('No tiene contactos registrados', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                      )
                                    else
                                      ...contacts.map((c) {
                                        final String name = c['name'] ?? 'N/A';
                                        final String relationship = c['relationship'] != null ? ' (${c['relationship']})' : '';
                                        final String phone = c['phone'] ?? 'N/A';
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                                          child: Text('• $name$relationship: $phone', style: const TextStyle(fontSize: 12)),
                                        );
                                      }),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildUnitsList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _unitSearchController,
            enabled: !_isProcessing,
            decoration: InputDecoration(
              hintText: 'Buscar unidad...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _unitSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _unitSearchController.clear();
                        _fetchUnits();
                      },
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: _isLoadingUnits && _units.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _units.isEmpty
                  ? const Center(child: Text('No hay unidades registradas'))
                  : ListView.builder(
                      controller: _unitsScrollController,
                      itemCount: _units.length + (_unitsHasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _units.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final unit = _units[index];
                        final bool isHistoryEnabled = unit['history_enabled'] == true || unit['history_enabled'] == 1;
                        final bool isActive = unit['active'] == true || unit['active'] == 1;
                        final int userCount = unit['users_count'] ?? 0;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: Icon(Icons.business, color: isActive ? Colors.indigo : Colors.grey),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(unit['name'], style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isActive ? Colors.black : Colors.grey,
                                        )),
                                      ),
                                      if (unit['code'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber[100],
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.amber[300]!),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                unit['code'],
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              InkWell(
                                                onTap: _isProcessing ? null : () {
                                                  Clipboard.setData(ClipboardData(text: unit['code']));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Código ${unit['code']} copiado')),
                                                  );
                                                },
                                                child: const Icon(Icons.copy, size: 14, color: Colors.brown),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text('${unit['description'] ?? 'Sin descripción'}\nPropietarios: $userCount'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: _isProcessing ? null : () => _showEditUnitDialog(unit),
                                        tooltip: 'Editar',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: (userCount == 0 && !_isProcessing)
                                          ? () => _deleteUnit(unit['id'], unit['name'])
                                          : null, // Deshabilitado si tiene propietarios o está procesando
                                        tooltip: userCount == 0 ? 'Eliminar' : 'No se puede eliminar (tiene propietarios)',
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Text('Estado: ', style: TextStyle(fontSize: 12)),
                                          Text(isActive ? 'Activa' : 'Inactiva', 
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.green : Colors.red)),
                                          Switch(
                                            value: isActive,
                                            activeColor: Colors.green,
                                            onChanged: _isProcessing ? null : (value) => _toggleUnitActive(unit['id'], isActive),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Text('Historial: ', style: TextStyle(fontSize: 12)),
                                          Switch(
                                            value: isHistoryEnabled,
                                            onChanged: _isProcessing ? null : (value) => _toggleUnitHistory(unit['id'], isHistoryEnabled),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
