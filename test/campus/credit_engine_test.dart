import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/campus/credit_engine.dart';
import 'package:yuki_blog_app/models/campus/campus_user.dart';

void main() {
  test('星级对应的增减分', () {
    expect(creditDeltaFor(5), 2);
    expect(creditDeltaFor(4), 1);
    expect(creditDeltaFor(3), 0);
    expect(creditDeltaFor(2), -2);
    expect(creditDeltaFor(1), -4);
  });

  test('越界星级按边界算，不会算出奇怪的分', () {
    expect(creditDeltaFor(9), creditDeltaFor(5));
    expect(creditDeltaFor(0), creditDeltaFor(1));
  });

  test('分数被夹在 0 到 100 之间', () {
    expect(applyReviewToCredit(99, 5), 100);
    expect(applyReviewToCredit(2, 1), 0);
    expect(applyReviewToCredit(70, 1), 66);
  });

  test('文案跟着增减走', () {
    expect(describeCreditDelta(5), '+2 分');
    expect(describeCreditDelta(3), '不加减分');
    expect(describeCreditDelta(1), '-4 分');
  });

  test('档位阈值与分数对得上', () {
    expect(CreditTier.of(92), CreditTier.excellent);
    expect(CreditTier.of(80), CreditTier.good);
    expect(CreditTier.of(65), CreditTier.normal);
    expect(CreditTier.of(40), CreditTier.low);
  });
}
