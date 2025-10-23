import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:convert';
import 'dart:async'; // For Timer
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'database_helper.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env.production");
  } catch (e) {
    // Обработка, если файл .env не найден или не загружен
    print("Ошибка загрузки .env файла: $e");
    // Можете установить значения по умолчанию, чтобы приложение запустилось
  }
  // HttpOverrides.global = MyHttpOverrides();
  runApp(const WaybillApp());
}

final String baseUrl = dotenv.env['BASE_URL']!;
final String loginUrl = '$baseUrl/auth';
final String registrationUrl = '$baseUrl/auth';
final String openShiftUrl = '$baseUrl/open_shift';
final String getWaybillUrl = '$baseUrl/get_waybill';

final String downloadWaybillUrl = dotenv.env['WAY_URL']!;
final String deleteAccountUrl = 'https://raw.githubusercontent.com/TillaevDamir/my_waybill/refs/heads/main/DATA_DELETION.md';
final String staticServerUsername = dotenv.env['API_USER']!;
final String staticServerPassword = dotenv.env['API_PASSWORD']!;

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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Мобильное приложение для водителей',
      theme: ThemeData(
        primarySwatch: Colors.yellow,
        primaryColor: Colors.yellow,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.black,

          selectionColor: Colors.yellowAccent,

          selectionHandleColor: Colors.black,
        ),
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
            backgroundColor: Colors.yellow,
            foregroundColor: Colors.black87,
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
            borderSide: const BorderSide(color: Colors.yellow, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.grey[700]),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      home: const AuthChecker(),
    );
  }
}

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
      if (user != null && user['phone'] != null) {
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
      body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
    );
  }
}


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordObscured = true;

  final _formKey = GlobalKey<FormState>();

  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  Future<void> _login() async {

    if (!_formKey.currentState!.validate()) {
      return;
    }

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
          'phone': _phoneMaskFormatter.getUnmaskedText(),
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        final fullName = responseBody['fullName'] as String?;
        await DatabaseHelper.instance.saveUserData(
          phone: _phoneMaskFormatter.getUnmaskedText(),
          password: _passwordController.text,
          fullName: fullName,
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const WaybillPage()),
          );
        }
      } else {
        await _showAlertDialog('Ошибка авторизации', '${response.body}');
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
              Icon(Icons.local_taxi_rounded, size: 80, color: Colors.yellow),
              const SizedBox(height: 16),
              Text('Авторизация водителя', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Войдите, чтобы начать работу', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(labelText: 'Номер телефона', hintText: '+7 (999) 123-45-67'),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [_phoneMaskFormatter],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Введите номер телефона';
                            }
                            if (value.length != 18) {
                              return 'Введите полный номер';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _isPasswordObscured,
                          decoration: InputDecoration(
                              labelText: 'Пароль',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordObscured = !_isPasswordObscured;
                                });
                              }
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Введите пароль';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.yellow)
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
                style: TextButton.styleFrom(foregroundColor: Colors.black87),
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
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 1.5,
    penColor: Colors.blue.shade900,
    exportBackgroundColor: Colors.transparent,
  );
  bool _isLoading = false;
  bool _isAgreed = false;
  bool _isPasswordObscured = true;

  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  final String _privacyPolicyText = """
1. ОБЩИЕ ПОЛОЖЕНИЯ
1.1. Настоящая Политика в отношении обработки персональных данных (далее – Политика) составлена в соответствии с требованиями законодательства о защите персональных данных и определяет порядок обработки персональных данных и меры по обеспечению безопасности персональных данных, предпринимаемые Оператором.
1.2. Оператор ставит своей важнейшей целью и условием осуществления своей деятельности соблюдение прав и свобод человека и гражданина при обработке его персональных данных, в том числе защиты прав на неприкосновенность частной жизни, личную и семейную тайну.

2. ОСНОВНЫЕ ПОНЯТИЯ, ИСПОЛЬЗУЕМЫЕ В ПОЛИТИКЕ
2.1. Автоматизированная обработка персональных данных – обработка персональных данных с помощью средств вычислительной техники.
2.2. Блокирование персональных данных – временное прекращение обработки персональных данных (за исключением случаев, если обработка необходима для уточнения персональных данных).
2.3. Информационная система персональных данных — совокупность содержащихся в базах данных персональных данных, и обеспечивающих их обработку информационных технологий и технических средств.

3. ПРАВА И ОБЯЗАННОСТИ ОПЕРАТОРА
3.1. Оператор имеет право:
– получать от субъекта персональных данных достоверные информацию и/или документы, содержащие персональные данные;
– в случае отзыва субъектом персональных данных согласия на обработку персональных данных Оператор вправе продолжить обработку персональных данных без согласия субъекта персональных данных при наличии оснований, указанных в Законе о персональных данных.
""";

  final String _termsOfUseText = """
1. ОБЩИЕ ПОЛОЖЕНИЯ
1.1. Настоящее Пользовательское соглашение (далее – Соглашение) относится к мобильному приложению «AlgaPro», расположенному по адресу Google Play.
1.2. Настоящее Соглашение регулирует отношения между Администрацией мобильного приложения «AlgaPro» (далее – Администрация приложения) и Пользователем данного Приложения.

2. ПРЕДМЕТ СОГЛАШЕНИЯ
2.1. Предметом настоящего Соглашения является предоставление Пользователю Приложения доступа к содержащимся в Приложении сервисам.
2.2. Приложение предоставляет Пользователю следующие виды услуг (сервисов):
– доступ к электронным путевым листам;
– доступ к средствам поиска и навигации;
– предоставление Пользователю возможности размещения сообщений, комментариев;
– доступ к информации о приложении и условиях его использования на бесплатной основе.

3. ПРАВА И ОБЯЗАННОСТИ СТОРОН
3.1. Администрация приложения вправе:
3.1.1. Изменять правила пользования Приложением, а также изменять содержание данного Приложения. Изменения вступают в силу с момента публикации новой редакции Соглашения в Приложении.
""";

  Future<void> _register() async {
    if (!_isAgreed) {
      _showAlertDialog('Требуется согласие', 'Пожалуйста, примите политику и условия использования, чтобы продолжить.');
      return;
    }

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
        'phone': _phoneMaskFormatter.getUnmaskedText(),
        'password': _passwordController.text,
        'lastName': _lastNameController.text,
        'firstName': _firstNameController.text,
        'middleName': _middleNameController.text,
        'signature': signatureBase64,
      };
      final String jsonData = jsonEncode(data);
      final credentials = utf8.fuse(base64).encode('$staticServerUsername:$staticServerPassword');
      final response = await http.post(
        Uri.parse(registrationUrl),
        headers: {'Authorization': 'Basic $credentials', 'Content-Type': 'application/json'},
        body: jsonData,
      );

      if (response.statusCode == 200) {
        await _showAlertDialog('Успех', 'Регистрация прошла успешно. Теперь вы можете войти.', onOkPressed: () {
          if (mounted) Navigator.of(context).pop();
        });
      } else {
        await _showAlertDialog('Ошибка регистрации', '${response.body}');
      }
    } catch (e) {
      await _showAlertDialog('Ошибка', 'Произошла ошибка при регистрации: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPolicyDialog(String title, String content) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Закрыть'),
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
            ),
          ],
        );
      },
    );
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
              TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Номер телефона', hintText: '+7 (999) 123-45-67'),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_phoneMaskFormatter],
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Обязательное поле';
                    }
                    if (v.length != 18) {
                      return 'Введите полный номер';
                    }
                    return null;
                  }),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _passwordController,
                  obscureText: _isPasswordObscured,
                  decoration: InputDecoration(
                      labelText: 'Пароль',
                      suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordObscured = !_isPasswordObscured;
                            });
                          },
                      ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Обязательное поле' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Фамилия'), validator: (v) => v!.isEmpty ? 'Обязательное поле' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'Имя'), validator: (v) => v!.isEmpty ? 'Обязательное поле' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _middleNameController, decoration: const InputDecoration(labelText: 'Отчество')),
              const SizedBox(height: 12),
              const Text('Подпись:'),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                child: Signature(controller: _signatureController, height: 150, backgroundColor: Colors.grey.shade200),
              ),
              TextButton(
                  onPressed: () => _signatureController.clear(),
                  child: const Text('Очистить'),
                  style: TextButton.styleFrom(foregroundColor: Colors.black87)
              ),

              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _isAgreed,
                    activeColor: Colors.yellow,
                    checkColor: Colors.black87,
                    onChanged: (bool? value) {
                      setState(() {
                        _isAgreed = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14),
                          children: [
                            const TextSpan(text: 'Я принимаю '),
                            TextSpan(
                              text: 'Политику обработки персональных данных',
                              style: TextStyle(color: Colors.black87, decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  _showPolicyDialog(
                                    'Политика обработки персональных данных',
                                    _privacyPolicyText,
                                  );
                                },
                            ),
                            const TextSpan(text: ' и '),
                            TextSpan(
                              text: 'Условия использования',
                              style: TextStyle(color: Colors.black87, decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  _showPolicyDialog(
                                    'Условия использования',
                                    _termsOfUseText,
                                  );
                                },
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _isLoading ? const CircularProgressIndicator(color: Colors.yellow) : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: _register,
                      child: const Text('Зарегистрироваться'),
                     ),
                  ),
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

enum WaybillStatus {
  loading,
  initial,
  waitingForDownload,
  waybillReady,
  error,
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
  String _userName = 'Загрузка...';

  Timer? _timer;
  int _remainingSeconds = 0;
  final int _waitTimeInSeconds = 30;

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
    final userData = await DatabaseHelper.instance.getUserData();

    if (userData == null || userData['phone'] == null) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
        );
      }
      return;
    }

    setState(() {
      _userName = userData['fullName'] as String? ?? 'Мой путевой лист';
    });

    _userCredentials = {
      'phone': userData['phone'] as String?,
      'password': userData['password'] as String?
    };
    _requestId = userData['request_id'] as String?;
    final timestamp = userData['request_timestamp'] as int?;

    final pdfFile = await _getPdfFile();
    if (await pdfFile.exists() && _requestId != null) {
      setState(() {
        _pdfPath = pdfFile.path;
        _status = WaybillStatus.waybillReady;
      });
      return;
    }

    if (_requestId != null && timestamp != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedSeconds = (now - timestamp) ~/ 1000;
      final secondsLeft = _waitTimeInSeconds - elapsedSeconds;
      if (secondsLeft > 0) {
        _startTimer(secondsLeft);
        setState(() => _status = WaybillStatus.waitingForDownload);
      } else {
        _downloadWaybill(isFirstTime: true);
      }
    } else {
      setState(() => _status = WaybillStatus.initial);
    }
  }

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

  Future<void> _downloadWaybill({bool isFirstTime = false}) async {
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

        if (isFirstTime) {
          await DatabaseHelper.instance.saveUserData(requestTimestamp: null);
        }

        setState(() {
          _pdfPath = pdfFile.path;
          _status = WaybillStatus.waybillReady;
        });
      } else if (response.statusCode == 203) {
        final message = utf8.decode(response.bodyBytes);
        await _showInfoDialog("Информация", message);
        _startTimer(_waitTimeInSeconds);
        setState(() => _status = WaybillStatus.waitingForDownload);
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        _status = WaybillStatus.error;
        _errorMessage = 'Ошибка при загрузке путевого листа: $e';
      });
    }
  }


  Future<void> _shareOrSaveWaybill() async {
    if (_requestId == null) {
      _showAlertDialog('Ошибка', 'ID путевого листа не найден.');
      return;
    }
    final snackBar = SnackBar(content: Text('Подготовка файла...'));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    try {
      final authHeader = utf8.fuse(base64).encode('$staticServerUsername:$staticServerPassword');
      final uri = Uri.parse('$downloadWaybillUrl?request_id=$_requestId');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Basic $authHeader'},
      );

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = await File('${tempDir.path}/waybill_${_requestId!.substring(0, 8)}.pdf').create();
        await tempFile.writeAsBytes(response.bodyBytes);

        final xFile = XFile(tempFile.path);
        await Share.shareXFiles([xFile], text: 'Путевой лист');

      } else {
        throw Exception('Ошибка сервера: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        _showAlertDialog('Ошибка', 'Не удалось подготовить файл: $e');
      }
    } finally {
      if(mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }


  Future<void> _endShift() async {
    setState(() => _status = WaybillStatus.loading);
    try {
      final file = await _getPdfFile();
      if (await file.exists()) {
        await file.delete();
      }
      await DatabaseHelper.instance.clearWaybillRequestData();
      _mileageController.clear();
      setState(() {
        _pdfPath = null;
        _requestId = null;
        _status = WaybillStatus.initial;
      });
    } catch (e) {
      setState(() {
        _status = WaybillStatus.error;
        _errorMessage = 'Ошибка при удалении файла: $e';
      });
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
              Icon(Icons.info_outline, color: Colors.yellow),
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

  Future<bool> _showConfirmationDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Нет'),
            style: TextButton.styleFrom(foregroundColor: Colors.black87)
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Да'),
            style: TextButton.styleFrom(foregroundColor: Colors.black87),
          ),
        ],
      ),
    );
    return result ?? false;
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
        _downloadWaybill(isFirstTime: true);
      }
    });
  }

  Future<void> _logout({bool clearSessionOnly = true}) async {
    if (clearSessionOnly) {
      await DatabaseHelper.instance.clearAuthCredentials();
    } else {
      await DatabaseHelper.instance.clearAllUserData();
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
      );
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showAlertDialog('Ошибка', 'Не удалось открыть ссылку: $url');
    }
  }

  String get _timerText {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _viewPdf() {
    if (_pdfPath != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerPage(filePath: _pdfPath!),
        ),
      );
    } else {
      _showAlertDialog('Ошибка', 'Файл путевого листа не найден.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _userName,
          style: const TextStyle(fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout()),
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
            if (_status == WaybillStatus.initial)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextButton(
                  onPressed: () => _launchURL(deleteAccountUrl),
                  child: Text(
                    'Запросить удаление аккаунта',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_status) {
      case WaybillStatus.waybillReady:
        return _buildQrCodeAndActionsContent();
      case WaybillStatus.initial:
        return _buildInitialContent();
      case WaybillStatus.loading:
        return const Center(child: CircularProgressIndicator(color: Colors.yellow));
      case WaybillStatus.waitingForDownload:
        return _buildWaitingContent();
      case WaybillStatus.error:
        return _buildErrorContent();
      default:
        return const Center(child: Text("Неизвестное состояние"));
    }
  }

  Widget _buildQrCodeAndActionsContent() {
    final qrData = '$downloadWaybillUrl?request_id=$_requestId';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Электронный Путевой Лист водителя',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Покажите данный QR код сотруднику ДПС или откройте ЭПЛ самостоятельно',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220.0,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(
                    Icons.share,
                    color: Colors.black,
                ),
                label: const Text(
                    'Поделиться / Сохранить ЭПЛ',
                     style: TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white38),
                onPressed: _shareOrSaveWaybill,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(
                    Icons.visibility,
                    color: Colors.black,
                ),
                label: const Text(
                    'Просмотреть ЭПЛ',
                    style: TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white38),
                onPressed: _viewPdf,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.close_sharp),
                label: const Text('Завершить смену'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () async {
                  final confirm = await _showConfirmationDialog(
                    'Завершение смены',
                    'Вы уверены? Электронный путевой лист будет удален.',
                  );
                  if (confirm) {
                    _endShift();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
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
        return SizedBox(width: double.infinity, child: ElevatedButton(onPressed: null, child: Text("Автоматическая загрузка через ($_timerText)")));
      case WaybillStatus.waybillReady:
        return const SizedBox.shrink();
      case WaybillStatus.loading:
      case WaybillStatus.error:
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }
}

class PdfViewerPage extends StatelessWidget {
  final String filePath;

  const PdfViewerPage({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Просмотр путевого листа'),
      ),
      body: PDFView(
        filePath: filePath,
      ),
    );
  }
}

