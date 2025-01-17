%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.Math64x61 import (
    Math64x61_toFelt,
    Math64x61_fromFelt,
    Math64x61_ONE,
    Math64x61_add,
    Math64x61_sub,
    Math64x61_mul,
    Math64x61_div
)

from contracts.amm import (_time_till_maturity, do_trade, get_pool_balance,
    get_pool_option_balance, get_pool_volatility)
from contracts.constants import (POOL_BALANCE_UPPER_BOUND, ACCOUNT_BALANCE_UPPER_BOUND, 
    VOLATILITY_LOWER_BOUND, VOLATILITY_UPPER_BOUND, TOKEN_A, TOKEN_B, OPTION_CALL, OPTION_PUT,
    TRADE_SIDE_LONG, TRADE_SIDE_SHORT, get_opposite_side, STRIKE_PRICE_UPPER_BOUND)
from contracts.initialize_amm import init_pool, add_fake_tokens

@external
func test_time_till_maturity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    
    alloc_locals
    
    %{ warp(1672527600 - (365*60*60*24)) %}
    
    let (result) = _time_till_maturity(1672527600)
    assert result = Math64x61_ONE
    return ()
end

func _test_pool_option_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt,
    target : felt
):

    let (result) = get_pool_option_balance(
        option_type=option_type,
        strike_price=strike_price,
        maturity=maturity,
        side=side
    )
    assert result = target
    return ()
end

func _test_volatility{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt,
    maturity : felt,
    target : felt
):

    let (result) = get_pool_volatility(option_type=option_type, maturity=maturity)
    assert result = target
    return ()
end

@external
func test_do_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    
    alloc_locals

    # mock timestamp
    %{ warp(1672527600 - (365*60*60*24)) %}

    # set some constants
    const account_id = 123456789
    let (hundred) = Math64x61_fromFelt(100)
    let (strike_1000) = Math64x61_fromFelt(1000)
    let (strike_1100) = Math64x61_fromFelt(1100)
    let (two) = Math64x61_fromFelt(2)
    let (half) = Math64x61_div(Math64x61_ONE, two)
    let (one_and_half) = Math64x61_add(Math64x61_ONE, half)
    let maturity_01 = 1644145200
    let maturity_1 = 1672527600

    # initialize pools
    init_pool()
    add_fake_tokens(account_id, hundred, hundred)

    # Trade 1 -------------------------------------------------------
    do_trade(account_id, OPTION_CALL, strike_1000, maturity_01, TRADE_SIDE_LONG, Math64x61_ONE)

    # Assuming the BS model is correctly computed
    # 12445 + premia + locked capital = 12445 + 0.1255... - 1
    let (result_1) = get_pool_balance(OPTION_CALL)
    let target_1 = 28694208692467424729200 # 12444.129360850251
    assert result_1 = target_1

    _test_volatility(OPTION_CALL, maturity_01, 2306028306787561975)
    _test_volatility(OPTION_PUT, maturity_01, Math64x61_ONE)
    _test_volatility(OPTION_CALL, maturity_1, Math64x61_ONE)
    _test_volatility(OPTION_PUT, maturity_1, Math64x61_ONE)

    # Trade 2 -------------------------------------------------------
    do_trade(account_id, OPTION_PUT, strike_1000, maturity_01, TRADE_SIDE_SHORT, two)

    # Assuming the BS model is correctly computed
    # The PUT is in quote token (CALL in base token... base/quote = ETH/USDC),
    # thats why we have such a difference here in comparison to the above trade
    # there is no locked capital here, since that is done by the user
    let (result_2) = get_pool_balance(OPTION_PUT)
    let target_2 = 28134463574457816631959 # 12445 - 2 * 125.5... * 0.97
    assert result_2 = target_2

    _test_volatility(OPTION_CALL, maturity_01, 2306028306787561975)
    _test_volatility(OPTION_PUT, maturity_01, 2305472503387516769)
    _test_volatility(OPTION_CALL, maturity_1, Math64x61_ONE)
    _test_volatility(OPTION_PUT, maturity_1, Math64x61_ONE)

    _test_pool_option_balance(OPTION_CALL, strike_1000, maturity_01, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_CALL, strike_1000, maturity_01, TRADE_SIDE_SHORT, Math64x61_ONE)
    _test_pool_option_balance(OPTION_PUT, strike_1000, maturity_01, TRADE_SIDE_LONG, two)
    _test_pool_option_balance(OPTION_PUT, strike_1000, maturity_01, TRADE_SIDE_SHORT, 0)

    _test_pool_option_balance(OPTION_CALL, strike_1000, maturity_1, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_CALL, strike_1000, maturity_1, TRADE_SIDE_SHORT, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1000, maturity_1, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1000, maturity_1, TRADE_SIDE_SHORT, 0)

    _test_pool_option_balance(OPTION_CALL, strike_1100, maturity_01, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_CALL, strike_1100, maturity_01, TRADE_SIDE_SHORT, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1100, maturity_01, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1100, maturity_01, TRADE_SIDE_SHORT, 0)

    _test_pool_option_balance(OPTION_CALL, strike_1100, maturity_1, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_CALL, strike_1100, maturity_1, TRADE_SIDE_SHORT, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1100, maturity_1, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1100, maturity_1, TRADE_SIDE_SHORT, 0)

    # Trade 3 -------------------------------------------------------
    # Buy 25% of put option that someone else bought
    do_trade(account_id, OPTION_PUT, strike_1000, maturity_01, TRADE_SIDE_LONG, half)

    _test_volatility(OPTION_CALL, maturity_01, 2306028306787561975)
    _test_volatility(OPTION_PUT, maturity_01, 2305566983161341618)
    _test_volatility(OPTION_CALL, maturity_1, Math64x61_ONE)
    _test_volatility(OPTION_PUT, maturity_1, Math64x61_ONE)

    _test_pool_option_balance(OPTION_CALL, strike_1000, maturity_01, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_CALL, strike_1000, maturity_01, TRADE_SIDE_SHORT, Math64x61_ONE)
    _test_pool_option_balance(OPTION_PUT, strike_1000, maturity_01, TRADE_SIDE_LONG, one_and_half)
    _test_pool_option_balance(OPTION_PUT, strike_1000, maturity_01, TRADE_SIDE_SHORT, 0)

    _test_pool_option_balance(OPTION_CALL, strike_1000, maturity_1, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_CALL, strike_1000, maturity_1, TRADE_SIDE_SHORT, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1000, maturity_1, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1000, maturity_1, TRADE_SIDE_SHORT, 0)

    _test_pool_option_balance(OPTION_CALL, strike_1100, maturity_01, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_CALL, strike_1100, maturity_01, TRADE_SIDE_SHORT, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1100, maturity_01, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1100, maturity_01, TRADE_SIDE_SHORT, 0)

    _test_pool_option_balance(OPTION_CALL, strike_1100, maturity_1, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_CALL, strike_1100, maturity_1, TRADE_SIDE_SHORT, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1100, maturity_1, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1100, maturity_1, TRADE_SIDE_SHORT, 0)

    # Test pool_balance
    # Call pool did not change
    let (result_31) = get_pool_balance(OPTION_CALL)
    let target_31 = target_1
    assert result_31 = target_31


    # Put pool increased by premia a didn't change by locked capital since the option
    # was taken from pool_option_balance
    let (result_32) = get_pool_balance(OPTION_PUT)
    # 12445 - 2 * 125.58804990779984 * 0.97 + .5 * 125.5... * 1.03
    let target_32 = 28283579780099304915573
    assert result_32 = target_32

    # Trade 4 -------------------------------------------------------
    # Buy all of the long put option from the pool_option_balance and 0.5 on top of it
    do_trade(account_id, OPTION_PUT, strike_1000, maturity_01, TRADE_SIDE_LONG, two)

    _test_volatility(OPTION_CALL, maturity_01, 2306028306787561975)
    _test_volatility(OPTION_PUT, maturity_01, 2305942971103526059)
    _test_volatility(OPTION_CALL, maturity_1, Math64x61_ONE)
    _test_volatility(OPTION_PUT, maturity_1, Math64x61_ONE)

    _test_pool_option_balance(OPTION_CALL, strike_1000, maturity_01, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_CALL, strike_1000, maturity_01, TRADE_SIDE_SHORT, Math64x61_ONE)
    _test_pool_option_balance(OPTION_PUT, strike_1000, maturity_01, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1000, maturity_01, TRADE_SIDE_SHORT, half)

    _test_pool_option_balance(OPTION_CALL, strike_1000, maturity_1, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_CALL, strike_1000, maturity_1, TRADE_SIDE_SHORT, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1000, maturity_1, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1000, maturity_1, TRADE_SIDE_SHORT, 0)

    _test_pool_option_balance(OPTION_CALL, strike_1100, maturity_01, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_CALL, strike_1100, maturity_01, TRADE_SIDE_SHORT, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1100, maturity_01, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1100, maturity_01, TRADE_SIDE_SHORT, 0)

    _test_pool_option_balance(OPTION_CALL, strike_1100, maturity_1, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_CALL, strike_1100, maturity_1, TRADE_SIDE_SHORT, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1100, maturity_1, TRADE_SIDE_LONG, 0)
    _test_pool_option_balance(OPTION_PUT, strike_1100, maturity_1, TRADE_SIDE_SHORT, 0)

    # Test pool_balance
    # Call pool did not change
    let (result_41) = get_pool_balance(OPTION_CALL)
    let target_41 = target_1
    assert result_41 = target_41

    # Put pool increased by premia and didn't change by locked capital since the option
    # was taken from pool_option_balance
    let (result_42) = get_pool_balance(OPTION_PUT)
    # 12445 - 2 * 125.58804990779984 * 0.97 + 2.5 * 125.5... * 1.03 - 0.5*1000
    let target_42 = 27727183503722603837152
    assert result_42 = target_42

    return ()
end