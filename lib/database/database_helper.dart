
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/task_model.dart';
import '../models/focus_session_model.dart';
import '../models/habit_model.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance =
  DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String databasePath = await getDatabasesPath();
    String path = join(databasePath, 'focusflow.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDatabase,
      onUpgrade: _onUpgrade,
    );
  }

  // CREATE ALL TABLES FOR A FRESH INSTALLATION

  Future<void> _createDatabase(
      Database db,
      int version,
      ) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        priority TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        dueDate TEXT,
        reminderDateTime TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE focus_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        durationSeconds INTEGER NOT NULL,
        completedAt TEXT NOT NULL
      )
    ''');

    await _createHabitTables(db);
  }

  // CREATE HABIT TABLES

  Future<void> _createHabitTables(Database db) async {
    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        reminderTime TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habitId INTEGER NOT NULL,
        completedDate TEXT NOT NULL,
        FOREIGN KEY (habitId) REFERENCES habits (id)
          ON DELETE CASCADE,
        UNIQUE (habitId, completedDate)
      )
    ''');
  }

  // DATABASE UPGRADE

  Future<void> _onUpgrade(
      Database db,
      int oldVersion,
      int newVersion,
      ) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE focus_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          durationSeconds INTEGER NOT NULL,
          completedAt TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      await _createHabitTables(db);
    }

    if (oldVersion < 4) {
      await db.execute('''
        ALTER TABLE tasks
        ADD COLUMN reminderDateTime TEXT
      ''');
    }

    if (oldVersion < 5) {
      await db.execute('''
        ALTER TABLE habits
        ADD COLUMN reminderTime TEXT
      ''');
    }
  }

  // ---------------- TASK METHODS ----------------

  Future<int> insertTask(TaskModel task) async {
    final db = await database;

    return await db.insert(
      'tasks',
      task.toMap()..remove('id'),
    );
  }

  Future<List<TaskModel>> getTasks() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      orderBy: 'createdAt DESC',
    );

    return maps.map((map) => TaskModel.fromMap(map)).toList();
  }

  Future<int> updateTask(TaskModel task) async {
    final db = await database;

    if (task.id == null) {
      throw ArgumentError('Task ID cannot be null during update');
    }

    return await db.update(
      'tasks',
      task.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;

    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------- FOCUS SESSION METHODS ----------------

  Future<int> insertFocusSession(
      FocusSessionModel session,
      ) async {
    final db = await database;

    return await db.insert(
      'focus_sessions',
      session.toMap()..remove('id'),
    );
  }

  Future<List<FocusSessionModel>> getFocusSessions() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'focus_sessions',
      orderBy: 'completedAt DESC',
    );

    return maps
        .map((map) => FocusSessionModel.fromMap(map))
        .toList();
  }

  // ---------------- HABIT METHODS ----------------

  Future<int> insertHabit(HabitModel habit) async {
    final db = await database;

    return await db.insert(
      'habits',
      habit.toMap()..remove('id'),
    );
  }

  Future<List<HabitModel>> getHabits({
    bool activeOnly = false,
  }) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'habits',
      where: activeOnly ? 'isActive = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'createdAt DESC',
    );

    return maps.map((map) => HabitModel.fromMap(map)).toList();
  }

  Future<int> updateHabit(HabitModel habit) async {
    final db = await database;

    if (habit.id == null) {
      throw ArgumentError('Habit ID cannot be null during update');
    }

    return await db.update(
      'habits',
      habit.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  Future<int> deleteHabit(int id) async {
    final db = await database;

    return await db.delete(
      'habits',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------- HABIT COMPLETION METHODS ----------------

  Future<int> markHabitCompleted(
      int habitId,
      DateTime date,
      ) async {
    final db = await database;

    final completedDate =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    return await db.insert(
      'habit_completions',
      {
        'habitId': habitId,
        'completedDate': completedDate,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> markHabitIncomplete(
      int habitId,
      DateTime date,
      ) async {
    final db = await database;

    final completedDate =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    return await db.delete(
      'habit_completions',
      where: 'habitId = ? AND completedDate = ?',
      whereArgs: [habitId, completedDate],
    );
  }

  Future<bool> isHabitCompleted(
      int habitId,
      DateTime date,
      ) async {
    final db = await database;

    final completedDate =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final result = await db.query(
      'habit_completions',
      where: 'habitId = ? AND completedDate = ?',
      whereArgs: [habitId, completedDate],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<List<String>> getHabitCompletionDates(
      int habitId,
      ) async {
    final db = await database;

    final result = await db.query(
      'habit_completions',
      columns: ['completedDate'],
      where: 'habitId = ?',
      whereArgs: [habitId],
      orderBy: 'completedDate DESC',
    );

    return result
        .map((row) => row['completedDate'] as String)
        .toList();
  }

  // =====================================================
  //                 BACKUP EXPORT METHOD
  // =====================================================

  Future<Map<String, dynamic>> exportBackupData() async {
    final db = await database;

    final tasks = await db.query('tasks');
    final focusSessions = await db.query('focus_sessions');
    final habits = await db.query('habits');
    final habitCompletions = await db.query('habit_completions');

    return {
      'appName': 'FocusFlow',
      'backupVersion': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'data': {
        'tasks': tasks,
        'focus_sessions': focusSessions,
        'habits': habits,
        'habit_completions': habitCompletions,
      },
    };
  }

  // =====================================================
  //                 BACKUP RESTORE METHOD
  // =====================================================

  Future<void> restoreBackupData(
      Map<String, dynamic> backup,
      ) async {
    // Validate backup information before changing database.

    if (backup['appName'] != 'FocusFlow') {
      throw const FormatException(
        'Invalid backup file. This is not a FocusFlow backup.',
      );
    }

    if (backup['backupVersion'] != 1) {
      throw const FormatException(
        'Unsupported backup version.',
      );
    }

    final data = backup['data'];

    if (data is! Map) {
      throw const FormatException(
        'Backup data is missing or invalid.',
      );
    }

    final tasks = _validateBackupTable(data, 'tasks');
    final focusSessions =
    _validateBackupTable(data, 'focus_sessions');
    final habits = _validateBackupTable(data, 'habits');
    final habitCompletions =
    _validateBackupTable(data, 'habit_completions');

    final db = await database;

    // Replace all existing records in one transaction.
    // If any operation fails, SQLite rolls back the transaction.

    await db.transaction((txn) async {
      // Delete child records before parent records.
      await txn.delete('habit_completions');
      await txn.delete('habits');
      await txn.delete('tasks');
      await txn.delete('focus_sessions');

      // Restore tasks.
      for (final row in tasks) {
        await txn.insert(
          'tasks',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Restore focus sessions.
      for (final row in focusSessions) {
        await txn.insert(
          'focus_sessions',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Restore habits before their completion records.
      for (final row in habits) {
        await txn.insert(
          'habits',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Restore habit completion history.
      for (final row in habitCompletions) {
        await txn.insert(
          'habit_completions',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // Validate each table's backup records.

  List<Map<String, dynamic>> _validateBackupTable(
      Map data,
      String tableName,
      ) {
    final value = data[tableName];

    if (value is! List) {
      throw FormatException(
        'Invalid or missing $tableName data.',
      );
    }

    return value.map((row) {
      if (row is! Map) {
        throw FormatException(
          'Invalid record found in $tableName.',
        );
      }

      return Map<String, dynamic>.from(row);
    }).toList();
  }
}
