import 'package:new_project_location/api/base_dao.dart';
import 'package:new_project_location/constants.dart';
import 'package:flutter/material.dart';

//Нэвтрэх, бүртгүүлэх DAO
class AuthDAO extends BaseDAO {
  //Бүх эмнэлгүүдийг дуудах - Login
  Future<ApiResponse<List<dynamic>>> getHospitals() {
    return get<List<dynamic>>(
      '${Constants.runnerUrl}/gateway/servers',
      config: const RequestConfig(headerType: HeaderType.xtoken),
    );
  }

  //Нэвтрэх
  Future<ApiResponse<Map<String, dynamic>>> login(Map<String, dynamic> body) {
    debugPrint(HeaderType.xtokenAndTenant.toString());
    return post<Map<String, dynamic>>(
      '${Constants.runnerUrl}/gateway/auth',
      body: body,
      config: const RequestConfig(headerType: HeaderType.xtokenAndTenant, excludeToken: false),
    );
  }
}
