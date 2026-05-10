import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'api_service.dart';
import 'data_repository.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _plateController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ApiService _apiService = ApiService();
  final DataRepository _repository = DataRepository();
  Map<String, dynamic>? _result;
  bool _searched = false;
  bool _isLoading = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('is_admin') ?? false;
    });
  }

  void _search() async {
    if (_plateController.text.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _searched = false;
    });

    try {
      final result = await _repository.searchByPlate(_plateController.text.toUpperCase().trim());
      
      setState(() {
        _result = result;
        _isLoading = false;
        _searched = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error al conectar con el servidor');
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showError('No se pudo iniciar la llamada');
    }
  }

  Future<void> _sendWhatsApp(String phoneNumber) async {
    // Clean the phone number (remove non-digits)
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    // Ensure it has a country code if needed, but we'll assume the user enters it correctly
    // or we can prefix with a default one if typical for the region.
    final Uri whatsappUri = Uri.parse("https://wa.me/$cleanNumber");
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      _showError('No se pudo abrir WhatsApp');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Consultar Placa'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Ingrese la placa del vehículo para encontrar el contacto de emergencia.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _plateController,
              decoration: const InputDecoration(
                labelText: 'Número de Placa',
                hintText: 'Ej: ABC123',
                prefixIcon: Icon(Icons.search, color: Colors.indigo),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _search,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('BUSCAR CONTACTO', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
            if (_searched) _buildResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    if (_result == null) {
      return Card(
        color: Colors.red[50],
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 10),
              Expanded(child: Text('No se encontró ningún vehículo con esa placa.', style: TextStyle(color: Colors.red))),
            ],
          ),
        ),
      );
    }

    final bool hasWhatsapp = _result!['has_whatsapp'] == true || _result!['has_whatsapp'] == 1;
    final String contactName = _result!['contact_name'] ?? 'No disponible';
    final String contactPhone = _result!['contact_phone'] ?? '';
    
    // Privacy check for apartment/address
    String ownerAddress = _result!['owner_address'] ?? 'Desconocido';
    if (!_isAdmin) {
      // Si no es admin, ocultamos el número de apartamento/ubicación exacta
      ownerAddress = 'Privado';
    }

    final String ownerInfo = _result!['owner_name'] != null 
        ? '${_result!['owner_name']} ($ownerAddress)'
        : ownerAddress;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_result!['type'] == 'Carro' ? Icons.directions_car : Icons.motorcycle, color: Colors.indigo),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${_result!['brand'] ?? ''} - ${_plateController.text.toUpperCase()}', 
                       style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text('Propietario: $ownerInfo', style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
            const Divider(height: 30),
            const Text('CONTACTO DE EMERGENCIA:', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(contactName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(contactPhone, style: const TextStyle(fontSize: 18, color: Colors.indigo)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: contactPhone.isNotEmpty ? () => _makeCall(contactPhone) : null,
                    icon: const Icon(Icons.call),
                    label: const Text('Llamar'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
                if (hasWhatsapp) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: contactPhone.isNotEmpty ? () => _sendWhatsApp(contactPhone) : null,
                      icon: const Icon(Icons.message),
                      label: const Text('WhatsApp'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
