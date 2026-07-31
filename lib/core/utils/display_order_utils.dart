/// Garson ekranında ürün/ekstra sıralaması.
List<T> sortByDisplayOrder<T>({
  required List<T> items,
  required List<String> displayOrder,
  required String Function(T item) idFor,
  int Function(T a, T b)? tieBreaker,
}) {
  if (displayOrder.isEmpty) {
    if (tieBreaker != null) {
      final sorted = [...items]..sort(tieBreaker);
      return sorted;
    }
    return items;
  }
  final indexOf = <String, int>{
    for (var i = 0; i < displayOrder.length; i++) displayOrder[i]: i,
  };
  final sorted = [...items]
    ..sort((a, b) {
      final ai = indexOf[idFor(a)];
      final bi = indexOf[idFor(b)];
      if (ai != null && bi != null) return ai.compareTo(bi);
      if (ai != null) return -1;
      if (bi != null) return 1;
      if (tieBreaker != null) return tieBreaker(a, b);
      return idFor(a).compareTo(idFor(b));
    });
  return sorted;
}
