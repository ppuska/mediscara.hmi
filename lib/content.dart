import 'package:flutter/material.dart';
import 'package:hmi_app/grafana.dart';
import 'package:hmi_app/services/auth.dart';
import 'package:hmi_app/services/fiware.dart';
import 'package:hmi_app/services/session.dart';

import 'control.dart';
import 'info.dart';
import 'models/user.dart';

class ContentWidget extends StatefulWidget {
  const ContentWidget({Key? key}) : super(key: key);

  @override
  State<ContentWidget> createState() => _ContentWidgetState();
}

class _ContentWidgetState extends State<ContentWidget> {
  int _selectedIndex = 0;

  late User currentUser;

  late List<Widget> _widgetOptions;

  late InfoWidget infoWidget;
  late ControlWidget controlWidget;
  late GrafanaWidget grafanaWidget;

  final fiwareService = FiwareService();
  final auth = AuthService();

  late Session visionSession;

  @override
  void initState() {
    super.initState();

    visionSession = Session(service: fiwareService);

    currentUser = auth.user!;

    infoWidget = InfoWidget(visionKpi: visionSession.kpi);
    controlWidget = ControlWidget(visionSession: visionSession);
    grafanaWidget = const GrafanaWidget();

    final userIsManager = currentUser.checkIsManager(auth.roles!);
    final userIsHMIUser = currentUser.checkIsHMIUser(auth.roles!);

    _widgetOptions = <Widget>[
      userIsHMIUser ? infoWidget : disabledWidget(),
      userIsHMIUser ? controlWidget : disabledWidget(),
      userIsManager ? grafanaWidget : disabledWidget(),
      userIsHMIUser ? const Text('Error logs') : disabledWidget(),
    ];
  }

  Widget disabledWidget() {
    return const Center(
      child: Icon(Icons.visibility_off),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _signOut() async {
    if (visionSession.started) {
      await showConfirmationDialog(
        "Vision session is still running, please end the session",
      );
      return;
    }
    Navigator.pop(context);
  }

  /// Shows a confirmation dialog and returns with a boolean depending on
  /// the answer
  Future<bool?> showConfirmationDialog(String message) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Warning"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String userDisplayString = "";
    userDisplayString = "Signed in as ${currentUser.id}";

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(userDisplayString),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(Colors.white),
                foregroundColor: MaterialStateProperty.all<Color>(Colors.black),
              ),
              onPressed: _signOut,
              child: const Text("Sign out"),
            ),
          )
        ],
      ),
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: SizedBox(
        height: 100,
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.info),
              label: 'Info',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Control',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_graph),
              label: "Grafana",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.error),
              label: "Error Log",
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
