import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const EromuKeresoApp());
}

class EromuKeresoApp extends StatelessWidget {
  const EromuKeresoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Erőmű - Szakaszolás segédlet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue[800]!,
        ),
        useMaterial3: true,
      ),
      home: const KeresoPanel(),
    );
  }
}

class BerendezesAdat {
  final String kod;
  final String megnevezes;
  final String helyszin;
  final String elosztoNev;
  final String leagazasJel;
  String elosztoHelye;
  final String feljegyzes;
  final int verzio;

  BerendezesAdat({
    required this.kod,
    required this.megnevezes,
    required this.helyszin,
    required this.elosztoNev,
    required this.leagazasJel,
    required this.elosztoHelye,
    required this.feljegyzes,
    required this.verzio,
  });

  factory BerendezesAdat.fromJson(Map<String, dynamic> json) {
    dynamic v = json['verzio'];
    int intVerzio = 0;
    if (v != null) {
      if (v is int) intVerzio = v;
      if (v is String) intVerzio = int.tryParse(v) ?? 0;
    }

    return BerendezesAdat(
      kod: json['kod'] ?? '',
      megnevezes: json['megnevezes'] ?? '',
      helyszin: json['helyszin'] ?? '',
      elosztoNev: json['elosztoNev'] ?? '',
      leagazasJel: json['leagazasJel'] ?? '',
      elosztoHelye: json['elosztoHelye'] ?? '',
      feljegyzes: json['feljegyzes'] ?? '',
      verzio: intVerzio,
    );
  }
}

enum NezetTipus { kereso, berendezesAdatlap, elosztoAdatlap }

class KeresoPanel extends StatefulWidget {
  const KeresoPanel({super.key});

  @override
  State<KeresoPanel> createState() => _KeresoPanelState();
}

class _KeresoPanelState extends State<KeresoPanel> {
  List<BerendezesAdat> _mindenAdat = [];
  List<BerendezesAdat> _szurtBerendezesLista = [];
  List<String> _szurtElosztoLista = [];

  BerendezesAdat? _kivalasztottBerendezes;
  String? _kivalasztottElosztoNev;
  String? _visszaElosztoNev;

  NezetTipus _aktualisNezet = NezetTipus.kereso;

  final _berendezesKeresoCtrl = TextEditingController();
  final _elosztoKeresoCtrl = TextEditingController();

  bool _isLoading = true;
  String _hibaUzenet = '';
  String _utolsoFrissites = 'Betöltés...';

  static const String _githubAssetsBase =
      'https://raw.githubusercontent.com/Akipapi27/eromu_app/main/assets/';

  @override
  void initState() {
    super.initState();
    _adatbazisBetoltese();
    _berendezesKeresoCtrl.addListener(_berendezesSzuresVegrehajtasa);
    _elosztoKeresoCtrl.addListener(_elosztoSzuresVegrehajtasa);
  }

  String _getCacheBuster() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  DateTime? _parseHttpDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
        final parts = dateStr.split(' ');
        if (parts.length >= 5) {
          final nap = parts[1];
          final honapNev = parts[2].toLowerCase();
          final ev = parts[3];
          final ido = parts[4];

          final honapok = {
            'jan': '01',
            'feb': '02',
            'mar': '03',
            'apr': '04',
            'may': '05',
            'jun': '06',
            'jul': '07',
            'aug': '08',
            'sep': '09',
            'oct': '10',
            'nov': '11',
            'dec': '12',
          };
          final honap = honapok[honapNev.substring(0, 3)] ?? '01';

          return DateTime.parse('$ev-$honap-${nap.padLeft(2, '0')}T${ido}Z');
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _adatbazisBetoltese() async {
    try {
      final alapUrl = Uri.base
          .resolve('assets/eromu_adatbazis.json')
          .toString();
      final urlKenszeritve = Uri.parse('$alapUrl?v=${_getCacheBuster()}');

      final response = await http.get(urlKenszeritve);

      if (response.statusCode != 200) {
        throw Exception('Szerver hiba: ${response.statusCode}');
      }

      if (response.headers['last-modified'] != null) {
        final parsedDate = _parseHttpDate(response.headers['last-modified']!);
        if (parsedDate != null) {
          final helyiIdo = parsedDate.toLocal();
          _utolsoFrissites =
              '${helyiIdo.year}. '
              '${helyiIdo.month.toString().padLeft(2, '0')}. '
              '${helyiIdo.day.toString().padLeft(2, '0')}. '
              '${helyiIdo.hour.toString().padLeft(2, '0')}:${helyiIdo.minute.toString().padLeft(2, '0')}';
        } else {
          _utolsoFrissites = 'Ismeretlen dátumformátum';
        }
      } else {
        _utolsoFrissites = 'Nem meghatározható';
      }

      final List<dynamic> jsonLista = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      final list = jsonLista
          .map((item) => BerendezesAdat.fromJson(item))
          .toList();

      Map<String, _ElosztoInfo> legfrissebbElosztok = {};
      for (var item in list) {
        final elosztoTiszta = item.elosztoNev.trim().toLowerCase();
        if (elosztoTiszta.isEmpty) continue;
        if (!legfrissebbElosztok.containsKey(elosztoTiszta)) {
          legfrissebbElosztok[elosztoTiszta] = _ElosztoInfo(
            item.elosztoHelye,
            item.verzio,
          );
        } else {
          if (item.verzio > legfrissebbElosztok[elosztoTiszta]!.verzio) {
            legfrissebbElosztok[elosztoTiszta] = _ElosztoInfo(
              item.elosztoHelye,
              item.verzio,
            );
          }
        }
      }

      for (var item in list) {
        final elosztoTiszta = item.elosztoNev.trim().toLowerCase();
        if (legfrissebbElosztok.containsKey(elosztoTiszta)) {
          item.elosztoHelye = legfrissebbElosztok[elosztoTiszta]!.hely;
        }
      }

      setState(() {
        _mindenAdat = list;
        _szurtBerendezesLista = [];
        _szurtElosztoLista = [];
        _isLoading = false;
        _hibaUzenet = '';
      });
    } catch (e) {
      setState(() {
        _hibaUzenet = 'Nem sikerült betölteni az adatbázist!\nHiba: $e';
        _isLoading = false;
      });
    }
  }

  void _berendezesSzuresVegrehajtasa() {
    final szo = _berendezesKeresoCtrl.text.trim().toLowerCase();
    if (szo.isEmpty) {
      setState(() {
        _szurtBerendezesLista = [];
      });
      return;
    }

    setState(() {
      _szurtBerendezesLista = _mindenAdat.where((item) {
        return item.kod.toLowerCase().contains(szo) ||
            item.megnevezes.toLowerCase().contains(szo);
      }).toList();
    });
  }

  void _elosztoSzuresVegrehajtasa() {
    final szo = _elosztoKeresoCtrl.text.trim().toLowerCase();
    if (szo.isEmpty) {
      setState(() {
        _szurtElosztoLista = [];
      });
      return;
    }

    final egyediElosztok = _mindenAdat
        .map((e) => e.elosztoNev.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    setState(() {
      _szurtElosztoLista = egyediElosztok.where((e) {
        return e.toLowerCase().contains(szo);
      }).toList();
      _szurtElosztoLista.sort();
    });
  }

  void _berendezesKivalasztasa(
    BerendezesAdat berendezes, {
    String? honnanEloszto,
  }) {
    setState(() {
      _kivalasztottBerendezes = berendezes;
      _visszaElosztoNev = honnanEloszto;
      _aktualisNezet = NezetTipus.berendezesAdatlap;
      _szurtBerendezesLista = [];
    });
  }

  void _elosztoKivalasztasa(String elosztoNev) {
    setState(() {
      _kivalasztottElosztoNev = elosztoNev;
      _aktualisNezet = NezetTipus.elosztoAdatlap;
      _szurtElosztoLista = [];
    });
  }

  void _visszaAKeresohoz() {
    setState(() {
      _kivalasztottBerendezes = null;
      _kivalasztottElosztoNev = null;
      _visszaElosztoNev = null;
      _aktualisNezet = NezetTipus.kereso;
      _berendezesKeresoCtrl.clear();
      _elosztoKeresoCtrl.clear();
      _szurtBerendezesLista = [];
      _szurtElosztoLista = [];
    });
  }

  // Összeállítja a lehetséges GitHub URL-ek listáját (alap + kis/nagybetűk + kiterjesztések + sorszámok)
  List<String> _osszesKigyujtottKepUrl(String alapNev) {
    if (alapNev.isEmpty) return [];
    final buster = _getCacheBuster();
    List<String> urlk = [];

    List<String> extensions = [
      'jpg',
      'JPG',
      'jpeg',
      'JPEG',
      'png',
      'PNG',
      'webp',
    ];
    List<String> names = [
      alapNev,
      alapNev.toUpperCase(),
      alapNev.toLowerCase(),
    ];

    for (var name in names) {
      for (var ext in extensions) {
        urlk.add('$_githubAssetsBase$name.$ext?v=$buster');
      }
    }

    for (int i = 1; i <= 5; i++) {
      for (var ext in extensions) {
        urlk.add('$_githubAssetsBase$alapNev-$i.$ext?v=$buster');
      }
    }

    return urlk;
  }

  void _galeriaInditasa(String alapNev, String cim) {
    final urlLista = _osszesKigyujtottKepUrl(alapNev);
    if (urlLista.isEmpty) {
      _nincsKepUzenet(context);
      return;
    }
    _galeriaMegnyitasa(urlLista, cim, alapNev);
  }

  void _galeriaMegnyitasa(
    List<String> kepurlEk,
    String cim,
    String egyediAzonosito,
  ) {
    int aktualisIndex = 0;
    final TransformationController transformCtrl = TransformationController();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Bezárás',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 10.0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              cim,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[800],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Variáció: ${aktualisIndex + 1} / ${kepurlEk.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4.0),
                            child: InteractiveViewer(
                              transformationController: transformCtrl,
                              clipBehavior: Clip.none,
                              minScale: 1.0,
                              maxScale: 10.0,
                              child: Image.network(
                                kepurlEk[aktualisIndex],
                                fit: BoxFit.contain,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(
                                      child: Text(
                                        'Nincs kép ezen a variáción.\nHasználd az alábbi Előre / Vissza gombokat!',
                                        style: TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 20.0,
                        left: 30,
                        right: 30,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: aktualisIndex > 0
                                ? () {
                                    setModalState(() {
                                      aktualisIndex--;
                                      transformCtrl.value = Matrix4.identity();
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.arrow_back, size: 16),
                            label: const Text('Előző variáció'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: aktualisIndex < kepurlEk.length - 1
                                ? () {
                                    setModalState(() {
                                      aktualisIndex++;
                                      transformCtrl.value = Matrix4.identity();
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: const Text('Következő variáció'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _nincsKepUzenet(BuildContext context) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nincs megadva azonosító a képkereséshez'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_hibaUzenet.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _hibaUzenet,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                    });
                    _adatbazisBetoltese();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Újrapróbálkozás'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Erőmű - Szakaszolás segédlet',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.blue[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _adatbazisBetoltese();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildBodyContent(),
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_aktualisNezet) {
      case NezetTipus.berendezesAdatlap:
        return _buildBerendezesAdatlapView();
      case NezetTipus.elosztoAdatlap:
        return _buildElosztoAdatlapView();
      case NezetTipus.kereso:
      default:
        return _buildKeresoView();
    }
  }

  Widget _buildKeresoView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.storage, size: 16, color: Colors.blue[900]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Az adatbázisban jelenleg összesen ${_mindenAdat.length} db berendezés található.',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.update, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Legutóbbi adatbázis-frissítés: $_utolsoFrissites',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 1. ELOSZTÓ KERESŐ MEZŐ
          Card(
            elevation: 2,
            color: Colors.amber[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.amber[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt, color: Colors.amber[900]),
                      const SizedBox(width: 8),
                      const Text(
                        'Keresés elosztó alapján:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _elosztoKeresoCtrl,
                    decoration: InputDecoration(
                      hintText: 'Gépeld be az elosztó nevét (pl. 3BA)...',
                      filled: true,
                      fillColor: Colors.white,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _elosztoKeresoCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _elosztoKeresoCtrl.clear(),
                            )
                          : null,
                    ),
                  ),
                  if (_szurtElosztoLista.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber[300]!),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _szurtElosztoLista.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final elosztoNev = _szurtElosztoLista[index];
                          final db = _mindenAdat
                              .where(
                                (e) =>
                                    e.elosztoNev.trim().toLowerCase() ==
                                    elosztoNev.toLowerCase(),
                              )
                              .length;
                          return ListTile(
                            leading: Icon(Icons.bolt, color: Colors.amber[900]),
                            title: Text(
                              elosztoNev,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('$db db leágazás található benne'),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                            ),
                            onTap: () => _elosztoKivalasztasa(elosztoNev),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 2. BERENDEZÉS KERESŐ MEZŐ
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.precision_manufacturing,
                        color: Colors.blue[900],
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Keresés berendezés / AK kód alapján:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _berendezesKeresoCtrl,
                    decoration: InputDecoration(
                      hintText:
                          'Gépeld be az AK kódot vagy a berendezés nevét...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _berendezesKeresoCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _berendezesKeresoCtrl.clear(),
                            )
                          : null,
                    ),
                  ),
                  if (_szurtBerendezesLista.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _szurtBerendezesLista.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _szurtBerendezesLista[index];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.kod,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ),
                            title: Text(
                              item.megnevezes,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text('Elosztó: ${item.elosztoNev}'),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                            ),
                            onTap: () => _berendezesKivalasztasa(item),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- BERENDEZÉS ADATLAP NÉZET ---
  Widget _buildBerendezesAdatlapView() {
    final item = _kivalasztottBerendezes!;
    final kodTiszta = item.kod.trim();
    final elosztoTiszta = item.elosztoNev.trim();
    final leagazasTiszta = item.leagazasJel.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KÉT FÉLE VISSZA GOMB
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_visszaElosztoNev != null)
              ElevatedButton.icon(
                onPressed: () => _elosztoKivalasztasa(_visszaElosztoNev!),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(
                  'Vissza a elosztóhoz [$_visszaElosztoNev]',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[100],
                  foregroundColor: Colors.amber[900],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _visszaAKeresohoz,
              icon: Icon(
                _visszaElosztoNev != null ? Icons.home : Icons.arrow_back,
                size: 18,
              ),
              label: Text(
                _visszaElosztoNev != null
                    ? 'Főoldal / Kereső'
                    : 'Vissza a keresőhöz',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            key: ValueKey('detail-card-${item.kod}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.kod,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _galeriaInditasa(
                        kodTiszta,
                        'Berendezés: ${item.megnevezes}',
                      ),
                      icon: Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Colors.blue[900],
                      ),
                      label: Text(
                        'Berendezés fotó',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.megnevezes,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fizikai helye: ${item.helyszin}',
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              InkWell(
                                onTap: () =>
                                    _elosztoKivalasztasa(item.elosztoNev),
                                child: Text(
                                  'Tápláló elosztó: ${item.elosztoNev} 🔗',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.blue[900],
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (item.leagazasJel.isNotEmpty)
                                InkWell(
                                  onTap: () => _galeriaInditasa(
                                    leagazasTiszta,
                                    'Leágazás: ${item.leagazasJel}',
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                      vertical: 2.0,
                                    ),
                                    child: Text(
                                      '[Leágazás: ${item.leagazasJel}]',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                        fontSize: 14,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Elosztó helye: ${item.elosztoHelye}',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _galeriaInditasa(
                        elosztoTiszta,
                        'Elosztó: ${item.elosztoNev}',
                      ),
                      icon: Icon(
                        Icons.bolt,
                        size: 18,
                        color: Colors.amber[900],
                      ),
                      label: Text(
                        'Elosztó fotó',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[900],
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[50],
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.feljegyzes.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[100]!),
                    ),
                    child: Text(
                      'Szívás / Feljegyzés: ${item.feljegyzes}',
                      style: TextStyle(
                        color: Colors.red[900],
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- ELOSZTÓ ADATLAP ÉS LEÁGAZÁS LISTA NÉZET ---
  Widget _buildElosztoAdatlapView() {
    final elosztoNev = _kivalasztottElosztoNev!;
    final leagazasok = _mindenAdat
        .where(
          (e) => e.elosztoNev.trim().toLowerCase() == elosztoNev.toLowerCase(),
        )
        .toList();

    String elosztoHelye = 'Nincs megadva';
    if (leagazasok.isNotEmpty) {
      elosztoHelye = leagazasok.first.elosztoHelye;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _visszaAKeresohoz,
          icon: const Icon(Icons.arrow_back),
          label: const Text(
            'Vissza a keresőhöz',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[200],
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 15),
        Card(
          elevation: 4,
          color: Colors.amber[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.amber[300]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bolt, size: 28, color: Colors.amber[900]),
                        const SizedBox(width: 8),
                        Text(
                          elosztoNev,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _galeriaInditasa(elosztoNev, 'Elosztó: $elosztoNev'),
                      icon: Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Colors.amber[900],
                      ),
                      label: Text(
                        'Elosztó fotó',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[900],
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Elosztó fizikai helye: $elosztoHelye',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Összesen ${leagazasok.length} db leágazás található ebben az elosztóban.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'Elosztóban található leágazások:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListView.separated(
              itemCount: leagazasok.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final elem = leagazasok[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      elem.leagazasJel.isNotEmpty ? elem.leagazasJel : '-',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.amber[900],
                      ),
                    ),
                  ),
                  title: Text(
                    elem.megnevezes,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Fizikai hely: ${elem.helyszin}'),
                  trailing: InkWell(
                    onTap: () => _berendezesKivalasztasa(
                      elem,
                      honnanEloszto: elosztoNev,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            elem.kod,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Colors.blue[900],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ElosztoInfo {
  final String hely;
  final int verzio;
  _ElosztoInfo(this.hely, this.verzio);
}
