//@version=4
strategy(title="ORB-A intraday scalping with CPR Sqeeze filter", overlay=true)

time_frame_cpr = input(defval='D', title='Timeframe for CPR', type=input.resolution)
tolerance = input(defval=0.0, title="Tolerance", type=input.float)
time_frame_m = input(defval='1D', title="Resolution for ORB", options=['1m', '5m', '10m', '15m', '30m', '45m', '1h', '2h', '4h', '1D', '2D', '4D', '1W', '2W', '1M', '2M', '6M'])
stop_loss = input(1.0,   title="Stop loss", type=input.float)
use_sperc = input(false, title='Stop loss & tolerance are in %centage(s)', type=input.bool)
use_iday  = input(false, title='Use intraday', type=input.bool)
use_tstop = input(true,  title='Use trailing stop', type=input.bool)
end_hr    = input(15,    title='End session hour', type=input.integer)
end_min   = input(14,    title='End session minutes', type=input.integer)
cpr_sqeeze_tol = input(1.0,       title='CPR Sqeeze tolerance', type=input.float)
cpr_sq_filter  = input(false,     title='Use cpr sqeeze filter', type=input.bool)


get_time_frame(tf) =>
    (tf == '1m')  ? "1"
  : (tf == '5m')  ? "5"
  : (tf == '10m') ? "10"
  : (tf == '15m') ? "15"
  : (tf == '30m') ? "30"
  : (tf == '45m') ? "45"
  : (tf == '1h')  ? "60"
  : (tf == '2h')  ? "120"
  : (tf == '4h')  ? "240"
  : (tf == '1D')  ? "D"
  : (tf == '2D')  ? "2D"
  : (tf == '4D')  ? "4D"
  : (tf == '1W')  ? "W"
  : (tf == '2W')  ? "2W"
  : (tf == '1M')  ? "M"
  : (tf == '2M')  ? "2M"
  : (tf == '6M')  ? "6M"
  : "wrong resolution"
//
time_frame = get_time_frame(time_frame_m)


is_newbar(res) =>
    change(time(res)) != 0
//

// check if this candle is close of session
chk_close_time(hr, min) =>
    time_sig = (hour[0] == hr) and (minute[0] > min and minute[1] < min)
    time_sig
//

// chechk if this candle doesn't fall in close session
chk_not_close_time(hr) =>
    time_ncs = (hour[0] < hr)
    [time_ncs]
//

pivot_cpr(time_frame_c) =>
    prev_close     = security(syminfo.tickerid, time_frame_c, close[1], lookahead=true)
    prev_open      = security(syminfo.tickerid, time_frame_c, open[1], lookahead=true)
    prev_high      = security(syminfo.tickerid, time_frame_c, high[1], lookahead=true)
    prev_low       = security(syminfo.tickerid, time_frame_c, low[1], lookahead=true)

    pi_level       = (prev_high + prev_low + prev_close)/3
    bc_level       = (prev_high + prev_low)/2
    tc_level       = (pi_level - bc_level) + pi_level
    r1_level       = pi_level * 2 - prev_low
    s1_level       = pi_level * 2 - prev_high
    r2_level       = (pi_level - s1_level) + r1_level
    s2_level       = pi_level - (r1_level - s1_level)
    
    [pi_level, tc_level, bc_level, r1_level, s1_level, r2_level, s2_level, prev_high, prev_low]
//

[pi_level, tc_level, bc_level, r1_level, s1_level, r2_level, s2_level, prev_high, prev_low] = pivot_cpr(time_frame_cpr)
cpr_sqeeze = abs(tc_level - bc_level)


high_range  = valuewhen(is_newbar('D'), high, 0)
low_range   = valuewhen(is_newbar('D'), low,  0)

high_rangeL = security(syminfo.tickerid, time_frame, high_range)
low_rangeL  = security(syminfo.tickerid, time_frame, low_range)
//range       = (high_rangeL - low_rangeL)/low_rangeL

//stop_l = use_sperc ? close*(1-stop_loss/100.0) : (close - stop_loss)
//stop_s = use_sperc ? close*(1+stop_loss/100.0) :  (close + stop_loss)
stop_l = use_sperc ? strategy.position_avg_price*(1-stop_loss/100.0) : (strategy.position_avg_price-stop_loss)
stop_s = use_sperc ? strategy.position_avg_price*(1+stop_loss/100.0) : (strategy.position_avg_price+stop_loss)
if use_tstop
    stop_l := use_sperc ? close*(1-stop_loss/100.0) : (close - stop_loss)
    stop_s := use_sperc ? close*(1+stop_loss/100.0) :  (close + stop_loss)
//
tolbu  = use_sperc ? high_rangeL*(1+tolerance/100.0) : (high_rangeL + tolerance)
tolbl  = use_sperc ? low_rangeL*(1-tolerance/100.0) : (low_rangeL-tolerance)

buy    = use_iday ? (crossover(close, tolbu) and (hour < end_hr)) : crossover(close, tolbu)
sell   = use_iday ? (crossunder(close, stop_l[1]) or chk_close_time(end_hr, end_min)) : crossunder(close, stop_l[1])
short  = use_iday ? (crossunder(close, tolbl) and (hour < end_hr)) : crossunder(close, tolbl)
cover  = use_iday ? (crossover(close, stop_s[1]) or chk_close_time(end_hr, end_min)) : crossover(close, stop_s[1])

if use_iday
    if cpr_sq_filter
        buy    := use_sperc ? (buy and (cpr_sqeeze/tc_level*100 < cpr_sqeeze_tol)) : (buy and (cpr_sqeeze[0] < cpr_sqeeze_tol))
        short  := use_sperc ? (short and (cpr_sqeeze/tc_level*100 < cpr_sqeeze_tol)) : (short and (cpr_sqeeze[0] < cpr_sqeeze_tol))
    //
//

strategy.entry("L", strategy.long, when=buy)
strategy.close("L", when=sell)
strategy.entry("S", strategy.short, when=short)
strategy.close("S", when=cover)

//plotshape(range < 0.01, style=shape.circle, location=location.belowbar, color=color.red)
plot(high_rangeL, color=color.green, linewidth=2) 
plot(low_rangeL,  color=color.red, linewidth=2) 

