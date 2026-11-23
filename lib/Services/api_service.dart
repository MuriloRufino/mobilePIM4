import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_application_1/Auth/api_client.dart';

class ApiService {
  static Future<List<dynamic>> _listar(String endpoint) async {
    await ApiClient.instance.configurarCertificadoDesenvolvimento();

    final resposta = await ApiClient.instance.dio.get(
      '/api/$endpoint',
    );

    dynamic dados = resposta.data;

    if (dados is String) {
      dados = jsonDecode(dados);
    }

    if (dados is List) {
      return dados;
    }

    if (dados is Map && dados['data'] is List) {
      return dados['data'];
    }

    throw Exception('Formato de resposta inválido: $endpoint');
  }

  static Future<List<dynamic>> listarAlugueis() =>
      _listar('Aluguel');

  static Future<List<dynamic>> listarCarros() =>
      _listar('Carro');

  static Future<List<dynamic>> listarAdaptacoes() =>
      _listar('Adaptacao');
}