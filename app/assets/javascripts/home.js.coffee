# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

#= require webgl
#= require readnrrd
#= require filewidget
#= require viewcontroller

$ ->
    # TODO: move this!

    vec3.linComb = (vec1, s1, vec2, s2, dest) ->
        if(!dest)
            dest = vec1
        dest[0] = vec1[0] * s1 + vec2[0] * s2
        dest[1] = vec1[1] * s1 + vec2[1] * s2
        dest[2] = vec1[2] * s1 + vec2[2] * s2
        return dest
    
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
        this.controller.camera.setMatrices this

        this.setupShader = ->
            shaderProgram = this.shaderProgram
            this.setUniformMatrices('uMVMatrix', 'uPMatrix', 'uNMatrix')

        this.setupShader()

        for slice in @slices
            slice.draw this

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

            eye = [4, 4, 4]

            @controllers =
                ThreeD : new PerspectiveController
                    eye : eye
                    direction : (vec3.normalize [-1, -1, -1]),
                    up : [0, 0, 1],
                    focalDist :  vec3.length eye
                    near : 0.1,
                    far : 20,
                    angle : 30
                X : new OrthoController
                    direction : [-1, 0, 0]
                    up : [0, 0, 1],
                Y : new OrthoController
                    direction : [0, -1, 0]
                    up : [0, 0, 1],
                Z : new OrthoController

            @controller = @controllers.ThreeD

        draw : drawScene


    $('#canvas').dragHelper
        onStart: (e) ->
            ctrlType = viewMouse()
            @rotate = false
            @pan = false
            @zoom = false
            this[ctrlType] = true

        onDrag : (e, delx, dely) ->
            widget = $(this.element).data('mrlgl')
            controller = widget.controller
            camera = widget.controller.camera
            mat4.identity(widget.pMatrix)
            mat4.identity(widget.mvMatrix)
            helper = new ViewHelper(widget)
            camera.setMatrices(helper)
            
            focalPlane = helper.screenPlaneThrough(camera.focalPoint())

            deltaInFocalPlane = ->
                oldPt = helper.screenToModel(this.lastX, this.lastY, focalPlane)
                pt = helper.screenToModel(this.lastX+delx, this.lastY+dely, focalPlane)
                vec3.subtract(pt, oldPt)
                return pt
            
            sz = Math.min($(this.element).height(), $(this.element).width())
            # remember, screen coordinates go top to bottom and left to right.
            axis = [dely, delx, 0]
            angle = - vec3.length(axis) / sz * Math.PI
            
            if @pan
                delta = deltaInFocalPlane.call this
                # do the pan
                controller.pan delta

            else if @rotate
                orbit = true
                if(orbit)
                    # Turn that axis into a model vector in the plane of the focalpoint
                    # Seems a lot more work than it should!
                    screenPt = helper.modelToScreen(camera.focalPoint())
                    otherScreenPt = [screenPt.pageX - dely, screenPt.pageY + delx]
                    otherScreenRay = helper.screenToRay(screenPt.pageX - dely, screenPt.pageY + delx)
                    focalPlane = helper.screenPlaneThrough(camera.focalPoint())
                    otherModelPoint = helper.intersectRayPlane(otherScreenRay, focalPlane)
                    modelAxis = vec3.normalize(vec3.subtract(otherModelPoint, camera.focalPoint()))
                    
                    controller.rotateAbout(-angle, modelAxis, camera.focalPoint())

            else if @zoom
                # figure out the distance in model coords from top to bottom of the window
                pt0 = helper.screenToModel this.lastX, 0, focalPlane
                pt1 = helper.screenToModel this.lastX, @element.height(), focalPlane
                scrDelta = vec3.subtract pt1, pt0, vec3.create()
                modelHeight = Math.abs vec3.dot scrDelta, camera.up

                delta = deltaInFocalPlane.call this
                dot = vec3.dot delta, camera.up
                controller.zoom dot, modelHeight

            widget.draw()

    # zoom on wheel.
    # TODO: combine with draghelper, maybe
    $("#canvas").mousewheel (e, delta) ->
        widget = $(this).data('mrlgl')
        controller = widget.controller
        camera = widget.controller.camera
        mat4.identity(widget.pMatrix)
        mat4.identity(widget.mvMatrix)
        helper = new ViewHelper(widget)
        camera.setMatrices(helper)
        
        focalPlane = helper.screenPlaneThrough(camera.focalPoint())
        screenRay = helper.screenToRay e.pageX, e.pageY
        modelPt = helper.intersectRayPlane screenRay, focalPlane
        controller.zoomPoint widget, modelPt, screenRay, delta
        widget.draw()

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

    # TODO, maybe: make this a widget
    statusArea = $('#status')
    setStatus = (msg, err) ->
        statusArea.text(msg)
        statusArea.toggleClass('error', err ? false)

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
            return (string.charCodeAt(idx) & 0xff) * 256 + (string.charCodeAt(idx+1) & 0xff)

        unpackTextureData : (reader, swizzle = ( (x) -> x ), unswizzle = (x) -> x ) ->
            unpackInt = reader.getValueFn()
            widthIn = reader.sizes[0]
            heightIn = reader.sizes[1]
            depthIn = reader.sizes[2]
            [width, height, depth] = swizzle [widthIn, heightIn, depthIn]
            [nrows, rowlen] = @_textureLayout { depth: depth }
            sz = width * height * nrows * rowlen
            pixels = new Uint8Array sz
            pixelsHigh = new Uint8Array sz
            maxValue = reader.max ? 255
            
            _rowsz = @_rowsz
            rowlen = if depth < _rowsz then depth else _rowsz
            for d in [0 ... depth]
                xoff = d % rowlen
                yoff = Math.floor(d / _rowsz)
                for i in [0 ... height]
                    for j in [0 ... width]
                        [jIn, iIn, dIn] = unswizzle [j, i, d]
                        p = unpackInt ( dIn * heightIn * widthIn + iIn * widthIn + jIn)
                        if p > maxValue then maxValue = p
                        pixelIdx = (i + yoff * height) * rowlen * width + j + xoff * width
                        pixels[pixelIdx] = p
                        pixelsHigh[pixelIdx] = p >> 8
            bits = 8
            for b in [8 ... 16]
                if (1 << b) > maxValue
                    bits = b
                    break
            # directions
            vectors = swizzle reader.vectors

            return {
                bits : bits,
                width : width,
                height : height,
                depth : depth,
                vectors : vec3.create(v) for v in vectors
                pixels : pixels,
                pixelsHigh : pixelsHigh
            }

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

            widget.pushmv()
            if @matrix?
                mat4.multiply widget.mvMatrix, @matrix
                widget.setUniformMatrices 'uMVMatrix', 'uPMatrix', 'uNMatrix'
            gl.drawArrays gl.TRIANGLE_STRIP, 0, widget.positionBuffer.numItems
            widget.popmv()

    swizzleYZX = ([x, y, z]) -> [y, z, x]
    swizzleZXY = ([x, y, z]) -> [z, x, y]

    _makeMat4 = (vecs) ->
        return mat4.create [
            vecs[0][0], vecs[0][1], vecs[0][2], 0,
            vecs[1][0], vecs[1][1], vecs[1][2], 0,
            vecs[2][0], vecs[2][1], vecs[2][2], 0,
            0, 0, 0, 1 ]

    # Figure out which coordinate is x, y, z
    _guessCoords = (vecs) ->
        zvec = [0, 0, 1]
        xvec = [1, 0, 0]
        bestz = 2
        bestd = -Infinity
        for v, i in vecs
            d = Math.abs(vec3.dot(v, zvec) / vec3.length(v))
            if d > bestd
                bestz = i
                bestd = d
        bestx = 0
        bestd = -Infinity
        for v, i in vecs
            d = Math.abs(vec3.dot(v, xvec) / vec3.length(v))
            if i != bestz and d > bestd
                bestx = i
                bestd = d
        # silly little hack!
        besty = 3 - bestx - bestz
        result = []
        result[bestx] = 0
        result[besty] = 1
        result[bestz] = 2
        return result

    _xyzVec = (i) ->
        v = [0, 0, 0]
        v[i] = 1
        return v
        
    # get data
    load_data = (widget, data) ->
        try
            widget.slices = []
            reader = new NrrdReader(data)
            reader.parseHeader()
            makeSlice = (idx, swizzle, unswizzle, matrix) ->
                pixelData = TextureObject::unpackTextureData reader, swizzle, unswizzle
                textureObj = TextureObject::makeTexture2dFromData widget, pixelData
                slice = new SliceObject textureObj
                #yuck
                vec3.scale pixelData.vectors[0], pixelData.width
                vec3.scale pixelData.vectors[1], pixelData.height
                vec3.scale pixelData.vectors[2], pixelData.depth
                if vec3.dot(pixelData.vectors[2], _xyzVec(idx)) < 0
                    slice.flipped = true
                slice.matrix = _makeMat4 pixelData.vectors
                widget.slices.push slice
                bindSliceControls widget, slice, idx
            xyz = _guessCoords(reader.vectors)
            # xy
            makeSlice xyz[2], ((x) -> x), ((y) -> y)
            # yz
            makeSlice xyz[0], swizzleYZX, swizzleZXY
            # zx
            makeSlice xyz[1], swizzleZXY, swizzleYZX

            pts = []
            for i in [-1, 1]
                for j in [-1, 1]
                    for k in [-1, 1]
                        pts.push mat4.multiplyVec3 widget.slices[0].matrix, [i, j, k]

            for own key, c of widget.controllers
                c.setPoints pts
                c.camera.zoomToFit pts
            widget.draw()
            setStatus "Loaded"
        catch msg
            setStatus msg, true

    load_url = (url) ->
        setStatus "Fetching data..."
        $.ajax url,
            type: 'GET',
            beforeSend: (xhr, settings) ->
                xhr.overrideMimeType('text/plain; charset=x-user-defined')
            success: (data, status, xhr) ->
                load_data widget, data

    load_url '/binary3d'

    $('#load-head').click ->
        load_url '/headData'

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

    bindSliceControls = (widget, slice, idx) ->
        coord = ['x', 'y', 'z'][idx]
        depthSliderSelector = "##{coord}-depth-slider"
        $(depthSliderSelector).slider('destroy')
        $(depthSliderSelector).slider
            min : 0
            max : 1
            step : 1 / (slice.textureObj.depth - 1)
            value : 0.5
            slide : (event, ui) ->
                slice.level = ui.value
                # this might belong inside the slice, not the ui!
                if slice.flipped
                    slice.level = 1-slice.level
                widget.draw()

    $('#load-file').fileWidget
        beforeRead: ->
            setStatus "Reading..."
        processFile : (data) ->
            load_data widget, data

    widget.setView = (view) ->
        # set up an appropriate camera
        widget.controller = widget.controllers[view]
        widget.draw()

    $('#viewradio').buttonset()
    $('#view3d').click( -> widget.setView "ThreeD" )
    $('#viewX').click( -> widget.setView "X" )
    $('#viewY').click( -> widget.setView "Y" )
    $('#viewZ').click( -> widget.setView "Z" )
    $('#viewMouse').buttonset()
    $('#viewReset').button().click( ->
        widget.controller.reset()
        widget.draw()
    )

    viewMouse = ->
        $("#viewMouse input[type='radio'][name='viewMouse']:checked").val()

