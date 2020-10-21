#
# Read an nrrd file
# For now, a very restricted set of those.
# only raw encoding
# only shorts

exports = this

class NrrdReader

    error: (msg) ->
        throw msg

    fieldFunctions :
        'type' : (data) ->
            switch data
                when 'unsigned char', 'uint8' then
                when 'signed char', 'int8' then
                when 'short', 'signed short', 'short int', 'int16' then
                when 'int', 'int32' then
                else
                    @error 'Only short/int/int8 data is allowed'
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
        'spacings' : (data) ->
            parts = data.split /\s+/
            @spacings = (parseFloat f for f in parts)
                        
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
            if @spacings
                for i in [0 .. 2]
                    if !isNaN @spacings[i]
                        vec3.scale @vectors[i], @spacings[i]

    makeValueArray : ->
        sz = 1
        sz *= s for s in @sizes
        pos = @pos
        data = @data
        arr = null
        max = 0
        min = Infinity
        switch @type
            when 'signed char', 'int8'
                arr = new Int8Array sz
                for i in [0 ... sz ]
                    iidx = pos + i
                    arr[i] = (data.charCodeAt(iidx) & 0xff)
                    max = Math.max max, arr[i]
                    min = Math.min min, arr[i]
            when 'unsigned char', 'uint8'
                arr = new Uint8Array sz
                for i in [0 ... sz ]
                    iidx = pos + i
                    arr[i] = (data.charCodeAt(iidx) & 0xff)
                    max = Math.max max, arr[i]
                    min = Math.min min, arr[i]
            when 'short', 'signed short', 'short int', 'int16'
                arr = new Int16Array sz
                if @endian == 'big'
                    for i in [0 ... sz ]
                        iidx = pos + i*2
                        arr[i] = (data.charCodeAt(iidx) & 0xff) * 256 + (data.charCodeAt(iidx+1) & 0xff)
                        max = Math.max max, arr[i]
                        min = Math.min min, arr[i]
                else
                    for i in [0 ... sz ]
                        iidx = pos + i*2
                        arr[i] = (data.charCodeAt(iidx+1) & 0xff) * 256 + (data.charCodeAt(iidx) & 0xff)
                        max = Math.max max, arr[i]
                        min = Math.min min, arr[i]
            when 'int', 'int32'
                arr = new Int32Array sz
                if @endian == 'big'
                    for i in [0 ... sz ]
                        iidx = pos + i*4
                        arr[i] = (data.charCodeAt(iidx) & 0xff) * 0x1000000 \
                            + (data.charCodeAt(iidx+1) & 0xff) * 0x10000 \
                            + (data.charCodeAt(iidx+2) & 0xff) * 256 \
                            + (data.charCodeAt(iidx+3) & 0xff)
                        max = Math.max max, arr[i]
                        min = Math.min min, arr[i]
                else
                    for i in [0 ... sz ]
                        iidx = pos + i*4
                        arr[i] = (data.charCodeAt(iidx+3) & 0xff) * 0x1000000 \
                            + (data.charCodeAt(iidx+2) & 0xff) * 0x10000 \
                            + (data.charCodeAt(iidx+1) & 0xff) * 256 \
                            + (data.charCodeAt(iidx) & 0xff)
                        max = Math.max max, arr[i]
                        min = Math.min min, arr[i]
        @max ?= max
        if min < 0
            for i in [0 ... sz]
                arr[i] -= min
            @max -= min
        return arr

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
