import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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
      home: TaskListScreen(),
    );
  }
}

class Task {
  final String id;
  final String name;
  bool completed;

  Task({required this.id, required this.name, this.completed = false});

  factory Task.fromDocument(DocumentSnapshot doc) {
    return Task(
      id: doc.id,
      name: doc['name'],
      completed: doc['completed'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'completed': completed,
    };
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskController = TextEditingController();
  final CollectionReference _tasks =
      FirebaseFirestore.instance.collection('tasks');

  final Map<String, List<String>> dailyTasks = {
    "Monday": ["9 am - 10 am: HW1, Essay2", "12 pm - 2 pm: Project1, Study"],
    "Tuesday": ["10 am - 11 am: Assignment1, Reading"],
  };

  Future<void> _addTask() async {
    if (_taskController.text.isNotEmpty) {
      await _tasks.add({
        'name': _taskController.text,
        'completed': false,
      });
      _taskController.clear();
    }
  }

  Future<void> _toggleTaskCompletion(String taskId, bool currentStatus) async {
    await _tasks.doc(taskId).update({
      'completed': !currentStatus,
    });
  }

  Future<void> _deleteTask(String taskId) async {
    await _tasks.doc(taskId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Task',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add),
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

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final task = snapshot.data!.docs[index];
                    final taskId = task.id;
                    final taskName = task['name'];
                    final taskCompleted = task['completed'];

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text(taskName),
                        leading: Checkbox(
                          value: taskCompleted,
                          onChanged: (value) {
                            _toggleTaskCompletion(taskId, taskCompleted);
                          },
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            _deleteTask(taskId);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: dailyTasks.keys.map((day) {
                return ExpansionTile(
                  title: Text(day),
                  children: dailyTasks[day]!.map((taskDetail) {
                    return ListTile(
                      title: Text(taskDetail),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
