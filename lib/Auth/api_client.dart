import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/io.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._();

  late final Dio dio;

  late final CookieJar cookieJar;
  bool _certificadoConfigurado = false;
  String? csrfToken;
  Future<void> configurarCertificadoDesenvolvimento() async {
    if (!kDebugMode || _certificadoConfigurado) {
      return;
    }

    print('=== CONFIGURANDO CERTIFICADO ===');

    final certificado = await rootBundle.load('assets/certificados/rootCA.pem');

    print('Certificado carregado: ${certificado.lengthInBytes} bytes');

    final bytes = certificado.buffer.asUint8List(
      certificado.offsetInBytes,
      certificado.lengthInBytes,
    );

    final contexto = SecurityContext(withTrustedRoots: true);

    contexto.setTrustedCertificatesBytes(bytes);

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        print('Criando HttpClient com certificado personalizado');
        return HttpClient(context: contexto);
      },
    );

    _certificadoConfigurado = true;

    print('=== CERTIFICADO CONFIGURADO ===');
  }
  // Future<void> configurarCertificadoDesenvolvimento() async {
  //   if (!kDebugMode || _certificadoConfigurado) {
  //     return;
  //   }

  //   final certificado = await rootBundle.load('assets/certificados/root_ca.pem');

  //   final bytes = certificado.buffer.asUint8List(
  //     certificado.offsetInBytes,
  //     certificado.lengthInBytes,
  //   );

  //   final contexto = SecurityContext(withTrustedRoots: true);

  //   contexto.setTrustedCertificatesBytes(bytes);

  //   dio.httpClientAdapter = IOHttpClientAdapter(
  //     createHttpClient: () {
  //       return HttpClient(context: contexto);
  //     },
  //   );

  //   _certificadoConfigurado = true;

  // }

  ApiClient._() {
    cookieJar = CookieJar();

    dio = Dio(
      BaseOptions(
        baseUrl: 'https://192.168.100.150:7240',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  // Obtém o token CSRF e recebe o cookie correspondente.
  Future<void> obterTokenCSRF() async {
    await configurarCertificadoDesenvolvimento();

    final response = await dio.get('/api/Auth/csrf');

    csrfToken = response.data['requestToken'];

    if (csrfToken == null || csrfToken!.isEmpty) {
      throw Exception('Falha ao obter token CSRF.');
    }
  }

  // Login
  // Future<Response> login({
  //   required String usuario,
  //   required String senha,
  // }) async {
  //   if (csrfToken == null) {
  //     await obterTokenCSRF();
  //   }

  //   return await dio.post(
  //     '/api/Auth/login',
  //     data: {'usuario': usuario, 'senha': senha},
  //     options: Options(headers: {'X-CSRF-TOKEN': csrfToken}),
  //   );
  // }
  Future<Response> login({
    required String usuario,
    required String senha,
  }) async {
    try {
      // Sempre obtém um novo token antes de autenticar.
      await obterTokenCSRF();

      return await dio.post(
        '/api/Auth/login',
        data: {'usuario': usuario, 'senha': senha},
        options: Options(headers: {'X-CSRF-TOKEN': csrfToken}),
      );
    } on DioException catch (e) {
      print('ERRO DIO: ${e.type}');
      print('MENSAGEM: ${e.message}');
      print('URL: ${e.requestOptions.uri}');
      print('STATUS HTTP: ${e.response?.statusCode}');
      print('RESPOSTA: ${e.response?.data}');
      rethrow;
    } catch (e) {
      print('ERRO GERAL: $e');
      rethrow;
    }
  }

  // Requisições protegidas
  Future<Response> requisicaoProtegida(
    String endpoint, {
    required String metodo,
    dynamic dados,
  }) async {
    await configurarCertificadoDesenvolvimento();
    final metodoNormalizado = metodo.toUpperCase();

    const metodosProtegidos = ['POST', 'PUT', 'PATCH', 'DELETE'];

    final protegida = metodosProtegidos.contains(metodoNormalizado);

    if (protegida && csrfToken == null) {
      await obterTokenCSRF();
    }

    return await dio.request(
      endpoint,
      data: dados,
      options: Options(
        method: metodoNormalizado,
        headers: protegida ? {'X-CSRF-TOKEN': csrfToken} : null,
      ),
    );
  }

  // Logout
  Future<void> logout() async {
    try {
      await requisicaoProtegida('/api/Auth/logout', metodo: 'POST');

      // Limpa os cookies armazenados localmente.
      await cookieJar.deleteAll();

      // Descarta o token CSRF anterior.
      csrfToken = null;

      print('Logout realizado. Cookies removidos.');
    } catch (e) {
      print('Erro ao realizar logout: $e');
      rethrow;
    }
  }
}
