import 'package:flutter/material.dart';


class Circle extends StatefulWidget {
  final int time;

  const Circle({super.key, required this.time});

  @override
  State<StatefulWidget> createState() => _CircleState();
}

class _CircleState extends State<Circle> with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _circleAnimation;
  

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3)
        );
    _circleAnimation = Tween<double>(begin: 125.0, end: 225.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget textInCircle() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${(widget.time/1000).toDouble()}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return 
                  //Animated Circle
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Container(
                        width: _circleAnimation.value,
                        height: _circleAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue,
                        ),
                        child: textInCircle(),
                      );
                    },
                  );
  }
}
