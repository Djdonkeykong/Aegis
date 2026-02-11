class AppConstants {
  AppConstants._();

  static const String appName = 'MedCheck';

  // Ollama AI
  static const String ollamaEndpoint = 'http://10.0.2.2:11434/api/generate';
  static const String ollamaModel = 'llama3.2';

  // CSV assets
  static const List<String> ddinterCsvAssets = [
    'assets/ddinter_downloads_code_A.csv',
    'assets/ddinter_downloads_code_B.csv',
    'assets/ddinter_downloads_code_D.csv',
    'assets/ddinter_downloads_code_H.csv',
    'assets/ddinter_downloads_code_L.csv',
    'assets/ddinter_downloads_code_P.csv',
    'assets/ddinter_downloads_code_R.csv',
    'assets/ddinter_downloads_code_V.csv',
  ];

  static const String kaggleCsvAsset = 'assets/db_drug_interactions.csv';

  // Disclaimers
  static const String disclaimer =
      'Based on DDInter & Kaggle databases. NOT medical advice. Always consult a healthcare professional.';
}
