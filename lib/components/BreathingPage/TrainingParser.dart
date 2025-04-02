import 'package:respire/components/Global/Phase.dart';
import 'package:respire/components/Global/Step.dart' as training_step;
import 'package:respire/components/Global/StepIncrement.dart';
import 'package:respire/components/Global/Training.dart';

class TrainingParser {
  int phaseID = 0;
  int stepID = -1;

  Training training;
  Phase currentPhase;
  late training_step.Step currentStep;

  TrainingParser({required this.training})
      : currentPhase = training.phases[0];

  Map<String, dynamic>? nextInstruction() {

      if (stepID == currentPhase.steps.length - 1) {
        stepID = 0;
        currentPhase.doneRepsCounter++;

        if (currentPhase.doneRepsCounter == currentPhase.reps) {
          phaseID++;

          if (phaseID == training.phases.length) {
            return null;
          } else {
            currentPhase = training.phases[phaseID];
          }
        }
      } else {
        stepID++;
      }

    currentStep = currentPhase.steps[stepID];

    return {
      "step": currentStep,
      "remainingTime": remainingTimeValue(currentStep.duration),
    };
}

   int remainingTimeValue(double duration) {
    double result = duration * 1000;
    switch (currentStep.increment?.type) {
            case IncrementType.percentage:
              result += (result * currentStep.increment!.value * currentPhase.doneRepsCounter);
              break;
            case IncrementType.value:
              result += currentStep.increment!.value * 1000 * currentPhase.doneRepsCounter;
              break;
            default:
              break;
          }
    return result.toInt();
  }

  int countSteps() {
    int result = 0;
    for (int i=0; i<training.phases.length; i++) {
      result += (training.phases[i].steps.length * training.phases[i].reps);
    }
    return result;
  }

}
