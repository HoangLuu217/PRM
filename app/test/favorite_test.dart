import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:prm_project/models/favorite_model.dart';
import 'package:prm_project/models/restaurant_model.dart';
import 'package:prm_project/providers/auth_provider.dart';
import 'package:prm_project/providers/favorite_provider.dart';
import 'package:prm_project/screens/customer/favorites_screen.dart';
import 'package:prm_project/services/favorite_service.dart';

class FakeFavoriteService extends FavoriteService {
  final List<RestaurantModel> initialFavorites;
  FakeFavoriteService({this.initialFavorites = const []});

  @override
  Future<List<RestaurantModel>> getFavorites() async => initialFavorites;

  @override
  Future<Set<String>> getFavoriteIds() async => initialFavorites.map((r) => r.id).toSet();

  @override
  Future<Map<String, dynamic>> addFavorite(dynamic restaurantOrId) async => {'success': true};

  @override
  Future<Map<String, dynamic>> removeFavorite(String businessId) async => {'success': true};
}

void main() {
  group('Member 2 - Favorite Feature Tests', () {
    final mockRestaurant = RestaurantModel(
      id: 'biz_123',
      name: 'Bếp Của Ngoại Đà Nẵng',
      description: 'Món ăn gia đình ấm cúng chuẩn vị',
      categories: ['RESTAURANT'],
      address: '136 Yên Bái, Hải Châu, Đà Nẵng',
      city: 'Đà Nẵng',
      district: 'Hải Châu',
      rating: 4.8,
      totalReviews: 120,
      googleRating: 4.9,
      googleTotalReviews: 245,
    );

    test('1. FavoriteModel should correctly deserialize from JSON', () {
      final json = {
        '_id': 'fav_999',
        'userId': 'user_001',
        'businessId': {
          '_id': 'biz_123',
          'name': 'Bếp Của Ngoại Đà Nẵng',
          'description': 'Món ngon',
          'categories': ['RESTAURANT'],
          'addressText': '136 Yên Bái, Hải Châu',
        },
        'createdAt': '2026-10-15T00:00:00.000Z',
      };

      final fav = FavoriteModel.fromJson(json);

      expect(fav.id, 'fav_999');
      expect(fav.userId, 'user_001');
      expect(fav.businessId, 'biz_123');
      expect(fav.business?.name, 'Bếp Của Ngoại Đà Nẵng');
      expect(fav.createdAt, isNotNull);
    });

    test('2. FavoriteProvider toggleFavorite should add and remove favorites correctly', () async {
      final provider = FavoriteProvider(favoriteService: FakeFavoriteService());

      expect(provider.isFavorite('biz_123'), false);
      expect(provider.count, 0);

      // Optimistic toggle add
      await provider.toggleFavorite(mockRestaurant);

      expect(provider.isFavorite('biz_123'), true);
      expect(provider.count, 1);
      expect(provider.favorites.length, 1);
      expect(provider.favorites.first.id, 'biz_123');

      // Optimistic toggle remove
      await provider.toggleFavorite(mockRestaurant);

      expect(provider.isFavorite('biz_123'), false);
      expect(provider.count, 0);
      expect(provider.favorites.isEmpty, true);
    });

    test('3. FavoriteProvider clear should reset all state', () async {
      final provider = FavoriteProvider(favoriteService: FakeFavoriteService());
      await provider.toggleFavorite(mockRestaurant);
      expect(provider.count, 1);

      provider.clear();

      expect(provider.count, 0);
      expect(provider.favorites.isEmpty, true);
      expect(provider.favoriteIds.isEmpty, true);
      expect(provider.isInitialLoaded, false);
    });

    testWidgets('4. FavoritesScreen displays empty state when there are no favorites', (tester) async {
      final favProvider = FavoriteProvider(favoriteService: FakeFavoriteService());
      favProvider.setInitialFavorites([]);
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: favProvider),
          ],
          child: const MaterialApp(
            home: FavoritesScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Quán yêu thích'), findsOneWidget);
      expect(find.text('Chưa có quán yêu thích nào'), findsOneWidget);
      expect(find.text('Khám phá quán ngon ngay'), findsOneWidget);
    });

    testWidgets('5. FavoritesScreen displays restaurant card when favorites exist', (tester) async {
      final favProvider = FavoriteProvider(
        favoriteService: FakeFavoriteService(initialFavorites: [mockRestaurant]),
      );
      favProvider.setInitialFavorites([mockRestaurant]);
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: favProvider),
          ],
          child: const MaterialApp(
            home: FavoritesScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Quán yêu thích'), findsOneWidget);
      expect(find.text('Bếp Của Ngoại Đà Nẵng'), findsOneWidget);
      expect(find.text('Xem menu & chi tiết'), findsOneWidget);
      expect(find.text('Đặt bàn ngay'), findsOneWidget);
    });
  });
}
