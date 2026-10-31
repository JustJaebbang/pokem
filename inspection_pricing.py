DEPOSIT_REFUND_UNIT_PRICE = 5_000
INSPECTION_UNIT_PRICE = 10_000
MAX_INSPECTION_AMOUNT = 2_147_483_647 // INSPECTION_UNIT_PRICE


def calculate_inspection_fee(amount: int) -> int:
    if type(amount) is not int or not 1 <= amount <= MAX_INSPECTION_AMOUNT:
        raise ValueError('검수 신청 수량을 확인해주세요.')
    return amount * INSPECTION_UNIT_PRICE
