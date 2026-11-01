class CardInfoGuideField {
  const CardInfoGuideField(
    this.key,
    this.label,
    this.example,
    this.description,
  );
  final String key, label, example, description;
}

const cardInfoGuideFields = [
  CardInfoGuideField(
    'regulation',
    '레귤레이션',
    'J',
    '카드 하단 왼쪽의 작은 네모 안에 있는 영문자입니다.',
  ),
  CardInfoGuideField(
    'packType',
    '카드 팩 구분',
    'M6a',
    '레귤레이션 옆에 표시된 팩 코드입니다. 대소문자도 확인해주세요.',
  ),
  CardInfoGuideField('element', '카드 번호 (분자)', '133', '슬래시(/) 앞에 있는 숫자입니다.'),
  CardInfoGuideField('setNumber', '세트 번호 (분모)', '103', '슬래시(/) 뒤에 있는 숫자입니다.'),
  CardInfoGuideField('rarity', '레어도', 'SAR', '번호 옆에 표시된 영문자입니다.'),
];

class ProductGuidePreference {
  const ProductGuidePreference({
    this.ready = false,
    this.hidden = false,
    this.selected = false,
    this.saving = false,
    this.error,
  });
  final bool ready, hidden, selected, saving;
  final String? error;
}
