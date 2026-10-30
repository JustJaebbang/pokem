class ProductFormInput {
  const ProductFormInput({
    required this.title,
    required this.description,
    required this.price,
    required this.regulation,
    required this.packType,
    required this.element,
    required this.setNumber,
    required this.rarity,
  });
  final String title,
      description,
      price,
      regulation,
      packType,
      element,
      setNumber,
      rarity;
  Map<String, String> get fields => {
    'title': title,
    'description': description,
    'price': price,
    'regulation': regulation,
    'packType': packType,
    'element': element,
    'setNumber': setNumber,
    'rarity': rarity,
  };
}
