import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // CONFIGURACIÓN GLOBAL: Cambia esta URL para apuntar a tu servidor
  static const String baseUrl =
    //  "http://10.0.2.2:8000/api"; // Emulador Android
      "http://192.168.1.9:8000/api"; // Servidor en red local (Cambia esta IP por la de tu PC)
  // php artisan serve --host=0.0.0.0 --port=8000 comando para servir en toda la red local
  // --- Manejo del Token ---

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // --- Usuarios (Users) ---

  Future<Map<String, dynamic>?> registerUser(
    Map<String, dynamic> userData,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/users/register'),
        headers: headers,
        body: jsonEncode(userData),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else if (response.statusCode == 403) {
        // Cuenta inactiva
        throw Exception(data['error'] ?? 'Cuenta inactiva');
      } else {
        return null;
      }
    } catch (e) {
      if (e.toString().contains('inactiva')) rethrow;
      return null;
    }
  }

  Future<List<dynamic>> getNeighbors() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/neighbors'),
        headers: headers,
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> reportUser(int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/report'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> activateUser(int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/activate'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: headers,
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateUser(int userId, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId'),
        headers: headers,
        body: jsonEncode(data),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('💥 Error updateUser: $e');
      return false;
    }
  }

  Future<String?> uploadProfileImage(int userId, String imagePath) async {
    try {
      final headers = await _getHeaders();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/users/$userId/upload-image'),
      );
      request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url']; // Devuelve la URL pública de la imagen
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- Unidades (Units) ---

  Future<Map<String, dynamic>> getUnits({int page = 1}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/units?page=$page'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'data': decoded}; // Fallback for old style
      }
      return {'data': []};
    } catch (e) {
      return {'data': []};
    }
  }

  Future<Map<String, dynamic>?> findUnitByCode(String code) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/units/code/$code'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> addUnit(Map<String, dynamic> unitData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/units'),
        headers: headers,
        body: jsonEncode(unitData),
      );
      return response.statusCode == 201 ? jsonDecode(response.body) : null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> toggleUnitActive(int unitId, bool active) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/units/$unitId/toggle-active'),
        headers: headers,
        body: jsonEncode({'active': active}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<String?> deleteUnit(int unitId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/units/$unitId'),
        headers: headers,
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return null; // Éxito
      } else {
        return data['message'] ?? 'Error al eliminar unidad';
      }
    } catch (e) {
      return 'Error de conexión';
    }
  }

  // --- Contactos de Emergencia ---

  Future<List<dynamic>> getEmergencyContacts(int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/emergency-contacts?user_id=$userId'),
        headers: headers,
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> addEmergencyContact(
    Map<String, dynamic> contactData,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/emergency-contacts'),
        headers: headers,
        body: jsonEncode(contactData),
      );
      return response.statusCode == 201 ? jsonDecode(response.body) : null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateEmergencyContact(int id, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/emergency-contacts/$id'),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteEmergencyContact(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/emergency-contacts/$id'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- Vehículos ---

  Future<List<dynamic>> getVehicles(int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/vehicles?user_id=$userId'),
        headers: headers,
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> addVehicle(
    Map<String, dynamic> vehicleData,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/vehicles'),
        headers: headers,
        body: jsonEncode(vehicleData),
      );
      return response.statusCode == 201 ? jsonDecode(response.body) : null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateVehicle(int id, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/vehicles/$id'),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteVehicle(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/vehicles/$id'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> searchByPlate(
    String plate, {
    int? userId,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/search/plate/$plate';
      if (userId != null) {
        url += '?user_id=$userId';
      }
      final response = await http.get(Uri.parse(url), headers: headers);
      return response.statusCode == 200 ? jsonDecode(response.body) : null;
    } catch (e) {
      return null;
    }
  }

  // --- Permisos y Sincronización ---

  Future<Map<String, dynamic>?> getMyProfile() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/auth/me'),
        headers: headers,
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> toggleUserHistory(int userId, bool enabled) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/toggle-history'),
        headers: headers,
        body: jsonEncode({'enabled': enabled}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleUserActive(int userId, bool active) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/toggle-active'),
        headers: headers,
        body: jsonEncode({'active': active}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleUnitHistory(int unitId, bool enabled) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/units/$unitId/toggle-history'),
        headers: headers,
        body: jsonEncode({'enabled': enabled}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getAllUsers({
    String? name,
    String? unit,
    String? plate,
    int? unitId,
    String? tower,
    String? apartment,
    int page = 1,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/admin/users?page=$page&';
      if (name != null && name.isNotEmpty)
        url += 'name=${Uri.encodeComponent(name)}&';
      if (unit != null && unit.isNotEmpty)
        url += 'unit=${Uri.encodeComponent(unit)}&';
      if (plate != null && plate.isNotEmpty)
        url += 'plate=${Uri.encodeComponent(plate)}&';
      if (unitId != null)
        url += 'unit_id=$unitId&';
      if (tower != null && tower.isNotEmpty)
        url += 'tower=${Uri.encodeComponent(tower)}&';
      if (apartment != null && apartment.isNotEmpty)
        url += 'apartment=${Uri.encodeComponent(apartment)}&';

      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'data': []};
    } catch (e) {
      return {'data': []};
    }
  }

  Future<Map<String, dynamic>> getAllUnits({String? name, int page = 1}) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/units?page=$page&';
      if (name != null && name.isNotEmpty) {
        url += 'name=${Uri.encodeComponent(name)}&';
      }
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'data': []};
    } catch (e) {
      return {'data': []};
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/admin/stats'), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>?> updateUnit(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/units/$id'),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> toggleUserAdmin(int userId, bool isAdmin) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/toggle-admin'),
        headers: headers,
        body: jsonEncode({'is_admin': isAdmin}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- Historial de Consultas ---

  Future<Map<String, dynamic>> getMyConsultations(int userId, {int page = 1}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/consultations/my?user_id=$userId&page=$page'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'data': []};
    } catch (e) {
      return {'data': []};
    }
  }

  Future<Map<String, dynamic>> getOthersConsultations(int userId, {int page = 1}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/consultations/others?user_id=$userId&page=$page'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'data': []};
    } catch (e) {
      return {'data': []};
    }
  }
}
