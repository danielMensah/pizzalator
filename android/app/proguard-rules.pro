# google_mlkit_text_recognition compiles against every script's recognizer;
# only the bundled Latin one is shipped (PRD §4.8), so the others are absent.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
