
# About:
#  generate color escape-codes into COLORS array,
#  where first element is always none-color-code.
# Usage:
# > color style,color,COLOR [codes] ...
# Where:
#  @style: one or any of: bold,dim,italic,overline,underline,blink,invisible,strikethrough,reverse
#  @color: (lowercase) foreground color one of: dark|red|green|yellow|blue|purple|cyan|white
#  @COLOR: (uppercase) background color one of: DARK|RED|GREEN|YELLOW|BLUE|PURPLE|CYAN|WHITE
#  @codes: combination of one-char codes of:
#   ! (bold)
#   * (blink)
#   % (reverse)
#   ? (invisible)
#   _ (underline)
#   - (strikethrough)
#   / (italic)
#   c (foreground color)
#   C (background color)
# Example:
# > color bold,red,WHITE [/G!] # generate two colors
# > printf "${COLORS[1]}Hello${COLORS[2]}World${COLORS[0]}"
#

declare -A COLOR_PALETTE
COLOR_PALETTE[d]=0 # dark (black)
COLOR_PALETTE[r]=1 # red
COLOR_PALETTE[g]=2 # green
COLOR_PALETTE[y]=3 # yellow
COLOR_PALETTE[b]=4 # blue
COLOR_PALETTE[p]=5 # purple
COLOR_PALETTE[c]=6 # cyan
COLOR_PALETTE[w]=7 # white

declare -A COLOR_STYLES
COLOR_STYLES[bold]=1
COLOR_STYLES[dim]=2
COLOR_STYLES[italic]=3
COLOR_STYLES[underline]=4
COLOR_STYLES[blink]=5
COLOR_STYLES[reverse]=7
COLOR_STYLES[invisible]=8
COLOR_STYLES[strikethrough]=9
COLOR_STYLES[overline]=53

if [[ $(tput colors 2>/dev/null) == 256 ]]; then
	COLOR_ON=true
	COLOR0='\e[0m'
else
	COLOR_ON=false
fi
COLORS=()

color() {
	COLORS=($COLOR0)
	$COLOR_ON || return 1
	local style styles=()
	while (("$#")); do
		styles=()
		case $1 in
			none|0)
				COLORS+=($COLOR0)
				shift; continue;;
			\[*\]) # styles by codes
				for ((i = 1; i < ${#1}-1; ++i)); do
					style=${1:$i:1}; case $style in
						\!) styles+=(${COLOR_STYLES[bold]});;
						\*) styles+=(${COLOR_STYLES[blink]});;
						\?) styles+=(${COLOR_STYLES[invisible]});;
						%) styles+=(${COLOR_STYLES[reverse]});;
						/) styles+=(${COLOR_STYLES[italic]});;
						-) styles+=(${COLOR_STYLES[strikethrough]});;
						_) styles+=(${COLOR_STYLES[underline]});;
						[a-z]) styles+=(3${COLOR_PALETTE[$style]});;
						[A-Z]) styles+=(4${COLOR_PALETTE[${style,,}]});;
					esac
				done
			;;
			*) # styles by words
				for style in ${1//,/ }; do
					local lower=${style,,}
					case $lower in
						red|green|yellow|blue|purple|cyan|white|black|dark)
							if [[ $style == ${style^^} ]]
								then local digit=4 # background
								else local digit=3 # foreground
							fi
							style=${lower/black/dark}
							styles+=(${digit}${COLOR_PALETTE[${style:0:1}]})
						;;
						*) if [[ ${COLOR_STYLES[$lower]+x} ]]; then
								styles+=(${COLOR_STYLES[$lower]})
							fi
						;;
					esac
				done
			;;
		esac
		if ((${#styles[@]})); then
			style="${styles[*]}"
			COLORS+=('\e['${style// /;}m)
		fi
		shift
	done
}
