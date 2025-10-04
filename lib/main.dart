import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:convert';
import 'dart:async'; // For Timer
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';
import 'package:share_plus/share_plus.dart';

// Import our updated helper
import 'database_helper.dart';

// --- Class to bypass SSL errors. Use for testing only! ---
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  runApp(const WaybillApp());
}

// --- URLs ---
// IMPORTANT: Replace with your actual endpoints
const String baseUrl = 'http://damir.service.kg//taxi/hs/taxi'; //212.42.103.160:5775
const String loginUrl = '$baseUrl/auth';
const String registrationUrl = '$baseUrl/auth'; // Corrected to match the code
const String openShiftUrl = '$baseUrl/open_shift'; // New URL for opening a shift
const String getWaybillUrl = '$baseUrl/get_waybill'; // New URL for getting a waybill by ID

const String staticServerUsername = 'Http User';
const String staticServerPassword = 'HttpUser';


// --- Main Application Class ---
class WaybillApp extends StatefulWidget {
  const WaybillApp({super.key});

  @override
  State<WaybillApp> createState() => _WaybillAppState();
}

class _WaybillAppState extends State<WaybillApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Logout logic on app minimize is removed as per new requirements
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Мобильное приложение для водителей',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[50],
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          titleTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.indigo, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.grey[700]),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      home: const AuthChecker(), // Start with authorization check
    );
  }
}

// New widget to check if the user is logged in
class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  _AuthCheckerState createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final user = await DatabaseHelper.instance.getUserData();
    if (mounted) {
      if (user != null) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const WaybillPage()));
      } else {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}


// --- Login Screen ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final credentials = utf8.fuse(base64).encode('$staticServerUsername:$staticServerPassword');
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'method': 'auth',
          'phone': _phoneController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        await DatabaseHelper.instance.saveUserData(
          phone: _phoneController.text,
          password: _passwordController.text,
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const WaybillPage()),
          );
        }
      } else {
        await _showAlertDialog('Ошибка авторизации', '${response.body} Код: ${response.statusCode}');
      }
    } catch (e) {
      await _showAlertDialog('Ошибка', 'Произошла ошибка при входе. Проверьте подключение к сети.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_shipping, size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 16),
              Text('Авторизация водителя', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Войдите, чтобы начать работу', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Номер телефона'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Пароль'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  onPressed: _login,
                  label: const Text('Войти'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationPage())),
                child: const Text('Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAlertDialog(String title, String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }
}

// --- Registration Screen ---
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 1.5,
    penColor: Colors.blue.shade900,
    exportBackgroundColor: Colors.transparent,
  );
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _signatureController.isEmpty) {
      _showAlertDialog('Ошибка', 'Пожалуйста, заполните все поля и поставьте подпись.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes == null) {
        _showAlertDialog('Ошибка', 'Не удалось создать подпись.');
        return;
      }
      final signatureBase64 = base64Encode(signatureBytes);
      final Map<String, dynamic> data = {
        'method': 'registr',
        'phone': _phoneController.text,
        'password': _passwordController.text,
        'lastName': _lastNameController.text,
        'firstName': _firstNameController.text,
        'middleName': _middleNameController.text,
        'dob': _dobController.text,
        'signature': signatureBase64,
      };
      final String jsonData = jsonEncode(data);
      final credentials = utf8.fuse(base64).encode('$staticServerUsername:$staticServerPassword');
      final response = await http.post(
        Uri.parse(registrationUrl),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/json',
        },
        body: jsonData,
      );

      if (response.statusCode == 200) {
        await _showAlertDialog('Успех', 'Регистрация прошла успешно. Теперь вы можете войти.', onOkPressed: () {
          if (mounted) Navigator.of(context).pop();
        });
      } else {
        await _showAlertDialog('Ошибка регистрации', '${response.body} Код: ${response.statusCode}');
      }
    } catch (e) {
      await _showAlertDialog('Ошибка', 'Произошла ошибка при регистрации: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              const Text('Введите данные для регистрации', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Номер телефона'), keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Обязательное поле' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Пароль'), obscureText: true, validator: (v) => v!.isEmpty ? 'Обязательное поле' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Фамилия'), validator: (v) => v!.isEmpty ? 'Обязательное поле' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'Имя'), validator: (v) => v!.isEmpty ? 'Обязательное поле' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _middleNameController, decoration: const InputDecoration(labelText: 'Отчество')),
              const SizedBox(height: 12),
              TextFormField(controller: _dobController, decoration: const InputDecoration(labelText: 'Дата рождения (ДД.ММ.ГГГГ)'), onTap: () => _selectDate(context, _dobController), readOnly: true, validator: (v) => v!.isEmpty ? 'Обязательное поле' : null),
              const SizedBox(height: 12),
              const Text('Подпись:'),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                child: Signature(controller: _signatureController, height: 150, backgroundColor: Colors.grey.shade200),
              ),
              TextButton(onPressed: () => _signatureController.clear(), child: const Text('Очистить')),
              const SizedBox(height: 20),
              _isLoading ? const CircularProgressIndicator() : SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _register, child: const Text('Зарегистрироваться'))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      controller.text = "${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}";
    }
  }

  Future<void> _showAlertDialog(String title, String message, {VoidCallback? onOkPressed}) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onOkPressed?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// --- NEW WAYBILL SCREEN WITH SHIFT LOGIC ---

// Enum to manage the screen state
enum WaybillStatus {
  loading, // Loading in progress
  initial, // "Start Shift" button
  waitingForDownload, // Waiting for 5 minutes
  readyToDownload, // "Download Waybill" button is active
  pdfDisplayed, // PDF is shown, "End Shift" button
  error, // An error occurred
}

class WaybillPage extends StatefulWidget {
  const WaybillPage({super.key});
  @override
  _WaybillPageState createState() => _WaybillPageState();
}

class _WaybillPageState extends State<WaybillPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _mileageController = TextEditingController();

  WaybillStatus _status = WaybillStatus.loading;
  String? _pdfPath;
  String? _requestId;
  String _errorMessage = '';
  Map<String, String?> _userCredentials = {};

  Timer? _timer;
  int _remainingSeconds = 0;
  final int _waitTimeInSeconds = 5; // 5 minutes = 300 sec

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mileageController.dispose();
    super.dispose();
  }

  Future<void> _initializeState() async {
    setState(() => _status = WaybillStatus.loading);
    final pdfFile = await _getPdfFile();
    if (await pdfFile.exists()) {
      setState(() {
        _pdfPath = pdfFile.path;
        _status = WaybillStatus.pdfDisplayed;
      });
      return;
    }

    final userData = await DatabaseHelper.instance.getUserData();
    if (userData == null) {
      _logout();
      return;
    }
    _userCredentials = {
      'phone': userData['phone'] as String?,
      'password': userData['password'] as String?
    };
    _requestId = userData['request_id'] as String?;
    final timestamp = userData['request_timestamp'] as int?;

    if (_requestId != null && timestamp != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedSeconds = (now - timestamp) ~/ 1000;
      final secondsLeft = _waitTimeInSeconds - elapsedSeconds;
      if (secondsLeft > 0) {
        _startTimer(secondsLeft);
        setState(() => _status = WaybillStatus.waitingForDownload);
      } else {
        setState(() => _status = WaybillStatus.readyToDownload);
      }
    } else {
      setState(() => _status = WaybillStatus.initial);
    }
  }

  // --- SHIFT MANAGEMENT METHODS ---
  Future<void> _openShift() async {
    if (_userCredentials['phone'] == null || _userCredentials['password'] == null) {
      _showAlertDialog('Ошибка сессии', 'Данные сессии были утеряны. Пожалуйста, авторизуйтесь снова.')
          .then((_) => _logout());
      return;
    }

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() => _status = WaybillStatus.loading);
    try {
      final authHeader = utf8.fuse(base64).encode('$staticServerUsername:$staticServerPassword');
      final response = await http.post(
        Uri.parse(openShiftUrl),
        headers: {'Authorization': 'Basic $authHeader', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _userCredentials['phone'],
          'password': _userCredentials['password'],
          'mileage': _mileageController.text,
        }),
      );
      if (response.statusCode == 200) {
        final responseBody = response.body.trim();
        if (responseBody.isNotEmpty) {
          _requestId = responseBody;
          await DatabaseHelper.instance.saveUserData(
            phone: _userCredentials['phone']!,
            password: _userCredentials['password']!,
            requestId: _requestId,
            requestTimestamp: DateTime.now().millisecondsSinceEpoch,
          );
          _startTimer(_waitTimeInSeconds);
          setState(() => _status = WaybillStatus.waitingForDownload);
        } else {
          throw Exception("Server returned an empty request_id");
        }
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        _status = WaybillStatus.error;
        _errorMessage = 'Ошибка при открытии смены:\n$e';
      });
    }
  }

  Future<void> _downloadWaybill() async {
    setState(() => _status = WaybillStatus.loading);
    try {
      final authHeader = utf8.fuse(base64).encode('$staticServerUsername:$staticServerPassword');
      final response = await http.post(
        Uri.parse(getWaybillUrl),
        headers: {'Authorization': 'Basic $authHeader', 'Content-Type': 'application/json'},
        body: jsonEncode({'request_id': _requestId}),
      );

      if (response.statusCode == 200) {
        final pdfFile = await _getPdfFile();
        await pdfFile.writeAsBytes(response.bodyBytes);
        await DatabaseHelper.instance.clearWaybillRequestData();
        setState(() {
          _pdfPath = pdfFile.path;
          _requestId = null;
          _status = WaybillStatus.pdfDisplayed;
        });
      } else if (response.statusCode == 203) {
        final message = utf8.decode(response.bodyBytes);
        await _showInfoDialog("Информация", message);
        setState(() {
          _status = WaybillStatus.readyToDownload;
        });
      }
      else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        _status = WaybillStatus.error;
        _errorMessage = 'Ошибка при загрузке путевого листа: $e';
      });
    }
  }

  Future<void> _endShift() async {
    setState(() => _status = WaybillStatus.loading);
    try {
      final file = await _getPdfFile();
      if (await file.exists()) {
        await file.delete();
      }
      _mileageController.clear();
      setState(() {
        _pdfPath = null;
        _status = WaybillStatus.initial;
      });
    } catch (e) {
      setState(() {
        _status = WaybillStatus.error;
        _errorMessage = 'Ошибка при удалении файла: $e';
      });
    }
  }

  // --- HELPER METHODS ---
  Future<void> _sharePdf() async {
    if (_pdfPath != null) {
      try {
        final file = XFile(_pdfPath!);
        await Share.shareXFiles([file], text: 'Путевой лист');
      } catch (e) {
        if (mounted) {
          _showAlertDialog('Ошибка', 'Не удалось поделиться файлом: $e');
        }
      }
    }
  }

  Future<void> _showInfoDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
              const SizedBox(width: 10),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAlertDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 10),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<File> _getPdfFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/waybill.pdf');
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    _remainingSeconds = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        setState(() => _status = WaybillStatus.readyToDownload);
      }
    });
  }

  Future<void> _logout() async {
    await DatabaseHelper.instance.clearAllUserData();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
      );
    }
  }

  String get _timerText {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои путевые листы'),
        actions: [
          if (_status == WaybillStatus.pdfDisplayed)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _sharePdf,
              tooltip: 'Поделиться/Сохранить/Печать',
            ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(child: _buildContent()),
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: _buildActionButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_status) {
      case WaybillStatus.pdfDisplayed:
        return _pdfPath != null ? PDFView(filePath: _pdfPath!) : _buildErrorContent();
      case WaybillStatus.initial:
        return _buildInitialContent();
      case WaybillStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case WaybillStatus.waitingForDownload:
        return _buildWaitingContent();
      case WaybillStatus.readyToDownload:
        return _buildReadyToDownloadContent();
      case WaybillStatus.error:
        return _buildErrorContent();
      default:
        return const Center(child: Text("Неизвестное состояние"));
    }
  }

  Widget _buildInitialContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.speed, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Смена закрыта', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Введите актуальный пробег, чтобы начать работу.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _mileageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: "Текущий пробег *"),
                    validator: (v) => v == null || v.isEmpty ? "Введите пробег" : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: _remainingSeconds / _waitTimeInSeconds,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                ),
                Center(
                  child: Text(
                    _timerText,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Путевой лист формируется...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Это займет несколько минут', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildReadyToDownloadContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
          const SizedBox(height: 24),
          const Text('Путевой лист готов!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Нажмите кнопку ниже, чтобы загрузить документ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Card(
          color: Colors.red[50],
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Произошла ошибка', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  style: TextStyle(fontSize: 16, color: Colors.red[800]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    switch (_status) {
      case WaybillStatus.initial:
        return SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.play_arrow), onPressed: _openShift, label: const Text("Открыть смену")));
      case WaybillStatus.waitingForDownload:
        return SizedBox(width: double.infinity, child: ElevatedButton(onPressed: null, child: Text("Загрузить путевой лист ($_timerText)")));
      case WaybillStatus.readyToDownload:
        return SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.download), onPressed: _downloadWaybill, label: const Text("Загрузить путевой лист")));
      case WaybillStatus.pdfDisplayed:
        return SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _endShift, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), icon: const Icon(Icons.close_sharp), label: const Text("Завершить смену")));
      case WaybillStatus.loading:
      case WaybillStatus.error:
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }
}
