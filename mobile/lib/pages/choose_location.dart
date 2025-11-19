import 'package:flutter/material.dart';

class ChooseLocation extends StatefulWidget {
  const ChooseLocation({super.key});

  @override
  State<ChooseLocation> createState() => _ChooseLocationState();
}

class _ChooseLocationState extends State<ChooseLocation> {
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[100],
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        title: Text("Choose The Location!"),
        centerTitle: true,
        elevation: 0,
      ),
      body: ElevatedButton(onPressed: () {
        setState(() {
        });
      },
      child: Text(""), 
      )
    );
  }
}