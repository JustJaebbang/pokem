class ProductDraft {
  const ProductDraft({
    required this.regulation,
    required this.packType,
    required this.element,
    required this.setNumber,
    required this.rarity,
    required this.title,
    required this.description,
    required this.price,
  });
  final String regulation,
      packType,
      element,
      setNumber,
      rarity,
      title,
      description;
  final int price;
  Map<String, Object> toJson(String imageUrl) => {
    'regulation': regulation.trim(),
    'card_pack_type': packType.trim(),
    'element_of_set': element.trim(),
    'set': setNumber.trim(),
    'rarity': rarity.trim(),
    'sell_product_title': title.trim(),
    'sell_product_image': imageUrl,
    'sell_product_contents': description.trim(),
    'sell_product_sell_price': price,
  };
}
