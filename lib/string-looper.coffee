_aEnums = [
    [ "yes", "no" ]
    [ "true", "false" ]
    [ "True", "False" ]
    [ "relative", "absolute", "fixed"  ]
    [ "top", "bottom" ]
    [ "left", "right" ]
    [ "width", "height" ]
    [ "margin", "padding" ]
    [ "block", "none", "inline", "inline-block" ]
    [ "h1", "h2", "h3", "h4", "h5", "h6" ]
    [ "am", "pm" ]
    [ "sun", "mon", "tue", "wed", "thu", "fri", "sat" ]
    [ "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday" ]
    [ "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec" ]
    [ "TODO", "DONE", "FIXME" ]
]

_rNumberExtractor = /^-?(\d+|\d+\.|\d+\.+\d+|\.\d+){1}[a-zA-Z%]*$/
_rNumberMatcher = /[0-9\.-]/

aEnums = []

_mergeEnums = ( aEnumsToMerge ) ->
    ( aEnums = _aEnums.concat aEnumsToMerge ).reverse()

_findAnEnum = ( sWord ) ->
    for aEnum in aEnums
        return aEnum if aEnum.indexOf( sWord ) > -1
    no

_getPrecision = ( iNumber ) ->
    d = ( s = "#{ iNumber }" ).indexOf( "." ) + 1
    if not d then 0 else s.length - d

module.exports =
    config:
        wordRegex:
            title: "Word RegExp"
            description: "A RegExp indicating what constitutes a 'word' (default will use the Atom's built-in Word RegExp)"
            type: "string"
            default: ""
        enums:
            type: "array"
            default: [ [ "yes", "no" ] ]
            items:
                type: "array"

    activate: ->
        _mergeEnums atom.config.get "string-looper.enums"
        atom.config.observe "string-looper.enums", _mergeEnums
        atom.commands.add "atom-text-editor:not([mini])",
            "string-looper:loop-up": => @loop()
            "string-looper:loop-down": => @loop "down"
            "string-looper:loop-up-at-cursor": => @loop "up", yes
            "string-looper:loop-down-at-cursor": => @loop "down", yes

    loop: ( sDirection = "up", bAtCursorPosition = no ) ->
        aCursorPositions = ( oEditor = atom.workspace.getActiveTextEditor() ).getCursorBufferPositions()
        for oCursor in oEditor.cursors
            oCursorWordRange = oCursor.getCurrentWordBufferRange
                wordRegex: atom.config.get( "string-looper.wordRegex" ) or oCursor.wordRegExp()
            sWord = oCursor.editor.getTextInRange oCursorWordRange

            # it's a number
            # TODO this part could have a decent refactor
            if aMatching = _rNumberExtractor.test sWord
                iIncrementValue = 1
                sLine = oCursor.editor.lineTextForBufferRow oCursor.getBufferPosition().row
                # extend word till spaces
                    # left
                i = 0
                ++i while _rNumberMatcher.test ( sChar = sLine.charAt oCursorWordRange.start.column - ( i + 1 ) ).trim()
                oCursorWordRange.start.column -= i
                    # right
                if bAtCursorPosition
                    sWordBeforeShifting = oCursor.editor.getTextInRange oCursorWordRange
                    oCursorWordRange.end.column = oCursor.getBufferPosition().column
                    sExtendedWord = oCursor.editor.getTextInRange oCursorWordRange
                    if sExtendedWord.charAt( sExtendedWord.length - 1 ) is "-"
                        oCursorWordRange.end.column += 1
                        sExtendedWord = oCursor.editor.getTextInRange oCursorWordRange
                    iPrecision = _getPrecision( sExtendedWord )
                else
                    i = 0
                    ++i while _rNumberMatcher.test ( sChar = sLine.charAt oCursorWordRange.start.column + i ).trim()
                    oCursorWordRange.end.column = oCursorWordRange.start.column + i
                    sExtendedWord = oCursor.editor.getTextInRange oCursorWordRange
                # if word ends with a point, exclude it.
                if sExtendedWord.charAt( sExtendedWord.length - 1 ) is "."
                    oCursorWordRange.end.column -= 1
                    sExtendedWord = oCursor.editor.getTextInRange oCursorWordRange
                iNumber = +sExtendedWord
                if iPrecision
                    iNumber *= Math.pow 10, iPrecision
                    iNumber = Math.trunc iNumber
                iNumber = if sDirection is "up" then iNumber + iIncrementValue else iNumber - iIncrementValue
                iNumber /= Math.pow( 10, iPrecision ) if iPrecision
                sNewWord = iNumber.toString()

            # it's an enum-listed word
            else if aEnum = _findAnEnum sWord
                sNewWord = aEnum[ aEnum.indexOf( sWord ) + ( if sDirection is "up" then 1 else -1 ) ] ? aEnum[ if sDirection is "up" then 0 else ( aEnum.length - 1 ) ]

            # cycle (lowercase/uppercase/camelCase at cursor position)
            else
                sNewWord = sWord
                iCursorPosition = oCursor.getBufferPosition().column - oCursorWordRange.start.column
                iCurrentLoop = switch
                    # detect snakeCase
                    when sNewWord.slice(iCursorPosition, iCursorPosition + 1) is "_"
                      sNewWord = sNewWord.slice( 0, iCursorPosition ).toLowerCase() + sNewWord.slice( iCursorPosition + 1).toLowerCase()
                      if sDirection is "up" then 0 else 2
                    when sNewWord.toLowerCase() is sNewWord
                      if sDirection is "up" then 1 else 3
                    when sNewWord.toUpperCase() is sNewWord
                      if sDirection is "up" then 2 else 0
                    else
                      if sDirection is "up" then 3 else 1
                switch iCurrentLoop
                    when 0 # lowerCase
                        sNewWord = sNewWord.toLowerCase()
                    when 1 # upperCase
                        sNewWord = sNewWord.toUpperCase()
                    when 2 # camelCase at cursor position
                        iCursorPosition = oCursor.getBufferPosition().column - oCursorWordRange.start.column
                        sNewWord = sNewWord.slice( 0, iCursorPosition ).toLowerCase() + sNewWord.slice( iCursorPosition, iCursorPosition + 1 ).toUpperCase() + sNewWord.slice( iCursorPosition + 1 ).toLowerCase()
                    when 3 # snakeCase at cursor position
                        sNewWord = sNewWord.slice( 0, iCursorPosition ).toLowerCase() + "_" + sNewWord.slice( iCursorPosition).toLowerCase()
            oEditor.setTextInBufferRange oCursorWordRange, sNewWord

        oEditor.setCursorBufferPosition aCursorPositions[ aCursorPositions.length - 1 ]
