import 'package:flutter/material.dart';
import 'package:respire/components/HomePage/BaseTile.dart';
import 'package:respire/theme/Colors.dart';

class AddTrainingStageButton extends StatelessWidget
{

  final GestureTapCallback onClick;
  final Color color;

  const AddTrainingStageButton({
    super.key,
    required this.onClick,
    this.color = darkerblue}
    );

  @override
  Widget build(BuildContext context) {
    return BaseTile(
      onClick: onClick,
        child:
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(Icons.add)]
          )
    );
  }
  
}