/*
 * Base64 encoding
 */

var base64;

(function() {
	
	var keys = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
	var x = -1;
	var values = [
	      x,  x,  x,  x,  x,  x,  x,  x,  x,  x,  x,  x,  x,  x,  x,  x,
	      x,  x,  x,  x,  x,  x,  x,  x,  x,  x,  x,  x,  x,  x,  x,  x,
	      x,  x,  x,  x,  x,  x,  x,  x,  x,  x,  x, 62,  x,  x,  x, 63,
	     52, 53, 54, 55, 56, 57, 58, 59, 60, 61,  x,  x,  x,  x,  x,  x,
	      x,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
	     15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,  x,  x,  x,  x,  x,
	      x, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
	     41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51,  x,  x,  x,  x,  x,
	     ];
	
	base64 = {
		encode : function(data) {
			var len = data.length;
			var ngroups = len/3;
			var i, c1, c2, c3, c4;
			var result = '';
			for(i=0; i<len; i++)
			{
				var d = data.charCodeAt(i);
				c1 = ((d & 0xfc) >>> 2);
				c2 = ((d & 3) << 4);
				i += 1;
				if(i < len) {
					d = data.charCodeAt(i);
					c2 += ((d & 0xf0) >>> 4);
					c3 = ((d & 0x0f) << 2);
					i += 1;
					if(i < len) {
						d = data.charCodeAt(i);
						c3 += ((d & 0xc0) >>> 6);
						c4 = (d & 0x3f);
					} else {
						c4 = 64;
					}
				}
				else
				{
					c3 = c4 = 64;
				}
				result += keys[c1];
				result += keys[c2];
				result += keys[c3];
				result += keys[c4];
			}
			return result;
		},
		
		decode : function(str) {
			// Strip anything that's not in our keys
			str = str.replace( /[^a-zA-Z0-9+\/]/g, '');
			var len = str.length;
			var result = '';
			var i, c1, c2, c3, v;
			for(i=0; i<len; i++)
			{
				v = values[str.charCodeAt(i)];
				c1 = c2 = c3 = undefined;
				if(++i < len) {
					c1 = (v << 2);
					v = values[str.charCodeAt(i)];
					c1 += ((v & 0x30) >>> 4);
				}
				if(++i < len) {
					c2 = ((v & 0x0f) << 4);
					v = values[str.charCodeAt(i)];
					c2 += ((v & 0x3c) >>> 2);
				}
				if(++i < len) {
					c3 = ((v & 0x03) << 6);
					v = values[str.charCodeAt(i)];
					c3 += (v & 0x3f);
				}
				if(c3 !== undefined) {
					result += String.fromCharCode(c1, c2, c3);
				} else if (c2 !== undefined) {
					result += String.fromCharCode(c1, c2);
				} else {
					result += String.fromCharCode(c1);
				}
			}
			return result;
		}
	};
} ());
