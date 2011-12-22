/*
 * Utilities for view manipulation and whatnot
 */

/* globals jQuery, vec3, mat4 */

var ViewHelper;

(function($) {
	
	// Really need to make an Object Factory.
	ViewHelper = function(widget) {
		this.gl = widget.gl;
		this.element = widget.element;
	};
	
	var vhp = ViewHelper.prototype;
	
    // Convert a point (in page coordinates) to a ray in model space
    // Do this by taking two point
    vhp.screenToRay = function(pageX, pageY)
    {
    	var mat = mat4.multiply(this.pMatrix, this.mvMatrix, mat4.create());
    	mat4.inverse(mat);
    	
    	var x = pageX - this.element.offset().left;
    	var y = pageY - this.element.offset().top;
    	
    	x = 2 * x / this.gl.viewportWidth - 1;
    	y = 1 - 2 * y / this.gl.viewportHeight;
    	
    	var pt0 = [x, y, 0, 1];
    	mat4.multiplyVec4(mat, pt0);
    	var pt1 = [x, y, -1, 1];
    	mat4.multiplyVec4(mat, pt1);
    	
    	// TODO: encapsulate...
    	pt0 = [pt0[0] / pt0[3], pt0[1] / pt0[3], pt0[2] / pt0[3] ];
    	pt1 = [pt1[0] / pt1[3], pt1[1] / pt1[3], pt1[2] / pt1[3] ];
    	
    	vec3.subtract(pt1, pt0);
    	vec3.normalize(pt1);
    	
    	return { point : pt0 , direction : pt1 };
    };
    
    vhp.screenNormal = function()
    {
    	// (M x) * n_4 = 0  <=> x * (Mt n_4) = 0,
    	var n = [0, 0, 1, 0];
    	var m1 = mat4.transpose(this.pMatrix, mat4.create());
    	mat4.multiplyVec4(m1, n);
    	mat4.transpose(this.mvMatrix, m1);
    	mat4.multiplyVec4(m1, n);
    	return vec3.normalize(n, vec3.create());
    };
    
    vhp.screenPlaneThrough = function(pt)
    {
    	var n = this.screenNormal();
    	var d = vec3.dot(n, pt);
    	return [ n[0], n[1], n[2], -d];
    };
    
    // Because I said so, ray is { point , direction }, and plane is
    // [n0, n1, n2, d]
    vhp.intersectRayPlane = function(ray, plane)
    {
    	var pn = vec3.dot(ray.point, plane);
    	var dn = vec3.dot(ray.direction, plane);
    	var t = -(pn + plane[3]) / dn;
    	return vec3.linComb(ray.point, 1.0, ray.direction, t, vec3.create());
    };
    
    vhp.modelToScreen = function(modelPoint)
    {
    	var pt = [modelPoint[0], modelPoint[1], modelPoint[2], 1];
    	mat4.multiplyVec4(this.mvMatrix, pt);
    	mat4.multiplyVec4(this.pMatrix, pt);
    	var x = pt[0] / pt[3];
    	var y = pt[1] / pt[3];
    	
    	var off = this.element.offset();
    	
    	var elementX = (1 + x) * this.gl.viewportWidth * 0.5;
    	var elementY = (1 - y) * this.gl.viewportHeight * 0.5;
    	return { elementX : elementX,
    			 elementY : elementY,
    			 pageX : (1 + x) * this.gl.viewportWidth * 0.5 + off.left,
    			 pageY: (1 - y) * this.gl.viewportHeight * 0.5 + off.top };
    };
    
    vhp.screenToModel = function(pageX, pageY, plane)
    {
		var ray = this.screenToRay(pageX, pageY);
		var pt = this.intersectRayPlane(ray, plane);
		return pt;
    };
	
} (jQuery));