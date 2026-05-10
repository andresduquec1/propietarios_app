import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'database_helper.dart';

class DataRepository {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Map<String, dynamic>?> findUnitByCode(String code) async {
    return await _apiService.findUnitByCode(code);
  }

  ApiService getApiService() => _apiService;

  // --- Usuarios ---

  Future<Map<String, dynamic>?> login(String email, String password) async {
    // 1. Intentar login en la API
    final apiResponse = await _apiService.loginUser(email, password);
    
    if (apiResponse != null) {
      final prefs = await SharedPreferences.getInstance();
      
      // 2. Si la API devuelve un token, guardarlo automáticamente
      if (apiResponse.containsKey('access_token')) {
        await _apiService.saveToken(apiResponse['access_token']);
      }

      // 3. Sincronizar con la BD local
      // El objeto user ahora viene dentro de la respuesta
      if (apiResponse.containsKey('user')) {
        final userData = apiResponse['user'];
        
        // Guardar user_id y permisos en SharedPreferences para consultas futuras
        if (userData.containsKey('id')) {
          await prefs.setInt('user_id', userData['id']);
          await prefs.setBool('is_admin', userData['is_admin'] ?? false);
          
          // El permiso de historial depende del usuario O de su unidad
          bool userHistory = userData['history_enabled'] ?? false;
          bool unitHistory = false;
          if (userData.containsKey('unit') && userData['unit'] != null) {
            unitHistory = userData['unit']['history_enabled'] ?? false;
          }
          await prefs.setBool('history_enabled', userHistory || unitHistory);
        }

        final localData = _filterLocalData(userData);
        
        final localUser = await _dbHelper.getUser(email);
        
        if (localUser == null) {
          await _dbHelper.registerUser(email, password, localData);
        } else {
          await _dbHelper.updateUser(email, localData);
        }
      }
      return apiResponse;
    }
    
    // 3. Fallback a local si la API falla
    final isLocalValid = await _dbHelper.loginUser(email, password);
    if (isLocalValid) {
      return await _dbHelper.getUser(email);
    }
    
    return null;
  }

  Future<bool> register(String email, String password, Map<String, dynamic> userData) async {
    // 1. Registrar en API
    // Asegurarse de que el campo 'name' existe para la API (Laravel lo requiere)
    final apiData = Map<String, dynamic>.from(userData);
    if (!apiData.containsKey('name') && apiData.containsKey('firstName')) {
      apiData['name'] = '${apiData['firstName']} ${apiData['lastName'] ?? ''}'.trim();
    }
    
    final apiResult = await _apiService.registerUser({'email': email, 'password': password, ...apiData});
    
    if (apiResult != null && apiResult.containsKey('user')) {
      final prefs = await SharedPreferences.getInstance();
      
      // 2. Guardar en local con el ID de la API
      final remoteUserData = apiResult['user'];
      
      // Guardar user_id en SharedPreferences
      if (remoteUserData.containsKey('id')) {
        await prefs.setInt('user_id', remoteUserData['id']);
      }

      final localData = _filterLocalData(remoteUserData);
      
      // Intentar actualizar si ya existe o registrar nuevo
      final existingUser = await _dbHelper.getUser(email);
      if (existingUser != null) {
        await _dbHelper.updateUser(email, localData);
      } else {
        await _dbHelper.registerUser(email, password, localData);
      }
      return true;
    }
    return false;
  }

  // Método auxiliar para filtrar campos que no pertenecen a la tabla 'users' local
  Map<String, dynamic> _filterLocalData(Map<String, dynamic> data) {
    final allowedKeys = [
      'id', 'unit_id', 'tower', 'apartment', 'firstName', 'lastName', 'phone', 'profileImagePath'
    ];
    final Map<String, dynamic> filtered = {};
    for (var key in allowedKeys) {
      if (data.containsKey(key)) {
        filtered[key] = data[key];
      }
    }
    return filtered;
  }

  Future<bool> updateProfile(int userId, String email, Map<String, dynamic> data) async {
    // 1. Actualizar en API
    final success = await _apiService.updateUser(userId, data);
    
    if (success) {
      // 2. Actualizar localmente
      await _dbHelper.updateUser(email, data);
      return true;
    }
    return false;
  }

  // --- Vehículos ---

  Future<bool> addVehicle(int userId, Map<String, dynamic> vehicleData) async {
    // 1. Agregar a API
    final apiResult = await _apiService.addVehicle({'user_id': userId, ...vehicleData});
    
    if (apiResult != null) {
      // 2. Agregar a local con el ID de la API
      await _dbHelper.addVehicleWithId(apiResult['id'], userId, vehicleData);
      return true;
    }
    return false;
  }

  Future<bool> updateVehicle(int id, Map<String, dynamic> vehicleData) async {
    final success = await _apiService.updateVehicle(id, vehicleData);
    if (success) {
      await _dbHelper.updateVehicle(id, vehicleData);
      return true;
    }
    return false;
  }

  Future<bool> deleteVehicle(int id) async {
    final success = await _apiService.deleteVehicle(id);
    if (success) {
      await _dbHelper.deleteVehicle(id);
      return true;
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getVehicles(int userId) async {
    final apiVehicles = await _apiService.getVehicles(userId);
    
    if (apiVehicles.isNotEmpty) {
      // Aquí podrías implementar una lógica de sincronización más compleja.
      // Por ahora devolvemos la API, pero en una app real actualizarías la BD local.
      return List<Map<String, dynamic>>.from(apiVehicles);
    }
    
    return await _dbHelper.getVehiclesWithContacts(userId);
  }

  // --- Contactos de Emergencia ---

  Future<bool> addEmergencyContact(int userId, String name, String phone, bool hasWhatsapp) async {
    final apiResult = await _apiService.addEmergencyContact({
      'user_id': userId,
      'name': name,
      'phone': phone,
      'has_whatsapp': hasWhatsapp ? 1 : 0
    });

    if (apiResult != null) {
      await _dbHelper.addEmergencyContactWithId(apiResult['id'], userId, name, phone, hasWhatsapp);
      return true;
    }
    return false;
  }

  Future<bool> updateEmergencyContact(int id, String name, String phone, bool hasWhatsapp) async {
    final success = await _apiService.updateEmergencyContact(id, {
      'name': name,
      'phone': phone,
      'has_whatsapp': hasWhatsapp ? 1 : 0
    });

    if (success) {
      await _dbHelper.updateEmergencyContact(id, name, phone, hasWhatsapp);
      return true;
    }
    return false;
  }

  Future<bool> deleteEmergencyContact(int id) async {
    final success = await _apiService.deleteEmergencyContact(id);
    if (success) {
      await _dbHelper.deleteEmergencyContact(id);
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> searchByPlate(String plate) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    // 1. Intentar buscar en la API
    final apiResult = await _apiService.searchByPlate(plate, userId: userId);
    if (apiResult != null) return apiResult;

    // 2. Si falla o no encuentra, buscar en local (opcional, dependiendo de si queremos ver nuestros propios vehículos)
    final localResult = await _dbHelper.getContactByPlate(plate);
    if (localResult != null) {
      return {
        'brand': localResult['brand'],
        'type': localResult['type'],
        'contact_name': localResult['name'],
        'contact_phone': localResult['phone'],
        'has_whatsapp': localResult['has_whatsapp'] == 1,
        'owner_address': 'Local (Mis datos)',
      };
    }
    
    return null;
  }

  Future<void> logout() async {
    await _apiService.clearToken();
    // Los datos locales se mantienen según requerimiento.
  }

  // --- Historial de Consultas ---

  Future<Map<String, dynamic>> getMyConsultations(int userId, {int page = 1}) async {
    // Estas consultas siempre las traemos de la API para estar actualizados
    return await _apiService.getMyConsultations(userId, page: page);
  }

  Future<Map<String, dynamic>> getOthersConsultations(int userId, {int page = 1}) async {
    // Estas consultas siempre las traemos de la API
    return await _apiService.getOthersConsultations(userId, page: page);
  }
}
