# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
    if false
        $.ajax '/binary',
            type: 'GET',
            success: (data) ->
                # unpack the data; it's 4-byte big-endian
                l = data.length
                nb = l/4
                for i in [0...nb]
                    d = data.charCodeAt(i*4)
                    for j in [1...4]
                        d = d * 256 + data.charCodeAt(i*4+j)
                    $('body').append d + '<br/>'

       
    # gl stuff
    drawScene = () ->
        widget = this
        gl = this.gl
        gl.viewport 0, 0, gl.viewportWidth, gl.viewportHeight
        gl.clear (gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        mat4.identity this.mvMatrix
        mat4.ortho(-1, 1, -1, -1, 1, -1, this.pMatrix)
        
        mat4.identity this.pMatrix

        this.setupShader = ->
            shaderProgram = this.shaderProgram
            this.setUniformMatrices('uMVMatrix', 'uPMatrix', 'uNMatrix')

        this.setupShader()
        this.vertexAttrib4f 'aColor', 1, 0.9, 0, 1

        bds =
            left : -0.5
            right : 0.5
            top : 0.5
            bottom : -0.5
        vertices = [
            bds.left, bds.bottom, 0,
            bds.right, bds.bottom, 0,
            bds.left, bds.top, 0,
            bds.right, bds.top, 0,
        ]
        normals = [
            0, 0, 1,
            0, 0, 1,
            0, 0, 1,
            0, 0, 1
        ]
        [u0, v0, u1, v1] = getUVOffsets widget.texture, Math.floor(widget.texture.depth / 2)
        uvs = [
            u0, v0
            u1, v0,
            u0, v1,
            u1, v1
        ]
        this.setFloatBufferData this.positionBuffer, vertices, 3
        this.setFloatAttribPointer 'aVertexPosition', this.positionBuffer
        this.setFloatBufferData this.normalBuffer, vertices, 3
        this.setFloatAttribPointer 'aVertexNormal', this.normalBuffer
        this.setFloatBufferData this.uvBuffer, uvs, 2
        this.setFloatAttribPointer 'aUV', this.uvBuffer

        this.uniform1f('uMin', this.minrange)
        this.uniform1f('uMax', this.maxrange)

        this.uniform1i 'uTexture', 0
        this.gl.activeTexture this.gl.TEXTURE0
        gl.bindTexture(gl.TEXTURE_2D, this.texture)
        gl.drawArrays gl.TRIANGLE_STRIP, 0, this.positionBuffer.numItems

    widget = null
    $('#canvas').mrlgl
        initialize: ->
            widget = this
            this.initProgram()
            this.positionBuffer = this.gl.createBuffer()
            this.normalBuffer = this.gl.createBuffer()
            this.uvBuffer = this.gl.createBuffer()
            this.enableVertexAttribArray("aUV", false)
            this.enableVertexAttribArray("aVertexPosition")
            this.gl.clearColor 0, 0, 0, 1
            this.gl.enable this.gl.DEPTH_TEST
            this.minrange = 0.0
            this.maxrange = 1.0

        draw : drawScene

    # texture-making functions
    makeTexture2d = (gl, maxval, height, width, data) ->
        idx = 0
        pixeldata = new Array(height * width)
        for i in [0 ... height]
            for j in [0 ... width]
                d = data[idx]
                pd = Math.round(d * 255 / maxval)
                pixeldata[idx] = pd
                idx += 1
        pixels = new Uint8Array(pixeldata)
        texture = gl.createTexture()
        gl.bindTexture gl.TEXTURE_2D, texture
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.LUMINANCE, texsz, texsz, 0, gl.LUMINANCE, gl.UNSIGNED_BYTE, pixels)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        return texture

    # make a texture
    gl = widget.gl
    texbits = []
    texsz = 256
    texsz2 = texsz/2
    for i in [0...texsz]
        f1 = (i - texsz2)/texsz2
        for j in [0...texsz]
            f2 = (j-texsz2)/texsz2
            z = Math.sqrt(1.0 - f1*f1 - f2*f2)
            texbits.push z
#     texture = makeTexture2d gl, 1, texsz, texsz, texbits
# 
#     widget.texture = texture

    _rowsz = 16

    _textureLayout = (texture) ->
        depth = texture.depth
        rowlen = if depth < _rowsz then depth else _rowsz
        nrows = Math.ceil(depth / rowlen)
        return [nrows, rowlen]

    getUVOffsets = (texture, d) ->
        depth = texture.depth
        [nrows, rowlen] = _textureLayout texture
        # nudge the bounds to the middle of the first and last pixels, so that there
        # won't be any interpolation from the adjacent patches
        ufudge = 0.5 / (texture.width * rowlen)
        vfudge = 0.5 / (texture.height * nrows)
        dx = d % rowlen
        dy = Math.floor(d / rowlen)
        delx = 1 / rowlen
        dely = 1 / Math.ceil(depth/rowlen)
        return [dx * delx + ufudge, dy * dely + vfudge, (dx+1) * delx - ufudge, (dy+1) * dely - vfudge]

    unpackInt = (string, idx) ->
        return string.charCodeAt(idx) * 256 + string.charCodeAt(idx+1)

    unpackTextureData = (data) ->
        len = data.length
        bits = unpackInt data, 0
        width = unpackInt data, 2
        height = unpackInt data, 4
        depth = unpackInt data, 6
        sz = width * height * depth
        pixels = new Uint8Array sz
        pixelsHigh = new Uint8Array sz
        
        rowlen = if depth < _rowsz then depth else _rowsz
        for d in [0 ... depth]
            xoff = d % rowlen
            yoff = Math.floor(d / _rowsz)
            for i in [0 ... height]
                for j in [0 ... width]
                    p = unpackInt data, 8 + 2 * ( d * height * width + i * width + j)
                    pixelIdx = (i + yoff * height) * rowlen * width + j + xoff * width
                    pixels[pixelIdx] = p
                    pixelsHigh[pixelIdx] = p >> 8
        return { bits : bits, width : width, height : height, depth : depth, pixels : pixels, pixelsHigh : pixelsHigh }

    makeTexture2dFromData = (widget, textureData) ->
        gl = widget.gl
        texture = gl.createTexture()
        gl.bindTexture gl.TEXTURE_2D, texture
        [nrows, rowlen] = _textureLayout textureData
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.LUMINANCE, textureData.width * rowlen, textureData.height * nrows, 0,
            gl.LUMINANCE, gl.UNSIGNED_BYTE, textureData.pixels)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        for p in ['height', 'width', 'depth']
            texture[p] = textureData[p]
        return texture

    # get data
    $.ajax '/binary3d',
        type: 'GET',
        success: (data) ->
            pixelData = unpackTextureData (base64.decode data)
            texture = makeTexture2dFromData widget, pixelData
            widget.texture = texture
            widget.draw()

    $('#window-width-slider').slider
        min : 0
        max : 1
        step : 0.01
        values : [0, 1]
        range : true
        slide : (event, ui) ->
            widget.minrange = $(this).slider('values', 0)
            widget.maxrange = $(this).slider('values', 1)
            widget.draw()

#     widget.draw()
