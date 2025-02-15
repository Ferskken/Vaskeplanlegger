import 'package:flutter/material.dart';
import 'dart:io';
import 'package:docx_template/docx_template.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vaskeliste',
      home: SchedulePage(),
    );
  }
}

class SchedulePage extends StatefulWidget {
  @override
  _SchedulePageState createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  // List of days (hardcoded in Norwegian)
  final List<String> weekDays = [
    'Mandag',
    'Tirsdag',
    'Onsdag',
    'Torsdag',
    'Fredag',
    'Lørdag',
    'Søndag'
  ];

  // Hardcoded list of resident rooms ("Beboer rom")
  final List<BeboerRom> beboerRooms = [
    BeboerRom('111'),
    BeboerRom('113'),
    BeboerRom('115'),
    BeboerRom('117'),
    BeboerRom('119'),
    BeboerRom('121'),
    BeboerRom('123'),
    BeboerRom('125'),
    BeboerRom('127'),
    BeboerRom('214'),
    BeboerRom('215'),
    BeboerRom('217'),
    BeboerRom('219'),
    BeboerRom('220'),
    BeboerRom('224'),
    BeboerRom('225'),
    BeboerRom('229'),
    BeboerRom('230'),
    BeboerRom('234'),
    BeboerRom('238'),
    BeboerRom('239'),
    BeboerRom('245'),
    BeboerRom('246'),
    BeboerRom('252'),
    BeboerRom('253'),
  ];

  // Global list of cleaning rooms ("Vaskes") that never change.
  final List<Vaskes> cleaningRooms = [
    Vaskes('Vaskerom 2. etg'),
    Vaskes('Toalett 2. etg'),
    Vaskes('Gang 2.etg'),
    Vaskes('Kjøkken 2.etg'),
    Vaskes('Kjøkken 2.etg'),
    Vaskes('Gang Sør 1.etg'),
    Vaskes('Gang  Nord 1.etg'),
    Vaskes('Kjøkken 1.etg'),
    Vaskes('Kjøkken 1.etg'),
    Vaskes('Vaskerom 2. etg'),
  ];

  // Map to store assignments for each day.
  // Each assignment links a cleaning room (Vaskes) with an optional resident room.
  late Map<String, List<Assignment>> assignments;

  @override
  void initState() {
    super.initState();
    // Initially, every day gets the full list of cleaning rooms.
    assignments = {};
    for (var day in weekDays) {
      assignments[day] = cleaningRooms
          .map((room) => Assignment(vaskes: room, day: day))
          .toList();
    }
  }

  Widget _buildDayPanel(String day) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Column(
        children: [
          Container(
            color: Colors.blueGrey[100],
            width: double.infinity,
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _showManageRoomsDialog(day),
                      icon: const Icon(Icons.edit),
                      label: const Text('Endre rom'),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Nullstill dag'),
                      onPressed: () {
                        setState(() {
                          assignments[day] = cleaningRooms
                              .map((room) => Assignment(vaskes: room, day: day))
                              .toList();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: assignments[day]!.length,
              itemBuilder: (context, index) {
                final assignment = assignments[day]![index];

                // Get all resident rooms that are already chosen on this day (except for the current assignment).
                final assignedRooms = assignments[day]!
                    .where((a) => a != assignment && a.beboerRom != null)
                    .map((a) => a.beboerRom)
                    .toSet();

                // Filter available resident rooms to those that are not already assigned.
                final List<BeboerRom> availableRooms = beboerRooms
                    .where((room) => !assignedRooms.contains(room))
                    .toList();

                // Ensure the current assignment’s selection is included.
                if (assignment.beboerRom != null &&
                    !availableRooms.contains(assignment.beboerRom)) {
                  availableRooms.add(assignment.beboerRom!);
                }

                return ListTile(
                  title: Text(assignment.vaskes.roomName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dropdown to choose a resident room.
                      DropdownButton<BeboerRom?>(
                        value: assignment.beboerRom,
                        hint: Text("Select"),
                        items: [
                          DropdownMenuItem<BeboerRom?>(
                            value: null,
                            child: Text("None"),
                          ),
                          ...availableRooms.map((room) {
                            return DropdownMenuItem<BeboerRom>(
                              value: room,
                              child: Text(room.roomName),
                            );
                          }).toList(),
                        ],
                        onChanged: (newValue) {
                          setState(() {
                            assignment.beboerRom = newValue;
                          });
                        },
                      ),
                      SizedBox(width: 10),

                      // Indicator: red X if unassigned, green check if assigned.
                      Icon(
                        assignment.beboerRom == null
                            ? Icons.close
                            : Icons.check,
                        color: assignment.beboerRom == null
                            ? Colors.red
                            : Colors.green,
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Dialog for managing (adding/removing) cleaning rooms on a given day.
  Future<void> _showManageRoomsDialog(String day) async {
    // Build a map for selection: cleaning room -> bool (selected or not).
    Map<Vaskes, bool> selection = {};
    // Get the current list of cleaning rooms for the day.
    List<Vaskes> currentRooms = assignments[day]!.map((a) => a.vaskes).toList();
    // Initialize the selection map from the global list.
    for (var room in cleaningRooms) {
      selection[room] = currentRooms.contains(room);
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Administrer vaskerom for $day"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: cleaningRooms.map((room) {
                    return CheckboxListTile(
                      title: Text(room.roomName),
                      value: selection[room],
                      onChanged: (bool? value) {
                        setState(() {
                          selection[room] = value ?? false;
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cancel
              },
              child: Text("Avbryt"),
            ),
            ElevatedButton(
              onPressed: () {
                // Build a new list of assignments for this day based on the selection.
                List<Assignment> newAssignments = [];
                for (var room in cleaningRooms) {
                  if (selection[room] == true) {
                    // Try to preserve an existing assignment for this room (and its resident selection).
                    Assignment? existing;
                    for (var a in assignments[day]!) {
                      if (a.vaskes.roomName == room.roomName) {
                        existing = a;
                        break;
                      }
                    }
                    if (existing != null) {
                      newAssignments.add(existing);
                    } else {
                      newAssignments.add(Assignment(vaskes: room, day: day));
                    }
                  }
                }
                setState(() {
                  assignments[day] = newAssignments;
                });
                Navigator.of(context).pop(); // Close the dialog.
              },
              child: Text("Lagre"),
            ),
          ],
        );
      },
    );
  }

  // Summary panel
  Widget _buildSummaryPanel() {
    return Card(
      margin: EdgeInsets.all(8),
      child: Column(
        children: [
          Container(
            color: Colors.blueGrey[100],
            width: double.infinity,
            padding: EdgeInsets.all(8),
            child: Text(
              "Summary",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(8),
              child: Text(
                _generateDocumentContent(),
                style: TextStyle(fontFamily: 'Courier'),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _saveDocument,
            child: Text("Lagre Dokument"),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  // Generate the text content for the document.
  String _generateDocumentContent() {
    StringBuffer sb = StringBuffer();

    sb.writeln("Vaskeliste:");
    sb.writeln("");

    // Group assignments by cleaning room name.
    Map<String, List<Assignment>> cleaningRoomGroups = {};
    for (var day in weekDays) {
      for (var assignment in assignments[day]!) {
        cleaningRoomGroups.putIfAbsent(assignment.vaskes.roomName, () => []);
        cleaningRoomGroups[assignment.vaskes.roomName]!.add(assignment);
      }
    }

    // For each cleaning room, output a separate table.
    cleaningRoomGroups.forEach((cleaningRoom, groupAssignments) {
      sb.writeln("$cleaningRoom");
      sb.writeln("Dato       | Rom   | Signer");
      sb.writeln("-----------------------------------------");

      // Loop through each day in order.
      for (var day in weekDays) {
        var dayAssignments =
            groupAssignments.where((a) => a.day == day).toList();
        if (dayAssignments.isNotEmpty) {
          for (var assignment in dayAssignments) {
            String resident =
                assignment.beboerRom?.roomName ?? "Ingen beboer valgt";
            sb.writeln("${day.padRight(9)}| ${resident.padRight(15)}| ");
          }
        }
      }
      sb.writeln("");
    });

    // Personal Assignment Table for each resident room.
    sb.writeln("\nPersnonlige lister:");
    for (var room in beboerRooms) {
      sb.writeln("\nBeboer Rom: ${room.roomName}");
      sb.writeln("Dag       |   Rom");
      sb.writeln("-----------------------------");
      for (var day in weekDays) {
        for (var assignment in assignments[day]!) {
          if (assignment.beboerRom?.roomName == room.roomName) {
            sb.writeln("${day.padRight(9)}| ${assignment.vaskes.roomName}");
          }
        }
      }
    }
    return sb.toString();
  }

  // Function to save the document to a file.
  Future<void> _saveDocument() async {
    try {
      String content = _generateDocumentContent();
      // For demonstration, saving in the current directory as 'summary.txt'
      final file = File('summary.txt');
      await file.writeAsString(content);

      // Show a success message.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Document saved as summary.txt")),
      );
    } catch (e) {
      // Error handling.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving document: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Using a GridView to display 8 panels (7 for days, 1 for summary).
    return Scaffold(
      appBar: AppBar(
        title: Text("Romvask Plan"),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        children: [
          // One panel for each day.
          ...weekDays.map((day) => _buildDayPanel(day)).toList(),
          // The 8th panel: Summary with save button.
          _buildSummaryPanel(),
        ],
      ),
    );
  }
}

// Data class for cleaning room ("Vaskes").
class Vaskes {
  final String roomName;
  Vaskes(this.roomName);
}

// Data class for resident room ("Beboer rom").
class BeboerRom {
  final String roomName;
  BeboerRom(this.roomName);
}

// Data class linking a cleaning room with an optional resident room on a specific day.
class Assignment {
  final Vaskes vaskes;
  BeboerRom? beboerRom;
  final String day;

  Assignment({required this.vaskes, required this.day, this.beboerRom});
}
