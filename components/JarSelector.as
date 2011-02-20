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

	import nochump.util.zip.ZipFile;
	import nochump.util.zip.ZipError;
	import mx.skins.halo.BusyCursor;
	import mx.collections.IViewCursor;

	public class JarSelector extends List
	{
		private static var _fileFilters:Array = [ new FileFilter("Jars", "*.jar"), new FileFilter("All Files", "*") ];

		[Embed (source="/assets/icons/book.png" )]
        private static const _libraryIcon:Class;

		[Embed (source="/assets/icons/brick.png" )]
        private static const _applicationIcon:Class;

		[Embed (source="/assets/icons/Java-logo.png" )]
        private static const _javaIcon:Class;

		[Embed (source="/assets/icons/Android-logo.png" )]
        private static const _androidIcon:Class;

        private var file:FileReference;

		public var mains:ArrayCollection;

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
			try {
				dataProvider.addItem({name:f.name, file:f, mains:computeMains(f, true), type:true});
			}
			catch (e:ZipError) {
				Alert.show("Your file does not look like a jar file");
			}

			this.mains.removeAll();
			for (var cursor:IViewCursor = dataProvider.createCursor(); !cursor.afterLast; cursor.moveNext())
				this.mains.addAll(cursor.current.mains);
		}

		private function addLibraryFiles(event:Event):void {
			var f:FileReference = event.target as FileReference;
			try {
				dataProvider.addItem({name:f.name, file:f, mains:computeMains(f, false), type:false});
			}
			catch (e:ZipError) {
				Alert.show("Your file does not look like a jar file");
			}
		}

		public function remove(event:ListEvent):void {
			dataProvider.removeItemAt(event.rowIndex);
			this.mains.removeAll();
			for (var cursor:IViewCursor = dataProvider.createCursor(); !cursor.afterLast; cursor.moveNext())
				this.mains.addAll(cursor.current.mains);
		}

		private function computeMains(file:FileReference, application:Boolean):ArrayCollection {
			const len:uint = file.name.length;

			// a stupid test. Later, the constructor of ZipFile might
			// throw this exception as well
			if (len < 4 || file.name.substring(len - 4, len) != ".jar")
				throw new ZipError();

			// we build the zip file anyway, also for libraries. This way,
			// if it does not look like a zip file, an exception is thrown
			const zip:ZipFile = new ZipFile(file.data);
			const mains:ArrayCollection = new ArrayCollection();

			if (application) {
				const androidActivityNames:ArrayCollection = computeAndroidActivityNames(zip);

				for (var i:uint = 0; i < zip.entries.length; i++) {
					var name:String = zip.entries[i].name;
					var pos:int;
					var result:uint;

					if ((pos = name.lastIndexOf(".class")) >= 0 && pos == name.length - 6) {
						while (name.indexOf('/') >= 0)
							name = name.replace('/', '.');
						const shortName:String = name.substring(0, name.length - 6);
						if (androidActivityNames.contains(shortName))
							mains.addItem({label:shortName, icon:_androidIcon});

						if (containsMain(zip.getInput(zip.entries[i])))
							mains.addItem({label:shortName + ".main(String[])", icon:_javaIcon});
					}
				}
			}

			return mains;
		}

		/**
		 * Computes the names of the Android activity classes in the zipped file.
		 * It first looks for the <tt>AndroidManifest.xml</tt> file, parses it
		 * and collects all activity names declared there.
		 */

		private function computeAndroidActivityNames(zip:ZipFile):ArrayCollection {
			const res:ArrayCollection = new ArrayCollection();

			for (var i:uint = 0; i < zip.entries.length; i++) {
				if (zip.entries[i].name == "AndroidManifest.xml") {
					// The AndroidManifest.xml file provides the list of activities
					// in an Android project
					const xml:XML = new XML(zip.getInput(zip.entries[i]).toString());
					const android:Namespace = new Namespace("http://schemas.android.com/apk/res/android");
					const androidName:QName = new QName(android, "name");
					const pack:String = xml.attribute("package");
					const activities:XMLList = xml.application.activity;

					for each (var activity:XML in activities) {
						const name:String = activity.attribute(androidName);

						if (name.length > 0)
							if (name.charAt(0) == ".")
								res.addItem(pack + name);
							else {
								// in this case, we do not really know if the package
								// should be prefixed or not to the name: we consider both scenarios
								res.addItem(pack + "." + name);
								res.addItem(name);
							}
					}
				}
			}

			return res;
		}

		/**
		 * Checks if the given sequence of bytes is a class file that defines a main()
		 * method.
		 */
 
		private function containsMain(bytes:ByteArray):Boolean {
			try {
				if (bytes.readUnsignedInt() != 0xcafebabe)  // magic
					return false;

				bytes.readUnsignedShort();  // minor_version
				bytes.readUnsignedShort();  // major version

				const cpc:uint = bytes.readUnsignedShort();  // constant_pool_count
				const cp:Array = parseConstantPool(bytes, cpc);

				bytes.readUnsignedShort();  // access_flags
				bytes.readUnsignedShort();  // this_class
				const sp:uint = bytes.readUnsignedShort();  // super_class;

				var ic:uint = bytes.readUnsignedShort();  // interfaces_count;

				while (ic-- > 0)
					bytes.readUnsignedShort();  // interfaces

				const fc:uint = bytes.readUnsignedShort();  // fields_count
				parseFields(bytes, fc);

				const mc:uint = bytes.readUnsignedShort();  // methods_count

				return parseMethods(bytes, mc, cp);  // methods
			}
			catch (e:EOFError) {
				// the .class file does not look like an actual Java class file
			}

			return false;
		}

		private function parseConstantPool(bytes:ByteArray, cpc:uint):Array {
			const res:Array = new Array(cpc);
			var pos:uint = 1;

			while (pos < cpc) {
				var tag:uint = bytes.readUnsignedByte(); // tag
				switch (tag) {
					case 7: // CONSTANT_Class
						res[pos] = bytes.readUnsignedShort();  // name_index
						break;
					case 9: // CONSTANT_Fieldref
					case 10: // CONSTANT_Methodref
					case 11: // CONSTANT_InterfaceMethodref
						res[pos] = -1;
						bytes.readUnsignedShort();  // class_index
						bytes.readUnsignedShort();  // name_and_type_index
						break;
					case 8: // CONSTANT_String
						res[pos] = bytes.readUnsignedShort();  // string_index
						break;
					case 3: // CONSTANT_Integer
					case 4: // CONSTANT_Float
						res[pos] = bytes.readUnsignedInt();  // bytes
						break;
					case 5: // CONSTANT_Long
					case 6: // CONSTANT_Double
						res[pos] = -1;
						bytes.readUnsignedInt();  // bytes
						bytes.readUnsignedInt();  // bytes
						pos++;  // these use two slots in the constant pool!
						break;
					case 12: // CONSTANT_NameAndType
						res[pos] = -1;
						bytes.readUnsignedShort();  // name_index
						bytes.readUnsignedShort();  // descriptor_index
						break;
					case 1: // CONSTANT_Utf8
						res[pos] = bytes.readUTF();  // length and bytes
						break;
					default:
						res[pos] = -1;
				}

				pos++;
			}

			return res;
		}

		private function parseFields(bytes:ByteArray, fc:uint):void {
			while (fc-- > 0) {
				bytes.readUnsignedShort();  // access_flags
				bytes.readUnsignedShort();  // name_index
				bytes.readUnsignedShort();  // descriptor_index

				const ac:uint = bytes.readUnsignedShort();  // attributes_count
				parseAttributes(bytes, ac);  // attributes
			}
		}

		private function parseAttributes(bytes:ByteArray, ac:uint):void {
			while (ac-- > 0) {
				bytes.readUnsignedShort();  // attribute_name_index;

				var al:uint = bytes.readUnsignedInt();  // attribute_length;
				while (al-- > 0)
					bytes.readUnsignedByte();  // info
			}
		}

		private function parseMethods(bytes:ByteArray, mc:uint, cp:Array):Boolean {
			while (mc-- > 0) {
				const af:uint = bytes.readUnsignedShort();  // access_flags;
				const ni:uint = bytes.readUnsignedShort();  // name_index;
				const di:uint = bytes.readUnsignedShort();  // descriptor_index
				const ac:uint = bytes.readUnsignedShort();  // attributes_count
				parseAttributes(bytes, ac);  // attributes

				if (af == 9 && cp[ni] == "main" && cp[di] == "([Ljava/lang/String;)V")  // public static void main(String[])
					return true;
			}

			return false;
		}
	}
}