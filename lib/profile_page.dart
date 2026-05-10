import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'data_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'search_page.dart';

class ProfilePage extends StatefulWidget {
  final String userEmail;
  const ProfilePage({super.key, required this.userEmail});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final DataRepository _repository = DataRepository();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _towerController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _unitCodeController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  int? _userId;
  String? _profileImagePath;
  String? _currentUnitName;
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _emergencyContacts = [];
  
  List<Map<String, dynamic>> _availableUnits = [];
  int? _selectedUnitId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final userData = await _dbHelper.getUser(widget.userEmail);
    if (userData != null) {
      _userId = userData['id'];
      _firstNameController.text = userData['firstName'] ?? '';
      _lastNameController.text = userData['lastName'] ?? '';
      _phoneController.text = userData['phone'] ?? '';
      _towerController.text = userData['tower'] ?? '';
      _apartmentController.text = userData['apartment'] ?? '';
      _passwordController.text = userData['password'] ?? '';
      _profileImagePath = userData['profileImagePath'];
      
      // Load user unit
      _selectedUnitId = userData['unit_id'];

      // Load all available units
      _availableUnits = await _dbHelper.getUnits();
      
      // Get current unit name
      if (_selectedUnitId != null) {
        final unit = _availableUnits.firstWhere((u) => u['id'] == _selectedUnitId, orElse: () => {});
        _currentUnitName = unit.isNotEmpty ? unit['name'] : 'Desconocida';
      }

      await _loadEmergencyContacts();
      await _loadVehicles();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeUnit() async {
    String code = _unitCodeController.text.trim();
    if (code.isEmpty) {
      _showMsg('Ingresa un código de unidad');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final unit = await _repository.getApiService().findUnitByCode(code);
      if (unit == null) {
        _showMsg('Código de unidad no válido');
        return;
      }

      setState(() {
        _selectedUnitId = unit['id'];
        _currentUnitName = unit['name'];
        _unitCodeController.clear();
      });
      _showMsg('Unidad cambiada a: ${_currentUnitName}. No olvides guardar los cambios.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickImage() async {
    if (_isProcessing) return;
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    
    if (image != null) {
      setState(() {
        _isProcessing = true;
        _profileImagePath = image.path;
      });
      try {
        // Save immediately to DB
        await _dbHelper.updateUser(widget.userEmail, {'profileImagePath': _profileImagePath});
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _loadEmergencyContacts() async {
    if (_userId != null) {
      // 1. Intentar cargar desde API
      try {
        final apiContacts = await _repository.getApiService().getEmergencyContacts(_userId!);
        if (apiContacts.isNotEmpty) {
          // Sincronizar con local
          for (var contact in apiContacts) {
            await _dbHelper.addEmergencyContactWithId(
              contact['id'], 
              _userId!, 
              contact['name'], 
              contact['phone'], 
              contact['has_whatsapp'] == 1 || contact['has_whatsapp'] == true
            );
          }
        }
      } catch (e) {
        print("Error loading contacts: $e");
      }

      // 2. Cargar desde local (que ahora está sincronizado)
      final contacts = await _dbHelper.getEmergencyContacts(_userId!);
      if (mounted) setState(() => _emergencyContacts = contacts);
    }
  }

  Future<void> _loadVehicles() async {
    if (_userId != null) {
      // 1. Intentar cargar desde API
      try {
        final apiVehicles = await _repository.getApiService().getVehicles(_userId!);
        if (apiVehicles.isNotEmpty) {
          // Sincronizar con local
          for (var v in apiVehicles) {
            await _dbHelper.addVehicleWithId(v['id'], _userId!, {
              'type': v['type'],
              'brand': v['brand'],
              'color': v['color'],
              'plate': v['plate'],
              'emergency_contact_id': v['emergency_contact_id'],
            });
          }
        }
      } catch (e) {
        print("Error loading vehicles: $e");
      }

      // 2. Cargar desde local
      final vehicles = await _dbHelper.getVehiclesWithContacts(_userId!);
      if (mounted) setState(() => _vehicles = vehicles);
    }
  }

  void _saveProfile() async {
    if (_isProcessing) return;
    Map<String, dynamic> data = {
      'firstName': _firstNameController.text,
      'lastName': _lastNameController.text,
      'phone': _phoneController.text,
      'tower': _towerController.text,
      'apartment': _apartmentController.text,
      'password': _passwordController.text,
      'profileImagePath': _profileImagePath,
      'unit_id': _selectedUnitId,
    };
    
    if (_userId != null) {
      setState(() => _isProcessing = true);
      try {
        bool success = await _repository.updateProfile(_userId!, widget.userEmail, data);
        if (success) {
          _showMsg('Perfil actualizado en el servidor');
        } else {
          _showMsg('Perfil actualizado localmente (error de conexión)');
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _addContactDialog() {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    bool hasWhatsapp = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isDialogProcessing = false;
          return AlertDialog(
            title: const Text('Nuevo Contacto de Emergencia'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nombre'), enabled: !isDialogProcessing),
                TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Teléfono'), keyboardType: TextInputType.number, enabled: !isDialogProcessing),
                CheckboxListTile(
                  title: const Text('Tiene WhatsApp'),
                  value: hasWhatsapp,
                  onChanged: isDialogProcessing ? null : (val) => setDialogState(() => hasWhatsapp = val!),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: isDialogProcessing ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: isDialogProcessing ? null : () async {
                  if (nameC.text.isNotEmpty && phoneC.text.isNotEmpty && _userId != null) {
                    setDialogState(() => isDialogProcessing = true);
                    try {
                      bool success = await _repository.addEmergencyContact(_userId!, nameC.text, phoneC.text, hasWhatsapp);
                      if (success) {
                        _showMsg('Contacto guardado en el servidor');
                      }
                      if (mounted) Navigator.pop(context);
                      _loadEmergencyContacts();
                    } finally {
                      setDialogState(() => isDialogProcessing = false);
                    }
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

  void _vehicleFormDialog({Map<String, dynamic>? vehicle}) {
    if (_emergencyContacts.isEmpty) {
      _showMsg('Primero debes agregar al menos un contacto de emergencia');
      return;
    }

    final isEditing = vehicle != null;
    String type = isEditing ? vehicle['type'] : 'Carro';
    
    // Check if the saved contact still exists in the current list
    int? savedContactId = isEditing ? vehicle['emergency_contact_id'] : null;
    bool contactExists = _emergencyContacts.any((c) => c['id'] == savedContactId);
    
    int? selectedContactId = contactExists 
        ? savedContactId 
        : _emergencyContacts.first['id'];
    
    final brandC = TextEditingController(text: isEditing ? vehicle['brand'] : '');
    final colorC = TextEditingController(text: isEditing ? vehicle['color'] : '');
    final plateC = TextEditingController(text: isEditing ? vehicle['plate'] : '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isDialogProcessing = false;
          return AlertDialog(
            title: Text(isEditing ? 'Editar Vehículo' : 'Agregar Vehículo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    items: ['Carro', 'Moto'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: isDialogProcessing ? null : (val) => setDialogState(() => type = val!),
                    decoration: const InputDecoration(labelText: 'Tipo'),
                  ),
                  TextField(controller: brandC, decoration: const InputDecoration(labelText: 'Marca'), enabled: !isDialogProcessing),
                  TextField(controller: colorC, decoration: const InputDecoration(labelText: 'Color'), enabled: !isDialogProcessing),
                  TextField(controller: plateC, decoration: const InputDecoration(labelText: 'Placa'), enabled: !isDialogProcessing),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: selectedContactId,
                    items: _emergencyContacts.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name']))).toList(),
                    onChanged: isDialogProcessing ? null : (val) => setDialogState(() => selectedContactId = val),
                    decoration: const InputDecoration(labelText: 'Contacto de Emergencia'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: isDialogProcessing ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: isDialogProcessing ? null : () async {
                  if (brandC.text.isNotEmpty && plateC.text.isNotEmpty && _userId != null) {
                    final data = {
                      'type': type,
                      'brand': brandC.text,
                      'color': colorC.text,
                      'plate': plateC.text.toUpperCase().trim(),
                      'emergency_contact_id': selectedContactId,
                    };
                    
                    setDialogState(() => isDialogProcessing = true);
                    try {
                      bool success;
                      if (isEditing) {
                        success = await _repository.updateVehicle(vehicle['id'], data);
                        if (success) _showMsg('Vehículo actualizado en el servidor');
                      } else {
                        success = await _repository.addVehicle(_userId!, data);
                        if (success) _showMsg('Vehículo guardado en el servidor');
                      }
                      
                      if (mounted) Navigator.pop(context);
                      _loadVehicles();
                    } finally {
                      setDialogState(() => isDialogProcessing = false);
                    }
                  }
                },
                child: isDialogProcessing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : Text(isEditing ? 'Actualizar' : 'Agregar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mi Perfil'), 
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.indigo, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _profileImagePath != null 
                        ? FileImage(File(_profileImagePath!)) 
                        : null,
                      child: _profileImagePath == null 
                        ? const Icon(Icons.person, size: 80, color: Colors.white) 
                        : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.indigo,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionHeader(Icons.person, 'Datos Personales'),
            _buildCard([
              _buildTextField(_firstNameController, 'Nombres', Icons.person),
              const SizedBox(height: 12),
              _buildTextField(_lastNameController, 'Apellidos', Icons.person_outline),
              const SizedBox(height: 12),
              _buildTextField(_phoneController, 'Celular', Icons.phone, type: TextInputType.number),
              const SizedBox(height: 12),
              _buildPasswordField(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unidad actual: ${_currentUnitName ?? 'Cargando...'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _unitCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Nuevo Código de Unidad',
                              hintText: 'Ej: UNIT123',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isProcessing ? null : _changeUnit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: _isProcessing 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Cambiar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildTextField(_towerController, 'Torre', Icons.apartment)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField(_apartmentController, 'Apartamento', Icons.door_front_door)),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity, 
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _saveProfile, 
                  child: _isProcessing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Actualizar Datos')
                )
              ),
            ]),

            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(Icons.emergency, 'Contactos de Emergencia'),
                IconButton(onPressed: _isProcessing ? null : _addContactDialog, icon: const Icon(Icons.add_circle, color: Colors.red)),
              ],
            ),
            _buildEmergencyContactsList(),

            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(Icons.directions_car, 'Mis Vehículos'),
                IconButton(onPressed: _isProcessing ? null : () => _vehicleFormDialog(), icon: const Icon(Icons.add_circle, color: Colors.blue)),
              ],
            ),
            _buildVehicleList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo, size: 24),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(padding: const EdgeInsets.all(16.0), child: Column(children: children)),
    );
  }

  Widget _buildEmergencyContactsList() {
    if (_emergencyContacts.isEmpty) return const Text('No hay contactos registrados');
    return Column(
      children: _emergencyContacts.map((c) => Card(
        child: ListTile(
          leading: const Icon(Icons.contact_phone, color: Colors.red),
          title: Row(
            children: [
              Expanded(child: Text(c['name'], overflow: TextOverflow.ellipsis)),
              if (c['has_whatsapp'] == 1) ...[
                const SizedBox(width: 8),
                const Icon(Icons.message, color: Colors.green, size: 18),
              ],
            ],
          ),
          subtitle: Text(c['phone']),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.grey), 
            onPressed: _isProcessing ? null : () async {
              setState(() => _isProcessing = true);
              try {
                bool success = await _repository.deleteEmergencyContact(c['id']);
                if (success) _showMsg('Contacto eliminado del servidor');
                _loadEmergencyContacts();
                _loadVehicles();
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            }
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildVehicleList() {
    if (_vehicles.isEmpty) return const Text('No hay vehículos registrados');
    return Column(
      children: _vehicles.map((v) => Card(
        child: ListTile(
          leading: Icon(v['type'] == 'Carro' ? Icons.directions_car : Icons.motorcycle, color: Colors.indigo),
          title: Text('${v['brand']} - ${v['plate']}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Color: ${v['color']}'),
              if (v['contact_name'] != null)
                Row(
                  children: [
                    const Text('Emergencia: ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                    Expanded(
                      child: Text(
                        '${v['contact_name']} ', 
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (v['contact_has_whatsapp'] == 1)
                      const Icon(Icons.message, color: Colors.green, size: 16),
                  ],
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: _isProcessing ? null : () => _vehicleFormDialog(vehicle: v)),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey), 
                onPressed: _isProcessing ? null : () async {
                  setState(() => _isProcessing = true);
                  try {
                    bool success = await _repository.deleteVehicle(v['id']);
                    if (success) _showMsg('Vehículo eliminado del servidor');
                    _loadVehicles();
                  } finally {
                    if (mounted) setState(() => _isProcessing = false);
                  }
                }
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.indigo, size: 20)),
      keyboardType: type,
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: 'Contraseña',
        prefixIcon: const Icon(Icons.lock, color: Colors.indigo, size: 20),
        suffixIcon: IconButton(
          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.indigo[200]),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
      ),
    );
  }
}
