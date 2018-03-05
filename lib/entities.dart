import 'dart:convert';
import 'package:flutter/material.dart';


class TabEntity {
  final Tab tab;
  final ListView view;

  TabEntity({this.tab, this.view});
}


class CurrencyEntity {
  String country;
  String name;
  int multiplier;
  String code;
  double rate;

  CurrencyEntity(this.country, this.name, this.multiplier, this.code,
      this.rate);

  String get countryCode => code.substring(0, 2);

  CurrencyEntity.fromCNB(String row) {
    List<String> _parts = row.split('|');
    country = _parts[0];
    name = _parts[1];
    multiplier = int.parse(_parts[2]);
    code = _parts[3];
    rate = double.parse(_parts[4].replaceAll(',', '.'));
  }

  CurrencyEntity.fromJson(Map<String, dynamic> json) {
    country = json['country'];
    name = json['name'];
    multiplier = json['multiplier'];
    code = json['code'];
    rate = json['rate'];
  }


  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'name': name,
      'multiplier': multiplier,
      'code': code,
      'rate': rate,
    };
  }
}


class ExchangesEntity {
  DateTime date;
  Map<String, CurrencyEntity> currencies = {};

  ExchangesEntity(this.date, this.currencies);

  ExchangesEntity.dump() {
    date = new DateTime.now();
    currencies = {};
  }

  ExchangesEntity.fromCNB(String body) {
    List<String> _lines = body.split("\n");

    // first line is info about date of created
    List<String> _dateParts = _lines.removeAt(0).substring(0, 10).split('.');
    date = DateTime.parse("${_dateParts[2]}-${_dateParts[1]}-${_dateParts[0]}");

    // next line is header for next data
    _lines.removeAt(0);

    // last line is empty
    _lines.removeLast();

    for (String row in _lines) {
      CurrencyEntity currency = new CurrencyEntity.fromCNB(row);
      currencies.addAll({currency.code: currency});
    }
  }

  ExchangesEntity.fromJson(String jsonSource) {
    var json = JSON.decode(jsonSource);
    date = DateTime.parse(json['date']);
    json['currencies'].forEach((String _code, dynamic _json) {
      currencies[_code] = new CurrencyEntity.fromJson(_json);
    });
  }

  String toJson() {
    return JSON.encode({
      'date': date.toIso8601String(),
      'currencies': currencies,
    });
  }

  void addCurrencies(Map<String, CurrencyEntity> currencies) {
    this.currencies.addAll(currencies);
    this._sortCurrencies();
  }

  void _sortCurrencies() {
    List<CurrencyEntity> _sortedEntities = [];

    this.currencies.forEach((String, CurrencyEntity _currency){
      _sortedEntities.add(_currency);
    });
    _sortedEntities.sort((CurrencyEntity a, CurrencyEntity b) => a.country.compareTo(b.country));

    this.currencies = {};
    _sortedEntities.forEach((CurrencyEntity _currency){
      this.currencies.addAll({_currency.code: _currency});
    });
  }
}
