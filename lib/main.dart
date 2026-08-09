import 'dart:convert';
import 'dart:async';
import 'dart:ui_web' as ui;
import 'package:universal_html/html.dart' as html;
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

  bool _vanBerendezesKep = false;
  bool _vanElosztoKep = false;
  bool _vanLeagazasKep = false;

  bool _berendezesKepToltodik = false;
  bool _elosztoKepToltodik = false;
  bool _leagazasKepToltodik = false;

  @override
  void initState() {
    super.initState();
    _adatbazisBetoltese();
    _berendezesKeresoCtrl.addListener(_berendezesSzuresVegrehajtasa);
    _elosztoKeresoCtrl.addListener(_elosztoSzuresVegrehajtasa);
  }

  String _keresHelyszin(String kod) {
    if (kod.isEmpty) return 'Nincs megadva';
    final talalat = _mindenAdat.where(
      (e) => e.kod.trim().toLowerCase() == kod.trim().toLowerCase(),
    );
    return talalat.isNotEmpty && talalat.first.helyszin.isNotEmpty
        ? talalat.first.helyszin
        : 'Nincs megadva';
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

          return DateTime.parse(
            '${ev}-${honap}-${nap.padLeft(2, '0')}T${ido}Z',
          );
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

      _vanBerendezesKep = false;
      _vanElosztoKep = false;
      _vanLeagazasKep = false;

      _berendezesKepToltodik = true;
      _elosztoKepToltodik = true;
      _leagazasKepToltodik = true;
    });

    _pahrhuzamosKepStatuszEllenorzes(berendezes);
  }

  void _elosztoKivalasztasa(String elosztoNev) {
    setState(() {
      _kivalasztottElosztoNev = elosztoNev;
      _aktualisNezet = NezetTipus.elosztoAdatlap;
      _szurtElosztoLista = [];
      _vanElosztoKep = false;
      _elosztoKepToltodik = true;
    });

    _elerhetoKepekKeresese(elosztoNev.trim()).then((kepek) {
      if (mounted) {
        setState(() {
          _vanElosztoKep = kepek.isNotEmpty;
          _elosztoKepToltodik = false;
        });
      }
    });
  }

  void _pahrhuzamosKepStatuszEllenorzes(BerendezesAdat item) async {
    final kodNev = item.kod.trim().toUpperCase();
    final elosztoNev = item.elosztoNev.trim().toUpperCase();
    final leagazasNev = item.leagazasJel.trim().toUpperCase();

    // 1. Berendezés ellenőrzése
    _elerhetoKepekKeresese(kodNev).then((kepek) {
      if (mounted && _kivalasztottBerendezes?.kod == item.kod) {
        setState(() {
          _vanBerendezesKep = kepek.isNotEmpty;
          _berendezesKepToltodik = false;
        });
      }
    });

    // 2. Elosztó ellenőrzése
    _elerhetoKepekKeresese(elosztoNev).then((kepek) {
      if (mounted && _kivalasztottBerendezes?.kod == item.kod) {
        setState(() {
          _vanElosztoKep = kepek.isNotEmpty;
          _elosztoKepToltodik = false;
        });
      }
    });

    // 3. Leágazás ellenőrzése
    if (leagazasNev.isNotEmpty) {
      _elerhetoKepekKeresese(leagazasNev).then((kepek) {
        if (mounted && _kivalasztottBerendezes?.kod == item.kod) {
          setState(() {
            _vanLeagazasKep = kepek.isNotEmpty;
            _leagazasKepToltodik = false;
          });
        }
      });
    } else {
      setState(() {
        _vanLeagazasKep = false;
        _leagazasKepToltodik = false;
      });
    }
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

  Future<bool> _kepLetezikE(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _keresElerhetoKepet(
    String alapMappaUrl,
    String fajlNev,
  ) async {
    List<String> verziok = [
      '$alapMappaUrl$fajlNev.jpg',
      '$alapMappaUrl$fajlNev.JPG',
      '$alapMappaUrl${fajlNev.toLowerCase()}.jpg',
      '$alapMappaUrl${fajlNev.toLowerCase()}.JPG',
      '$alapMappaUrl${fajlNev.toLowerCase()}.webp',
      '$alapMappaUrl${fajlNev.toLowerCase()}.png',
    ];

    for (var url in verziok) {
      if (await _kepLetezikE(url)) {
        return url;
      }
    }
    return null;
  }

  Future<List<String>> _elerhetoKepekKeresese(String alapNev) async {
    if (alapNev.isEmpty) return [];

    String tisztaAlapNev = alapNev.trim().toUpperCase();
    if (tisztaAlapNev.isEmpty) return [];

    List<String> talalatok = [];
    final buster = _getCacheBuster();
    final alapMappaUrl = Uri.base.resolve('assets/').toString();

    // Alap kép keresése (pl. 6DS01.jpg)
    final elsoTalalatUrl = await _keresElerhetoKepet(
      alapMappaUrl,
      tisztaAlapNev,
    );
    if (elsoTalalatUrl != null) {
      talalatok.add('$elsoTalalatUrl?v=$buster');
    }

    // Sorszámozott képek keresése (pl. 6DS01-1.jpg ... 6DS01-9.jpg)
    for (int i = 1; i <= 9; i++) {
      final sorszamosUrl = await _keresElerhetoKepet(
        alapMappaUrl,
        '$tisztaAlapNev-$i',
      );
      if (sorszamosUrl != null) {
        final teljesUrl = '$sorszamosUrl?v=$buster';
        if (!talalatok.contains(teljesUrl)) {
          talalatok.add(teljesUrl);
        }
      }
    }

    return talalatok;
  }

  void _galeriaInditasa(String alapNev, String cim) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final letoltottUrlLista = await _elerhetoKepekKeresese(alapNev);
    if (!mounted) return;
    Navigator.pop(context);

    if (letoltottUrlLista.isEmpty) {
      _nincsKepUzenet(context);
      return;
    }

    _galeriaMegnyitasa(letoltottUrlLista, cim, alapNev);
  }

  void _galeriaMegnyitasa(
    List<String> kepUrl_ek,
    String cim,
    String egyediAzonosito,
  ) {
    int aktualisIndex = 0;
    final TransformationController transformCtrl = TransformationController();

    void regisztralKepatmero(String url, int index) {
      ui.platformViewRegistry.registerViewFactory(
        'html-image-$egyediAzonosito-$index',
        (int viewId) => html.ImageElement()
          ..src = url
          ..style.objectFit = 'contain'
          ..style.width = '100%'
          ..style.height = '100%',
      );
    }

    regisztralKepatmero(kepUrl_ek[aktualisIndex], aktualisIndex);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Bezárás',
      barrierColor: Colors.black.withOpacity(0.85),
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
                          if (kepUrl_ek.length > 1)
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${aktualisIndex + 1} / ${kepUrl_ek.length}',
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
                    const Text(
                      'Két ujjal / egérrel extra nagyra (10x) nagyítható',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
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
                              child: HtmlElementView(
                                key: ValueKey(
                                  'view-$egyediAzonosito-$aktualisIndex',
                                ),
                                viewType:
                                    'html-image-$egyediAzonosito-$aktualisIndex',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (kepUrl_ek.length > 1)
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
                                        transformCtrl.value =
                                            Matrix4.identity();
                                        regisztralKepatmero(
                                          kepUrl_ek[aktualisIndex],
                                          aktualisIndex,
                                        );
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('Vissza'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white24,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: aktualisIndex < kepUrl_ek.length - 1
                                  ? () {
                                      setModalState(() {
                                        aktualisIndex++;
                                        transformCtrl.value =
                                            Matrix4.identity();
                                        regisztralKepatmero(
                                          kepUrl_ek[aktualisIndex],
                                          aktualisIndex,
                                        );
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_forward, size: 16),
                              label: const Text('Előre'),
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
        content: Text('Nincs még kép feltöltve'),
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

  Widget _buildBerendezesAdatlapView() {
    final item = _kivalasztottBerendezes!;
    final kodNev = item.kod.trim().toUpperCase();
    final elosztoNev = item.elosztoNev.trim().toUpperCase();
    final leagazasNev = item.leagazasJel.trim().toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    Tooltip(
                      message: _berendezesKepToltodik
                          ? 'Képkeresés...'
                          : (_vanBerendezesKep
                                ? 'Berendezés fotójának megtekintése'
                                : 'Nincs még kép feltöltve'),
                      child: ElevatedButton.icon(
                        onPressed: _berendezesKepToltodik
                            ? null
                            : (_vanBerendezesKep
                                  ? () => _galeriaInditasa(
                                      kodNev,
                                      'Berendezés: ${item.megnevezes}',
                                    )
                                  : () => _nincsKepUzenet(context)),
                        icon: _berendezesKepToltodik
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: _vanBerendezesKep
                                    ? Colors.blue[900]
                                    : Colors.grey[600],
                              ),
                        label: Text(
                          'Berendezés fotó',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _vanBerendezesKep
                                ? Colors.blue[900]
                                : Colors.grey[600],
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _vanBerendezesKep
                              ? Colors.blue[50]
                              : Colors.grey[200],
                          elevation: _vanBerendezesKep ? 2 : 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
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
                                Tooltip(
                                  message: _leagazasKepToltodik
                                      ? 'Képkeresés...'
                                      : (_vanLeagazasKep
                                            ? 'Leágazás fotójának megtekintése'
                                            : 'Nincs még kép feltöltve'),
                                  child: InkWell(
                                    onTap: _leagazasKepToltodik
                                        ? null
                                        : (_vanLeagazasKep
                                              ? () => _galeriaInditasa(
                                                  leagazasNev,
                                                  'Leágazás: ${item.leagazasJel}',
                                                )
                                              : () => _nincsKepUzenet(context)),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0,
                                        vertical: 2.0,
                                      ),
                                      child: Text(
                                        '[Leágazás: ${item.leagazasJel}]',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _vanLeagazasKep
                                              ? Colors.blue[700]
                                              : Colors.grey[600],
                                          fontSize: 14,
                                          decoration: _vanLeagazasKep
                                              ? TextDecoration.underline
                                              : TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Elosztó helye: ${_keresHelyszin(item.elosztoNev)}',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: _elosztoKepToltodik
                          ? 'Képkeresés...'
                          : (_vanElosztoKep
                                ? 'Elosztó fotójának megtekintése'
                                : 'Nincs még kép feltöltve'),
                      child: ElevatedButton.icon(
                        onPressed: _elosztoKepToltodik
                            ? null
                            : (_vanElosztoKep
                                  ? () => _galeriaInditasa(
                                      elosztoNev,
                                      'Elosztó: ${item.elosztoNev}',
                                    )
                                  : () => _nincsKepUzenet(context)),
                        icon: _elosztoKepToltodik
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.bolt,
                                size: 18,
                                color: _vanElosztoKep
                                    ? Colors.amber[900]
                                    : Colors.grey[600],
                              ),
                        label: Text(
                          'Elosztó fotó',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _vanElosztoKep
                                ? Colors.amber[900]
                                : Colors.grey[600],
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _vanElosztoKep
                              ? Colors.amber[50]
                              : Colors.grey[200],
                          elevation: _vanElosztoKep ? 2 : 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
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

  Widget _buildElosztoAdatlapView() {
    final elosztoNev = _kivalasztottElosztoNev!;
    final leagazasok = _mindenAdat
        .where(
          (e) => e.elosztoNev.trim().toLowerCase() == elosztoNev.toLowerCase(),
        )
        .toList();

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
                    Tooltip(
                      message: _elosztoKepToltodik
                          ? 'Képkeresés...'
                          : (_vanElosztoKep
                                ? 'Elosztó fotójának megtekintése'
                                : 'Nincs még kép feltöltve'),
                      child: ElevatedButton.icon(
                        onPressed: _elosztoKepToltodik
                            ? null
                            : (_vanElosztoKep
                                  ? () => _galeriaInditasa(
                                      elosztoNev.toUpperCase(),
                                      'Elosztó: $elosztoNev',
                                    )
                                  : () => _nincsKepUzenet(context)),
                        icon: _elosztoKepToltodik
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: _vanElosztoKep
                                    ? Colors.amber[900]
                                    : Colors.grey[600],
                              ),
                        label: Text(
                          'Elosztó fotó',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _vanElosztoKep
                                ? Colors.amber[900]
                                : Colors.grey[600],
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _vanElosztoKep
                              ? Colors.white
                              : Colors.grey[200],
                          elevation: _vanElosztoKep ? 2 : 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Elosztó fizikai helye: ${_keresHelyszin(elosztoNev)}',
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
                  color: Colors.black.withOpacity(0.05),
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
