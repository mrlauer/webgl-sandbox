/*
 * mrlmaterial.js
 * Copyright 2011 Michael Lauer
 * 
 * materials for webgl rendering
 * assumes the following uniforms and attributes and uniforms:
 * 		aEmision, uEmissionTexture, uUseEmissionTexture
 *		aDiffuse, uDiffuseTexture, uUseDiffuseTexture
 *		aAmbient, uAmbientTexture, uUseAmbientTexture
 *		aSpecular, uSpecularTexture, uUseSepcularTexture
 *		uShininess
 */

var mrlMaterial, defaultMaterial;

(function($) {
	
mrlMaterial = function( params )
{
	this.emission = { color : [ 0, 0, 0, 1] };
	this.diffuse = { color : [ 0.8, 0.8, 0.8, 1] };
	this.ambient = { color : [ 0.2, 0.2, 0.2, 1 ] };
	this.specular = { color : [ 1, 1, 1, 1] };
	this.shininess = 1.0;
	if(params) {
		$.extend(this, params);
	}
};

var colorAttrs = { };
var colors = [ 'emission', 'diffuse', 'ambient', 'specular' ];

(function() {
	var i;
	for(i=0; i<colors.length; i++) {
		var c = colors[i];
		var cbase = c.substr(0, 1).toUpperCase() + c.substr(1);
		var colorAttr = 'a' + cbase;
		var textureUni = 'u' + cbase + 'Texture';
		var useUni = 'uUse' + cbase + 'Texture';
		colorAttrs[c] = { colorAttr : colorAttr, textureUni : textureUni, useUni : useUni };
	}
}());

mrlMaterial.prototype.setAttributes = function(widget) {
	var i;
	var ncolors = colors.length;
	widget.vertexAttrib4fv('aColor', [0, 0, 0, 1]);
	for(i=0; i<ncolors; i++) {
		var c = colors[i];
		var attrs = colorAttrs[c];
		var v = this[c];
		if(v.color)
		{
			widget.vertexAttrib4fv(attrs.colorAttr, v.color);
			widget.useTexture(attrs.textureUni, attrs.useUni, null, i);
		}
		else if(v.texture)
		{
			widget.vertexAttrib4fv(attrs.colorAttr, [1, 0, 0, 1]);
			widget.useTexture(attrs.textureUni, attrs.useUni, v.texture, i);
		}
	}
	widget.uniform1f('uMaterialShininess', this.shininess);
};

mrlMaterial.prototype.loadTextures = function(widget, baseurl) {
	var i;
	for(i in colors) {
		var c = colors[i];
		var v = this[c];
		if(v.texturesource && v.texture) {
			var src = baseurl.replace(/[^\/]*$/, v.texturesource);
			widget.loadTexture(v.texture, src);
		}
	}
};

var _defaultMaterial = new mrlMaterial();

defaultMaterial = function() {
	return _defaultMaterial;
};

	
} (jQuery) );

