
(function( $, undefined ) {

$.widget("mrl.dragHelper", $.ui.mouse, {
	widgetEventPrefix: "dragHelper",
	options: {
		onStart : function(e) {},
		onDrag : function(e) {},
		onStop : function(e) {}
	},
	_create: function() {

		this._mouseInit();
		this._dragging = false;
                this.middleButton = false;
	},

	destroy: function() {
		if(!this.element.data('dragHelper')) return;
		this.element
			.removeData("dragHelper")
			.unbind(".dragHelper");
		this._mouseDestroy();

		return this;
	},
	
	dragging: function() {
		return this._dragging;
	},

	_mouseStart: function(event) { this._dragging = true; this.lastX = event.pageX; this.lastY = event.pageY; this.options.onStart.call(this, event); },
	_mouseDrag: function(event) { 
		this.options.onDrag.call(this, event, event.pageX - this.lastX, event.pageY - this.lastY);
		this.lastX = event.pageX;
		this.lastY = event.pageY;
	},
	_mouseStop: function(event) { this.options.onStop.call(this, event); this._dragging = false; },

        // Override the base class to allow middle button
        _mouseDown: function(event) {
            this.middleButton = false;
            if(event.which == 2) {
                // middle button
                event.which = 1;
                this.middleButton = true;
            }
            return $.ui.mouse.prototype._mouseDown.call(this, event);
        }
});
})(jQuery);

