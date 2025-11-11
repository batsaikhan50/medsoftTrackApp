import 'package:new_project_location/api/base_dao.dart';
import 'package:new_project_location/constants.dart';

//Байршил солилцох үйлдлийн DAO
class MapDAO extends BaseDAO {
  //Өрөөний мэдээлэл авах
  Future<ApiResponse<List<dynamic>>> getPatientsListAmbulance() {
    return get<List<dynamic>>(
      '${Constants.appUrl}/room/get/driver',
      config: const RequestConfig(
        headerType: HeaderType.xtokenAndTenantAndxmedsoftToken,
        excludeToken: true,
      ),
    );
  }

  //Иргэн-рүү Апп татах мессеж илгээх
  Future<ApiResponse<void>> sendSmsToPatient(String roomId, String phone) {
    return get<void>(
      '${Constants.runnerUrl}/gateway/general/get/api/inpatient/ambulance/sendToMedsoftApp?roomId=$roomId&patientPhone=$phone',
      config: const RequestConfig(
        headerType: HeaderType.xtokenAndTenantAndxmedsoftToken,
        excludeToken: false,
      ),
    );
  }

  //Иргэн рүү ирсэн хүсэлт явуулах
  Future<ApiResponse<void>> sendArrivedToPatient(String roomId) {
    return get<void>(
      '${Constants.appUrl}/room/arrived?id=$roomId',
      config: const RequestConfig(
        headerType: HeaderType.xtokenAndTenantAndxmedsoftToken,
        excludeToken: true,
      ),
    );
  }
}
