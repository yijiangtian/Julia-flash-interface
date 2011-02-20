package components
{
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.events.HTTPStatusEvent;
    import flash.events.IOErrorEvent;
    import flash.events.SecurityErrorEvent;
    import flash.errors.EOFError;
    import flash.net.URLRequest;
    import flash.net.FileFilter;
    import flash.net.FileReference;
    import flash.utils.ByteArray;

    import mx.managers.CursorManager;
    import mx.controls.List;
    import mx.controls.Alert;
    import mx.events.ListEvent;
    import mx.collections.ArrayCollection;

    import mx.skins.halo.BusyCursor;
    import mx.collections.IViewCursor;

    public class JarSelector extends List
    {
        private static var _fileFilters:Array = [ new FileFilter("Jars", "*.jar"), new FileFilter("All Files", "*") ];

        [Embed (source="/assets/icons/book.png" )]
        private static const _libraryIcon:Class;

        [Embed (source="/assets/icons/brick.png" )]
        private static const _applicationIcon:Class;

        private var file:FileReference;

        public function JarSelector()
        {
            this.dataProvider = new ArrayCollection();
            this.addEventListener(ListEvent.ITEM_CLICK, remove);
            this.iconFunction = iconFunc;
            this.labelField = "name";
        }

        public function get jarFiles():ArrayCollection {
            const result:ArrayCollection = new ArrayCollection();

            for (var cursor:IViewCursor = dataProvider.createCursor(); !cursor.afterLast; cursor.moveNext())
                result.addItem({file: cursor.current.file, type: cursor.current.type});

            return result;
        }

	public function ok():Boolean {
	    for (var cursor:IViewCursor = dataProvider.createCursor(); !cursor.afterLast; cursor.moveNext())
                if (cursor.current.type)
		   return true;

            return false;
	}

        public function addApplicationJar():void {
            file = new FileReference();
            file.addEventListener(Event.COMPLETE, addApplicationFiles);
            file.addEventListener(HTTPStatusEvent.HTTP_STATUS, errorHandler);
            file.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
            file.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler);
            file.addEventListener(Event.SELECT, fileSelectedHandler);
            file.browse(_fileFilters);
        }

        public function addLibraryJar():void {
            file = new FileReference();
            file.addEventListener(Event.COMPLETE, addLibraryFiles);
            file.addEventListener(HTTPStatusEvent.HTTP_STATUS, errorHandler);
            file.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
            file.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler);
            file.addEventListener(Event.SELECT, fileSelectedHandler);
            file.browse(_fileFilters);
        }

        private function errorHandler(event:Event):void {
            Alert.show("I/O error");
        }

        private function fileSelectedHandler(event:Event):void {
            event.target.load();
        }

        private function iconFunc(item:Object):Class {
            if (item.type)
                return _applicationIcon;
            else
                return _libraryIcon;
        }

        private function addApplicationFiles(event:Event):void {
            var f:FileReference = event.target as FileReference;
            dataProvider.addItem({name:f.name, file:f, type:true});
	}

        private function addLibraryFiles(event:Event):void {
            var f:FileReference = event.target as FileReference;
            dataProvider.addItem({name:f.name, file:f, type:false});
        }

        public function remove(event:ListEvent):void {
            dataProvider.removeItemAt(event.rowIndex);
        }
    }
}