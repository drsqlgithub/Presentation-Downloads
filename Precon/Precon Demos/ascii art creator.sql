--****************T-SQL ASCII Text-Art Creator****************
--************************************************************
--********************Only edit this stuff********************
--************************************************************
DECLARE @Face nvarchar(10) = 'Banner3' --Name of the font (must be available below)
DECLARE @S nvarchar(200) = 'demo' --What you want it to say
--************************************************************
--**********************Revision History**********************
--************************************************************
--20101116 - Narrowed the code to prep for sharing
--20101115 - Added 0-9.!?',(space) and another font
--20101112 - Created original with Banner3 font
--	     Fonts from http://patorjk.com/software/taag/
--	     (admittedly, used without permission)
--	     Created by LongboredSurfer.com
--	     Licensed under Creative Commons Attribution Share Alike
--	     http://creativecommons.org/licenses/by-sa/3.0/
--************************************************************


DECLARE @L1 nvarchar(1000), --The variables used to store
	@L2 nvarchar(1000), --the font to be used
	@L3 nvarchar(1000),
	@L4 nvarchar(1000),
	@L5 nvarchar(1000),
	@L6 nvarchar(1000),
	@L7 nvarchar(1000)
DECLARE @AlphaLen nvarchar(100) = '', --Length of the next character to display
	@AlphaStart nvarchar(100)='', --Starting position of @AlphaLen
	@Final nvarchar(max), --All stored in one variable at the end
	@CharOrder nvarchar(50) --Order of letters in the L1-L7 variables
		= 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.!?'', '

DECLARE @P1 nvarchar(1000) = '', --The final individual lines
	@P2 nvarchar(1000) = '', --which combine to make each
	@P3 nvarchar(1000) = '', --letter when stacked on top
	@P4 nvarchar(1000) = '', --of each other.
	@P5 nvarchar(1000) = '',
	@P6 nvarchar(1000) = '',
	@P7 nvarchar(1000) = ''
DECLARE @SU nvarchar(200) = UPPER(@S) --Convert the string to uppercase
DECLARE @StringLength int = LEN(@S) --How many times to loop through (1 character at a time)
DECLARE @J int = 0 --Counter for the subloop to figure out start position
DECLARE @K int = 0 --Start position for each letter in its @L1-7 string
DECLARE @L int = 0 --0-25 position of the letter for each loop
DECLARE @M int = 0 --Length of the character it's about to grab


IF @Face = '4max'
	BEGIN
		----4max           ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.!?',(space)
		SET @AlphaLen   = '867766762666867676667886657465767766336444'
		SET @AlphaStart = '186776676266686767666788665746576776633644'
		SET @L1 = '   db    88""Yb  dP""b8 8888b.  888888 888888  dP""b8 88  88 88  88888'
		SET @L2 = '  dPYb   88__dP dP   `"  8I  Yb 88__   88__   dP   `" 88  88 88     88'
		SET @L3 = ' dP__Yb  88""Yb Yb       8I  dY 88""   88""   Yb  "88 888888 88 o.  88'
		SET @L4 = 'dP""""Yb 88oodP  YboodP 8888Y"  888888 88      YboodP 88  88 88 "bodP '
		----       12345678910234567892023456789302345678940234567895023456789602345678970
		SET @L1 = @L1 + ' 88  dP 88     8b    d8 88b 88  dP"Yb  88""Yb  dP"Yb  88""Yb .dP"Y8'
		SET @L2 = @L2 + ' 88odP  88     88b  d88 88Yb88 dP   Yb 88__dP dP   Yb 88__dP `Ybo."'
		SET @L3 = @L3 + ' 88"Yb  88  .o 88YbdP88 88 Y88 Yb   dP 88"""  Yb b dP 88"Yb  o.`Y8b'
		SET @L4 = @L4 + ' 88  Yb 88ood8 88 YY 88 88  Y8  YbodP  88      `"YoYo 88  Yb 8bodP '
		----            71234567898023456789902345678910234567891103456789120345678913034567
		SET @L1 = @L1 + ' 888888 88   88 Yb    dP Y      P Yb  dP Yb  dP 8888P  dP"Yb    .d'
		SET @L2 = @L2 + '   88   88   88  Yb  dP  Yb db dP  YbdP   YbdP    dP  dP   Yb .d88'
		SET @L3 = @L3 + '   88   Y8   8P   YbdP    YbPYdP   dPYb    8P    dP   Yb   dP   88'
		SET @L4 = @L4 + '   88   `YbodP     YP      Y  P   dP  Yb  dP    d8888  YbodP    88'
		----           13891403456789150345678916034567891703456789180345678919034567892003
		SET @L1 = @L1 + ' oP"Yb. 88888   dP88  888888   dP"   888888P .dP"o. dP""Yb     d8b'
		SET @L2 = @L2 + ' "" dP"   .dP  dP 88  88oo.  .d8"        dP  `8b.d" Ybood8     Y8P'
		SET @L3 = @L3 + '   dP   o `Yb d888888    `8b 8P"""Yb    dP   d"`Y8b   .8P" .o. `" '
		SET @L4 = @L4 + ' .d8888 YbodP     88  8888P  `YboodP   dP    `bodP   .dP   `"  (8)'
		----           20456789210345678922034567892303456789240345678925034567892603456789
		SET @L1 = @L1 + ' oP"Yb.  .o.          '
		SET @L2 = @L2 + ' "" dP" ,dP"          '
		SET @L3 = @L3 + '   8P         .o.     '
		SET @L4 = @L4 + '  (8)        ,dP"     '
		----           270345678928034567892903
	END
IF @Face = 'Banner3'
	BEGIN
		----Banner3        ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.!?',(space)
		SET @AlphaLen   = '998988994888989999889999889699989899349444'
		SET @AlphaStart = '199898899488898999988999988969998989934944'
		SET @L1 = '   ###    ########   ######  ########  ######## ########  ######   '
		SET @L2 = '  ## ##   ##     ## ##    ## ##     ## ##       ##       ##    ##  '
		SET @L3 = ' ##   ##  ##     ## ##       ##     ## ##       ##       ##        '
		SET @L4 = '##     ## ########  ##       ##     ## ######   ######   ##   #### '
		SET @L5 = '######### ##     ## ##       ##     ## ##       ##       ##    ##  '
		SET @L6 = '##     ## ##     ## ##    ## ##     ## ##       ##       ##    ##  '
		SET @L7 = '##     ## ########   ######  ########  ######## ##        ######   '
		----       1234567891023456789202345678930234567894023456789502345678960234567
		SET @L1 = @L1 + '##     ## ####       ## ##    ## ##       ##     ## ##    ## '
		SET @L2 = @L2 + '##     ##  ##        ## ##   ##  ##       ###   ### ###   ## '
		SET @L3 = @L3 + '##     ##  ##        ## ##  ##   ##       #### #### ####  ## '
		SET @L4 = @L4 + '#########  ##        ## #####    ##       ## ### ## ## ## ## '
		SET @L5 = @L5 + '##     ##  ##  ##    ## ##  ##   ##       ##     ## ##  #### '
		SET @L6 = @L6 + '##     ##  ##  ##    ## ##   ##  ##       ##     ## ##   ### '
		SET @L7 = @L7 + '##     ## ####  ######  ##    ## ######## ##     ## ##    ## '
		----            68970234567898023456789902345678912345678911034567891203456789
		SET @L1 = @L1 + ' #######  ########   #######  ########   ######  ######## '
		SET @L2 = @L2 + '##     ## ##     ## ##     ## ##     ## ##    ##    ##    '
		SET @L3 = @L3 + '##     ## ##     ## ##     ## ##     ## ##          ##    '
		SET @L4 = @L4 + '##     ## ########  ##     ## ########   ######     ##    '
		SET @L5 = @L5 + '##     ## ##        ##  ## ## ##   ##         ##    ##    '
		SET @L6 = @L6 + '##     ## ##        ##    ##  ##    ##  ##    ##    ##    '
		SET @L7 = @L7 + ' #######  ##         ##### ## ##     ##  ######     ##    '
		----           130345678914034567891503456789160345678917034567891803456789
		SET @L1 = @L1 + '##     ## ##     ## ##     ## ##     ## ##    ## ######## '
		SET @L2 = @L2 + '##     ## ##     ## ##  #  ##  ##   ##   ##  ##       ##  '
		SET @L3 = @L3 + '##     ## ##     ## ##  #  ##   ## ##     ####       ##   '
		SET @L4 = @L4 + '##     ## ##     ## ##  #  ##    ###       ##       ##    '
		SET @L5 = @L5 + '##     ##  ##   ##  ##  #  ##   ## ##      ##      ##     '
		SET @L6 = @L6 + '##     ##   ## ##   ##  #  ##  ##   ##     ##     ##      '
		SET @L7 = @L7 + ' #######     ###     ### ###  ##     ##    ##    ######## '
		----           19034568920034567892103456789220345678923034567892403456789250
		SET @L1 = @L1 + '  #####     ##    #######   #######  ##        ########  #######  '
		SET @L2 = @L2 + ' ##   ##  ####   ##     ## ##     ## ##    ##  ##       ##     ## '
		SET @L3 = @L3 + '##     ##   ##          ##        ## ##    ##  ##       ##        '
		SET @L4 = @L4 + '##     ##   ##    #######   #######  ##    ##  #######  ########  '
		SET @L5 = @L5 + '##     ##   ##   ##               ## #########       ## ##     ## '
		SET @L6 = @L6 + ' ##   ##    ##   ##        ##     ##       ##  ##    ## ##     ## '
		SET @L7 = @L7 + '  #####   ###### #########  #######        ##   ######   #######  '
		----           25123456789260345678927034567892803456789290345678930034567893103456
		SET @L1 = @L1 + '########  #######   #######      ####  #######  ####          '
		SET @L2 = @L2 + '##    ## ##     ## ##     ##     #### ##     ## ####          '
		SET @L3 = @L3 + '    ##   ##     ## ##     ##     ####       ##   ##           '
		SET @L4 = @L4 + '   ##     #######   ########      ##      ###   ##   ####     '
		SET @L5 = @L5 + '  ##     ##     ##        ##             ##          ####     '
		SET @L6 = @L6 + '  ##     ##     ## ##     ## ### ####                 ##      '
		SET @L7 = @L7 + '  ##      #######   #######  ### ####    ##          ##       '
		----           3178932034567893303456789340345678935034567893603456789370345678
	END

DECLARE @Counter int = 0
WHILE @Counter < @StringLength
	BEGIN
		SET @Counter = @Counter+1
		SET @L --Determine the numeric value of the current letter (1-26)
			= CHARINDEX(SUBSTRING(@SU,@Counter,1),@CharOrder,0)
		SET @K = -1 --Set the start position over for the next letter
		SET @J = 0 --Reset the loop you're about to enter
		WHILE @J < @L
			BEGIN
				SET @J=@J+1	--The whole point of this loop, which is to figure
						--out the starting position of the character in the
						--giant strings that make up the ASCII letters
				SET @K=@K + CAST(SUBSTRING(@AlphaStart,@J,1) as int)+1
					--Add the width of all previous characters in the list
					--to figure out the starting position of the current
					--character (and add 1 extra for the spaces between letters)
				----Some debug stuff, which will show the character's position
				----being found. Good for helping to see if you have all the
				----character widths correct before the next one
				--PRINT 'Letter''s Starting Position (running): '+CAST(@K as nvarchar(10))+'.'
				--+' Current (Sub)Loop Count: '+CAST(@J as nvarchar(10))+'.'
			END
		SET @M = SUBSTRING(@AlphaLen,@L,1)+1 --Character's Length(including space)
		----More debug, to show the current status of things as it runs through the loop(s)
		--PRINT ' Letter = '+SUBSTRING(@SU,@Counter,1)+'/(#'+CAST(@L as nvarchar(10))+').'
		--	+' Character''s Length (@M): '+CAST(@M-1 as nvarchar(10))+'.'
		--	+' Starting Position (@K): '+CAST(@K as nvarchar(10))+'.'
		--	+' Counter: '+CAST(@Counter as nvarchar(10))+'.'
		--	+' Position of character:'+CAST(SUBSTRING(@SU,@Counter,1) as nvarchar(10))+'.'

		--Build
		SET @P1 = @P1 + SUBSTRING(@L1,@K,@M) --+ '||' --Helpful debug delimeter to show what
		SET @P2 = @P2 + SUBSTRING(@L2,@K,@M) --+ '||' --each cycle is pulling for each letter
		SET @P3 = @P3 + SUBSTRING(@L3,@K,@M) --+ '||' --or cycle through.
		SET @P4 = @P4 + SUBSTRING(@L4,@K,@M) --+ '||'
		SET @P5 = @P5 + SUBSTRING(@L5,@K,@M) --+ '||'
		SET @P6 = @P6 + SUBSTRING(@L6,@K,@M) --+ '||'
		SET @P7 = @P7 + SUBSTRING(@L7,@K,@M) --+ '||'
	END
----More debugging
--PRINT 'String Length: '+CAST(@StringLength as nvarchar(10))
SET @Final = (ISNULL(@P1,'') + CHAR(10)
	+ ISNULL(@P2,'') + CHAR(10)
	+ ISNULL(@P3,'') + CHAR(10)
	+ ISNULL(@P4,'') + CHAR(10)
	+ ISNULL(@P5,'') + CHAR(10)
	+ ISNULL(@P6,'') + CHAR(10)
	+ ISNULL(@P7,''))
PRINT @Final
