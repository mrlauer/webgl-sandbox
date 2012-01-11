# Deal with cameras and things for views
exports ?= this

_clone = (obj) ->
    if typeof obj == "object"
        newobj = if (this instanceof Array) then [] else {}
        for own idx, val of obj
            newobj[idx] = _clone val
        return newobj
    else
        return obj


class ViewController
    constructor: (options) ->
        @options = _clone options

    reset: =>
        if @camera
            $.extend @camera, @camera.defaults(), _clone @options
            if @points
                @camera.zoomToFit @points

    setPoints: (points) =>
        @points = points

    rotateAbout: (angle, axis, center) ->

    turntable: (zAngle, xAngle) ->

    pan: (vec) ->
        
    zoom: (distMoved, distNorm) ->

    zoomPoint: (widget, point, ray, delta) ->

    flipIfOrtho: ->


class PerspectiveController extends ViewController
    constructor: (cameraOptions) ->
        super cameraOptions
        @camera = new mrlCamera cameraOptions

    rotateAbout: (angle, axis, center) ->
        # decompose into x and y
        @camera.rotateAbout angle, axis, center

    turntable: (zAngle, xAngle) ->
        focus = @camera.focalPoint()
        delta = vec3.subtract @camera.eye, focus, vec3.create()

        # Rotate about the x angle. First compute the view's x-vector in model coordinates
        matrices = {}
        @camera.setMatrices matrices
        mat4.inverse matrices.mvMatrix
        # Pass a vec4 with 0 w to get proper transformation of a vector, not a point.
        xVec = mat4.multiplyVec4 matrices.mvMatrix, [1, 0, 0, 0]

        # Rotate about the z angle
        zVec = [0, 0, 1]
        zMat = mat4.identity mat4.create()
        mat4.rotate zMat, -zAngle, zVec

        # And the x rotation
        mat4.rotate zMat, -xAngle, xVec

        mat4.multiplyVec3 zMat, delta
        vec3.add focus, delta, @camera.eye
        mat4.multiplyVec3 zMat, @camera.up
        mat4.multiplyVec3 zMat, @camera.direction

        @camera.setNearFar()

    pan: (delta) ->
        vec3.subtract @camera.eye, delta

    zoom: (distMoved, distNorm) ->
        camera = @camera
        dist = distMoved/Math.tan(camera.angle / 2)
        camera.dolly dist
        camera.setNearFar()

    zoomPoint: (widget, point, ray, delta) ->
        # move the eye along the ray
        camera = @camera
        dist = camera.focalDist * delta / 6
        camera.dollyAlong dist, ray.direction
        camera.setNearFar()


class OrthoController extends ViewController
    constructor: (cameraOptions) ->
        super cameraOptions
        @camera = new mrlOrthoCamera cameraOptions

    pan: (delta) ->
        vec3.subtract @camera.center, delta

    zoom: (distMoved, distNorm) ->
        factor = Math.pow 2, (distMoved/distNorm)
        for c in ['left', 'right', 'top', 'bottom']
            @camera[c] *= factor

    zoomPoint: (widget, point, ray, delta) ->
        factor = Math.pow 2, (delta / 6)
        delvec = vec3.subtract point, @camera.focalPoint(), vec3.create()
        rtvec = vec3.cross @camera.direction, @camera.up, vec3.create()
        xdel = vec3.dot delvec, rtvec
        ydel = vec3.dot delvec, @camera.up
        [left, right, top, bottom] = @camera.getEffectiveBounds widget
        @camera.left = (left - xdel) * factor + xdel
        @camera.right = (right - xdel) * factor + xdel
        @camera.top = (top - ydel) * factor + ydel
        @camera.bottom = (bottom - ydel) * factor + ydel

    flipIfOrtho: ->
        vec3.scale @camera.direction, -1

exports.ViewController = ViewController
exports.PerspectiveController = PerspectiveController
exports.OrthoController = OrthoController
