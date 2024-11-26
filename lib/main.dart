import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as htmlParser;
import 'package:html/dom.dart' as dom;
import 'dart:convert';

void main() => runApp(const SpeechRecognitionApp());

class SpeechRecognitionApp extends StatelessWidget {
  const SpeechRecognitionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Speech Recognition',
      theme: ThemeData.dark(),
      home: const SpeechRecognitionScreen(),
    );
  }
}

class SpeechRecognitionScreen extends StatefulWidget {
  const SpeechRecognitionScreen({super.key});

  @override
  _SpeechRecognitionScreenState createState() => _SpeechRecognitionScreenState();
}

class _SpeechRecognitionScreenState extends State<SpeechRecognitionScreen>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isListening = false;
  String _text = 'Press the button and start speaking';
  String _translatedText = '';
  final Map<String, String> languages = {
    'en': 'English',
    'hi': 'Hindi',
    'es': 'Spanish',
    'fr': 'French',
  };
  String _inputLanguage = 'hi';
  String _outputLanguage = 'en';
  final String _apiKey = 'Your_Api_Key'; // Replace with your API key

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'notListening') {
            setState(() => _isListening = false);
            _animationController.stop();
            Future.delayed(Duration(seconds: 1), () {
              _translateText();
            });
          }
        },
        onError: (val) {
          setState(() {
            _isListening = false;
            _animationController.stop();
          });
        },
      );
      if (available) {
        setState(() {
          _isListening = true;
          _animationController.forward();
        });
        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
          }),
          localeId: _inputLanguage,
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _animationController.stop();
      Future.delayed(Duration(seconds: 1), () {
        _translateText();
      });
    }
  }

  Future<void> _translateText() async {
    final translatedText = await translateText(_text, _outputLanguage);
    setState(() {
      String decodedText = htmlParser.parse('<div>$translatedText</div>').body!.text;
      _translatedText = decodedText;
    });
  }

  Future<String> translateText(String text, String targetLanguage) async {
    final response = await http.post(
      Uri.parse('https://translation.googleapis.com/language/translate/v2?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'q': text, 'target': targetLanguage}),
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return jsonData['data']['translations'][0]['translatedText'];
    } else {
      throw Exception('Failed to translate text');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(title: Center(child: Text('Speech Translator')),),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.grey[900]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDropdownRow(),
              const SizedBox(height: 50),
              _buildTextContainer('Original Text:', _text),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _translateText,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 12.0),
                ),
                child: const Text(
                  'Translate',
                  style: TextStyle(color: Colors.black87, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              _buildTextContainer('Translated Text:', _translatedText),
              const SizedBox(height: 40),
              ScaleTransition(
                scale: _isListening ? _animation : AlwaysStoppedAnimation(1.0),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: _isListening
                        ? [
                      BoxShadow(
                        color: Colors.tealAccent.withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: 15,
                      )
                    ]
                        : [],
                  ),
                  child: FloatingActionButton(
                    onPressed: _listen,
                    backgroundColor: Colors.grey[800],
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.tealAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildDropdown('Input Language', _inputLanguage, (newLang) {
          setState(() => _inputLanguage = newLang!);
        }),
        _buildDropdown('Output Language', _outputLanguage, (newLang) {
          setState(() => _outputLanguage = newLang!);
        }),
      ],
    );
  }

  Widget _buildDropdown(
      String label, String selectedValue, ValueChanged<String?> onChanged) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white70)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black54,
            border: Border.all(color: Colors.tealAccent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: Colors.grey[850],
              style: const TextStyle(color: Colors.white),
              value: selectedValue,
              items: languages.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextContainer(String label, String text) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.tealAccent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}