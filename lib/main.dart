import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ParkCepteApp());
}

class ParkCepteApp extends StatelessWidget {
  const ParkCepteApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkCepte',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B19),
        primaryColor: const Color(0xFF39FF14),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0A1024),
          selectedItemColor: Color(0xFF39FF14),
          unselectedItemColor: Colors.white54,
          elevation: 10,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ReceiptScreen(),
    const BudgetScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Ana Ekran',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            activeIcon: Icon(Icons.camera_alt),
            label: 'Fiş Kasası',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Bütçem',
          ),
        ],
      ),
    );
  }
}

class ExpenseItem {
  final String id;
  final String date;
  final String location;
  final double amount;

  ExpenseItem({
    required this.id,
    required this.date,
    required this.location,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'location': location,
        'amount': amount,
      };

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(
        id: json['id'],
        date: json['date'],
        location: json['location'],
        amount: json['amount'],
      );
}

// ============================================ //
// 1. SEKME: ANA EKRAN (Sayaç ve Firestore Sync) //
// ============================================ //
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String? parkedLocation;
  Timer? _timer;
  final int _totalSeconds = 10800;
  int _remainingSeconds = 0;
  
  double? _latitude;
  double? _longitude;

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  
  final ScreenshotController _screenshotController = ScreenshotController();

  final List<String> letters = List.generate(26, (index) => String.fromCharCode(65 + index));
  final List<String> numbers = List.generate(100, (index) => (index + 1).toString());
  final List<String> colors = ['Kırmızı', 'Mavi', 'Yeşil', 'Sarı', 'Turuncu', 'Beyaz'];

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

  }

  @override
  void dispose() {
    _timer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint("Konum Alma Hatası: $e");
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingSeconds = _totalSeconds - 1; 
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _resetParking() {
    _timer?.cancel();
    setState(() {
      parkedLocation = null;
      _remainingSeconds = 0;
      _latitude = null;
      _longitude = null;
    });
  }

  Color get _currentColor {
    if (parkedLocation == null) return const Color(0xFF39FF14);
    if (_remainingSeconds > 3600) return const Color(0xFF39FF14);
    if (_remainingSeconds > 900) return Colors.amberAccent;
    return Colors.redAccent;
  }

  String get _formattedTime {
    int h = _remainingSeconds ~/ 3600;
    int m = (_remainingSeconds % 3600) ~/ 60;
    int s = _remainingSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _shareParkingInfo() async {
    if (parkedLocation == null) return;
    String mapsLink = "";
    if (_latitude != null && _longitude != null) {
      mapsLink = "🗺️ Tam harita konumu için tıkla: http://maps.google.com/maps?q=$_latitude,$_longitude \n\n";
    }
    final String shareMessage = "📍 Arabayı buraya park ettim: ${parkedLocation!.replaceAll('\n', ' ')}. \n\n"
                                "$mapsLink"
                                "⏳ Kalan süremiz: $_formattedTime. ParkCepte ile her şey kontrol altında! 🚗💨";

    if (kIsWeb) {
      await Share.share(shareMessage);
      return;
    }

    try {
      final imageBytes = await _screenshotController.capture();
      if (imageBytes != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/parking_status.png').create();
        await imagePath.writeAsBytes(imageBytes);
        await Share.shareXFiles([XFile(imagePath.path)], text: shareMessage);
      } else {
        await Share.share(shareMessage);
      }
    } catch (e) {
      await Share.share(shareMessage);
    }
  }

  void _showLocationPicker() {
    String tempLetter = 'A';
    String tempNumber = '1';
    String tempColor = 'Kırmızı';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1024),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext builderContext) {
        return Container(
          height: 380,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text('Park Konumunu Seç', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 2, child: CupertinoPicker(itemExtent: 40, backgroundColor: Colors.transparent, onSelectedItemChanged: (i) => tempLetter = letters[i], children: letters.map((l) => Center(child: Text(l, style: const TextStyle(color: Colors.white, fontSize: 20)))).toList())),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: CupertinoPicker(itemExtent: 40, backgroundColor: Colors.transparent, onSelectedItemChanged: (i) => tempNumber = numbers[i], children: numbers.map((n) => Center(child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 20)))).toList())),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: CupertinoPicker(itemExtent: 40, backgroundColor: Colors.transparent, onSelectedItemChanged: (i) => tempColor = colors[i], children: colors.map((c) => Center(child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 20)))).toList())),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF39FF14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 5),
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() {
                      parkedLocation = '$tempLetter - $tempNumber\n$tempColor';
                    });
                    _startTimer();
                    await _determinePosition();
                  },
                  child: const Text('Konumu Kaydet', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParkedContent(Color currentColor) {
    Widget timerText = Text(_formattedTime, style: TextStyle(color: currentColor, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 2.0, fontFamily: 'monospace'));
    if (_remainingSeconds <= 900) timerText = FadeTransition(opacity: _blinkAnimation, child: timerText);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(parkedLocation!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5, height: 1.2)),
        const SizedBox(height: 12),
        timerText,
    ]);
  }

  Widget _buildUnparkedContent() {
    return const Text('PARK\nETTİM', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 2.0, height: 1.2, shadows: [Shadow(offset: Offset(1.0, 1.0), blurRadius: 3.0, color: Colors.black45)]));
  }

  @override
  Widget build(BuildContext context) {
    bool isParked = parkedLocation != null;
    Color currentColor = _currentColor;

    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Screenshot(
                    controller: _screenshotController,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      color: const Color(0xFF070B19),
                      child: GestureDetector(
                        onTap: isParked ? null : _showLocationPicker,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isParked)
                              SizedBox(width: 250, height: 250, child: CircularProgressIndicator(value: _remainingSeconds / _totalSeconds, strokeWidth: 4, color: currentColor, backgroundColor: Colors.white.withOpacity(0.05))),
                            Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: isParked ? const Color(0xFF0A1024) : const Color(0xFF39FF14), boxShadow: [BoxShadow(color: currentColor.withOpacity(0.5), blurRadius: isParked ? 20 : 40, spreadRadius: isParked ? 2 : 10), const BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5))]), child: Center(child: isParked ? _buildParkedContent(currentColor) : _buildUnparkedContent())),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isParked) ...[
                    const SizedBox(height: 30),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: GestureDetector(onTap: _shareParkingInfo, child: Container(height: 60, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF39FF14), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF39FF14).withOpacity(0.4), blurRadius: 20, spreadRadius: 2)]), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.location_on, color: Colors.black, size: 28), SizedBox(width: 12), Text("Konumu ve Yer Bilgisini Paylaş", style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5))])))),
                    const SizedBox(height: 20),
                  ]
                ],
              ),
            ),
          ),
          if (isParked) Positioned(top: 10, right: 20, child: Container(decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle), child: IconButton(iconSize: 28, icon: const Icon(Icons.delete_outline, color: Colors.white70), tooltip: 'Parkı Temizle', onPressed: _resetParking))),
        ],
      ),
    );
  }
}

// 2. SEKME VE 3. SEKME MODELLERİ (AYNI KALDI)
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({Key? key}) : super(key: key);
  @override State<ReceiptScreen> createState() => _ReceiptScreenState();
}
class _ReceiptScreenState extends State<ReceiptScreen> {
  String? _imagePath; String? _entryTime;
  @override void initState() { super.initState(); _loadSavedData(); }
  Future<void> _loadSavedData() async { final prefs = await SharedPreferences.getInstance(); setState(() { _imagePath = prefs.getString('receipt_image_path'); _entryTime = prefs.getString('receipt_entry_time'); }); }
  Future<void> _takePicture() async { final picker = ImagePicker(); final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 80); if (pickedFile != null) { final now = DateTime.now(); final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'; final prefs = await SharedPreferences.getInstance(); await prefs.setString('receipt_image_path', pickedFile.path); await prefs.setString('receipt_entry_time', formattedTime); setState(() { _imagePath = pickedFile.path; _entryTime = formattedTime; }); } }
  void _clearReceipt() async { final prefs = await SharedPreferences.getInstance(); await prefs.remove('receipt_image_path'); await prefs.remove('receipt_entry_time'); setState(() { _imagePath = null; _entryTime = null; }); }
  @override Widget build(BuildContext context) { bool hasReceipt = _imagePath != null; return SafeArea(child: Center(child: hasReceipt ? _buildDigitalReceipt() : _buildPlaceholder())); }
  Widget _buildPlaceholder() { return GestureDetector(onTap: _takePicture, child: Container(width: 280, height: 380, decoration: BoxDecoration(color: const Color(0xFF0A1024), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF39FF14).withOpacity(0.5), width: 2), boxShadow: [BoxShadow(color: const Color(0xFF39FF14).withOpacity(0.1), blurRadius: 40, spreadRadius: 5)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.document_scanner_outlined, size: 80, color: Color(0xFF39FF14)), SizedBox(height: 20), Text('FİŞİ TARA', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2.0)), SizedBox(height: 12), Text('Kamerayı açmak için dokunun\n(Fişin fotoğrafını kalıcı saklar)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4))]))); }
  Widget _buildDigitalReceipt() { return Stack(children: [Center(child: Container(width: 320, height: 520, decoration: BoxDecoration(color: const Color(0xFF0A1024), borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: const Color(0xFF39FF14).withOpacity(0.3), blurRadius: 40, spreadRadius: 5), BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))], border: Border.all(color: const Color(0xFF39FF14), width: 1.5)), child: Column(children: [Container(padding: const EdgeInsets.symmetric(vertical: 18), decoration: const BoxDecoration(color: Color(0xFF39FF14), borderRadius: BorderRadius.only(topLeft: Radius.circular(23.5), topRight: Radius.circular(23.5))), width: double.infinity, child: const Text('DİJİTAL FİŞ KASASI', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2.0))), const SizedBox(height: 20), Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white24, width: 2), image: DecorationImage(image: FileImage(File(_imagePath!)), fit: BoxFit.cover))))), const SizedBox(height: 20), Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20), margin: const EdgeInsets.symmetric(horizontal: 20), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF39FF14).withOpacity(0.3))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.access_time_filled, color: Color(0xFF39FF14), size: 24), const SizedBox(width: 10), Text('Giriş Saati: ${_entryTime ?? "..."}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontFamily: 'monospace'))])), const SizedBox(height: 20), Padding(padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20), child: SizedBox(width: double.infinity, height: 55, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _takePicture, icon: const Icon(Icons.camera_alt, color: Colors.white), label: const Text('YENİ FİŞ TARA', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)))))]))), Positioned(top: 10, right: 20, child: Container(decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle), child: IconButton(iconSize: 28, icon: const Icon(Icons.delete_outline, color: Colors.white70), tooltip: 'Fişi Temizle', onPressed: _clearReceipt)))]); }
}

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({Key? key}) : super(key: key);
  @override State<BudgetScreen> createState() => _BudgetScreenState();
}
class _BudgetScreenState extends State<BudgetScreen> {
  final TextEditingController _amountController = TextEditingController(); final TextEditingController _locationController = TextEditingController(); List<ExpenseItem> _expenses = [];
  @override void initState() { super.initState(); _loadExpenses(); }
  @override void dispose() { _amountController.dispose(); _locationController.dispose(); super.dispose(); }
  Future<void> _loadExpenses() async { final prefs = await SharedPreferences.getInstance(); final String? expensesJson = prefs.getString('budget_expenses'); if (expensesJson != null) { final List<dynamic> decodedList = jsonDecode(expensesJson); setState(() { _expenses = decodedList.map((item) => ExpenseItem.fromJson(item)).toList(); }); } }
  Future<void> _saveExpenses() async { final prefs = await SharedPreferences.getInstance(); final String encodedList = jsonEncode(_expenses.map((e) => e.toJson()).toList()); await prefs.setString('budget_expenses', encodedList); }
  void _addExpense() { if (_amountController.text.isEmpty) return; final double? amount = double.tryParse(_amountController.text); if (amount == null || amount <= 0) return; final now = DateTime.now(); final formattedDate = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'; final location = _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : 'Bilinmeyen Otopark'; final newItem = ExpenseItem(id: DateTime.now().millisecondsSinceEpoch.toString(), date: formattedDate, location: location, amount: amount); setState(() { _expenses.insert(0, newItem); }); _saveExpenses(); _amountController.clear(); _locationController.clear(); FocusScope.of(context).unfocus(); }
  void _deleteExpense(String id) { setState(() { _expenses.removeWhere((item) => item.id == id); }); _saveExpenses(); }
  double get _totalExpense => _expenses.fold(0, (sum, item) => sum + item.amount); double get _savedAmount => _totalExpense * 0.35;
  @override Widget build(BuildContext context) { return SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Column(children: [Container(decoration: BoxDecoration(color: const Color(0xFF0A1024), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF39FF14).withOpacity(0.4), width: 1.5), boxShadow: [BoxShadow(color: const Color(0xFF39FF14).withOpacity(0.1), blurRadius: 10, spreadRadius: 2)]), padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(flex: 4, child: TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: 'Tutar (TL)', hintStyle: const TextStyle(color: Colors.white30), prefixIcon: const Icon(Icons.currency_lira, color: Color(0xFF39FF14)), filled: true, fillColor: Colors.white10, contentPadding: const EdgeInsets.symmetric(vertical: 0), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF39FF14), width: 1.5))))), const SizedBox(width: 10), Expanded(flex: 5, child: TextField(controller: _locationController, style: const TextStyle(color: Colors.white, fontSize: 16), decoration: InputDecoration(hintText: 'Mekan (Örn: AVM)', hintStyle: const TextStyle(color: Colors.white30), prefixIcon: const Icon(Icons.place_outlined, color: Colors.white54), filled: true, fillColor: Colors.white10, contentPadding: const EdgeInsets.symmetric(vertical: 0), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF39FF14), width: 1.5)))))]), const SizedBox(height: 15), SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF39FF14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 3), onPressed: _addExpense, icon: const Icon(Icons.add_circle, color: Colors.black), label: const Text('HARCAMAYI EKLE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.0))))])), const SizedBox(height: 25), Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 25), decoration: BoxDecoration(color: const Color(0xFF0A1024), borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: const Color(0xFF39FF14).withOpacity(0.15), blurRadius: 30, spreadRadius: 2)], border: Border.all(color: Colors.white10), gradient: RadialGradient(colors: [const Color(0xFF39FF14).withOpacity(0.1), const Color(0xFF0A1024)], radius: 2.0)), child: Column(children: [const Text('BU AY OTOPARK HARCAMAM', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0)), const SizedBox(height: 10), Text('${_totalExpense.toStringAsFixed(0)} ₺', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'monospace', shadows: [Shadow(color: Color(0xFF39FF14), blurRadius: 15.0)])), const SizedBox(height: 15), Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF39FF14).withOpacity(0.5))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.shield_outlined, color: Color(0xFF39FF14), size: 20), const SizedBox(width: 8), Text('ParkCepte Sayesinde Kurtarılan: ${_savedAmount.toStringAsFixed(0)} ₺', style: const TextStyle(color: Color(0xFF39FF14), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5))]))])), const SizedBox(height: 25), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('SON İŞLEMLER', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)), Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(6, (index) { final heights = [10.0, 22.0, 15.0, 32.0, 18.0, 26.0]; bool isHighest = index == 3; return Container(margin: const EdgeInsets.only(left: 4), width: 5, height: heights[index], decoration: BoxDecoration(color: isHighest ? Colors.redAccent : const Color(0xFF39FF14), borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: isHighest ? Colors.redAccent.withOpacity(0.6) : const Color(0xFF39FF14).withOpacity(0.4), blurRadius: 5, spreadRadius: 1)])); }))]), const SizedBox(height: 12), Expanded(child: _expenses.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.inventory_2_outlined, size: 50, color: Colors.white24), SizedBox(height: 10), Text('Henüz bir harcama eklenmedi.', style: TextStyle(color: Colors.white30, fontSize: 16))])) : ListView.builder(itemCount: _expenses.length, physics: const BouncingScrollPhysics(), itemBuilder: (context, index) { final item = _expenses[index]; return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xFF0A1024), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white12)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle), child: const Icon(Icons.local_parking, color: Color(0xFF39FF14))), title: Text(item.location, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(item.date, style: const TextStyle(color: Colors.white54, fontSize: 13, fontFamily: 'monospace'))), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('-${item.amount.toStringAsFixed(0)} ₺', style: const TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white30, size: 22), onPressed: () => _deleteExpense(item.id))]))); }))],))); }
}
