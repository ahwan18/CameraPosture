# S.I.R.A.J / CameraPosture

S.I.R.A.J is an iOS posture guidance prototype for Pencak Silat beginners. The app helps users practice basic movement accuracy through visual posture feedback.

## Problem

Beginners learning Pencak Silat often need clearer guidance when practicing movements outside formal training sessions. S.I.R.A.J explores how computer vision can support beginner-friendly posture learning.

## What I Built

- iOS posture guidance flow for Pencak Silat practice
- Camera-based body pose analysis prototype
- Visual feedback to help users compare posture accuracy
- Beginner-focused flow for practice preparation and belt progression
- Pose reference data flow using a converter app
- TestFlight validation flow for early users

## App Modules

This repository contains two connected iOS apps:

```text
PoseToJsonConverter   Converts reference Pencak Silat poses into JSON pose data
SilatTrainer          Uses camera-based posture feedback for practice sessions
PoseData              Stores pose reference data used by the trainer
jurus_1_ipsi          Reference pose images for Jurus Satu IPSI
```

## Training Flow

```text
Reference Pose Data
-> Camera Pose Detection
-> Joint Comparison
-> Visual Feedback
-> Practice Progression
```

## Tech Stack

- Swift
- SwiftUI
- Vision
- Core ML
- AVFoundation
- Xcode

## Project Structure

```text
PoseToJsonConverter/  Utility app for preparing pose reference data
SilatTrainer/         Main training app for posture feedback
PoseData/             JSON pose reference data
jurus_1_ipsi/         Pencak Silat reference images
```

## Role

Developer and researcher. I focused on the iOS implementation, posture-analysis flow, pose reference workflow, and validation with early users.

## Result

Published to TestFlight and validated with 5+ users. Users reported that the posture feedback was clear and helpful for understanding basic movement positions.

## How to Run

1. Open `SilatTrainer/SilatTrainer.xcodeproj` in Xcode to run the training app.
2. Open `PoseToJsonConverter/PoseToJsonConverter.xcodeproj` if you need to adjust or regenerate pose reference data.
3. Use a physical iPhone for the best camera and Vision framework testing experience.

## Notes

This repository is a portfolio prototype focused on movement-learning validation. The core value is the workflow: preparing reference poses, detecting user posture, and showing beginner-friendly feedback.
