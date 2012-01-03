#
# Read an nrrd file
# For now, a very restricted set of those.
# only raw encoding
# only shorts

exports ?= this

class NrrdReader

    error: (msg) ->
        throw msg

    fieldFunctions :
        'type' : (data) ->
            if data != 'short' && data != 'int'
                @error 'Only short/int data is allowed'
            @type = data
        'endian' : (data) ->
            @endian = data
        'dimension' : (data) ->
            @dim = parseInt(data)
        'sizes' : (data) ->
            @sizes = (parseInt i for i in data.split /\s+/)
        'space directions' : (data) ->
            parts = data.match /\(.*?\)/g
            @vectors = ( (parseFloat f for f in v[1...-1].split /,/) for v in parts)
                        
    constructor: (@data) ->
        @pos = 0

    getHeader: ->
        # looks for a blank line
        m = @data.match /^([\s\S]*?)\r?\n\r?\n/
        if m
            @pos = m[0].length
            return m[1]
        else
            return ""

    parseHeader: ->
        header = @getHeader()
        lines = header.split /\r?\n/
        for l in lines
            if l.match /NRRD\d+/
                @isNrrd = true
            else if l.match /^#/
                # comment
            else if m = l.match /(.*):(.*)/
                # data
                field = m[1].trim()
                data = m[2].trim()
                fn = @fieldFunctions[field]
                if fn
                    fn.call this, data
                else
                    this[field] = data

        # Some assertions
        if !@isNrrd
            @error "Not an NRRD file"
        if @encoding != 'raw'
            @error "Only raw encoding is allowed"

        # make sure we have some spacing
        if not @vectors?
            @vectors = [
                [1, 0, 0],
                [0, 1, 0],
                [0, 0, 1]
            ]



    getValueFn : ->
        pos = @pos
        data = @data
        if @type == 'short'
            if @endian == 'big'
                return (idx) ->
                    iidx = pos + idx*2
                    return (data.charCodeAt(iidx) & 0xff) * 256 + (data.charCodeAt(iidx+1) & 0xff)
            else
                return (idx) ->
                    iidx = pos + idx*2
                    return (data.charCodeAt(iidx+1) & 0xff) * 256 + (data.charCodeAt(iidx) & 0xff)
        else if @type == 'int'
            if @endian == 'big'
                return (idx) ->
                    iidx = pos + idx*4
                    return (data.charCodeAt(iidx) & 0xff) * 0x1000000 \
                        + (data.charCodeAt(iidx+1) & 0xff) * 0x10000 \
                        + (data.charCodeAt(iidx+2) & 0xff) * 256 \
                        + (data.charCodeAt(iidx+3) & 0xff)
            else
                return (idx) ->
                    iidx = pos + idx*4
                    return ((data.charCodeAt(iidx+3) & 0xff) * 0x1000000 \
                        + (data.charCodeAt(iidx+2) & 0xff) * 0x10000 \
                        + (data.charCodeAt(iidx+1) & 0xff) * 256 \
                        + (data.charCodeAt(iidx) & 0xff))
        

exports.NrrdReader = NrrdReader
