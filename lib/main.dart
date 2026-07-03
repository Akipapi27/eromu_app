import 'dart:convert';
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

class KeresoPanel extends StatefulWidget {
  const KeresoPanel({super.key});

  @override
  State<KeresoPanel> createState() => _KeresoPanelState();
}

class _KeresoPanelState extends State<KeresoPanel> {
  List<BerendezesAdat> _mindenAdat = [];
  List<BerendezesAdat> _szurtAdat = [];
  BerendezesAdat? _kivalasztottBerendezes; // Az éppen kiválasztott egyetlen berendezés adatlapja
  final _keresoCtrl = TextEditingController();
  bool _isLoading = true;
  String _hibaUzenet = '';

  @override
  void initState() {
    super.initState();
    _adatbazisBetoltese();
    _keresoCtrl.addListener(_szuresVegrehajtasa);
  }

  String _getCacheBuster() {
    return DateTime.now().millisecondsSinceEpoch.toString();
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
        _szurtAdat = []; // Kezdésnél üres a szűrt lista, nincs felesleges adatözön
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

  void _szuresVegrehajtasa() {
    final szo = _keresoCtrl.text.trim().toLowerCase();
    if (szo.isEmpty) {
      setState(() {
        _szurtAdat = [];
      });
      return;
    }

    setState(() {
      _szurtAdat = _mindenAdat.where((item) {
        return item.kod.toLowerCase().contains(szo) ||
            item.megnevezes.toLowerCase().contains(szo);
      }).toList();
    });
  }

  // Amikor rákattintunk egy ajánlott elemre
  void _berendezesKivalasztasa(BerendezesAdat berendezes) {
    setState(() {
      _kivalasztottBerendezes = berendezes;
      _szurtAdat = []; // Elrejtjük a kis ablakot
    });
  }

  // A kért Vissza gomb funkciója, ami kiürít mindent és visszaadja a keresőt
  void _visszaAListahoz() {
    setState(() {
      _kivalasztottBerendezes = null;
      _keresoCtrl.clear(); // Kiüríti a mezőt a tiszta nyitólaphoz
      _szurtAdat = [];
    });
  }

  Future<bool> _kepLetezikE(String url) async {
    try {
      final urlKenszeritve = url.contains('?v=')
          ? url
          : '$url?v=${_getCacheBuster()}';
      final res = await http.head(Uri.parse(urlKenszeritve));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _keresElerhetoKepet(
    String alapMappaUrl,
    String fajlNev,
  ) async {
    List<String> verziok = [
      '$alapMappaUrl${fajlNev.toLowerCase()}.webp',
      '$alapMappaUrl${fajlNev.toLowerCase()}.jpg',
      '$alapMappaUrl${fajlNev.toLowerCase()}.png',
      '$alapMappaUrl${fajlNev.toUpperCase()}.webp',
      '$alapMappaUrl${fajlNev.toUpperCase()}.jpg',
      '$alapMappaUrl${fajlNev.toUpperCase()}.png',
      '$alapMappaUrl$fajlNev.webp',
      '$alapMappaUrl$fajlNev.jpg',
      '$alapMappaUrl$fajlNev.png',
    ];

    for (var url in verziok) {
      if (await _kepLetezikE(url)) {
        return url;
      }
    }
    return null;
  }

  Future<List<String>> _elerhetoKepekKeresese(String alapNev) async {
    List<String> talalatok = [];
    final buster = _getCacheBuster();
    final alapMappaUrl = Uri.base.resolve('assets/').toString();

    final elsoTalalatUrl = await _keresElerhetoKepet(alapMappaUrl, alapNev);
    if (elsoTalalatUrl != null) {
      talalatok.add('$elsoTalalatUrl?v=$buster');
    }

    for (int i = 1; i <= 9; i++) {
      final sorszamosNev = '$alapNev-$i';
      final sorszamosTalalatUrl = await _keresElerhetoKepet(
        alapMappaUrl,
        sorszamosNev,
      );
      if (sorszamosTalalatUrl != null) {
        final teljesUrl = '$sorszamosTalalatUrl?v=$buster';
        if (!talalatok.contains(teljesUrl)) {
          talalatok.add(teljesUrl);
        }
      }
    }

    return talalatok;
  }

  void _galeriaInditasa(String alapNev, String cim, String tipusNev) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final letoltottUrlLista = await _elerhetoKepekKeresese(alapNev);
    if (!mounted) return;
    Navigator.pop(context);

    if (letoltottUrlLista.isEmpty) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ehhez a ${tipusNev}hez még nincs feltöltve fotó ($alapNev.webp/.jpg/.png)',
          ),
          backgroundColor: Colors.orange[800],
          duration: const Duration(seconds: 3),
        ),
      );
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

    void _regisztralKepatmero(String url, int index) {
      ui.platformViewRegistry.registerViewFactory(
        'html-image-$egyediAzonosito-$index',
        (int viewId) => html.ImageElement()
          ..src = url
          ..style.objectFit = 'contain'
          ..style.width = '100%'
          ..style.height = '100%',
      );
    }

    _regisztralKepatmero(kepUrl_ek[aktualisIndex], aktualisIndex);

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
                      'Két ujjal extra nagyra (10x) nagyítható',
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
                                        _regisztralKepatmero(
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
                                        _regisztralKepatmero(
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
        child: _kivalasztottBerendezes != null
            ? _buildAdatlapView() // Ha kiválasztottál egy ágát, az adatlapot mutatja
            : _buildKeresoView(), // Alapból a letisztult üres keresőt mutatja
      ),
    );
  }

  // 1. NÉZET: Letisztult kezdő keresőoldal lebegő kis ajánlati ablakkal
  Widget _buildKeresoView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Válassz ki egy berendezést a szakaszolási adatok megtekintéséhez:',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _keresoCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Gépeld be az AK kódot vagy a berendezés nevét...',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _keresoCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _keresoCtrl.clear();
                    },
                  )
                : null,
          ),
          // Ha beírja a kódot és egyből Entert üt, megnyitja a legfelső találatot
          onSubmitted: (value) {
            if (_szurtAdat.isNotEmpty) {
              _berendezesKivalasztasa(_szurtAdat.first);
            }
          },
        ),
        const SizedBox(height: 5),
        // "KIS ABLAK" - Az intelligens felugró lista gépelés közben
        if (_keresoCtrl.text.isNotEmpty)
          Expanded(
            child: _szurtAdat.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Nincs a keresésnek megfelelő berendezés az adatbázisban.',
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _szurtAdat.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _szurtAdat[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Helyszín: ${item.helyszin}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () => _berendezesKivalasztasa(item),
                        );
                      },
                    ),
                  ),
          ),
        if (_keresoCtrl.text.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    'Kezdj el gépelni a kereséshez...',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 2. NÉZET: A kiválasztott egyetlen gép részletes adatlapja a Vissza gombbal
  Widget _buildAdatlapView() {
    final item = _kivalasztottBerendezes!;
    final kodTiszta = item.kod.trim();
    final elosztoTiszta = item.elosztoNev.trim();
    final leagazasTiszta = item.leagazasJel.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fényes, könnyen kattintható Vissza gomb
        ElevatedButton.icon(
          onPressed: _visszaAListahoz,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Vissza a keresőhöz', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[200],
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 15),
        // Adatlap kártya
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        'berendezés',
                      ),
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text(
                        'Berendezés fotó',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue[900],
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        crossAxisAlignment: Cross CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Tápláló elosztó: ${item.elosztoNev} ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (item.leagazasJel.isNotEmpty)
                                InkWell(
                                  onTap: () => _galeriaInditasa(
                                    leagazasTiszta,
                                    'Leágazás: ${item.leagazasJel}',
                                    'leágazás',
                                  ),
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
                                        color: Colors.blue[700],
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
                            style: TextStyle(color: Colors.grey[800], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _galeriaInditasa(
                        elosztoTiszta,
                        'Elosztó: ${item.elosztoNev}',
                        'elosztó',
                      ),
                      icon: const Icon(Icons.bolt, size: 18),
                      label: const Text(
                        'Elosztó fotó',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[50],
                        foregroundColor: Colors.amber[900],
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
}

class _ElosztoInfo {
  final String hely;
  final int verzio;
  _ElosztoInfo(this.hely, this.verzio);
}