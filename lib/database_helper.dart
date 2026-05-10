import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'user_database.db');
    return await openDatabase(
      path,
      version: 9,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT UNIQUE, password TEXT, unit_id INTEGER, tower TEXT, apartment TEXT, firstName TEXT, lastName TEXT, phone TEXT, profileImagePath TEXT, FOREIGN KEY (unit_id) REFERENCES units (id))',
        );
        await db.execute(
          'CREATE TABLE units(id INTEGER PRIMARY KEY, name TEXT, description TEXT)',
        );
        await db.execute(
          'CREATE TABLE emergency_contacts(id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, name TEXT, phone TEXT, has_whatsapp INTEGER DEFAULT 0, FOREIGN KEY (user_id) REFERENCES users (id))',
        );
        await db.execute(
          'CREATE TABLE vehicles(id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, type TEXT, brand TEXT, color TEXT, plate TEXT, emergency_contact_id INTEGER, FOREIGN KEY (user_id) REFERENCES users (id), FOREIGN KEY (emergency_contact_id) REFERENCES emergency_contacts (id))',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // ... previous upgrades ...
        if (oldVersion < 8) {
          await db.execute(
            'CREATE TABLE units(id INTEGER PRIMARY KEY, name TEXT, description TEXT)',
          );
          // We don't need user_units anymore as per the new requirement
        }
        if (oldVersion < 9) {
          // Check if column exists before adding (safety)
          var columns = await db.rawQuery('PRAGMA table_info(users)');
          bool hasUnitId = columns.any((column) => column['name'] == 'unit_id');
          if (!hasUnitId) {
            await db.execute('ALTER TABLE users ADD COLUMN unit_id INTEGER');
          }
          await db.execute('DROP TABLE IF EXISTS user_units');
        }
      },
    );
  }

  // --- Unit Methods ---
  Future<void> saveUnits(List<dynamic> units) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var unit in units) {
        await txn.insert('units', {
          'id': unit['id'],
          'name': unit['name'],
          'description': unit['description']
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getUnits() async {
    final db = await database;
    return await db.query('units');
  }

  Future<Map<String, dynamic>?> getUnit(int id) async {
    final db = await database;
    final maps = await db.query('units', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? maps.first : null;
  }

  // --- User Methods ---
  Future<int> registerUser(String email, String password, Map<String, dynamic> extraData) async {
    final db = await database;
    try {
      return await db.insert('users', {'email': email, 'password': password, ...extraData}, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      return -1;
    }
  }

  Future<int> registerUserWithId(int id, String email, String password, Map<String, dynamic> extraData) async {
    final db = await database;
    try {
      return await db.insert('users', {'id': id, 'email': email, 'password': password, ...extraData}, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      return -1;
    }
  }

  Future<Map<String, dynamic>?> getUser(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (maps.isNotEmpty) {
      final user = Map<String, dynamic>.from(maps.first);
      if (user['unit_id'] != null) {
        user['unit'] = await getUnit(user['unit_id']);
      }
      return user;
    }
    return null;
  }

  Future<int> updateUser(String email, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('users', data, where: 'email = ?', whereArgs: [email]);
  }

  Future<bool> loginUser(String email, String password) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users', where: 'email = ? AND password = ?', whereArgs: [email, password]);
    return maps.isNotEmpty;
  }

  // --- Emergency Contact Methods ---
  Future<int> addEmergencyContact(int userId, String name, String phone, bool hasWhatsapp) async {
    final db = await database;
    return await db.insert('emergency_contacts', {
      'user_id': userId, 
      'name': name, 
      'phone': phone,
      'has_whatsapp': hasWhatsapp ? 1 : 0
    });
  }

  Future<int> addEmergencyContactWithId(int id, int userId, String name, String phone, bool hasWhatsapp) async {
    final db = await database;
    return await db.insert('emergency_contacts', {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'has_whatsapp': hasWhatsapp ? 1 : 0
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getEmergencyContacts(int userId) async {
    final db = await database;
    return await db.query('emergency_contacts', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<int> updateEmergencyContact(int id, String name, String phone, bool hasWhatsapp) async {
    final db = await database;
    return await db.update('emergency_contacts', {
      'name': name,
      'phone': phone,
      'has_whatsapp': hasWhatsapp ? 1 : 0
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteEmergencyContact(int id) async {
    final db = await database;
    return await db.delete('emergency_contacts', where: 'id = ?', whereArgs: [id]);
  }

  // --- Vehicle Methods ---
  Future<int> addVehicle(int userId, Map<String, dynamic> vehicle) async {
    final db = await database;
    return await db.insert('vehicles', {...vehicle, 'user_id': userId});
  }

  Future<int> addVehicleWithId(int id, int userId, Map<String, dynamic> vehicle) async {
    final db = await database;
    return await db.insert('vehicles', {
      'id': id,
      ...vehicle, 
      'user_id': userId
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getVehiclesWithContacts(int userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT v.*, ec.name as contact_name, ec.phone as contact_phone, ec.has_whatsapp as contact_has_whatsapp
      FROM vehicles v 
      LEFT JOIN emergency_contacts ec ON v.emergency_contact_id = ec.id 
      WHERE v.user_id = ?
    ''', [userId]);
  }

  Future<int> deleteVehicle(int id) async {
    final db = await database;
    return await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateVehicle(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('vehicles', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('vehicles');
    await db.delete('emergency_contacts');
    await db.delete('users');
  }

  Future<Map<String, dynamic>?> getContactByPlate(String plate) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT ec.name, ec.phone, ec.has_whatsapp, v.brand, v.color, v.type
      FROM vehicles v
      JOIN emergency_contacts ec ON v.emergency_contact_id = ec.id
      WHERE TRIM(UPPER(v.plate)) = ?
    ''', [plate.toUpperCase().trim()]);
    
    return results.isNotEmpty ? results.first : null;
  }
}
