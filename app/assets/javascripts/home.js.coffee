# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

#= require webgl
#= require readnrrd
#= require filewidget
#= require viewcontroller
#= require colors
#= require histogram

$ ->
    # In chrome, memory management of lots of Float32Arrays gets slow.
    # So don't use them for all the math
    if window?
        window.glMatrixArrayType = Array

    # TODO: move this!

    vec3.linComb = (vec1, s1, vec2, s2, dest) ->
        if(!dest)
            dest = vec1
        dest[0] = vec1[0] * s1 + vec2[0] * s2
        dest[1] = vec1[1] * s1 + vec2[1] * s2
        dest[2] = vec1[2] * s1 + vec2[2] * s2
        return dest

    # minimum b s.t. 2^b >= n
    bitsNeeded = (n) ->
        # if we have a power of two, then there can be roundoff error, so we need a bit
        # of mucking about
        r = Math.floor Math.log(n) / Math.LN2
        if (1 << r) < n
            r += 1
        return r
    
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
        # for volume display a black background works best.
        # for slices it's a little nicer (IMO) gray
        if @volumeOn
            this.gl.clearColor 0, 0, 0, 1
        else
            this.gl.clearColor 0.75, 0.75, 0.75, 1

        gl.clear (gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        gl.enable(gl.BLEND)
        gl.blendFuncSeparate(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA, gl.ZERO, gl.ONE)

        mat4.identity this.mvMatrix
        mat4.identity this.pMatrix
        this.controller.camera.setMatrices this

        this.setupShader = ->
            shaderProgram = this.shaderProgram
            this.setUniformMatrices('uMVMatrix', 'uPMatrix', 'uNMatrix')

        this.setupShader()

        if @rainbow and @rainbowTexture
            widget.uniform1i 'uRainbow', 1
            widget.uniform1i 'uRainbowTexture', 2
            gl.activeTexture gl.TEXTURE2
            gl.bindTexture gl.TEXTURE_2D, @rainbowTexture
        else
            widget.uniform1i 'uRainbow', 0

        if @slicesOn
            widget.uniform1i 'uMultiple', 0
            for slice in @slices
                slice.draw this

        if @volumeOn
            widget.uniform1i 'uMultiple', 1
            # figure out which set to draw, and which order to draw in
            bestd = -Infinity
            flip = false
            dir = @controller.camera.direction
            bestSlice = null
            for s in @slices
                n = s.normal()
                d = vec3.dot dir, n
                absd = Math.abs d
                if absd > bestd
                    bestd = absd
                    bestSlice = s
                    flip = (d > 0)
            # Draw the slice at many depths
            
            # Since different directions have different spacings and thus
            # different numbers of rendered slices through the same volumes
            # we need to adjust the opacity, making the more sparsely spaced
            # ones more opaque.
            # t_base ^ n_base = t ^ (n_base / scale)
            # t = t_base ^ scale
            tbase = 1 - @opacity
            t = Math.pow tbase, bestSlice.scale
            opacity = 1 - t
            widget.uniform1f 'uOpacity', opacity
            first = Math.round((bestSlice.depth - 1) * bestSlice.trim[0])
            last = Math.round((bestSlice.depth - 1) * bestSlice.trim[1])
            if flip
                [first, last] = [last, first]
            bestSlice.draw this, first, last

    # set the bounds for the i'th coordinate
    setLimits = (idx, low, high) ->
        self = this
        slice = self.slices[idx]
        if slice.flipped
            [low, high] = [1-high, 1-low]
        slice.trim = [low, high]
        slice1 = self.slices[(idx+1)%3]
        slice1.bounds[1] = [low, high]
        slice2 = self.slices[(idx+2)%3]
        slice2.bounds[0] = [low, high]

    widget = null
    $('#canvas').mrlgl
        initialize: ->
            widget = this
            this.initProgram()
            this.enableVertexAttribArray("aUV", false)
            this.enableVertexAttribArray("aVertexPosition")
            this.gl.clearColor 0.75, 0.75, 0.75, 1
            this.gl.enable this.gl.DEPTH_TEST
            this.minrange = 0.0
            this.maxrange = 1.0
            this.minthreshold = 0.0
            this.maxthreshold = 1.0
            this.opacity = 0.125

            @xLimits = [0, 1]
            @yLimits = [0, 1]
            @zLimits = [0, 1]

            @slicesOn = true
            @volumesOn = false
            @interpolateTextures = true

            @rainbowTexture = ColorUtilities.makeRainbowTexture(@gl)

            @getTextureInterpolation = ->
                if @interpolateTextures then @gl.LINEAR else @gl.NEAREST

            eye = [4, 4, 4]

            @setLimits = setLimits

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
            if this.middleButton
                @rotate = true
            else
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
                    
                    angleFac = Math.PI * 2 / 3
                    zAngle = delx / sz * angleFac
                    xAngle = dely / sz * angleFac
                    controller.turntable zAngle, xAngle
#                     controller.rotateAbout(-angle, modelAxis, camera.focalPoint())

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
        interp = widget.getTextureInterpolation()
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, interp)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, interp)
        return texture

    # TODO, maybe: make this a widget
    statusArea = $('#status')
    setStatus = (msg, err) ->
        statusArea.text(msg)
        statusArea.toggleClass('error', err ? false)

    # Represents a SINGLE texture, which may be an array of slices
    # A slice object may have many of them
    class TextureObject
        _rowsz : 8
        _maxDepth : 64

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

        unpackTextureData : (startIdx, reader, swizzle = ( (x) -> x ), unswizzle = (x) -> x ) ->
            unpackInt = reader.getValueFn()
            widthIn = reader.sizes[0]
            heightIn = reader.sizes[1]
            depthIn = reader.sizes[2]
            [width, height, depth] = swizzle [widthIn, heightIn, depthIn]
            depth -= startIdx
            if depth <= 0
                return null
            if depth > @_maxDepth
                depth = @_maxDepth
            [nrows, rowlen] = @_textureLayout { depth: depth }
            sz = width * height * nrows * rowlen
            pixels = new Uint8Array sz
            pixelsHigh = new Uint8Array sz
            maxValue = reader.max ? 255
            
            [s0, s1, s2] = unswizzle [0, 1, 2]
            _rowsz = @_rowsz
            rowlen = if depth < _rowsz then depth else _rowsz
            values = reader.values
            for d in [0 ... depth]
                xoff = d % rowlen
                yoff = Math.floor(d / _rowsz)
                dd = d+startIdx
                for i in [0 ... height]
                    baseIdx = (i + yoff * height) * rowlen * width + xoff * width
                    for j in [0 ... width]
                        coords = [j, i, dd]
                        jIn = coords[s0]
                        iIn = coords[s1]
                        dIn = coords[s2]
                        p = values[ dIn * heightIn * widthIn + iIn * widthIn + jIn ]
                        if p < 0 then p = 0
                        if p > maxValue then maxValue = p
                        pixelIdx = baseIdx + j
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
                interp = widget.getTextureInterpolation()
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, interp)
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, interp)
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
                return texture
            obj = new TextureObject
            for p in ['bits', 'height', 'width', 'depth']
                obj[p] = textureData[p]
            gl.activeTexture gl.TEXTURE0
            obj.texture = makeTexture textureData.pixels
            gl.activeTexture gl.TEXTURE1
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
        constructor : (@textures) ->
            @level = 0.5
            @depth = 0
            @trim = [0, 1]
            @bounds = [[0, 1], [0, 1]]
            bits = 0
            for texture in @textures
                @depth += texture.depth
                bits = Math.max bits, texture.bits
            texture.bits = bits for texture in @textures

        normal : () ->
            v = [0, 0, 1, 0]
            mat4.multiplyVec4 @matrix, v
            return vec3.normalize v

        createBuffers : (widget) ->
            gl = widget.gl
            thisIdx = 0
            @indexBuffer ?= gl.createBuffer()
            @indexRevBuffer ?= gl.createBuffer()
            maxd = 0
            for idx, texture of @textures
                maxd = Math.max maxd, texture.depth
                positionBuffer = gl.createBuffer()
                uvBuffer = gl.createBuffer()
                localUvBuffer = gl.createBuffer()
                vertices = []
                uvs = []
                localuvs = []
                indices = []

                bds =
                    left : -1
                    right : 1
                    top : 1
                    bottom : -1

                for i in [0...texture.depth]
                    level = thisIdx / (@depth - 1)
                    z = -1 + 2 * level
                    vertices.push(
                        bds.left, bds.bottom, z,
                        bds.right, bds.bottom, z,
                        bds.left, bds.top, z,
                        bds.right, bds.top, z
                    )
                    [u0, v0, u1, v1] = texture.getUVOffsets i
                    uvs.push(
                        u0, v0
                        u1, v0,
                        u0, v1,
                        u1, v1
                    )
                    localuvs.push(
                        0, 0,
                        1, 0,
                        0, 1,
                        1, 1
                    )
                    thisIdx++

                widget.setFloatBufferData positionBuffer, vertices, 3
                widget.setFloatBufferData uvBuffer, uvs, 2
                widget.setFloatBufferData localUvBuffer, localuvs, 2
                texture.positionBuffer = positionBuffer
                texture.uvBuffer = uvBuffer
                texture.localUvBuffer = localUvBuffer

            # forward and backwards index buffers.
            # could live in the widget. But eh.
            indices = []
            indicesRev = []
            for i in [0 ... maxd]
                i4 = i * 4
                i4r = (maxd - 1) *4 - i4
                indices.push(
                    i4, i4+1, i4+2, i4+2, i4+1, i4+3
                )
                indicesRev.push(
                    i4r, i4r+1, i4r+2, i4r+2, i4r+1, i4r+3
                )

            widget.setElementArrayBufferData @indexBuffer, indices
            widget.setElementArrayBufferData @indexRevBuffer, indicesRev


        draw : (widget, first, last) ->
            gl = widget.gl
            first ?= Math.round(@level * (@depth-1))
            last ?= first
            tstart = 0
            tstop = @textures.length - 1
            if first > last
                [tstart, tstop] = [tstop, tstart]
            min = Math.min(first, last)
            max = Math.max(first, last)

            widget.pushmv()
            if @matrix?
                mat4.multiply widget.mvMatrix, @matrix
                widget.setUniformMatrices 'uMVMatrix', 'uPMatrix', 'uNMatrix'

            widget.uniform1f('uMin', widget.minrange)
            widget.uniform1f('uMax', widget.maxrange)
            widget.uniform1f('uMinThreshold', widget.minthreshold)
            widget.uniform1f('uMaxThreshold', widget.maxthreshold)

            widget.uniform2f 'uLocalMin', @bounds[0][0], @bounds[1][0]
            widget.uniform2f 'uLocalMax', @bounds[0][1], @bounds[1][1]

            rev = (last < first)
            gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, (if rev then @indexRevBuffer else @indexBuffer)

            for idx in [tstart .. tstop]
                texture = @textures[idx]
                tFirst = Math.max(min - texture.startIdx, 0)
                tLast = Math.min(max - texture.startIdx, texture.depth - 1)
                if (tLast < tFirst)
                    continue
                if !texture.positionBuffer
                    @createBuffers widget

                widget.setFloatAttribPointer 'aVertexPosition', texture.positionBuffer
                widget.setFloatAttribPointer 'aUV', texture.uvBuffer
                widget.setFloatAttribPointer 'aLocalUV', texture.localUvBuffer

                widget.uniform1f 'uMaxLimit', texture.getMaxLimit()
                texture.setTextureUniforms widget, 'uTextureLow', 'uTextureHigh'

                offset = 2 * 6 * (if rev then (texture.depth - tLast - 1) else tFirst)
                nVerts = 6 * (Math.abs(tLast - tFirst) + 1)

                gl.drawElements gl.TRIANGLES, nVerts, gl.UNSIGNED_SHORT, offset

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
            reader.values = reader.makeValueArray()
            scales = (vec3.length v for v in reader.vectors)
            minScale = Math.min.apply Math, scales
            makeSlice = (idx, swizzle, unswizzle, matrix) ->
                startIdx = 0
                textures = []
                while true
                    pixelData = TextureObject::unpackTextureData startIdx, reader, swizzle, unswizzle
                    if !pixelData
                        break
                    textureObj = TextureObject::makeTexture2dFromData widget, pixelData
                    textureObj.startIdx = startIdx
                    textures.push textureObj
                    startIdx += textureObj.depth
                slice = new SliceObject textures
                slice.scale = (swizzle scales)[2] / minScale
                #yuck
                vectors = ((vec3.scale reader.vectors[i], reader.sizes[i], vec3.create()) for i in [0..2])
                vectors = swizzle vectors
                if vec3.dot(vectors[2], _xyzVec(idx)) < 0
                    slice.flipped = true
                slice.matrix = _makeMat4 vectors
                widget.slices[idx] = slice
                slice.createBuffers widget
                bindSliceControls widget, slice, idx
            xyz = _guessCoords(reader.vectors)
            widget.slices = []
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

            computeHistogramData(reader)
            drawHistogram()
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

    _sliderValues = (slider, ui) ->
        return ui.values

    $('#window-width-slider').dragslider
        min : 0
        max : 1
        step : 0.01
        values : [0, 1]
        range : true
        rangeDrag : true
        slide : (event, ui) ->
            [widget.minrange, widget.maxrange] = _sliderValues $(this).slider, ui
            widget.draw()
            drawHistogram()

    $('#threshold-slider').dragslider
        min : 0
        max : 1
        step : 0.01
        values : [0, 1]
        range : true
        rangeDrag : true
        slide : (event, ui) ->
            [widget.minthreshold, widget.maxthreshold] = _sliderValues $(this).slider, ui
            c = (widget.minthreshold + widget.maxthreshold)/2
            $('#threshold-center-slider').slider 'value', c
            widget.draw()
            drawHistogram()

    $('#threshold-center-slider').slider
        min : 0
        max : 1
        step : 0.01
        value : 0.5
        slide : (event, ui) ->
            [min, max] = [widget.minthreshold, widget.maxthreshold]
            hw = (max-min)/2
            min = Math.max ui.value - hw, 0
            max = Math.min ui.value + hw, 1
            widget.minthreshold = min
            widget.maxthreshold = max
            $('#threshold-slider').dragslider 'values', 0, min
            $('#threshold-slider').dragslider 'values', 1, max
            widget.draw()
            drawHistogram()

    [uiToOpacity, opacityToUi] = ( ->
        beta = 10
        return [
            (x)-> (Math.pow(beta, x) - 1)/ (beta - 1) ,
            (y)-> Math.log(y * (beta - 1) + 1) / Math.log(beta)
        ]
    )()
    $('#opacity-slider').slider
        min : 0
        max : 1
        step : 1/256
        value : opacityToUi widget.opacity
        slide : (event, ui) ->
            widget.opacity = uiToOpacity ui.value
            widget.draw()

    bindSliceControls = (widget, slice, idx) ->
        coord = ['x', 'y', 'z'][idx]
        depthSliderSelector = "##{coord}-depth-slider"
        $(depthSliderSelector).slider('destroy')
        $(depthSliderSelector).slider
            min : 0
            max : 1
            step : 1 / (slice.depth - 1)
            value : 0.5
            slide : (event, ui) ->
                slice.level = ui.value
                # this might belong inside the slice, not the ui!
                if slice.flipped
                    slice.level = 1-slice.level
                widget.draw()
        trimSliderSelector = "##{coord}-trim-slider"
        $(trimSliderSelector).slider('destroy')
        $(trimSliderSelector).slider
            min : 0
            max : 1
            step : 1 / (slice.depth - 1)
            values : [0, 1]
            range : true
            rangeDrag : true
            slide : (event, ui) ->
                # this might belong inside the slice, not the ui!
                widget.setLimits idx, ui.values[0], ui.values[1]
                widget.draw()

    $('#load-file').fileWidget
        beforeRead: ->
            setStatus "Reading..."
        processFile : (data) ->
            load_data widget, data

    widget.setView = (view) ->
        # set up an appropriate camera
        c = widget.controllers[view]
        if widget.controller == c
            c.flipIfOrtho()
        else
            widget.controller = c
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
    $('#viewType').buttonset().on 'change', 'input', (e)->
        val = $(this).val()
        widget[a] = false for a in ['slicesOn', 'volumeOn']
        widget[val + "On"] = $(this).is(':checked')
        $('.volume-control').toggleClass('hidden', !widget.volumeOn)
        $('.slice-control').toggleClass('hidden', !widget.slicesOn)
        widget.draw()

    $('#rainbow').
        attr('checked', if widget.rainbow then "checked" else null).
        button().
        click ->
            widget.rainbow = $(this).is(':checked')
            widget.draw()

    $('#textureInterpolate').
        attr('checked', if widget.interpolate then "checked" else null).
        button().
        click ->
            checked = $(this).is(':checked')
            widget.interpolateTextures = checked
            interp = widget.getTextureInterpolation()
            for slice in widget.slices
                for texture in slice.textures
                    gl = widget.gl
                    gl.bindTexture gl.TEXTURE_2D, texture.texture
                    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, interp)
                    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, interp)
                    gl.bindTexture gl.TEXTURE_2D, null
            widget.draw()

    viewMouse = ->
        $("#viewMouse input[type='radio'][name='viewMouse']:checked").val()

    $('#histogram').histogram()
    drawHistogram = ->
        $('#histogram').histogram 'option',
            minRange : widget.minrange
            maxRange : widget.maxrange
            minThreshold : widget.minthreshold
            maxThreshold : widget.maxthreshold
        $('#histogram').histogram 'draw'

    computeHistogramData = (reader) ->
        w = $('#histogram').width()
        result = null
        if w
            result =
                min: []
                max: []
            # this should be more flexible and generally better
            datamax = reader.max
            b = bitsNeeded datamax
            datamax = (1 << b)

            nbuckets = 1 << (bitsNeeded w)
            buckets = new Uint32Array(nbuckets)
            perBucket = datamax / nbuckets
            d1 = new Date
            for data in reader.values
                if data > 0
                    bucket = Math.floor(data / perBucket)
                    buckets[bucket] += 1
            d2 = new Date
#             console.log "took #{d2-d1} ms to fill buckets"
            for i in [0 .. w]
                start = Math.floor(i * (nbuckets-1) / w)
                stop = Math.floor((i+1) * (nbuckets-1) / w)
                min = Infinity
                max = 0
                for j in [start ... stop]
                    if buckets[j]?
                        max += buckets[j]
                if (stop - start)
                    max /= (stop - start)
                min = Math.min min, max
                result.min[i] = min
                result.max[i] = max
        $('#histogram').histogram 'option', 'data', result

