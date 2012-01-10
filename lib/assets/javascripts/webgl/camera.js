/*
 * Camera, for working with glwidget
 */

var mrlCamera;

(function($) {
    mrlCamera = function(options) {
        $.extend(this, this.defaults(), options)
    };

    mrlCamera.prototype.defaults = function() {
        return {
            eye: [0, 0, 0],
            direction: [0, 0, 1],
            up: [0, 1, 0],
            angle: 45,
            focalDist: 1.5,
            near: 1,
            far: 2
        }
    }
    
    mrlCamera.prototype.focalPoint = function() {
        return vec3.add(vec3.scale(this.direction, this.focalDist, vec3.create()), this.eye);
    }
    
    mrlCamera.prototype.setMatrices = function(widget, reset)
    {
        var mvMatrix = widget.mvMatrix;
        var pMatrix = widget.pMatrix;
        if(!mvMatrix || !pMatrix)
        {
            widget.mvMatrix = mvMatrix = mat4.identity(mat4.create());
            widget.pMatrix = pMatrix = mat4.identity(mat4.create());
        }
        else if(reset) {
            mat4.identity(mvMatrix);
            mat4.identity(pMatrix);
        }
        var gl = widget.gl;
        var fdir = vec3.scale(this.direction, this.focalDist, vec3.create());
        var focus = vec3.add(fdir, this.eye);
        mat4.lookAt(this.eye, focus, this.up, mvMatrix);
        // If there's no gl, then don't do the perspective part
        if(gl) {
            mat4.perspective(this.angle, gl.viewportWidth / gl.viewportHeight, this.near, this.far, pMatrix);
        }
    };
    
    mrlCamera.prototype.setNearFar = function(points)
    {
        points = points || this.pointsToBound;
        if(!points || !points.length) { return; }
        var center = this.focalPoint();
        var delta = vec3.create();
        var max = -Infinity;
        var min = Infinity;
        var i;
        for(i=0; i<points.length; i++) {
            var d = vec3.dot(vec3.subtract(points[i], center, delta), this.direction);
            max = Math.max(max, d);
            min = Math.min(min, d);
            
        }
        this.near = Math.max(this.focalDist + min, this.focalDist * 0.01);
        this.far = Math.max(this.near, this.focalDist + max);
    }
    
    mrlCamera.prototype.zoomToFit = function(points, fudge)
    {
        if(!points) { return; }
        var center = [0, 0, 0];
        var i, npts = points.length;
        for(i=0; i<npts; i++)
        {
            vec3.add(center, points[i]);
        }
        vec3.scale(center, 1/npts);
        var dist = 0.0;
        var tan = Math.tan(this.angle * Math.PI / 360);
        var delta = vec3.create();
        var max = -Infinity;
        var min = Infinity;
        var maxd = -Infinity;
        var maxdelta = -Infinity;
        var right = vec3.cross(this.direction, this.up, vec3.create());
        for(i=0; i<npts; i++)
        {
            vec3.subtract(points[i], center, delta);
            var dot = vec3.dot(delta, this.direction);
            max = Math.max(max, dot);
            min = Math.min(min, dot);
            maxdelta = Math.max(maxdelta, vec3.length(delta));
            var u = Math.abs(vec3.dot(delta, this.up));
            var r = Math.abs(vec3.dot(delta, right));
            maxd = Math.max(maxd, u / tan - dot, r / tan - dot);
        }
        if(fudge)
        {
            maxd *= fudge;
        }
        var r2 = Math.sqrt(2);
        this.focalDist = maxd;
        this.near = this.focalDist - maxdelta;
        this.far = this.focalDist + maxdelta;
        var focalVec = vec3.scale(this.direction, this.focalDist, vec3.create());
        vec3.subtract(center, focalVec, this.eye);
        
        this.pointsToBound = points;
    };
    
    mrlCamera.prototype.rotateAbout = function(angle, axis, center)
    {
        if(!center) { center = this.eye; }
        // Ack. encapsulate!
        var m = mat4.identity(mat4.create());
        mat4.rotate(m, angle, axis);
        mat4.multiplyVec3(m, this.direction);
        mat4.multiplyVec3(m, this.up);
        var e = vec3.subtract(this.eye, center, vec3.create());
        mat4.multiplyVec3(m, e);
        vec3.add(center, e, this.eye);
    };
    
    mrlCamera.prototype.pan = function(modelX, modelY)
    {
        var right = vec3.cross(this.direction, this.up, vec3.create());
        vec3.add(this.eye, vec3.scale(right, modelX, vec3.create()));
        vec3.add(this.eye, vec3.scale(this.up, modelY, vec3.create()));
    };
    
    mrlCamera.prototype.dolly = function(modelDist)
    {
        vec3.add(this.eye, vec3.scale(this.direction, modelDist, vec3.create()));
        this.focalDist -= modelDist;
    };

    mrlCamera.prototype.dollyAlong = function(modelDist, direction)
    {
        focalPoint = this.focalPoint()
        vec3.add(this.eye, vec3.scale(direction, modelDist, vec3.create()));
        this.focalDist = vec3.length( vec3.subtract(focalPoint, this.eye) )
    };
    
})(jQuery);
