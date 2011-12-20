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
        mat4.identity this.pMatrix
        this.camera.setMatrices this

        this.setupShader = ->
            shaderProgram = this.shaderProgram
            this.setUniformMatrices('uMVMatrix', 'uPMatrix', 'uNMatrix')

        this.setupShader()

        if @slice?
            @slice.draw this

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
            this.gl.clearColor 0.75, 0.75, 0.75, 1
            this.gl.enable this.gl.DEPTH_TEST
            this.minrange = 0.0
            this.maxrange = 1.0

            this.camera = new mrlCamera
                eye : [5, 5, 5],
                direction : [-1, -1, -1],
                up : [0, 0, 1],
                focalDist : 10,
                near : 0.1,
                far : 20,
                angle : 30

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

    class TextureObject
        _rowsz : 16

        constructor : ->

        _textureLayout : (data) ->
            data ?= this
            _rowsz = @_rowsz
            depth = data.depth
            rowlen = if depth < _rowsz then depth else _rowsz
            nrows = Math.ceil(depth / rowlen)
            return [nrows, rowlen]

        getUVOffsets : (d) ->
            depth = @depth
            [nrows, rowlen] = @_textureLayout()
            # nudge the bounds to the middle of the first and last pixels, so that there
            # won't be any interpolation from the adjacent patches
            ufudge = 0.5 / (@width * rowlen)
            vfudge = 0.5 / (@height * nrows)
            dx = d % rowlen
            dy = Math.floor(d / rowlen)
            delx = 1 / rowlen
            dely = 1 / Math.ceil(depth/rowlen)
            return [dx * delx + ufudge, dy * dely + vfudge, (dx+1) * delx - ufudge, (dy+1) * dely - vfudge]

        unpackInt : (string, idx) ->
            return string.charCodeAt(idx) * 256 + string.charCodeAt(idx+1)

        unpackTextureData : (data, swizzle = ( (x) -> x ), unswizzle = (x) -> x ) ->
            len = data.length
            unpackInt = @unpackInt
            bits = unpackInt data, 0
            widthIn = unpackInt data, 2
            heightIn = unpackInt data, 4
            depthIn = unpackInt data, 6
            [width, height, depth] = swizzle [widthIn, heightIn, depthIn]
            sz = width * height * depth
            pixels = new Uint8Array sz
            pixelsHigh = new Uint8Array sz
            
            _rowsz = @_rowsz
            rowlen = if depth < _rowsz then depth else _rowsz
            for d in [0 ... depth]
                xoff = d % rowlen
                yoff = Math.floor(d / _rowsz)
                for i in [0 ... height]
                    for j in [0 ... width]
                        [jIn, iIn, dIn] = unswizzle [j, i, d]
                        p = unpackInt data, 8 + 2 * ( dIn * heightIn * widthIn + iIn * widthIn + jIn)
                        pixelIdx = (i + yoff * height) * rowlen * width + j + xoff * width
                        pixels[pixelIdx] = p
                        pixelsHigh[pixelIdx] = p >> 8
            return { bits : bits, width : width, height : height, depth : depth, pixels : pixels, pixelsHigh : pixelsHigh }

        makeTexture2dFromData : (widget, textureData) ->
            gl = widget.gl
            [nrows, rowlen] = @_textureLayout textureData

            makeTexture = (pixels) =>
                texture = gl.createTexture()
                gl.bindTexture gl.TEXTURE_2D, texture
                gl.texImage2D(gl.TEXTURE_2D, 0, gl.LUMINANCE, textureData.width * rowlen, textureData.height * nrows, 0,
                    gl.LUMINANCE, gl.UNSIGNED_BYTE, pixels)
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
                return texture
            obj = new TextureObject
            for p in ['bits', 'height', 'width', 'depth']
                obj[p] = textureData[p]
            obj.texture = makeTexture textureData.pixels
            obj.textureHigh = makeTexture textureData.pixelsHigh
            return obj

        getMaxLimit : ->
            return (1 << @bits) - 1

        setTextureUniforms : (widget, lowvar, highvar) ->
            gl = widget.gl
            widget.uniform1i lowvar, 0
            gl.activeTexture gl.TEXTURE0
            gl.bindTexture(gl.TEXTURE_2D, @texture)
            if highvar?
                widget.uniform1i highvar, 1
                gl.activeTexture gl.TEXTURE1
                gl.bindTexture gl.TEXTURE_2D, @textureHigh

    class SliceObject
        constructor : (@textureObj) ->
            @level = 0.5

        draw : (widget) ->
            gl = widget.gl
            texture = @textureObj
            bds =
                left : -1
                right : 1
                top : 1
                bottom : -1

            z = -1 + 2 * @level 
            vertices = [
                bds.left, bds.bottom, z,
                bds.right, bds.bottom, z,
                bds.left, bds.top, z,
                bds.right, bds.top, z,
            ]
            normals = [
                0, 0, 1,
                0, 0, 1,
                0, 0, 1,
                0, 0, 1
            ]
            [u0, v0, u1, v1] = texture.getUVOffsets Math.round(@level * (texture.depth-1))
            uvs = [
                u0, v0
                u1, v0,
                u0, v1,
                u1, v1
            ]
            widget.setFloatBufferData widget.positionBuffer, vertices, 3
            widget.setFloatAttribPointer 'aVertexPosition', widget.positionBuffer
            widget.setFloatBufferData widget.normalBuffer, vertices, 3
            widget.setFloatAttribPointer 'aVertexNormal', widget.normalBuffer
            widget.setFloatBufferData widget.uvBuffer, uvs, 2
            widget.setFloatAttribPointer 'aUV', widget.uvBuffer

            widget.uniform1f('uMin', widget.minrange)
            widget.uniform1f('uMax', widget.maxrange)

            widget.uniform1f 'uMaxLimit', texture.getMaxLimit()
            texture.setTextureUniforms widget, 'uTextureLow', 'uTextureHigh'

            gl.drawArrays gl.TRIANGLE_STRIP, 0, widget.positionBuffer.numItems


    # get data
    $.ajax '/binary3d',
        type: 'GET',
        success: (data) ->
            pixelData = TextureObject::unpackTextureData (base64.decode data) #,
#                 ([x, y, z]) -> [y, z, x],
#                 ([y, z, x]) -> [x, y, z]
            textureObj = TextureObject::makeTexture2dFromData widget, pixelData
            widget.slice = new SliceObject textureObj
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

    $('#z-depth-slider').slider
        min : 0
        max : 1
        step : 1/128 
        value : 0.5
        slide : (event, ui) ->
            widget.slice.level = ui.value
            widget.draw()


#     widget.draw()
