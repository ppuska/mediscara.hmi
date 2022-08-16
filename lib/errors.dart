import 'package:flutter/material.dart';
import 'package:hmi_app/services/backend.dart';

class ErrorWidget extends StatefulWidget {
  const ErrorWidget({Key? key}) : super(key: key);

  @override
  State<ErrorWidget> createState() => _ErrorWidgetState();
}

class _ErrorWidgetState extends State<ErrorWidget> {
  List<Error> errors = [];

  late BackendService backendService;

  @override
  void initState() {
    super.initState();

    backendService = BackendService();

    backendService.registerErrorCallback(_newError);

    setState(() {
      errors = backendService.errors;
    });
  }

  @override
  void dispose() {
    backendService.unregisterErrorCallback(_newError);

    super.dispose();
  }

  void _newError(Error error) {
    setState(() {
      errors.add(error);
    });
  }

  void _deleteError(int index) {
    backendService.errors.removeAt(index);

    setState(() {
      errors = backendService.errors;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) {
      return const Text("No errors");
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: errors.length,
      itemBuilder: (BuildContext context, int index) {
        return SizedBox(
          height: 100,
          child: Card(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 0, 0),
                    child: Text('id: ${errors[index].id}'),
                  ),
                ),
                Expanded(
                  child: Text('message: ${errors[index].message}'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 32, 0),
                  child: IconButton(
                    onPressed: () => _deleteError(index),
                    icon: const Icon(Icons.delete),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class Error {
  String id;
  String message;

  Error({required this.id, required this.message});
}
