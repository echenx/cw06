import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task Manager',
      home: AuthScreen(),
    );
  }
}

class AuthScreen extends StatelessWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return const TaskListScreen();
        }
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed login. Please try again.')),
      );
    }
  }

  Future<void> _signUp() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed signup. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _signUp,
              child: const Text('Create new account'),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _timeSlotController = TextEditingController();
  final TextEditingController _taskDetailController = TextEditingController();
  final CollectionReference _tasks =
      FirebaseFirestore.instance.collection('tasks');

  Future<void> _addTask() async {
    if (_dayController.text.isNotEmpty &&
        _timeSlotController.text.isNotEmpty &&
        _taskDetailController.text.isNotEmpty) {
      await _tasks.add({
        'day': _dayController.text,
        'timeSlot': _timeSlotController.text,
        'taskDetails': [
          {'name': _taskDetailController.text, 'completed': false}
        ],
      });
      _dayController.clear();
      _timeSlotController.clear();
      _taskDetailController.clear();
    }
  }

  Future<void> _toggleSubTaskCompletion(
      String taskId, int subTaskIndex, bool currentStatus) async {
    final task = await _tasks.doc(taskId).get();
    final taskDetails = List<Map<String, dynamic>>.from(task['taskDetails']);
    taskDetails[subTaskIndex]['completed'] = !currentStatus;

    await _tasks.doc(taskId).update({'taskDetails': taskDetails});
  }

  Future<void> _deleteTimeSlotTasks(String taskId) async {
    await _tasks.doc(taskId).delete();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        actions: [
          TextButton(
            onPressed: _logout,
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _dayController,
                  decoration: const InputDecoration(
                    labelText: 'Day (EX: Monday, Tuesday, etc)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _timeSlotController,
                  decoration: const InputDecoration(
                    labelText: 'Time (EX: 9 am - 10 am)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _taskDetailController,
                  decoration: const InputDecoration(
                    labelText: 'Task',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _addTask,
                  child: const Text('Add Task'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _tasks.snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No tasks available'));
                }

                final groupedTasks = snapshot.data!.docs.groupBy((doc) {
                  final day = doc['day'];
                  if (day == null) {
                    return 'Unknown';
                  }
                  return day;
                });

                return ListView(
                  children: groupedTasks.entries.map((entry) {
                    final day = entry.key;
                    final tasksForDay = entry.value;

                    return ExpansionTile(
                      title: Text(day),
                      children: tasksForDay.map<Widget>((task) {
                        final taskId = task.id;
                        final timeSlot = task['timeSlot'];
                        final taskDetails = List<Map<String, dynamic>>.from(
                            task['taskDetails']);

                        return ExpansionTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(timeSlot),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  _deleteTimeSlotTasks(taskId);
                                },
                              ),
                            ],
                          ),
                          children: taskDetails.asMap().entries.map((entry) {
                            final subTaskIndex = entry.key;
                            final subTask = entry.value;

                            return ListTile(
                              title: Text(subTask['name']),
                              leading: Checkbox(
                                value: subTask['completed'],
                                onChanged: (value) {
                                  _toggleSubTaskCompletion(taskId, subTaskIndex,
                                      subTask['completed']);
                                },
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension GroupByExtension<E> on Iterable<E> {
  Map<K, List<E>> groupBy<K>(K Function(E) keySelector) {
    final map = <K, List<E>>{};
    for (var element in this) {
      final key = keySelector(element);
      if (map.containsKey(key)) {
        map[key]!.add(element);
      } else {
        map[key] = [element];
      }
    }
    return map;
  }
}
