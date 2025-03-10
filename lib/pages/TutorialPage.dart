import 'package:flutter/material.dart';

class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});

  @override
  State<StatefulWidget> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {

    Widget _mainBox(double screenWidth) {
    return Container(
      width: screenWidth * 0.9,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey,
      ),
      child: Center(
        child: Column(
          children: [
            SizedBox(height: 20),
            Icon(
              Icons.info_outline
            ),
            SizedBox(height: 20),
            Text(
              "Tutorial",
              style: TextStyle(
                fontSize: 30
              ),
            ),
            SizedBox(height: 20),
            Text(
              "Click this to do this",
              style: TextStyle(
                fontSize: 20
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
     double screenWidth = MediaQuery.of(context).size.width;
     return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text("ReSpire", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.grey,
        ),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            _mainBox(screenWidth)
          ]
        ),
      )
    );
  }
}