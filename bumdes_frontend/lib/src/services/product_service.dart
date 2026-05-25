import 'api_service.dart';
import '../models/product_model.dart';

class ProductService {
  final ApiService api = ApiService();

  Future<List<ProductModel>> fetchProducts() async {
    final response = await api.getRaw('/products');
    final rawProducts = _extractProductList(response);
    return rawProducts
        .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<dynamic> _extractProductList(dynamic response) {
    if (response is List) {
      return response;
    }
    if (response is Map<String, dynamic>) {
      if (response['data'] is List) {
        return response['data'] as List<dynamic>;
      }
      if (response['products'] is List) {
        return response['products'] as List<dynamic>;
      }
      if (response['items'] is List) {
        return response['items'] as List<dynamic>;
      }
    }
    return [];
  }
}
