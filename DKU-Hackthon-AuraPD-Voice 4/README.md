# AuraPD-Voice

A voice-first, on-device iOS application for real-time Parkinson's disease (PD) motor-state monitoring.  
All processing happens **on-device with zero cloud dependency** using Apple's native frameworks.

---

## System Architecture

| Layer | Responsibility |
|---|---|
| **User Layer** | Wake-word "Check my condition" (no button press) + fallback touch trigger |
| **Sensing Layer** | CoreMotion accelerometer + gyroscope at ~50 Hz in a 2.5-second sliding window |
| **Intelligence Layer** | Feature extraction (mean, variance σ, signal energy) + rule-based classifier |
| **Explainability Layer** | Plain-language rationale spoken via AVSpeechSynthesizer |
| **Ethical AI Layer** | Voice-prompted informed consent before every capture session |

---

## Classification Rule

```
if σ > 2τ         →  State = Tremor   (high variability)
else if σ > τ     →  State = OFF       (elevated variability)
else              →  State = ON        (normal variability)
```

`σ` = standard deviation of the accelerometer magnitude window  
`τ` = user-personalised threshold (default 0.60, recalculated after calibration)

---

## Project Structure

```
AuraPD-Voice.xcodeproj/         ← Xcode project
AuraPD-Voice/
├── App/
│   └── AuraPD_VoiceApp.swift   ← @main entry point
├── Models/
│   ├── MotorState.swift         ← MotorState enum + voice explanation templates
│   ├── SensorData.swift         ← SensorSample, SensorWindow (sliding window)
│   ├── AssessmentResult.swift   ← Persisted result model (Codable)
│   └── UserProfile.swift        ← Personalised threshold + calibration data
├── Intelligence/
│   ├── FeatureExtractor.swift   ← Mean / variance / signal energy extraction
│   └── PDClassifier.swift       ← Rule-based σ vs τ classifier
├── Services/
│   ├── MotionService.swift      ← CoreMotion 50 Hz data collection
│   ├── SpeechService.swift      ← AVSpeechSynthesizer TTS wrapper
│   ├── VoiceCommandService.swift← SFSpeechRecognizer wake-word detection
│   └── ConsentService.swift     ← Voiced consent gate (Ethical AI layer)
├── Storage/
│   └── LocalStorageService.swift← On-device-only UserDefaults persistence
├── ViewModels/
│   └── MainViewModel.swift      ← Central coordinator (ObservableObject)
├── Views/
│   ├── ContentView.swift        ← TabView root (Dashboard / History / Settings)
│   ├── DashboardView.swift      ← Motor-state indicator + trigger button
│   ├── HistoryView.swift        ← Chronological assessment log
│   └── SettingsView.swift       ← Threshold slider + auto-calibration
└── Resources/
    └── Info.plist               ← NSMotion / NSSpeechRecognition / NSMicrophone usage keys
```

---

## Requirements

* iOS 16.0+
* Xcode 15+
* Physical iPhone (CoreMotion and on-device speech recognition require real hardware)

---

## Privacy Guarantees

* Motion data is never transmitted externally.
* Speech audio is processed on-device only (`requiresOnDeviceRecognition = true`).
* Assessment logs are stored in the app's private `UserDefaults` sandbox.
* The app asks for verbal consent before every motion-capture session.

---

## Getting Started

1. Clone the repository.
2. Open `AuraPD-Voice.xcodeproj` in Xcode 15.
3. Select your development team in *Signing & Capabilities*.
4. Build and run on a physical iPhone.
5. Say **"Check my condition"** to trigger an assessment.
