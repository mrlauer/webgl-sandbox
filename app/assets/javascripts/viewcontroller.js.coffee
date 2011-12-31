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
        

class PerspectiveController extends ViewController
    constructor: (cameraOptions) ->
        super cameraOptions
        @camera = new mrlCamera cameraOptions

class OrthoController extends ViewController
    constructor: (cameraOptions) ->
        super cameraOptions
        @camera = new mrlOrthoCamera cameraOptions

exports.ViewController = ViewController
exports.PerspectiveController = PerspectiveController
exports.OrthoController = OrthoController
