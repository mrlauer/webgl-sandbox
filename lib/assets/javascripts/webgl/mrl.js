var mrl;
if (!mrl) mrl = {};

mrl.A = function(a)
{
    if(!a) return [];
    else if(a.toArray) return a.toArray();
    else if(length in a)
    {
        var l = a.length;
        var ret = new Array(l); 
        while(l--) ret[l] = a[l];
        return ret;
    }
    else return [a];
};

mrl.zip = function()
{
    var args = mrl.A(arguments);
    var result = [];
    if(args.length)
    {
        var a0 = args[0];
        var n = args.length;
        var l = a0.length;
        result = new Array(l);
        for(var i=0; i<l; i++)
        {
            var t = new Array(n);
            for(var j=0; j<n; j++)
            {
                t[j] = args[j][i];
            }
            result[i] = t;
        }
    }
    return result;
};

mrl.curry = function()
{
    var args = mrl.A(arguments);
    var __fn = args.shift();
    return function() { 
        return __fn.apply(this, args.concat(mrl.A(arguments))); 
    };
};

mrl.asmethod = function(fn)
{
    var __t = this;
    return function() {
        return fn.apply(__t, [this].concat(mrl.A(arguments)));
    };
};

mrl.asfunction = function(fn)
{
    return function() {
        var args = mrl.A(arguments);
        var __t = args.shift();
        return fn.apply(__t, args);
    }
};

mrl.compose = function()
{
    var args = mrl.A(arguments);
    return function()
    {
        var __t = this;
        var l = args.length;
        if(!l) return null;
        var r = arguments[--l].apply(__t, arguments);
        while(l--) r = arguments[l].apply(__t, r);
        return r;
    }
}

mrl.equalArrays = function(a0, a1)
{
    if (a0.length != a1.length) return false;
    for(var i=0; i<a0.length; i++) {
        if (a0[i] != a1[i]) return false;
    }
    return true;
}

// Get the matching cell in the next table row
var _get_matching_cell = function(cell, row, other)
{
    // is there a nice way to do this?
    var idx = -1;
    row.children('td').each( function(i, child) { 
            if($(child)[0] == $(cell)[0]) { idx = i; }
            });
    if(idx >= 0)
    {
        return other.children()[idx];
    }
    return null;
}

mrl.nextRow = function(cell)
{
    var row = $(cell).parent('tr');
    var next = $(row).next('tr');
    return _get_matching_cell(cell, row, next);
}

mrl.prevRow = function(cell)
{
    var row = $(cell).parent('tr');
    var next = $(row).prev('tr');
    return _get_matching_cell(cell, row, next);
}

mrl.Observer = function(e, t, fn) {
    var self = this;
    var getvals = function() {
        return $(e).map(function(el) {
                return $(this).val();
                } ).get();
    }
    this.value = getvals();
    this.timer = setInterval(
        function() {
            var v = getvals();
            if(!mrl.equalArrays(v, self.value))
            {
                fn();
                self.value = v;
            }
        },
        t * 1000.0
    );
};

mrl.Observer.prototype.stop = function()
{
    if(this.timer)
    {
        clearInterval(this.timer);
        this.timer = null;
    }
};

if(this.jQuery)
{
    jQuery.fn.observe = function(t, fn)
    {
        var ob = new mrl.Observer(this, t, fn) ;
        return this;
    };
}

mrl.adjustWidth = function(elem)
{
	var bumpSize = function(incr)
	{
		if(incr > 0)
		{
		    var parents = $(this).parents();
		    var bodysz = $("body").width();
		    parents.each(function() {
		        var mw = getMaxWidth($(this));
		        if(mw)
		        {
		            var newmw = mw + incr;
		            setMaxWidth(this, newmw);
		        }
		    });
		}
	}

	var getMaxWidth = function(e)
	{
	    var mw = $(e).css('max-width');
	    if(mw)
	    {
	        var m = mw.match(/(\d+)(?:px)?/);
	        if(m)
	        {
	            var val = parseFloat(m[1]);
	            return val;
	        }
	    }
	    return null;
	}

	var setMaxWidth = function(e, newval)
	{
	    $(e).css('max-width', newval + 'px');
	}

	var parent = $(elem).parent();
	bumpSize.call($(elem), $(elem).width() - parent.width());
};

mrl.ajaxFile = function(url, file, optionsIn) {
	var options = {
		type : 'POST',
		xhrFields : {},
		headers : {},
		contentType : 'application/octet-stream'
	};
	$.extend(options, optionsIn);
	//options.xhrFields.onprogress = function(e) { optionsIn.progress(e); };
	options.xhr = function() {
		var xhr = $.ajaxSettings.xhr();
		if(xhr && xhr.upload) {
			xhr.upload.onprogress = function(e) { if(optionsIn.progress) { optionsIn.progress(e); } };
		}
		return xhr;
	}
	options.data = file;
	options.processData = false;
	if('name' in file && !('X-File-Name' in options.headers) ) {
		options.headers['X-File-Name'] = file.name;
	}
	return $.ajax(url, options);
};

mrl.ajaxBinary = function(url, data, optionsIn) {
	var BlobBuilder = window.BlobBuilder || window.MozBlobBuilder || window.WebKitBlobBuilder;
	var bb = new BlobBuilder();
	bb.append(data);
	return mrl.ajaxFile(url, bb.getBlob(), optionsIn);
};

