/*
 * Simple webgl scenegraph. Intended for use with mrlglwidget
 *
 * Copyright 2011, Michael R. Lauer
 *
 * Depends:
 *   jquery.ui.core.js
 *   jquery.ui.widget.js
 *   mrlglwidget.js
 */

/*global vec3, mat4, jQuery */

var mrlSG;

(function($) {
	mrlSG = function(widget) {
	};
	
	var sg = mrlSG;
	var sgp = sg.prototype;
	
	sg.Node = function(widget) {
		if(widget)
		{
			this.widget = widget;
		}
	};
	sg.Node.prototype.drawInternal = function() {
	};
	sg.Node.prototype.draw = function() {
		var m = this.matrix;
		var material = this.getMaterial();
		var widget = this.widget;
		if(m)
		{
			widget.pushmv();
			mat4.multiply(widget.mvMatrix, m);
		}
		try 
		{
			widget.setUniformMatrices('uMVMatrix', 'uPMatrix', 'uNMatrix');
			if(material) {
				widget.pushMaterial(material);
			}
			return this.drawInternal();
		}
		finally 
		{
			if(m)
			{
				widget.popmv();
			}
			if(material) {
				widget.popMaterial();
			}
		}
	};
	sg.Node.prototype._addToBBox = function(points)
	{
		if(!this.bbox && arguments.length) {
			this.bbox =  [ [Infinity, Infinity, Infinity], [-Infinity, -Infinity, -Infinity] ];
		}
		var i, j;
		var min = this.bbox[0];
		var max = this.bbox[1];
		var npts = points.length;
		for(i=0; i<npts; i++)
		{
			var pt = points[i];
			for(j=0; j<3; j++)
			{
				max[j] = Math.max(max[j], pt[j]);
				min[j] = Math.min(min[j], pt[j]);
			}
		}
	};
	sg.Node.prototype.bboxCorners = function() {
		var i, j, k;
		if(!this.bbox) { return []; }
		var result = [];
		var bbox = this.bbox;
		for(i=0; i<2; i++)
		{
			for(j=0; j<2; j++)
			{
				for(k=0; k<2; k++)
				{
					var pt = [bbox[i][0], bbox[j][1], bbox[k][2]];
					if(this.matrix) { mat4.multiplyVec3(this.matrix, pt); }
					result.push(pt); 
				}
			}
		}
		return result;
	};
	sg.Node.prototype.bboxCenter = function() {
		var bbox = this.bbox;
		if(!this.bbox) { return null; }
		var center = vec3.add(bbox[0], bbox[1], vec3.create());
		vec3.scale(center, 0.5);
		if(this.matrix) { mat4.multiplyVec3(this.matrix, center); }
		return center;
	};
	sg.Node.prototype.getMaterial = function() {
		return this.material;
	};

	sg.ListNode = function(widget, children) {
		if(widget)
		{
			sg.Node.call(this, widget);
			this.children = children;
			if(children)
			{
				var self = this;
				$.each(children, function() {
					self._addToBBox(this.bboxCorners());
				});
			}
		}
	};
	sg.ListNode.prototype = new sg.Node();
	sg.ListNode.prototype.drawInternal = function()
	{
		var children = this.children;
		if(children)
		{
			var i, n = children.length;
			for(i=0; i<n; i++)
			{
				children[i].draw();
			}
		}
	};
	
	sg.MeshNode = function(widget, points, normals, texcoords, data) {
		if(data === undefined && !$.isArray(texcoords)) { data = texcoords; texcoords = undefined; }
		if(widget && points && data)
		{
			sg.Node.call(this, widget);
			
			var gl = widget.gl;
			
			this._addToBBox.call(this, points);
			
			// Create buffers for the points and normals
			this.makeFloatBuffer('pointBuffer', points);
			this.makeFloatBuffer('normalBuffer', normals);
			this.makeFloatBuffer('texcoordBuffer', texcoords);
			this._setTypeIndices(data);
		}
	};
	sg.MeshNode.prototype = new sg.Node();
	
	sg.MeshNode.prototype.types = [ 'LINES', 'TRIANGLES', 'TRIANGLE_STRIP', 'TRIANGLE_FAN' ];
	sg.MeshNode.prototype.pointArrayToFloatArray = function(arr)
	{
		var i, j;
		if(arr && arr.length)
		{
			var n = arr[0].length;
			var dblArr = [];
			for(i=0; i<arr.length; i++)
			{
				for(j=0; j<n; j++)
				{
					dblArr.push(arr[i][j]);
				}
			}
			dblArr.pointSize = n;
			return dblArr;
		}
		else
		{
			return null;
		}
	};
	sg.MeshNode.prototype.makeFloatBuffer = function(buffname, arr)
	{
		if(arr)
		{
			var dbls = this.pointArrayToFloatArray(arr);
			this[buffname] = this.widget.setFloatBufferData(this[buffname], dbls, dbls.pointSize);
		}
		else
		{
			this[buffname] = null;
		}
	};
	sg.MeshNode.prototype._setTypeIndices = function(data)
	{
		this.trianglesOnly(data);
		var self = this;
		var idx = 0;
		var i;
		self.typeData = {};
		var allIndices = [];
		$.each(this.types, function() {
			var t = this;
			var sizes = [];
			self.typeData[t] = sizes;
			if (data[t]) {
				$.each(data[t], function() {
					for(i = 0; i<this.length; i++)
					{
						allIndices.push(this[i]);
					}
					sizes.push(this.length);
				});
			}
		});
		

		var simple = allIndices.every(function(val, idx) { return val === idx; });
		if(simple) {
			this.simpleArray = true;
		}
		else
		{
			self.indexBuffer = self.widget.setElementArrayBufferData(null, allIndices);
		}
	};
	sg.MeshNode.prototype.trianglesOnly = function(data)
	{
		var triangleIndices = [];
		// triangles---concatenate all of them
		var trianglesIn = data.TRIANGLES;
		if(trianglesIn)
		{
			$.each(trianglesIn, function() {
				triangleIndices = triangleIndices.concat(this);
			});
		}
		var tristripsIn = data.TRIANGLE_STRIP;
		if(tristripsIn)
		{
			$.each(tristripsIn, function() {
				var strip = this;
				var ntri = strip.length - 2;
				var i;
				for(i = 0; i<ntri; i++)
				{
					triangleIndices.push(strip[i]);
					triangleIndices.push(strip[i+1]);
					triangleIndices.push(strip[i+2]);
				}
			});
		}
		var trifansIn = data.TRIANGLE_FAN;
		if(trifansIn)
		{
			$.each(trifansIn, function() {
				var fan = this;
				var ntri = fan.length - 1;
				var i;
				for(i = 0; i<ntri; i++)
				{
					triangleIndices.push(fan[0]);
					triangleIndices.push(fan[i]);
					triangleIndices.push(fan[i+1]);
				}
			});
		}
		
		data.TRIANGLES = [triangleIndices];
		data.TRIANGLE_STRIP = undefined;
		data.TRIANGLE_FAN = undefined;
		return data;
	};
	
	sg.MeshNode.prototype.drawInternal = function() {
		var self = this;
		var idx = 0;
		var widget = self.widget;
		var gl = widget.gl;
		widget.setFloatAttribPointer('aVertexPosition', this.pointBuffer);
		widget.setFloatAttribPointer('aVertexNormal', this.normalBuffer);
		widget.setFloatAttribPointer('aUV', this.texcoordBuffer);
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
		
		var btype = widget.gl.UNSIGNED_SHORT;
		var types = self.types;
		var ntypes = types.length;
		var i, j;
		for(i = 0; i< ntypes; i++) {
			var t = types[i];
			var tenum = gl[t];
			var typedata = self.typeData[t];
			var ndata = typedata.length;

			for(j = 0; j < ndata; j++) {
				var sz = typedata[j];
				if(this.simpleArray)
				{
					gl.drawArrays(tenum, idx, sz);
				}
				else
				{
					gl.drawElements(tenum, sz, btype, 2 * idx);
				}
				idx += sz;
			}
		}
	};
	
	sg.FacetNode = function(widget, facets) {
		if(widget && facets)
		{
			var points = [];
			var normals = [];
			var indices = [];
			var i, j, idx=0;
			for(i=0; i<facets.length; i++)
			{
				var facet = facets[i];
				var n = facet.normal;
				var verts = facet.vertices;
				for(j=0; j<3; j++)
				{
					points.push(verts[j]);
					normals.push(n);
					indices.push(idx++);
				}
			}
			sg.MeshNode.call(this, widget, points, normals, {
				TRIANGLES : [indices]
			});
		}
	};
	sg.FacetNode.prototype = new sg.MeshNode();
	
	sg.SphereNode = function(widget, center, radius, nlat, nlong) {
		if(widget)
		{
			if(!center) { center = [0, 0, 0]; }
			if(!radius) { radius = 1.0; }
			var points = [];
			var normals = [];
			var doPoint = function(x, y, z) {
				var n = [x, y, z];
				normals.push(n);
				var p = vec3.scale(n, radius, vec3.create());
				points.push(p);
			};
			doPoint(0, 0, 1);
			var i, j;
			for(i=0; i<nlong; i++)
			{
				var along = i * Math.PI * 2 / nlong;
				var clong = Math.cos(along);
				var slong = Math.sin(along);
				for(j=1; j<=nlat; j++)
				{
					var clong = Math.cos(along + j * Math.PI / nlong);
					var slong = Math.sin(along + j * Math.PI / nlong);
					var alat = j * Math.PI / (nlat + 1);
					var slat = Math.sin(alat);
					var clat = Math.cos(alat);
					doPoint(slat * clong, slat * slong, clat);
				}
			}
			doPoint(0, 0, -1);
			var latLongIndex = function(lat, long) {
				if(lat >= nlat) { return nlat * nlong + 1; }
				
				var idx = nlat * (long % nlong) + lat + 1;
				return idx;
			};
			
			var strip = [];
			if(false)
			{
				var indices = [];
				for(i=0; i<nlong; i++)
				{
					strip = [0];
					for(j=0; j<nlat; j++)
					{
						strip.push(latLongIndex(j, i));
						strip.push(latLongIndex(j, i+1));
					}
					strip.push(nlat * nlong + 1);
					indices.push(strip);
				}
				sg.MeshNode.call(this, widget, points, normals, {
					TRIANGLE_STRIP : indices
				});
			} else {
				var fans = [[], []];
				var strips = [];
				// Fans
				fans[0].push(0);
				fans[1].push(nlat * nlong + 1);
				for(i=0; i<=nlong; i++)
				{
					fans[0].push(latLongIndex(0, i));
					fans[1].push(latLongIndex(nlat-1, nlong-i));
				}
				for(i=1; i<nlat; i++)
				{
					strip = [];
					for(j=0; j<=nlong; j++)
					{
						strip.push(latLongIndex(i-1, j));
						strip.push(latLongIndex(i, j));
					}
					strips.push(strip);
				}
				sg.MeshNode.call(this, widget, points, normals, {
					TRIANGLE_FAN : fans,
					TRIANGLE_STRIP : strips
				});
			}
		}
	};
	sg.SphereNode.prototype = new sg.MeshNode();
	
	
})(jQuery);