"""contracts/option_pricing.cairo test file."""
import os
import math

import pytest
from starkware.starknet.testing.starknet import Starknet

# The path to the contract source code.
CONTRACT_FILE = os.path.join("contracts", "initialize_amm.cairo")

TOKEN_A = 1
TOKEN_B = 2

OPTION_CALL = 0
OPTION_PUT = 1

TRADE_SIDE_LONG = 0
TRADE_SIDE_SHORT = 1

Math64x61_FRACT_PART = 2 ** 61



@pytest.mark.asyncio
async def test_init_pool() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=CONTRACT_FILE,)

    # pool_balance
    result = await contract.get_pool_balance(OPTION_CALL).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)
    result = await contract.get_pool_balance(OPTION_PUT).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # account_balance
    account_id = 123456789
    result = await contract.get_account_balance(account_id, TOKEN_A).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)
    result = await contract.get_account_balance(account_id, TOKEN_B).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # pool_option_balance
    for option_type in [OPTION_CALL, OPTION_PUT]:
        for strike_price in [1000, 1100, 1200]:
            for maturity in [1., 1.1]:
                for side in [TRADE_SIDE_LONG, TRADE_SIDE_SHORT]:
                    result = await contract.get_pool_option_balance(
                        option_type,
                        strike_price * Math64x61_FRACT_PART,
                        int(maturity * Math64x61_FRACT_PART),
                        side
                    ).call()
                    assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # pool_volatility
    for option_type in [OPTION_CALL, OPTION_PUT]:
        for maturity in [1000, 1100]:
            result = await contract.get_pool_volatility(option_type, maturity).call()
            assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # ----------initialize pool----------
    await contract.init_pool().invoke()

    # pool_balance
    result = await contract.get_pool_balance(OPTION_CALL).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 12345, abs_tol=0.0001)
    result = await contract.get_pool_balance(OPTION_PUT).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 12345, abs_tol=0.0001)

    # account_balance
    account_id = 123456789
    result = await contract.get_account_balance(account_id, TOKEN_A).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)
    result = await contract.get_account_balance(account_id, TOKEN_B).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # pool_option_balance
    for option_type in [OPTION_CALL, OPTION_PUT]:
        for strike_price in [1000, 1100, 1200]:
            for maturity in [1., 1.1]:
                for side in [TRADE_SIDE_LONG, TRADE_SIDE_SHORT]:
                    result = await contract.get_pool_option_balance(
                        option_type,
                        strike_price * Math64x61_FRACT_PART,
                        int(maturity * Math64x61_FRACT_PART),
                        side
                    ).call()
                    assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # pool_volatility
    for option_type in [OPTION_CALL, OPTION_PUT]:
        for maturity in [1., 1.1]:
            result = await contract.get_pool_volatility(
                option_type,
                int(maturity * Math64x61_FRACT_PART)
            ).call()
            assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 100, abs_tol=0.0001)


@pytest.mark.asyncio
async def test_add_fake_tokens() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=CONTRACT_FILE,)

    # initialize pool
    await contract.init_pool().invoke()

    # pool_balance
    result = await contract.get_pool_balance(OPTION_CALL).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 12345, abs_tol=0.0001)
    result = await contract.get_pool_balance(OPTION_PUT).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 12345, abs_tol=0.0001)

    # account_balance
    account_id = 123456789
    result = await contract.get_account_balance(account_id, TOKEN_A).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)
    result = await contract.get_account_balance(account_id, TOKEN_B).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)


    # ----------------add fake tokens----------------
    account_id = 123456789
    await contract.add_fake_tokens(
        account_id=account_id,
        amount_token_a=100 * Math64x61_FRACT_PART,
        amount_token_b=90 * Math64x61_FRACT_PART
    ).invoke()
    account_id = 987654321
    await contract.add_fake_tokens(
        account_id=account_id,
        amount_token_a=50 * Math64x61_FRACT_PART,
        amount_token_b=40 * Math64x61_FRACT_PART
    ).invoke()

    # pool_balance
    result = await contract.get_pool_balance(OPTION_CALL).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 12495, abs_tol=0.0001)
    result = await contract.get_pool_balance(OPTION_PUT).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 12475, abs_tol=0.0001)

    # account_balance
    account_id = 123456789
    result = await contract.get_account_balance(account_id, TOKEN_A).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 100, abs_tol=0.0001)
    result = await contract.get_account_balance(account_id, TOKEN_B).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 90, abs_tol=0.0001)
    account_id = 987654321
    result = await contract.get_account_balance(account_id, TOKEN_A).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 50, abs_tol=0.0001)
    result = await contract.get_account_balance(account_id, TOKEN_B).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 40, abs_tol=0.0001)

    # pool_option_balance
    for option_type in [OPTION_CALL, OPTION_PUT]:
        for strike_price in [1000, 1100, 1200]:
            for maturity in [1, 1.1]:
                for side in [TRADE_SIDE_LONG, TRADE_SIDE_SHORT]:
                    result = await contract.get_pool_option_balance(
                        option_type,
                        strike_price * Math64x61_FRACT_PART,
                        int(maturity * Math64x61_FRACT_PART),
                        side
                    ).call()
                    assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # pool_volatility
    print('--------------------------------')
    for option_type in [OPTION_CALL, OPTION_PUT]:
        for maturity in [1., 1.1]:
            result = await contract.get_pool_volatility(
                option_type,
                int(maturity*Math64x61_FRACT_PART)
            ).call()
            print(maturity, option_type, result.result)
            assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 100, abs_tol=0.0001)