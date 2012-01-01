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

    pan: (vec) ->
        
    zoom: (distMoved, distNorm) ->

class PerspectiveController extends ViewController
    constructor: (cameraOptions) ->
        super cameraOptions
        @camera = new mrlCamera cameraOptions

    rotateAbout: (angle, axis, center) ->
        @camera.rotateAbout angle, axis, center

    pan: (delta) ->
        vec3.subtract @camera.eye, delta

    zoom: (distMoved, distNorm) ->
        camera = @camera
        dist = distMoved/Math.tan(camera.angle / 2)
        camera.dolly dist
        camera.setNearFar()

class OrthoController extends ViewController
    constructor: (cameraOptions) ->
        super cameraOptions
        @camera = new mrlOrthoCamera cameraOptions

    pan: (delta) ->
        vec3.subtract @camera.center, delta

exports.ViewController = ViewController
exports.PerspectiveController = PerspectiveController
exports.OrthoController = OrthoController
