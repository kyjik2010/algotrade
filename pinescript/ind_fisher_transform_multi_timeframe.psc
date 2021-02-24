//@version=4
study(title="Fisher Transform MTR", overlay=false)

/////////////////////////////////////////////////////////////////////
// Inputs
fish_len    = input(defval=10,     title='Channel Length', type=input.integer)
param1      = input(defval=0.33,   title='Param 1', type=input.float, maxval=1.0, minval=0.0, step=0.01)
param2      = input(defval=0.5,    title='Param 2', type=input.float, maxval=1.0, minval=0.0, step=0.01)
time_frame  = input(defval='1D',   title='Time Frame', type=input.resolution)

//////////////////////////////////////////////////////////////////
// Calculate signals

fisher_transform(fish_len, param1, param2) =>
    max_hi      = highest(hl2, fish_len)
    min_lo      = lowest(hl2, fish_len)
    value1      = 0.0
    value1      := param1 * 2 * ((hl2 - min_lo) / (max_hi - min_lo) - 0.5) + (1 - param1) * nz(value1[1])
    value2      = iff(value1 > .99,  .999,
	                  iff(value1 < -.99, -.999, value1))
    fish_t      = 0.0
    fish_t      := param2 * log((1 + value2) / (1 - value2)) + 0.5 * nz(fish_t[1])
//

fish = security(syminfo.tickerid, time_frame, fisher_transform(fish_len, param1, param2))

/////////////////////////////////////////////////////////////////
// Plots
plot(fish,           color=color.green, title="Fisher")
plot(nz(fish[1]),    color=color.red,   title="Trigger")
