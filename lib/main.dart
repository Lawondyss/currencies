import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'entities.dart';
import 'flags.dart';

void main() => runApp(new App());

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Měny',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {

  ExchangesEntity exchangesEntity = new ExchangesEntity.dump();
  List<String> favorites = [];
  bool loadingInProgress = true;

  TabController tabController;

  @override
  void initState() {
    super.initState();

    this.tabController = new TabController(length: this
        ._views()
        .length, vsync: this);

    this._loadFavorites();
    this._loadExchanges();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
          title: new Text('Měny'),
          bottom: new TabBar(
            controller: tabController,
            tabs: this._views().map((TabEntity entity) {
              return entity.tab;
            }).toList(),
          ),
          actions: [
            new Padding(
              padding: const EdgeInsets.all(8.0),
              child: new FlatButton(
                onPressed: _refreshExchanges,
                child: new Row(
                  children: [
                        () {
                      String _date = "${exchangesEntity.date
                          .day}.${exchangesEntity
                          .date.month}. ${exchangesEntity.date.year}";
                      return new Text("Platné od\n${_date}",
                          style: new TextStyle(color: Colors.white70));
                    }(),
                    new Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: new Icon(Icons.refresh, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ]
      ),
      body: this._buildBody(),
    );
  }

  Widget _buildBody() {
    if (this.loadingInProgress) {
      return new Center(
        child: new CircularProgressIndicator(),
      );
    } else {
      return new TabBarView(
        controller: tabController,
        children: this._views().map((TabEntity entity) {
          return entity.view;
        }).toList(),
      );
    }
  }

  List<TabEntity> _views() {
    return [
      new TabEntity(
        tab: new Tab(
          text: 'Oblíbené',
          icon: new Icon(Icons.favorite, color: Colors.white70),
        ),
        view: new ListView.builder(
          itemCount: this.favorites.length,
          itemBuilder: (context, index) {
            List<CurrencyEntity> _currencies = this.exchangesEntity.currencies
                .values.toList();
            _currencies = _currencies.where((CurrencyEntity _currency) {
              return this.favorites.contains(_currency.code);
            }).toList();
            return this._buildRow(_currencies[index]);
          },
        ),
      ),
      new TabEntity(
        tab: new Tab(
          text: 'Kurzy',
          icon: new Image.asset(
              'images/exchange-rates.png', color: Colors.white70, scale: 20.0),
        ),
        view: new ListView.builder(
          itemCount: this.exchangesEntity.currencies.length,
          itemBuilder: (context, index) {
            List<CurrencyEntity> _currencies = this.exchangesEntity.currencies
                .values.toList();
            return this._buildRow(_currencies[index]);
          },
        ),
      ),
    ];
  }

  ListTile _buildRow(CurrencyEntity entity) {
    return new ListTile(
      title: new Text(entity.country),
      subtitle: new Text("${entity.name} (${entity.code})"),
      leading: new Image.asset(Flags.byCountryCode(entity.countryCode)),
      trailing: new Row(
        children: <Widget>[
          new Text(
              "${entity.multiplier} ${entity.code} » ${entity.rate.toString()
                  .replaceFirst('.', ',')} CZK"),
          new IconButton(
            icon: new Icon(this._isFavorite(entity) ? Icons.favorite : Icons
                .favorite_border),
            onPressed: () {
              this._isFavorite(entity) ? this._removeFavorite(entity) : this
                  ._addFavorite(entity);
            },
          ),
        ],
      ),
      onLongPress: () {
        this._showCurrencyModal(entity);
      },
    );
  }

  void _showCurrencyModal(CurrencyEntity currency) {
    showDialog(
      context: context,
      child: new ModalForm(currency),
    );
  }

  void _refreshExchanges() {
    this.setState(() => this.loadingInProgress = true);
    _loadExchanges();
  }

  void _loadExchanges() async {
    ExchangesEntity entityBases = new ExchangesEntity.fromCNB(
        await _getResponseBody(
            'http://www.cnb.cz/cs/financni_trhy/devizovy_trh/kurzy_devizoveho_trhu/denni_kurz.txt'));
    ExchangesEntity entityOthers = new ExchangesEntity.fromCNB(
        await _getResponseBody(
            'http://www.cnb.cz/cs/financni_trhy/devizovy_trh/kurzy_ostatnich_men/kurzy.txt'));

    await getApplicationDocumentsDirectory().then((Directory directory) {
      DateTime _now = new DateTime.now();
      if (entityBases.date.weekday < 6 &&
          _now.isAfter(new DateTime(_now.year, _now.month, _now.day, 15, 15))) {
        this._getFileRates(directory).deleteSync();
      }

      entityBases.addCurrencies(entityOthers.currencies);
      this._getFileRates(directory).writeAsStringSync(entityBases.toJson());
      this.setState(() {
        this.exchangesEntity = entityBases;
        this.loadingInProgress = false;
      });
    });
  }

  Future<String> _getResponseBody(String url) async {
    HttpClient http = new HttpClient();
    Uri uri = Uri.parse(url);
    var request = await http.getUrl(uri);
    var response = await request.close();
    return await response.transform(UTF8.decoder).join();
  }

  void _loadFavorites() async {
    await getApplicationDocumentsDirectory().then((Directory directory) {
      File _file = this._getFileFavorites(directory);
      String _fileContent = _file.readAsStringSync();
      this.setState(() =>
      this.favorites =
      _fileContent.isEmpty ? [] : JSON.decode(_fileContent).toList());
    });
  }

  void _addFavorite(CurrencyEntity currency) async {
    await getApplicationDocumentsDirectory().then((Directory directory) {
      File _file = this._getFileFavorites(directory);
      String _fileContent = _file.readAsStringSync();
      List<String> _favorites = _fileContent.isEmpty ? [] : JSON.decode(
          _fileContent).toList();
      if (!_favorites.contains(currency.code)) {
        _favorites.add(currency.code);
        print(_favorites);
      }
      _file.writeAsStringSync(JSON.encode(_favorites));
      this.setState(() => this.favorites = _favorites);
    });
  }

  void _removeFavorite(CurrencyEntity currency) async {
    await getApplicationDocumentsDirectory().then((Directory directory) {
      File _file = _getFileFavorites(directory);
      String _fileContent = _file.readAsStringSync();
      List<String> _favorites = _fileContent.isEmpty ? [] : JSON.decode(
          _fileContent).toList();
      if (_favorites.contains(currency.code)) {
        _favorites.remove(currency.code);
        print(_favorites);
      }
      _file.writeAsStringSync(JSON.encode(_favorites));
      this.setState(() => this.favorites = _favorites);
    });
  }

  bool _isFavorite(CurrencyEntity currency) {
    return this.favorites.contains(currency.code);
  }

  File _getFileRates(Directory directory) {
    File file = new File("${directory.path}/rates.json");
    if (!file.existsSync()) {
      file.createSync();
    }

    return file;
  }

  File _getFileFavorites(Directory directory) {
    File file = new File("${directory.path}/favorites.json");
    if (!file.existsSync()) {
      file.createSync();
    }

    return file;
  }
}

class ModalForm extends StatefulWidget {
  final CurrencyEntity currency;

  ModalForm(this.currency);

  @override
  _ModalFormState createState() => new _ModalFormState(this.currency);
}

class _ModalFormState extends State<ModalForm> {
  final CurrencyEntity currency;
  TextStyle bigFont = const TextStyle(fontSize: 25.0, color: Colors.black);
  double exchangeValue;

  _ModalFormState(this.currency);

  @override
  Widget build(BuildContext context) {
    return new Center(
        child: new Container(
            margin: const EdgeInsets.all(20.0),
            child: new Material(
              type: MaterialType.card,
              child: new Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  new ListTile(
                    leading: new Image.asset(
                        Flags.byCountryCode(currency.countryCode)),
                    title: new Text(currency.country,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: new IconButton(
                        icon: new Icon(Icons.close),
                        onPressed: () {
                          this.setState(() => this.exchangeValue = null);
                          Navigator.of(context).pop();
                        }),
                  ),
                  new ListTile(
                    title: new TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: bigFont,
                      autofocus: true,
                      onChanged: (String value) {
                        _exchangeCurrency(value);
                      },
                    ),
                    trailing: new Text(currency.code, style: bigFont),
                  ),
                  new ListTile(
                    title: new Text(
                        (this.exchangeValue ?? '').toString().replaceAll(
                            '.', ','), style: bigFont,
                        textAlign: TextAlign.right),
                    trailing: new Text('CZK', style: bigFont),
                  ),
                ],
              ),
            )
        )
    );
  }

  void _exchangeCurrency(String value) {
    print(value);
    if (value.isEmpty) {
      return;
    }

    this.setState(() {
      this.exchangeValue =
          (this.currency.rate / this.currency.multiplier) * double.parse(value);
    });
  }
}