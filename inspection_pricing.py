DEPOSIT_REFUND_UNIT_PRICE = 5_000
INSPECTION_UNIT_PRICE = 10_000
MAX_INSPECTION_AMOUNT = 2_147_483_647 // INSPECTION_UNIT_PRICE


def calculate_inspection_fee(amount: int, unit_price: int = INSPECTION_UNIT_PRICE) -> int:
    """설정된 건당 가격으로 검수비를 계산하되 DB INT 범위를 넘지 않게 한다."""
    if type(unit_price) is not int or unit_price < 0:
        raise ValueError('검수 단가를 확인해주세요.')
    maximum = 2_147_483_647 if unit_price == 0 else 2_147_483_647 // unit_price
    if type(amount) is not int or not 1 <= amount <= maximum:
        raise ValueError('검수 신청 수량을 확인해주세요.')
    return amount * unit_price
