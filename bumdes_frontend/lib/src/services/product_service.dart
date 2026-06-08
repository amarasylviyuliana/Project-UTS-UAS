import 'api_service.dart';
import 'profile_service.dart';
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

  Future<List<ProductModel>> fetchProductsByStore(String token) async {
    final profileService = ProfileService();
    final store = await profileService.getStore(token);
    final storeId = store['id'];
    final api = ApiService(token: token);
    final response = await api.getRaw('/stores/$storeId/products');
    final rawProducts = _extractProductList(response);
    return rawProducts
        .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ProductModel> createProduct(
    String token,
    String name,
    int categoryId,
    String type,
    double price,
    int stock,
    String description,
  ) async {
    final api = ApiService(token: token);
    final payload = {
      'name': name,
      'category_id': categoryId,
      'type': type,
      'price': price,
      'stock': stock,
      'description': description,
    };
    final response = await api.post('/products', payload);
    final productData = response['data'] ?? response;
    return ProductModel.fromJson(productData as Map<String, dynamic>);
  }

  Future<ProductModel> updateProduct(
    String token,
    int productId,
    String name,
    int categoryId,
    String type,
    double price,
    int stock,
    String description,
  ) async {
    final api = ApiService(token: token);
    final payload = {
      'name': name,
      'category_id': categoryId,
      'type': type,
      'price': price,
      'stock': stock,
      'description': description,
    };
    final response = await api.put('/products/$productId', payload);
    final productData = response['data'] ?? response;
    return ProductModel.fromJson(productData as Map<String, dynamic>);
  }

  Future<void> deleteProduct(String token, int productId) async {
    final api = ApiService(token: token);
    await api.put('/products/$productId', {'_method': 'DELETE'});
  }

  List<dynamic> _extractProductList(dynamic response) {
    if (response is List) {
      return response;
    }
    if (response is Map<String, dynamic>) {
      if (response['data'] is List) {
        return response['data'] as List<dynamic>;
      }
      if (response['data'] is Map<String, dynamic> &&
          response['data']['data'] is List) {
        return response['data']['data'] as List<dynamic>;
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
