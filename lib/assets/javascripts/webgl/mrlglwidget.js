/*
 * jquery-ui widget for adding gl stuff to canvas
 *
 * Copyright 2011, Michael R. Lauer
 *
 * Depends:
 *   jquery.ui.core.js
 *   jquery.ui.widget.js
 */

/*global WebGLUtils, mat4, mat3, alert, Float32Array, Int32Array, Uint16Array, jQuery */


(function($) {
    
var standardDraw = function(options) {
    var internalDraw = this.options.internalDraw;
    if(internalDraw) {
        var gl = this.gl;
        gl.viewport(0, 0, gl.viewportWidth, gl.viewportHeight);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    
        mat4.identity(this.mvMatrix);        
        mat4.identity(this.pMatrix);
        
        this.camera.setMatrices(this);
        this.pickingMatrices();
        
        this.setupShader = function() {
            var shaderProgram = this.shaderProgram;
            var lighting = true;
            gl.uniform1i(shaderProgram.useLightingUniform, lighting);
            var phong = true;
            this.uniform1i('uPhong', phong);
            var shiny = 8.0;
            this.uniform1f("uMaterialShininess", shiny);
            
            this.uniform1i("uShowSpecularHighlights", 1);
            this.uniform3f("uAmbientColor", 0.5, 0.5, 0.5);
            this.uniform3f('uPintLightingLocation', 1.0, 10.0, 4.0);
            this.uniform3f('uPointLightingSpecularColor', 1.0, 1.0, 1.0);
            this.uniform3f('uPointLightingDiffuseColor', 0.5, 0.5, 0.5);
            
            this.enableVertexAttribArray("aUV", true);
            this.enableVertexAttribArray("aVertexPostion");
            this.enableVertexAttribArray("aColor", false);
            this.enableVertexAttribArray("aVertexNormal", true);
            
            this.setUniformMatrices('uMVMatrix', 'uPMatrix', 'uNMatrix');
        }
        
        this.setupShader();
        this.options.internalDraw.call(this, options);
    }
};

var args = {
        options: {
            draw : standardDraw,
            internalDraw : null,
            initialize : function() {},
            useMatrices : true
        },

        _create: function() {
            var message;
            try {
                var canvas = this.element.get(0);
                var gl = WebGLUtils.setupWebGL(canvas);
                if(gl)
                {
                    this.gl = gl;
                    canvas.width = $(canvas).width();
                    canvas.height = $(canvas).height();
                    this.gl.viewportWidth = canvas.width;
                    this.gl.viewportHeight = canvas.height;
                    $(canvas).resize(function(e) {
                        canvas.width = $(canvas).width();
                        canvas.height = $(canvas).height();
                        gl.viewportWidth = canvas.width;
                        gl.viewportHeight = canvas.height;
                    });
                    this._initMatrices();
                    this.textures = {};
                    this.options.initialize.call(this);
                }
            } catch(e) {
                if(e) { message = e; }
            }
            if(message)
            {
                alert(message);
            }
        },

        _makeShader: function(content, type) {
            var gl = this.gl;
            var script = $(content).first();
            if (type === undefined)
            {
                if(script.attr('type') === 'x-shader/x-fragment')
                {
                    type = gl.FRAGMENT_SHADER;
                }
                else if(script.attr('type') === 'x-shader/x-vertex')
                {
                    type = gl.VERTEX_SHADER;
                }
                else
                {
                    return null;
                }
            }
            var source = $(content).text();
            var shader = gl.createShader(type);
            gl.shaderSource(shader, source);
            gl.compileShader(shader);

            if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
                alert(gl.getShaderInfoLog(shader));
                return null;
            }
            return shader;
        },

        initProgram: function(vertexShader, fragmentShader) {
            var gl = this.gl;
            if(!vertexShader) {
                vertexShader = $('script[type="x-shader/x-vertex"]').first();
            }
            if(!fragmentShader) {
                fragmentShader = $('script[type="x-shader/x-fragment"]').first();
            }
            var vs = this._makeShader(vertexShader);
            var fs = this._makeShader(fragmentShader);

            var shaderProgram = gl.createProgram();
            gl.attachShader(shaderProgram, vs);
            gl.attachShader(shaderProgram, fs);
            gl.linkProgram(shaderProgram);

            if (!gl.getProgramParameter(shaderProgram, gl.LINK_STATUS)) {
                alert("Could not initialise shaders");
            }
            
            this.useProgram(shaderProgram);
            return shaderProgram;
        },

        useProgram: function(program) {
            this.shaderProgram = program;
            this.gl.useProgram(program);
            if(this.setupShader)
            {
                this.setupShader();
            }
        },

        _initMatrices : function()
        {
            this.mvMatrix = mat4.create();
            this.pMatrix = mat4.create();
            this.mvStack = [];
            this.pStack = [];
            this.materialStack = [];
        },

        pushmv : function () {
            var copy = mat4.create();
            mat4.set(this.mvMatrix, copy);
            this.mvStack.push(copy);
        },

        popmv : function () {
            if (this.mvStack.length === 0) {
                throw "Invalid popMatrix!";
            }
            this.mvMatrix = this.mvStack.pop();
        },

        pushp : function () {
            var copy = mat4.create();
            mat4.set(this.pMatrix, copy);
            this.pStack.push(copy);
        },

        popp : function () {
            if (this.pStack.length === 0) {
                throw "Invalid popMatrix!";
            }
            this.pMatrix = this.pStack.pop();
        },

        getUniformLocation : function(attrName) {
            var loc = this.shaderProgram[attrName];
            if(loc === undefined)
            {
                loc = this.gl.getUniformLocation(this.shaderProgram, attrName);
                this.shaderProgram[attrName] = loc;
            }
            return loc;
        },

        setUniformMatrices : function (mv, proj, normal) {
            var gl = this.gl, attr;
            if(mv)
            {
                attr = this.getUniformLocation(mv);
                gl.uniformMatrix4fv(attr, false, this.mvMatrix);
            }
            if(proj)
            {
                attr = this.getUniformLocation(proj);
                gl.uniformMatrix4fv(attr, false, this.pMatrix);
            }

            if(normal)
            {
                var normalMatrix = mat3.create();
                mat4.toInverseMat3(this.mvMatrix, normalMatrix);
                mat3.transpose(normalMatrix);
                attr = this.getUniformLocation(normal);
                gl.uniformMatrix3fv(attr, false, normalMatrix);
            }
        },
        
        draw : function()
        {
            this.options.draw.apply(this, arguments);
        },
        
        setFloatBufferData : function(buffer, data, itemSize, type)
        {
            if(!buffer)
            {
                buffer = this.gl.createBuffer();
            }
            if (type === undefined) { type = this.gl.STATIC_DRAW; }
            this.gl.bindBuffer(this.gl.ARRAY_BUFFER, buffer);
            if (typeof (data) !== 'Float32Array') { data = new Float32Array(data); }
            this.gl.bufferData(this.gl.ARRAY_BUFFER, data, type);
            buffer.itemSize = itemSize;
            buffer.numItems = data.length / itemSize;
            return buffer;
        },

        setIntBufferData : function(buffer, data, itemSize, type)
        {
            if(!buffer)
            {
                buffer = this.gl.createBuffer();
            }
            if (type === undefined) { type = this.gl.STATIC_DRAW; }
            this.gl.bindBuffer(this.gl.ARRAY_BUFFER, buffer);
            this.gl.bufferData(this.gl.ARRAY_BUFFER, new Int32Array(data), type);
            buffer.itemSize = itemSize;
            buffer.numItems = data.length / itemSize;
            return buffer;
        },

        setElementArrayBufferData : function(buffer, data, type)
        {
            if(!buffer)
            {
                buffer = this.gl.createBuffer();
            }
            if (type === undefined) { type = this.gl.STATIC_DRAW; }
            this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, buffer);
            this.gl.bufferData(this.gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(data), type);
            buffer.itemSize = 1;
            buffer.numItems = data.length;
            return buffer;
        },
        
        getAttribLocation : function(attr)
        {
            var loc = this.shaderProgram[attr];
            if(loc === undefined)
            {
                loc = this.gl.getAttribLocation(this.shaderProgram, attr);
                this.shaderProgram[attr] = loc;
            }
            return loc;
        },
        
        setFloatAttribPointer : function(attr, buffer)
        {
            var gl = this.gl;
            var loc = this.shaderProgram[attr];
            if(loc === undefined)
            {
                loc = this.gl.getAttribLocation(this.shaderProgram, attr);
                this.shaderProgram[attr] = loc;
            }
            if(buffer) {
                gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
                gl.vertexAttribPointer(loc, buffer.itemSize, gl.FLOAT, false, 0, 0);
                gl.enableVertexAttribArray(loc);
            } else {
                gl.disableVertexAttribArray(loc);
            }
        },
        
        enableDepthTest : function(enable)
        {
            if(enable)
            {
                this.gl.enable(this.gl.DEPTH_TEST);
                this.gl.blendFunc(this.gl.SRC_ALPHA, this.gl.ONE_MINUS_SRC_ALPHA);
                this.gl.enable(this.gl.BLEND);
            }
            else
            {
                this.gl.disable(this.gl.DEPTH_TEST);
                this.gl.blendFunc(this.gl.SRC_ALPHA, this.gl.ONE_MINUS_SRC_ALPHA);
                this.gl.enable(this.gl.BLEND);
            }
        },
        
        enableVertexAttribArray : function(attr, enable)
        {
            if(enable === undefined) { enable = true; }
            var loc = this.gl.getAttribLocation(this.shaderProgram, attr);
            if(loc >= 0)
            {
                if(enable)
                {
                    this.gl.enableVertexAttribArray(loc);
                }
                else
                {
                    this.gl.disableVertexAttribArray(loc);
                }
            }
        },
        
        encodePickingIndex : function(i)
        {
            var d = 1.0/255.0;
            return [ ((i >>> 24) & 0xff) * d, ((i >>> 16) & 0xff) * d, ((i >>> 8) & 0xff) * d, (i & 0xff) * d];
        },
        
        decodePickingIndex : function(v)
        {
            return (v[0] << 24) + (v[1]<< 16) + (v[2] << 8) +  v[3];
        },
        
        // picking stuff
        beginPicking : function(x, y, defaultPickingIndex)
        {
            var gl = this.gl;
            if(defaultPickingIndex === undefined) { defaultPickingIndex = -1; }
            
            var width = 4;
            var height = 4;
            
            // create a texture
            if(!this.pickingTexture)
            {
                var texture = gl.createTexture();
                gl.bindTexture(gl.TEXTURE_2D, texture);
                gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
                gl.bindTexture(gl.TEXTURE_2D, null);
                
                this.pickingTexture = texture;
                
                // Now a framebuffer and renderbuffer
                var globalRenderBufferId = gl.createRenderbuffer();
                gl.bindRenderbuffer(gl.RENDERBUFFER, globalRenderBufferId);
                gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT16, width, height);
                gl.isRenderbuffer(globalRenderBufferId);
                gl.bindRenderbuffer(gl.RENDERBUFFER, null);
    
                var framebuffer = gl.createFramebuffer();
                gl.bindFramebuffer( gl.FRAMEBUFFER, framebuffer);
                gl.framebufferTexture2D( gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0);
                gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, globalRenderBufferId);

                gl.bindFramebuffer( gl.FRAMEBUFFER, null);
                this.pickingFramebuffer = framebuffer;
            }
                
            // Setup to draw to this fb
            gl.bindFramebuffer(gl.FRAMEBUFFER, this.pickingFramebuffer);
            
            // modify the proj matrix
            this.pickMat = mat4.identity(mat4.create());
            mat4.translate(this.pickMat, [-2*(x)/gl.viewportWidth, 2*(y)/gl.viewportHeight - 2, 0]);
            
            this.uniform1i('uPicking', true);
            
            this.uniform4fv('uPickingIndex', this.encodePickingIndex(defaultPickingIndex)); 
            this.gl.clearColor(0.0, 0.0, 0.0, 0.0);
            
            return this.pickingFramebuffer;
        },
        
        finishPicking : function()
        {
            delete this.pickMat;

            this.uniform1i('uPicking', false);
            
            var gl = this.gl;
            gl.clearColor(0.0, 0.0, 0.0, 1.0);
            gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        },
        
        pick : function(x, y, defaultPickingIndex)
        {
            var gl = this.gl;
            var fb = this.beginPicking(x, y, defaultPickingIndex);
            this.draw({ picking : true });
            
            var width = 3, height = 3;
            var pixsz = width * height * 4;
            var pixels = new Uint8Array(pixsz);
            gl.bindFramebuffer( gl.FRAMEBUFFER, fb);
            gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
            gl.bindFramebuffer( gl.FRAMEBUFFER, null);
            
            var i, hits = {}, hitlist = [];
            for(i=0; i<pixsz/4; i++)
            {
                var off = i*4;
                var idx = this.decodePickingIndex([pixels[off], pixels[off+1], pixels[off+2], pixels[off+3] ]);
                if(idx && !hits[idx])
                {
                    hits[idx] = 1;
                    hitlist.push(idx);
                }
            }
            
            this.finishPicking();
            return hitlist.length ? hitlist : false;
        },
        
        pickingMatrices : function()
        {
            if(this.pickMat)
            {
                mat4.multiply(this.pickMat, this.pMatrix, this.pMatrix);
            }
        },
        
        // Textures
        loadTexture : function(id, url)
        {
            var widget = this;
            var gl = this.gl;
            var image = new Image();
            image.onload = function() {
                var texture = gl.createTexture();
                texture.image = image;
                widget.textures[id] = texture;
                gl.bindTexture(gl.TEXTURE_2D, texture);
                gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
                gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, texture.image);
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
                gl.bindTexture(gl.TEXTURE_2D, null);
                texture.loaded = true;
                widget.draw();
            };
            image.src = url;
        },
        
        useTexture : function(uniform, useUniform, id, idx)
        {
            var gl = this.gl;
            var texture = this.textures[id] || null;
            if(texture && !texture.loaded) { texture = null; }

            gl.activeTexture(gl['TEXTURE' + idx]);
            gl.bindTexture(gl.TEXTURE_2D, texture);
            this.uniform1i(uniform, idx);
            this.uniform1i(useUniform, texture ? 1 : 0);
        },
        
        pushMaterial : function(material) {
            this.materialStack.push(material);
            material.setAttributes(this);
        },
        
        popMaterial : function() {
            this.materialStack.pop();
            if(this.materialStack.length) {
                this.materialStack[materialStack.length-1].setAttributes(this);
            }
        }
    };

// uniform functions
var _uniformFunctions = [];
var i;
for (i=1; i<=4; i++)
{
    $.each (['f', 'i', 'fv', 'iv'], function(index, value)
    {
        _uniformFunctions.push('uniform' + i + value);
    });
    if(i > 1)
    {
        _uniformFunctions.push('uniformMatrix' + i + 'fv');
    }
}

$.each(_uniformFunctions, function(index, name)
    {
        args[name] = function(uname) {
            if(this.shaderProgram)
            {
                var loc = this.gl.getUniformLocation(this.shaderProgram, uname);
                if(loc)
                {
                    if(arguments.length > 1)
                    {
                        arguments[0] = loc;
                        this.gl[name].apply(this.gl, arguments);
                    }
                    else
                    {
                        return this.gl.getUniform(this.shaderProgram, loc);
                    }
                }
            }
        }
    });

// attribute functions
var _attrFunctions = [];
for (i=1; i<=4; i++)
{
    _attrFunctions.push('vertexAttrib' + i + 'f');
    _attrFunctions.push('vertexAttrib' + i + 'fv');
}

$.each(_attrFunctions, function(index, name)
    {
        args[name] = function(aname) {
            if(this.shaderProgram)
            {
                var attr = this.gl.getAttribLocation(this.shaderProgram, aname);
                if(arguments.length > 1)
                {
                    arguments[0] = attr;
                    this.gl[name].apply(this.gl, arguments);
                }
            }
        }
    });

$.widget( "mrlgl.mrlgl", args);

}) (jQuery);
