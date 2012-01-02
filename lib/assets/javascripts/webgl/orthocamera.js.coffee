# Camera for ortho views
#
exports ?= this

class mrlOrthoCamera
    constructor: (options) ->
        $.extend this, @defaults(), options

    defaults: ->
        center : [0, 0, 0]
        direction : [0, 0, -1]
        up : [0, 1, 0]
        left : -1
        right : 1
        top : 1
        bottom : -1
        near : -1
        far : 1

    focalPoint: =>
        @center

    getEffectiveBounds: (widget) =>
        gl = widget.gl
        viewAspect = gl.viewportWidth / gl.viewportHeight
        width = @right - @left
        height = @top - @bottom
        cameraAspect = width / height
        [left, right, top, bottom] = [@left, @right, @top, @bottom]
        if viewAspect >= cameraAspect
            # fit the height, need to shrink the width
            left *= viewAspect / cameraAspect
            right *= viewAspect / cameraAspect
        else
            # fit the width, need to shrink the height
            top *= cameraAspect / viewAspect
            bottom *= cameraAspect / viewAspect
        return [left, right, top, bottom]

    setMatrices: (widget, reset) =>
        mvMatrix = widget.mvMatrix
        pMatrix = widget.pMatrix
        if !mvMatrix || !pMatrix
            widget.mvMatrix = mvMatrix = mat4.identity(mat4.create())
            widget.pMatrix = pMatrix = mat4.identity(mat4.create())
        else if reset
            mat4.identity(mvMatrix)
            mat4.identity(pMatrix)
        gl = widget.gl
        eye = @center
        focus = vec3.add eye, @direction, vec3.create()
        mat4.lookAt eye, focus, @up, mvMatrix

        # avoid stretching
        [left, right, top, bottom] = @getEffectiveBounds widget

        mat4.ortho left, right, bottom, top, @near, @far, pMatrix

    rotateAbout: (angle, axis, center) =>

    zoomToFit: (points, fudge) =>
        if !points.length
            return
        max = (-Infinity for i in [0..2])
        min = (Infinity for i in [0..2])
        z = vec3.create @direction
        x = vec3.create @up
        # it's a left-handed coordinate system
        y = vec3.cross x, z, vec3.create()
        for p in points
            pt = [  vec3.dot(p, x),
                    vec3.dot(p, y),
                    vec3.dot(p, z) ]

            for i in [0..2]
                max[i] = Math.max max[i], pt[i]
                min[i] = Math.min min[i], pt[i]
        ct = vec3.lerp max, min, 0.5, [0, 0, 0]
        # fudge near/far a bit.
        min[2] -= 0.1
        max[2] += 0.1
        [@left, @bottom, @near] = (min[i] - ct[i] for i in [0..2])
        [@right, @top, @far] = (max[i] - ct[i] for i in [0..2])
        @center = [0, 0, 0]
        for v, i in [x, y, z]
            vec3.scale v, ct[i]
            vec3.add @center, v


exports.mrlOrthoCamera = mrlOrthoCamera

