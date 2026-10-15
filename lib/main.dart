import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProductFinderApp());
}

const Color kBg = Color(0xFF080D19);
const Color kPanel = Color(0xFF111A2B);
const Color kPanel2 = Color(0xFF172238);
const Color kAccent = Color(0xFF9B8CFF);
const Color kAccent2 = Color(0xFF4DD8C5);
const Color kMuted = Color(0xFF9BA9C4);
const List<String> kModels = <String>[
  'gemini-3.8-flash',
  'gemini-4-argon',
  'gemini-3.6-flash',
  'gemini-3.5-flash-lite',
  'gemini-2.5-flash',
  'gemini-2.5-pro',
];

class ProductFinderApp extends StatelessWidget {
  const ProductFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MANGO Lens | كاشف المنتجات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          brightness: Brightness.dark,
          surface: kPanel,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kPanel2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          labelStyle: const TextStyle(color: kMuted),
          hintStyle: const TextStyle(color: Color(0xFF74819A)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF27334C)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kAccent, width: 1.4),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF26334B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: ProductFinderHome(),
      ),
    );
  }
}

class ProductFinderHome extends StatefulWidget {
  const ProductFinderHome({super.key});

  @override
  State<ProductFinderHome> createState() => _ProductFinderHomeState();
}

class _ProductFinderHomeState extends State<ProductFinderHome> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _extraController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController(text: 'gemini-3.8-flash');
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _resultKey = GlobalKey();

  File? _image;
  String _apiKey = '';
  String _model = 'gemini-3.8-flash';
  String _result = '';
  String _market = 'مصر';
  String _condition = 'غير محددة';
  String _category = 'تلقائي';
  String _detailLevel = 'تفصيلي';
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _extraController.dispose();
    _keyController.dispose();
    _modelController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> history = <Map<String, dynamic>>[];
    try {
      final raw = prefs.getString('product_history_v2');
      if (raw != null) {
        history = (jsonDecode(raw) as List<dynamic>)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {
      history = <Map<String, dynamic>>[];
    }
    if (!mounted) return;
    setState(() {
      _apiKey = prefs.getString('gemini_api_key') ?? '';
      _model = prefs.getString('gemini_model') ?? 'gemini-3.8-flash';
      _modelController.text = _model;
      _market = prefs.getString('product_market') ?? 'مصر';
      _condition = prefs.getString('product_condition') ?? 'غير محددة';
      _category = prefs.getString('product_category') ?? 'تلقائي';
      _detailLevel = prefs.getString('product_detail') ?? 'تفصيلي';
      _history = history;
    });
  }

  Future<void> _settings() async {
    _keyController.text = _apiKey;
    _modelController.text = _model;
    bool showKey = false;
    String chosenModel = kModels.contains(_model) ? _model : 'أدخل اسمًا مخصصًا';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refreshDialog) => AlertDialog(
          backgroundColor: kPanel,
          title: const Row(children: [
            Icon(Icons.tune_rounded, color: kAccent),
            SizedBox(width: 10),
            Expanded(child: Text('إعدادات الذكاء الاصطناعي')),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('اربط التطبيق بمفتاح Gemini API الخاص بك.', style: TextStyle(color: kMuted, height: 1.5)),
              const SizedBox(height: 16),
              TextField(
                controller: _keyController,
                obscureText: !showKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Gemini API Key',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    tooltip: showKey ? 'إخفاء المفتاح' : 'إظهار المفتاح',
                    onPressed: () => refreshDialog(() => showKey = !showKey),
                    icon: Icon(showKey ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: chosenModel,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'نموذج جاهز'),
                items: <String>[...kModels, 'أدخل اسمًا مخصصًا'].map((m) => DropdownMenuItem<String>(value: m, child: Text(m))).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  refreshDialog(() {
                    chosenModel = value;
                    if (value != 'أدخل اسمًا مخصصًا') _modelController.text = value;
                    else _modelController.clear();
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modelController,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'اسم النموذج المستخدم فعليًا',
                  hintText: 'gemini-3.8-flash',
                  prefixIcon: Icon(Icons.memory_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF202A41), borderRadius: BorderRadius.circular(14)),
                child: const Text(
                  'أنشئ المفتاح من Google AI Studio. لا تشارك مفتاحك مع أحد. التخزين داخل التطبيق مناسب للتجربة الشخصية فقط؛ تطبيق منشور للعامة يحتاج خادمًا يحمي المفتاح.',
                  style: TextStyle(color: kMuted, fontSize: 12, height: 1.6),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _openUrl('https://aistudio.google.com/apikey'),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('فتح Google AI Studio'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.save_outlined), label: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final key = _keyController.text.trim();
    final model = _modelController.text.trim().replaceAll('models/', '');
    if (model.isEmpty) {
      _message('اكتب اسم النموذج أولًا');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
    await prefs.setString('gemini_model', model);
    if (!mounted) return;
    setState(() {
      _apiKey = key;
      _model = model;
    });
    _message('تم حفظ الإعدادات');
  }

  Future<void> _chooseImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (picked == null) return;
      setState(() {
        _image = File(picked.path);
        _result = '';
        _error = null;
      });
    } catch (_) {
      _message('تعذر فتح الكاميرا أو الصور. تأكد من أذونات الجهاز ثم حاول مرة أخرى.');
    }
  }

  void _imageOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kPanel,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(children: [
            const ListTile(title: Text('اختر صورة المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF29264D), child: Icon(Icons.camera_alt_rounded, color: kAccent)),
              title: const Text('التقاط صورة بالكاميرا'),
              subtitle: const Text('صوّر المنتج والملصق بوضوح'),
              onTap: () { Navigator.pop(ctx); _chooseImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF163D3A), child: Icon(Icons.photo_library_outlined, color: kAccent2)),
              title: const Text('اختيار صورة من المعرض'),
              subtitle: const Text('يمكن اختيار صورة ملتقطة سابقًا'),
              onTap: () { Navigator.pop(ctx); _chooseImage(ImageSource.gallery); },
            ),
          ]),
        ),
      ),
    );
  }

  String _mimeFor(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _makePrompt(String extra) {
    final detail = _detailLevel == 'سريع'
        ? 'اكتب تقريرًا متوسط الطول يركز على التعرف والسعر وأفضل روابط الشراء والتحذيرات الأساسية.'
        : 'اكتب تقريرًا عميقًا منظمًا، غنيًا بالمعلومات، مع أقسام واضحة وجداول Markdown عند فائدتها.';
    return '''أنت مساعد متخصص في التعرف على المنتجات وتحليلها والبحث عن عروض حقيقية على الويب. حلل صورة المنتج المرفقة واستعمل بحث Google المتاح لك للمعلومات الحديثة. أجب بالعربية الواضحة، ولا تملأ أي فراغ بمعلومات مختلقة.

سوق الشراء المستهدف: $_market.
حالة المنتج التي يريد المستخدم المقارنة على أساسها: $_condition.
التصنيف المفضل: $_category.
${extra.isNotEmpty ? 'تفاصيل إضافية من المستخدم: $extra' : ''}

$detail

قسّم الإجابة بهذه الأقسام:
## 1. تحديد هوية المنتج
الاسم المرجح، العلامة التجارية، الطراز أو رقم القطعة إن أمكن، وما الذي في الصورة يدعم هذا التعرف. أعط درجة ثقة تقريبية واطلب صورة إضافية إذا لم تكفِ الصورة.
## 2. وصف ومواصفات
الغرض والاستخدام، المواصفات التي أمكن التحقق منها، الخامات/المكونات، المقاس أو السعة إن أمكن، الشركة المصنعة وبلد المنشأ وبلد التصنيع عند توفر دليل. ميّز الحقائق من التقديرات.
## 3. الأسعار والعروض
أقل سعر موثوق وجدته في سوق $_market، ومتوسط/نطاق الأسعار إن توفرت عدة عروض، والعملة، وحالة كل عرض (جديد أو مستعمل أو مجدد)، وتاريخ التحقق. اذكر هل السعر يشمل الشحن والضرائب إن كان ذلك معروفًا. لا تخلط بين سعر دولي وسعر السوق المستهدف، ولا تخترع سعرًا أو سعر صرف.
## 4. روابط الشراء والمقارنة
اعرض روابط مباشرة موثوقة قدر الإمكان، واسم المتجر والسعر والحالة بجوار كل رابط. وضّح إن كان الرابط صفحة منتج مؤكدة أم نتيجة بحث عامة، ولا تنشئ روابط وهمية.
## 5. الندرة والقيمة لهواة الاقتناء
هل المنتج شائع أو قديم أو إصدار محدود أو نادر؟ استخدم أدلة مثل تاريخ الإصدار، أرقام الإنتاج أو توافر عروض فعلية. إذا لم توجد أدلة كافية فاكتب أن الندرة غير مؤكدة. لا تستنتج الندرة من غرابة الشكل وحدها.
## 6. الأصالة والحالة
علامات أو أرقام يمكن فحصها، وما الذي لا يمكن إثباته من صورة واحدة. لا تؤكد الأصالة نهائيًا من الصورة وحدها. اذكر التلف الظاهر فقط إذا أمكن رؤيته.
## 7. نصائح قبل الشراء
ما المعلومات أو الصور الإضافية التي ينبغي طلبها، وأبرز مخاطر التقليد أو اختلاف النسخ، وهل يمكن الحكم أن السعر مناسب بناءً على مصادر متاحة.
## 8. خلاصة سريعة
لخص الاسم المرجح، أدنى سعر موثوق وجدته أو صرّح بعدم توفره، درجة الثقة، وخطوة التحقق التالية.

قواعد دقة إلزامية:
- استخدم نتائج البحث الفعلية واستشهد بالمصادر أو روابطها.
- لا تقل إنك فحصت المخزون أو السعر في وقت محدد إلا إذا أظهرت النتائج ذلك فعلًا.
- أظهر تاريخ الفحص بأنه وقت إنشاء هذا التقرير، وليس ضمانًا لبقاء السعر.
- افصل بوضوح بين المعلومة المؤكدة والتقدير.
- إذا لم تتعرف على المنتج، اقترح ما يجب تصويره أو رقم الملصق المطلوب.
''';
  }

  List<Map<String, String>> _groundingSources(Map<String, dynamic> data) {
    final sources = <Map<String, String>>[];
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty || candidates.first is! Map) return sources;
    final candidate = Map<String, dynamic>.from(candidates.first as Map);
    final meta = candidate['groundingMetadata'];
    if (meta is! Map) return sources;
    final chunks = meta['groundingChunks'];
    if (chunks is! List) return sources;
    final seen = <String>{};
    for (final item in chunks) {
      if (item is! Map) continue;
      final web = item['web'];
      if (web is! Map) continue;
      final uri = web['uri']?.toString() ?? '';
      final title = web['title']?.toString().trim() ?? '';
      final parsed = Uri.tryParse(uri);
      if (parsed == null || (parsed.scheme != 'https' && parsed.scheme != 'http') || !seen.add(uri)) continue;
      sources.add(<String, String>{'title': title.isEmpty ? parsed.host : title, 'url': uri});
    }
    return sources;
  }

  Future<void> _analyze() async {
    if (_image == null) {
      _message('صوّر المنتج أو اختر صورة أولًا');
      return;
    }
    if (_apiKey.isEmpty) {
      _message('أضف مفتاح Gemini API من الإعدادات أولًا');
      await _settings();
      return;
    }
    setState(() { _busy = true; _error = null; _result = ''; });
    try {
      final bytes = await _image!.readAsBytes();
      final prompt = _makePrompt(_extraController.text.trim());
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${Uri.encodeComponent(_model)}:generateContent');
      final response = await http.post(
        uri,
        headers: <String, String>{'Content-Type': 'application/json', 'x-goog-api-key': _apiKey},
        body: jsonEncode(<String, dynamic>{
          'contents': <dynamic>[{'parts': <dynamic>[{'text': prompt}, {'inline_data': {'mime_type': _mimeFor(_image!.path), 'data': base64Encode(bytes)}}]}],
          'tools': <dynamic>[{'google_search': <String, dynamic>{}}],
          'generationConfig': <String, dynamic>{
            'temperature': _detailLevel == 'سريع' ? 0.25 : 0.35,
            'maxOutputTokens': _detailLevel == 'سريع' ? 5000 : 9000,
          },
        }),
      ).timeout(const Duration(seconds: 150));

      Map<String, dynamic> data;
      try {
        data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      } catch (_) {
        throw Exception('وصل رد غير مفهوم من الخدمة. حاول مرة أخرى بعد قليل.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorObject = data['error'];
        final apiMessage = errorObject is Map ? (errorObject['message']?.toString() ?? 'خطأ غير معروف') : 'خطأ غير معروف';
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw Exception('مفتاح API غير صحيح أو غير مسموح له باستخدام هذا النموذج. راجع المفتاح واسم النموذج.');
        }
        if (response.statusCode == 429) {
          throw Exception('تم تجاوز حد الطلبات أو الحصة المتاحة. انتظر قليلًا وتحقق من حدود استخدام Gemini.');
        }
        if (response.statusCode == 404) {
          throw Exception('لم يتم العثور على النموذج "$_model". تحقق من اسم النموذج في الإعدادات.');
        }
        throw Exception('خطأ Gemini (${response.statusCode}): $apiMessage');
      }

      final candidates = data['candidates'];
      if (candidates is! List || candidates.isEmpty || candidates.first is! Map) {
        final feedback = data['promptFeedback'];
        if (feedback is Map && feedback['blockReason'] != null) {
          throw Exception('لم تتم معالجة الطلب بسبب قيود السلامة: ${feedback['blockReason']}');
        }
        throw Exception('لم يرجع النموذج تقريرًا. جرّب صورة أوضح أو نموذجًا آخر.');
      }
      final candidate = Map<String, dynamic>.from(candidates.first as Map);
      final content = candidate['content'];
      final parts = content is Map ? content['parts'] : null;
      final report = parts is List
          ? parts.whereType<Map>().map((p) => p['text']?.toString() ?? '').where((s) => s.isNotEmpty).join('\n\n').trim()
          : '';
      if (report.isEmpty) throw Exception('التقرير فارغ. قد يكون النموذج قد أنهى الطلب دون نص؛ جرّب مرة أخرى.');

      final sources = _groundingSources(data);
      final output = StringBuffer(report);
      if (sources.isNotEmpty) {
        output.write('\n\n## مصادر البحث التي أعادها Google\n');
        for (final source in sources.take(10)) {
          output.write('\n- [${source['title']}](${source['url']})');
        }
      }
      final finalReport = output.toString();
      if (!mounted) return;
      setState(() => _result = finalReport);
      await _saveHistory(finalReport);
      HapticFeedback.mediumImpact();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_resultKey.currentContext != null) {
          Scrollable.ensureVisible(_resultKey.currentContext!, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic, alignment: 0.04);
        }
      });
    } on SocketException {
      if (mounted) setState(() => _error = 'لا يوجد اتصال بالإنترنت. تحقق من الشبكة وحاول مجددًا.');
    } on HttpException {
      if (mounted) setState(() => _error = 'حدثت مشكلة أثناء الاتصال بخدمة البحث. حاول مرة أخرى.');
    } on FormatException {
      if (mounted) setState(() => _error = 'وصل رد غير مفهوم من الخدمة. حاول مرة أخرى.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _titleFromReport(String report) {
    for (final line in report.split('\n')) {
      final cleaned = line.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s*'), '').replaceAll('*', '').trim();
      if (cleaned.isNotEmpty && !cleaned.startsWith('[') && !cleaned.startsWith('- ')) {
        return cleaned.length > 72 ? '${cleaned.substring(0, 69)}…' : cleaned;
      }
    }
    return 'تحليل منتج';
  }

  Future<void> _saveHistory(String report) async {
    final entry = <String, dynamic>{
      'title': _titleFromReport(report),
      'report': report,
      'createdAt': DateTime.now().toIso8601String(),
      'market': _market,
      'model': _model,
    };
    final next = <Map<String, dynamic>>[entry, ..._history].take(25).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('product_history_v2', jsonEncode(next));
    if (!mounted) return;
    setState(() => _history = next);
  }

  Future<void> _openHistory() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPanel,
        title: Row(children: [
          const Expanded(child: Text('سجل عمليات الفحص')),
          if (_history.isNotEmpty)
            IconButton(tooltip: 'مسح السجل', onPressed: () async {
              final confirm = await showDialog<bool>(
                context: ctx,
                builder: (confirmCtx) => AlertDialog(
                  backgroundColor: kPanel2,
                  title: const Text('مسح سجل الفحص؟'),
                  content: const Text('سيتم حذف التقارير المحفوظة محليًا من هذا الجهاز.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(confirmCtx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(confirmCtx, true), child: const Text('مسح'))],
                ),
              );
              if (confirm == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('product_history_v2');
                if (mounted) setState(() => _history = <Map<String, dynamic>>[]);
                if (ctx.mounted) Navigator.pop(ctx);
                _message('تم مسح السجل');
              }
            }, icon: const Icon(Icons.delete_sweep_outlined)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: _history.isEmpty
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.history_rounded, size: 48, color: kMuted), SizedBox(height: 12), Text('لا توجد تقارير محفوظة حتى الآن'), SizedBox(height: 6), Text('بعد تحليل أول منتج سيظهر تقريرك هنا.', style: TextStyle(color: kMuted, fontSize: 12))]))
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 430),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _history.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFF27334C)),
                    itemBuilder: (ctx, index) {
                      final item = _history[index];
                      final date = DateTime.tryParse(item['createdAt']?.toString() ?? '')?.toLocal();
                      final dateLabel = date == null ? '' : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(backgroundColor: Color(0xFF29264D), child: Icon(Icons.document_scanner_outlined, color: kAccent)),
                        title: Text(item['title']?.toString() ?? 'تحليل منتج', maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${item['market'] ?? 'السوق غير محدد'}${dateLabel.isEmpty ? '' : ' • $dateLabel'}', style: const TextStyle(color: kMuted, fontSize: 11)),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _result = item['report']?.toString() ?? '');
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_resultKey.currentContext != null) Scrollable.ensureVisible(_resultKey.currentContext!, duration: const Duration(milliseconds: 400), alignment: 0.05);
                          });
                        },
                      );
                    },
                  ),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      try {
        final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!opened) _message('تعذر فتح الرابط على هذا الجهاز');
      } catch (_) {
        _message('تعذر فتح الرابط');
      }
    } else {
      _message('الرابط غير صالح');
    }
  }

  Future<void> _saveChoice(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF29264D), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: kAccent)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: kMuted, fontSize: 12, height: 1.45)),
        ])),
      ]),
    );
  }

  Widget _dropdown({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged, IconData? icon}) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon, size: 19)),
      items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _featurePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(50), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: kAccent2), const SizedBox(width: 6), Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFFD8E0F4)))],),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [kAccent, Color(0xFF665BE8)]), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.center_focus_strong_rounded, color: Colors.white)),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('MANGO LENS', style: TextStyle(fontSize: 16, letterSpacing: 1.1, fontWeight: FontWeight.w900)), Text('كاشف المنتجات الذكي', style: TextStyle(fontSize: 11, color: kMuted, fontWeight: FontWeight.normal))])),
        ]),
        actions: [
          IconButton(tooltip: 'سجل الفحص', onPressed: _openHistory, icon: Badge(isLabelVisible: _history.isNotEmpty, label: Text('${_history.length}'), child: const Icon(Icons.history_rounded))),
          IconButton(tooltip: 'الإعدادات', onPressed: _settings, icon: const Icon(Icons.settings_outlined)),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF29245C), Color(0xFF152D42), Color(0xFF102D33)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF514B8C).withValues(alpha: 0.55)),
                boxShadow: const [BoxShadow(color: Color(0x20211A63), blurRadius: 24, offset: Offset(0, 10))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: kAccent2.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(40)), child: const Row(children: [Icon(Icons.auto_awesome, size: 13, color: kAccent2), SizedBox(width: 5), Text('AI PRODUCT INTELLIGENCE', style: TextStyle(fontSize: 9, letterSpacing: 0.7, fontWeight: FontWeight.bold, color: kAccent2))])),
                  const Spacer(),
                  const Icon(Icons.radar_rounded, size: 27, color: Color(0xFFB8B0FF)),
                ]),
                const SizedBox(height: 17),
                const Text('كل تفاصيل المنتج،\nفي صورة واحدة.', style: TextStyle(fontSize: 29, height: 1.18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 10),
                const Text('تعرّف على المنتج، قارن الأسعار، اكتشف المواصفات، وافحص مؤشرات الندرة من خلال تحليل الصورة والبحث على الويب.', style: TextStyle(color: Color(0xFFD0D8EA), height: 1.65, fontSize: 13)),
                const SizedBox(height: 17),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  _featurePill(Icons.price_check_rounded, 'مقارنة أسعار'),
                  _featurePill(Icons.travel_explore_rounded, 'بحث ويب'),
                  _featurePill(Icons.verified_outlined, 'فحص مؤشرات الأصالة'),
                  _featurePill(Icons.inventory_2_outlined, 'تقدير الندرة'),
                ]),
              ]),
            ),
            const SizedBox(height: 24),
            _sectionTitle('1. صوّر أو ارفع المنتج', 'صورة واضحة للمنتج والملصق أو رقم الموديل تعطي نتيجة أدق.', Icons.add_a_photo_outlined),
            InkWell(
              onTap: _imageOptions,
              borderRadius: BorderRadius.circular(22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: _image == null ? 212 : 275,
                decoration: BoxDecoration(
                  color: kPanel,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _image == null ? const Color(0xFF34415E) : kAccent, width: 1.3),
                ),
                child: _image == null
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 66, height: 66, decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.add_a_photo_rounded, size: 32, color: kAccent)),
                        const SizedBox(height: 14),
                        const Text('اضغط لاختيار صورة المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        const Text('الكاميرا أو معرض الصور • JPG / PNG / WebP', style: TextStyle(color: kMuted, fontSize: 11)),
                      ])
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: Stack(fit: StackFit.expand, children: [
                          GestureDetector(onTap: () => showDialog<void>(context: context, builder: (_) => Dialog(backgroundColor: Colors.black, insetPadding: const EdgeInsets.all(12), child: InteractiveViewer(child: Image.file(_image!, fit: BoxFit.contain)))), child: Image.file(_image!, fit: BoxFit.contain)),
                          Positioned(top: 10, left: 10, child: IconButton.filled(onPressed: () => setState(() { _image = null; _result = ''; }), style: IconButton.styleFrom(backgroundColor: const Color(0xDD182237)), icon: const Icon(Icons.close_rounded), tooltip: 'إزالة الصورة')),
                          Positioned(right: 10, bottom: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: const Color(0xDD101827), borderRadius: BorderRadius.circular(30)), child: const Row(children: [Icon(Icons.zoom_in_rounded, size: 15, color: Colors.white), SizedBox(width: 4), Text('اضغط للتكبير', style: TextStyle(fontSize: 11))]))),
                        ]),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _chooseImage(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('الكاميرا'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(47), side: const BorderSide(color: Color(0xFF34415E)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _chooseImage(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('المعرض'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(47), side: const BorderSide(color: Color(0xFF34415E)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
            ]),
            const SizedBox(height: 24),
            _sectionTitle('2. خصّص البحث', 'اختَر السوق ونوع المنتج وعمق التقرير للحصول على نتائج أقرب لاحتياجك.', Icons.tune_rounded),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF202D45))),
              child: Column(children: [
                _dropdown(label: 'السوق المستهدف', value: _market, items: const ['مصر', 'السعودية', 'الإمارات', 'الكويت', 'قطر', 'الأردن', 'الولايات المتحدة', 'المملكة المتحدة', 'السوق العالمي'], icon: Icons.public_rounded, onChanged: (v) { if (v == null) return; setState(() => _market = v); _saveChoice('product_market', v); }),
                const SizedBox(height: 12),
                _dropdown(label: 'تصنيف المنتج', value: _category, items: const ['تلقائي', 'إلكترونيات', 'أجهزة منزلية', 'ملابس وأحذية', 'عطور ومستحضرات', 'ألعاب ومقتنيات', 'تحف وأنتيكات', 'كتب ومطبوعات', 'أدوات ومعدات', 'أخرى'], icon: Icons.category_outlined, onChanged: (v) { if (v == null) return; setState(() => _category = v); _saveChoice('product_category', v); }),
                const SizedBox(height: 12),
                _dropdown(label: 'حالة المنتج للمقارنة', value: _condition, items: const ['غير محددة', 'جديد', 'مستعمل', 'مجدد / Refurbished', 'قطعة لهواة الاقتناء'], icon: Icons.inventory_2_outlined, onChanged: (v) { if (v == null) return; setState(() => _condition = v); _saveChoice('product_condition', v); }),
                const SizedBox(height: 12),
                _dropdown(label: 'عمق التقرير', value: _detailLevel, items: const ['سريع', 'تفصيلي'], icon: Icons.subject_rounded, onChanged: (v) { if (v == null) return; setState(() => _detailLevel = v); _saveChoice('product_detail', v); }),
                const SizedBox(height: 12),
                TextField(
                  controller: _extraController,
                  maxLines: 3,
                  minLines: 2,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'معلومات إضافية (اختياري)',
                    hintText: 'مثال: أريد أقل سعر بالجنيه المصري، أو ابحث عن إصدار 2010، أو هذا المنتج مستعمل...',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(padding: EdgeInsets.only(bottom: 40), child: Icon(Icons.edit_note_rounded)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 19),
            FilledButton.icon(
              onPressed: _busy ? null : _analyze,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(59),
                backgroundColor: const Color(0xFF8173F2),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF38334E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                elevation: 0,
              ),
              icon: _busy ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded, size: 22),
              label: Text(_busy ? 'جاري تحليل الصورة والبحث على الويب…' : 'حلّل المنتج وابحث عن أفضل سعر', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            if (_busy) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(minHeight: 3, borderRadius: BorderRadius.all(Radius.circular(3)), color: kAccent2, backgroundColor: Color(0xFF1E2B40)),
              const SizedBox(height: 8),
              const Text('يقارن النموذج المعلومات المتاحة. قد يستغرق البحث بعض الوقت.', textAlign: TextAlign.center, style: TextStyle(color: kMuted, fontSize: 11)),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(_apiKey.isNotEmpty ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 18, color: _apiKey.isNotEmpty ? kAccent2 : const Color(0xFFFFC477)),
                const SizedBox(width: 8),
                Expanded(child: Text(_apiKey.isNotEmpty ? 'متصل بالإعدادات • $_model' : 'أضف مفتاح Gemini من الإعدادات لبدء التحليل', style: const TextStyle(color: kMuted, fontSize: 11))),
                if (_apiKey.isEmpty) TextButton(onPressed: _settings, child: const Text('إعداد')), 
              ]),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: const Color(0xFF3A202C), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF693044))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFFFABB9)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFFFD5DC), height: 1.55))),
                  IconButton(onPressed: () => setState(() => _error = null), icon: const Icon(Icons.close, size: 18), tooltip: 'إغلاق'),
                ]),
              ),
            ],
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 27),
              Container(
                key: _resultKey,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(23), border: Border.all(color: const Color(0xFF39466A)), boxShadow: const [BoxShadow(color: Color(0x17000000), blurRadius: 22, offset: Offset(0, 10))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: kAccent2.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.fact_check_rounded, color: kAccent2)),
                    const SizedBox(width: 10),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('تقرير المنتج', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('تم إنشاء التقرير بواسطة Gemini', style: TextStyle(color: kMuted, fontSize: 11))])),
                    IconButton(tooltip: 'نسخ التقرير', onPressed: () { Clipboard.setData(ClipboardData(text: _result)); _message('تم نسخ التقرير بالكامل'); }, icon: const Icon(Icons.copy_all_rounded)),
                  ]),
                  const SizedBox(height: 13),
                  const Divider(color: Color(0xFF2B3751)),
                  MarkdownBody(
                    data: _result,
                    selectable: true,
                    onTapLink: (text, href, title) { if (href != null) _openUrl(href); },
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 14, height: 1.78, color: Color(0xFFE4EAF7)),
                      h1: const TextStyle(fontSize: 22, height: 1.3, fontWeight: FontWeight.w900, color: Color(0xFFC2BBFF)),
                      h2: const TextStyle(fontSize: 18, height: 1.4, fontWeight: FontWeight.w800, color: Color(0xFFC2BBFF)),
                      h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF9FE9DE)),
                      a: const TextStyle(color: Color(0xFF87D6FF), decoration: TextDecoration.underline),
                      listBullet: const TextStyle(color: kAccent2),
                      blockquote: const TextStyle(color: kMuted, fontStyle: FontStyle.italic),
                      tableHead: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                      tableBody: const TextStyle(fontSize: 12, height: 1.5),
                      tableBorder: TableBorder.all(color: const Color(0xFF35415B), borderRadius: BorderRadius.circular(8)),
                      tableCellsPadding: const EdgeInsets.all(7),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF202A40), borderRadius: BorderRadius.circular(14)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.shield_outlined, color: kAccent2, size: 19), SizedBox(width: 9), Expanded(child: Text('الأسعار والمخزون قد يتغيران، وتقرير الذكاء الاصطناعي ليس إثباتًا للأصالة أو تقييمًا رسميًا. افتح رابط المتجر وتحقق من الحالة والشحن قبل الشراء.', style: TextStyle(color: kMuted, fontSize: 11, height: 1.6)))])),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: _result)); _message('تم نسخ التقرير'); }, icon: const Icon(Icons.content_copy_rounded, size: 18), label: const Text('نسخ التقرير'), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))))),
                    const SizedBox(width: 9),
                    Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => _result = ''), icon: const Icon(Icons.close_rounded, size: 18), label: const Text('إخفاء التقرير'), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))))),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 27),
            Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF111926), borderRadius: BorderRadius.circular(18)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.lock_outline_rounded, size: 19, color: kMuted), SizedBox(width: 10), Expanded(child: Text('صورك تُرسل إلى خدمة Gemini لتحليلها عند الضغط على زر الفحص. سجل التقارير محفوظ محليًا على جهازك. لا تحفظ بيانات حساسة في الصور، ولا تشارك مفتاح API.', style: TextStyle(color: kMuted, fontSize: 11, height: 1.6)))])),
            const SizedBox(height: 14),
            const Center(child: Text('MANGO LENS • Google Gemini Search Grounding', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF697691), fontSize: 10, letterSpacing: 0.3))),
          ],
        ),
      ),
    );
  }
}