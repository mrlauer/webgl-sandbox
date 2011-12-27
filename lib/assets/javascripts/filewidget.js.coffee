//

( ($)->
    $.widget 'mrl.fileWidget',
        options :
            processFile : (file) ->

        _create: ->
            self = this
            element = this.element
            element.addClass('ui-fileWidget')

            fileInput = $('<input type="file"></input>').appendTo(element)
            fileInput.change (event) ->
                nfiles = this.files.length
                if nfiles == 1
                    f = this.files[0]
                    freader = new FileReader()
                    freader.onload = (e) ->
                        self.options.processFile.call self, this.result
                    freader.readAsBinaryString(f)

)(jQuery)
