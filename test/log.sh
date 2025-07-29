#!/usr/bin/env bash

source $(dirname $0)/../core/log.sh

LOG_PANIC=false

log custom Custom message
log debug Debug message
log info 'Informational message'
log notice "Significant message"
log warning Warning message
log error Error message

log colors Foreground: \
	/clr:[r!] Red \
	/clr:[g!] Green \
	/clr:[b!] Blue \
	/clr:[c!] Cyan \
	/clr:[y!] Yellow \
	/clr:[w!] White \
	/clr:[p!] Purple \
	/clr:[d!] Black

log colors Background: \
	/clr:RED Red \
	/clr:GREEN Green \
	/clr:BLUE Blue \
	/clr:CYAN Cyan \
	/clr:YELLOW Yellow \
	/clr:WHITE White \
	/clr:PURPLE Purple \
	/clr:BLACK Black

log colors Styles: \
	Regular \
	/clr:dim Dim \
	/clr:bold Bold \
	/clr:blink Blink \
	/clr:italic Italic \
	/clr:reverse Reverse \
	/clr:overline Overline \
	/clr:underline Underline \
	/clr:strikethrough Strikethrough \
	/clr:invisible Invisible

echo Errors: $(log_count error)
echo Warnings: $(log_count warning)
echo Total: $(log_count)
