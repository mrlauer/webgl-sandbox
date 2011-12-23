#
# Read an nrrd file
# For now, a very restricted set of those.
# only raw encoding
# only shorts

exports ?= this

class NrrdReader

    error: (msg) ->

    fieldFunctions :
        'type' : (data) ->
            if data != 'short'
                @error()
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
            if l.match /^#/
                # comment
            else if m = l.match /(.*):(.*)/
                # data
                field = m[1].trim()
                data = m[2].trim()
                fn = @fieldFunctions[field]
                if fn
                    fn.call this, data

    getIntFn : ->
        pos = @pos
        data = @data
        if @endian == 'big'
            return (idx) ->
                iidx = pos + idx*2
                return (data.charCodeAt(iidx) & 0xff) * 256 + (data.charCodeAt(iidx+1) & 0xff)
        else
            return (idx) ->
                iidx = pos + idx*2
                return (data.charCodeAt(iidx+1) & 0xff) * 256 + (data.charCodeAt(iidx) & 0xff)
        

exports.NrrdReader = NrrdReader
