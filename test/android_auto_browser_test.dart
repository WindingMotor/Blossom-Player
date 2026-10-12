import 'package:blossom/android_auto/android_auto_browser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('paginateItems', () {
    test('maps only the requested page', () {
      var mapped = 0;

      final result = paginateItems(
        List<int>.generate(1000, (index) => index),
        page: 2,
        pageSize: 25,
        convert: (value) {
          mapped++;
          return 'item-$value';
        },
      );

      expect(result, hasLength(25));
      expect(result.first, 'item-50');
      expect(result.last, 'item-74');
      expect(mapped, 25);
    });

    test('rejects invalid and out-of-range pages', () {
      final items = [1, 2, 3];

      expect(
        paginateItems(items, page: -1, pageSize: 2, convert: (item) => item),
        isEmpty,
      );
      expect(
        paginateItems(items, page: 0, pageSize: 0, convert: (item) => item),
        isEmpty,
      );
      expect(
        paginateItems(items, page: 5, pageSize: 2, convert: (item) => item),
        isEmpty,
      );
    });
  });
}
