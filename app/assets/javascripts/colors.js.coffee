exports ?= this

colorMap =
    red : "ff0000"
    orange : "ffa500"
    yellow : "ffff00"
    green : "008f00"
    blue : "0000ff"
    indigo : "4b0082"
    violet : "ee82ee"

exports.ColorUtilities =
    colorToRgb : (c) ->
        if c in colorMap
            c = colorMap[c]
        val = parseInt c, 16
        r = (val >> 16) & 0xff
        g = (val >> 8) & 0xff
        b = val & 0xff
        return [r, g, b]

    makeRainbowTexture : (gl) ->
        arr = new Uint8Array(21)
        idx = 0
        for c, value of colorMap
            rgb = @colorToRgb value
            arr[idx++] = r for r in rgb
        texture = gl.createTexture()
        gl.bindTexture gl.TEXTURE_2D, texture
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, 7, 1, 0, gl.RGB, gl.UNSIGNED_BYTE, arr)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        gl.bindTexture gl.TEXTURE_2D, null
        return texture
        
