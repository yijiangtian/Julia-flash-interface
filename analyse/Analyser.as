package analyse
{
	import flash.events.Event; 
	import flash.events.ProgressEvent;
	import flash.events.MouseEvent;
	import flash.events.IOErrorEvent;
 	import flash.events.SecurityErrorEvent;
 	import flash.net.navigateToURL;
 	import flash.net.URLLoader;
 	import flash.net.URLStream;
 	import flash.net.URLRequest;
 	import flash.net.URLVariables;

    import mx.managers.CursorManager;
    import mx.managers.PopUpManager;
    import mx.core.Application;
    import mx.core.UIComponent;
    import mx.core.ClassFactory;
    import mx.controls.Alert;
    import mx.controls.TextArea;
    import mx.controls.ProgressBar;
    import mx.controls.ProgressBarMode;
    import mx.controls.List;
    import mx.controls.Label;
    import mx.controls.dataGridClasses.DataGridColumn;
 	import mx.controls.DataGrid;
 	import mx.controls.VRule;
	import mx.controls.Button;
	import mx.controls.CheckBox;
 	import mx.containers.TitleWindow;
 	import mx.containers.Panel;
 	import mx.containers.HBox;
 	import mx.containers.VBox;
  	import mx.collections.IViewCursor;
 	import mx.collections.ArrayCollection;
 	import mx.events.CloseEvent;
 	import mx.events.ListEvent;

 	import ext.MultipartURLLoader;

	import components.BugCheckBox;
	import components.AttachmentButton;
	import components.MyProgressBar;

	/**
	 * A web interface for a static analysis. It is a window the contacts the
	 * analysis server, shows progress bars during the analysis and finally reports
	 * the number of warnings and problems and let the user interact with them.
	 *
	 * @author <fausto.spoto@univr.i>
	 */

	public class Analyser extends TitleWindow {

		/**
		 * The address of the analysis servlets. This might be changed
		 * to anything you like.
		 */

		public static const JULIA:String = "http://julia.scienze.univr.it:8080/julia/";

		/**
		 * The main application, containing the jars to analyse and the entry points.
		 */

		private var _julia:Julia;

		/**
		 * The servlet name that must be contacted for the analysis.
		 */

		private var _servlet:String;

		/**
		 * The box containing the attachments buttons, if any.
		 */

		private const _attachmentsBox:HBox = new HBox();

		/**
		 * Creates and perform an analysis by contacting a remove server.
		 *
		 * @param julia
		 * 			the main application, containing the jars to analyse and the
		 * 			entry points.
		 * @param title
		 * 			the name that must be put in the analysis window
		 * @param servlet
		 * 			the name of the servlet that performs the analysis
		 */

		public function Analyser(julia: Julia, title: String, servlet: String)
		{
			this._julia =julia;
			this._servlet = servlet;
			this.title = title;
			this.showCloseButton = true;
			this.width = julia.width / 1.3;
			this.height = 200;

			// if the window is closed, we go to closeHandler
			this.addEventListener(CloseEvent.CLOSE, closeHandler);

			// we add ourselves as a pop-up of the jar selectors
			PopUpManager.addPopUp(this, julia, true);
			PopUpManager.centerPopUp(this);
			CursorManager.setBusyCursor();

			// we do the first phase
			sendApplication();
		}

		/**
		 * Executed when the user clicks on the close button of the window.
		 * It removes the pop-up and sets a normal cursor.
		 *
		 * @param event
		 * 			the close event
		 */

		private function closeHandler(event:CloseEvent):void {
			CursorManager.removeBusyCursor();
			PopUpManager.removePopUp(this);
			// I should tell the server to stop any ongoing computation...
		}

		/**
		 * The first phase of the analysis: we remove any information possibly bound
		 * to our session in the server and then send the jar files to the server.
		 */

		private function sendApplication():void {
			const analyser:Analyser = this;
			var error:Boolean = false;

			var stream:URLStream = new URLStream();
			// when this phase finishes, we go to sendJars()
			stream.addEventListener(Event.COMPLETE, sendJars);
			stream.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			stream.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler);

			// we create an indeterminate progress bar to show the "contacting server" activity
			const bar:ProgressBar = new MyProgressBar(this);
			bar.label = "contacting the server";
			bar.indeterminate = true;
			this.addChild(bar);

			// we call a servlet that removes any information possibly bound to our session
			const request:URLRequest = new URLRequest(JULIA + "ResetApplication");
			request.method = "POST";
			request.data = new URLVariables();

			try {
				stream.load(request);
			}
			catch (e:Error) {
				ioError();
			}

			/**
			 * Sends the jars to the server.
			 *
			 * @param event
			 * 			the completion event of the previous task
			 */

			function sendJars(event:Event):void {
				const reply:String = stream.readUTFBytes(stream.bytesAvailable);
				if (reply.length < 2 || reply.substring(0, 2) != "OK") {
					ioError();
					return;
				}

				// we remove the bar of the previous activity
				removeChild(bar);

				try {
					stream.close();
				}
				catch (e:Error) {
					ioError();
					return;
				}

				// we create a cursor over the jar files to send
				const cursor:IViewCursor = _julia.application_list.jarFiles.createCursor();

				// we start from the first jar file
				sendJar();

				/**
				 * Send a jar at a time.
				 */

				function sendJar():void {
					// a loader of multipart messages used to send jar files to the server.
					const multipartLoader:MultipartURLLoader = new MultipartURLLoader();	
					const loader:URLLoader = multipartLoader.loader;

					// we add an indeterminate progress bar to show the upload activity
					bar.label = "uploading " + cursor.current.file.name + " to the server";
					bar.indeterminate = true;
					analyser.addChild(bar);

					// we set the file to send, from the cursor
					loader.addEventListener(Event.COMPLETE, uploadComplete);
					loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler);			
					multipartLoader.addFile(cursor.current.file.data, cursor.current.file.name, "file", "application/java-archive");

					// we use two different servlets to upload library and application classes
					if (cursor.current.type)
						multipartLoader.load(JULIA + "UploadApplicationJar");
					else
						multipartLoader.load(JULIA + "UploadLibraryJar");

					/**
					 * Run when each jar file is completely uploaded. It passes to the next jar file
					 * or goes to the third phase.
					 */

					function uploadComplete(event:Event):void {
						// we clear everything and remove the previous bar
						multipartLoader.dispose();
						analyser.removeChild(bar);

						if (error)
							return;

						// we consider the next jar or move to the next phase
						if (cursor.moveNext())
							sendJar();
						else
							analyseApplication();
					}
				}
			}

			function errorHandler(event:Event):void {
				ioError();
				error = true;
			}
		}

		/**
		 * The second phase: it sets the entry points for the analysis
		 * and calls the analysis servlet, showing progress bars reflecting
		 * the server activities.
		 */

		private function analyseApplication():void {
			const analyser:Analyser = this;
			var error:Boolean = false;

			// an array of progress bars. We store them here to match them
			// with their unique identifier
			const bars:Array = new Array();

			// the arrays of warnings and problems
			const warnings:ArrayCollection = new ArrayCollection();
			const problems:ArrayCollection = new ArrayCollection();

			// we build a string of entries, separated by an exclamation mark
			var names:String = "names=";
			var pos:uint = 0;
			var end:uint;
			for each (var entry:Object in _julia.cbl.dataProvider) {
				var found:Boolean = false;
				for each (var i:uint in _julia.cbl.selectedIndices)
					if (i == pos) {
						found = true;
						break;
					}

				pos++;

				if (!found)
					continue;

				var name:String = entry.label;
				if (names.length > 6)
					names += "!";

				if ((end = name.lastIndexOf(".main(String[])")) >= 0
					&& end == name.length - 15)
					// we remove the trailing .main(String[])
					names += name.substring(0, name.length - 15);
				else
					// Android activities are simulated by a subclass with their
					// same name and ending the a funny suffix
					names += name + "$13011973";
			}

			// we call the servlet that sets the entries. At its end,
			// we go to startAnalysis()
			var stream:URLStream = new URLStream();
			stream.addEventListener(Event.COMPLETE, startAnalysis);
			stream.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			stream.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler);

			const request:URLRequest = new URLRequest(JULIA + "SetEntries");
			request.method = "POST";
			request.data = new URLVariables(names);

			try {
				stream.load(request);
			}
			catch (e:Error) {
				ioError();
			}

			function errorHandler(event:Event):void {
				ioError();
				error = true;
			}

			// the last line of input, which might be incomplete
			var incompleteInput:String;

			/**
			 * Starts the analysis, callingthe analysis servlet.
			 *
			 * @param event
			 * 			the completion event of the previous activity
			 */

			function startAnalysis(event:Event):void {
				if (error)
					return;

				const reply:String = stream.readUTFBytes(stream.bytesAvailable);
				if (reply.length < 2 || reply.substring(0, 2) != "OK") {
					ioError();
					return;
				}

				try {
					stream.close();
				}
				catch (e:Error) {
					ioError();
					return;
				}

				incompleteInput = "";

				// we call the analysis servlet. Each time some bytes arrive,
				// analysisProgressHandler gets called
				stream = new URLStream();
				stream.addEventListener(Event.COMPLETE, endAnalysis);
				stream.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
				stream.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler);
				stream.addEventListener(ProgressEvent.PROGRESS, analysisProgressHandler);

				const request:URLRequest = new URLRequest(JULIA + _servlet);
				request.method = "POST";
				request.data = new URLVariables();

				try {
					stream.load(request);
				}
				catch (e:Error) {
					ioError();
				}
			}

			/**
			 * Called when some bytes arrive from the analysis servlet.
			 * It parses those bytes and executes the corresponding command.
			 *
			 * @param event
			 * 			the progress event of the stream receiving data
			 * 			from the servlet
			 */

			function analysisProgressHandler(event:ProgressEvent):void {
				// we read the bytes available in the stream. We prepend
				// the previous incomplete input
				const input:String = incompleteInput + stream.readUTFBytes(stream.bytesAvailable);
				if (input == "")
					return;

				// commands are separated by an exclamation mark
				var commands:Array = input.split("!");

				// postpone incomplete command processing to next call
				incompleteInput = commands[commands.length - 1];
				commands.pop();

				// we process each command
				for each (var command:String in commands)
					if (command != null)
						parseCommand(command);
			}

			/**
			 * Called when the stream is finished. It process any
			 * possibly trailing command and calls showWarnings().
			 *
			 * @param event
			 * 			the completion event of the analysis activity
			 */

			function endAnalysis(event:Event):void {
				if (error)
					return;

				// we process the remaining input, if any
				parseCommand(incompleteInput);

				try {
					stream.close();
				}
				catch (e:Error) {
					ioError();
					return;
				}

				// we show the warnings and the problems, if any
				showWarnings(warnings, problems);
			}

			/**
			 * Parses the given command.
			 *
			 * @param command
			 * 			the command to parse
			 */

			function parseCommand(command:String):void {
				// the command parts are separated by ampersands
				const parts:Array = command.split("&");

				// the first token is the kind of the command
				const kind:String = parts[0];

				var bar:ProgressBar;

				if (kind == "v") {
					// the v command starts an indeterminate progress bar
					// reporting a number of processed "things"
					bar = bars[num(parts[1])] = new MyProgressBar(analyser);
					bar.label = parts[2] + " %1 " + parts[3];
					bar.indeterminate = true;
					bar.mode = ProgressBarMode.MANUAL;
					analyser.addChild(bar);
				}
				else if (kind == "p") {
					// the p command starts a progress bar reporting the
					// percent of execution of some task
					bar = bars[num(parts[1])] = new MyProgressBar(analyser);
					bar.label = parts[2] + " %3%%";
					bar.mode = ProgressBarMode.MANUAL;
					analyser.addChild(bar);
				}
				else if (kind == "i") {
					// the i command starts a progress bar reporting
					// an indeterminate process, with no advance information at all
					bar = bars[num(parts[1])] = new MyProgressBar(analyser);
					bar.label = parts[2];
					bar.indeterminate = true;
					analyser.addChild(bar);
				}
				else if (kind == "s") {
					// the s command advances a bar created with the v command.
					// It is followed by the number of processed "things"
					var done:uint = num(parts[2]);
					bars[num(parts[1])].setProgress(done, done);
				}
				else if (kind == "a") {
					// the a command advances a bar created with the p command.
					// It is followed by the percent of progress
					bars[num(parts[1])].setProgress(num(parts[2]), 100);
				}
				else if (kind == "c") {
					// the c command removes a progress bar from the window.
					// It is followed by the number of the bar
					analyser.removeChild(bars[num(parts[1])]);
				}
				else if (kind == "w") {
					// the w command adds a warning to the window. It is followed
					// by the place where the warning is signalled, the description
					// of the warning and the enumeration of the problems explaining
					// the warning, possibly empty
					var probs:Array = new Array();
					var pos:uint = 2;
					// this is a variable-sized command, so we check how many
					// problems explain this warning
					while (++pos < parts.length)
						probs[pos - 3] = num(parts[pos]);

					warnings.addItem(new Warning(parts[1], parts[2], probs, false));
				}
				else if (kind == "q") {
					// the q command adds a problem to the window. It is followed
					// by the description of the problem
					problems.addItem(new Problem(problems.length + 1, parts[1], "don't know"));
				}
				else if (kind == "x") {
					// the x command populates the HBox in the title bar
					// with a link to an attached file. It is followed by the
					// name of the attachments, the path to the attachment inside
					// the server's file system and a tooltip about the attachment
					_attachmentsBox.addChild(new AttachmentButton("download " + parts[1], JULIA + parts[2], parts[3]));
				}
				else if (kind == "e") {
					// this is an exception thrown by the analyser. We print its message
					// and aborts the analysis
					error = true;
					CursorManager.removeBusyCursor();
					PopUpManager.removePopUp(analyser);
					Alert.show(parts[1], "Error");
				}
			}

			/**
			 * Tranforms a string containing a decimal number into the corresponding integer
			 * value.
			 *
			 * @param line the string
			 * @return the integer value
			 */

			function num(line:String):uint {
				var num:uint = 0;
				var pos:uint = 0;
				const zero:uint = "0".charCodeAt(0);

				do {
					num *= 10;
					num += line.charCodeAt(pos) - zero;
					pos++;
				}
				while (pos < line.length);

				return num;
			}
		}

		/**
		 * Shows the warnings to the user.
		 *
		 * @param warnings
		 * 			the array of warnings
		 * @param problems
		 * 			the array of problems explaining the warnings
		 */

		private function showWarnings(warnings:ArrayCollection, problems:ArrayCollection):void {
			// we stretch the window to cover most of the screen
			this.height = _julia.height / 1.05;
			this.width = _julia.width / 1.05;
			PopUpManager.centerPopUp(this);

			// we create a HBox inside the window. It will contain
			// the warnings grid and the problems grid
			const hor:HBox = new HBox();

			// this vertical box will contain the warnings title and grid
			const ver1:VBox = new VBox();

			// there are up to four columns in these grids
			var col1:DataGridColumn;
			var col2:DataGridColumn;
			var col3:DataGridColumn;
			var col4:DataGridColumn;

			if (problems.length > 0) {
				// if there is some problem to show, we add the problems grid.
				// It is a vertical box with a title and the actual grid
				const ver2:VBox = new VBox();

				const title:Label = new Label();
				title.setStyle("fontSize", 12);
				title.setStyle("fontWeight", "bold");
				title.text = "You can also remove false alarms by answering to these questions";
				ver2.addChild(title);

				const problemsGrid:DataGrid = new DataGrid();
				problemsGrid.dataProvider = problems;
				problemsGrid.width = this.width / 2 - 40;
				problemsGrid.height = this.height - 80;
				problemsGrid.sortableColumns = false;
				problemsGrid.selectable = false;
				problemsGrid.editable = false;
				problemsGrid.addEventListener(ListEvent.ITEM_CLICK, problemClickHandler);
				col1 = new DataGridColumn("num");
				col1.headerText = "";
				col1.width = 25;
				col1.setStyle("fontSize", 9);
				col1.setStyle("fontWeight", "bold");
				col3 = new DataGridColumn("status");
				col3.headerText = "answer";
				col3.width = 70;
				col3.setStyle("fontSize", 9);
				col3.setStyle("color", 0xff5544);
				col3.setStyle("fontWeight", "bold");
				col2 = new DataGridColumn("problem");
				col2.width = problemsGrid.width - col1.width - col3.width;
				col2.setStyle("fontSize", 9);
				problemsGrid.columns = [ col1, col2, col3 ];

				ver2.addChild(problemsGrid);
			}

			// we build the warnings title and grid
			const warningsTitle:Label = new Label();
			warningsTitle.setStyle("fontSize", 12);
			warningsTitle.setStyle("fontWeight", "bold");
			setWarningsTitle();
			ver1.addChild(warningsTitle);

			if (warnings.length > 0) {
				const warningsGrid:DataGrid = new DataGrid();
				warningsGrid.dataProvider = warnings;
				warningsGrid.width = problems.length > 0 ? this.width / 2 - 40 : this.width - 30;
				warningsGrid.height = this.height - 80;
				warningsGrid.sortableColumns = false;
				warningsGrid.selectable = false;
				warningsGrid.editable = false;
				warningsGrid.setStyle("rollOverColor", 0xffffff);
				warningsGrid.setStyle("selectionColor", 0x000000);
				col1 = new DataGridColumn("where");
				col1.width = 210;
				col1.setStyle("fontSize", 9);
				col1.setStyle("fontWeight", "bold");
				col3 = new DataGridColumn("problems");
				col3.width = 60;
				col3.setStyle("fontSize", 9);
				col3.setStyle("fontWeight", "italic");
				col4 = new DataGridColumn("cb");
				col4.dataField = "falseAlarm";
				col4.editorDataField = "selected";
				col4.headerText = "";
				col4.width = 20;
				col4.itemRenderer = new ClassFactory(components.BugCheckBox);
				col2 = new DataGridColumn("warning");
				col2.width = warningsGrid.width - col1.width - col3.width - col4.width;
				col2.setStyle("fontSize", 9);

				// if there are no explaining problems, we do not add
				// the column reporting the problems related to each warning
				if (problems.length > 0)
					warningsGrid.columns = [ col4, col1, col2, col3 ];
				else
					warningsGrid.columns = [ col4, col1, col2 ];

				warningsGrid.addEventListener(ListEvent.ITEM_CLICK, warningClickHandler);

				ver1.addChild(warningsGrid);
			}

			hor.addChild(ver1);

			// if there are problems, we add a vertical rule between
			// warnings and problems
			if (problems.length > 0) {
				const rule:VRule = new VRule();
				rule.height = this.height - 50;
				hor.addChild(rule);
				hor.addChild(ver2);
			}

			this.addChild(hor);

			CursorManager.removeBusyCursor();

			/**
			 * Sets the title over the warnings list, reporting the number of
			 * active warnings.
			 */

			function setWarningsTitle():void {
				var count:uint = 0;

				// we count the warnings not marked as false alarms
				for (var pos:uint = 0; pos < warnings.length; pos++)
					if (!warnings[pos].falseAlarm)
						count++;

				if (count > 1)
					warningsTitle.text = "There are " + count + " warnings. Click on false alarms to remove them";
				else if (count == 1)
					warningsTitle.text = "There is 1 warning. Click on false alarms to remove them";
				else
					warningsTitle.text = "There are no warnings";
			}

			/**
			 * Handler called when the user clicks on a problem. It looks
			 * for the warnings explained by that problem and toggles their state.
			 *
			 * @param event
			 * 			the list event triggered by a click on the grid's data
			 */

			function problemClickHandler(event:ListEvent):void {
				const index:uint = event.rowIndex;
				var pos:uint, prob:uint;

				// we toggle the state of the problem
				if (problems[index].status == "yes") {
					problems[index].status = "don't know";

					// we iterate on the warnings
					for (pos = 0; pos < warnings.length; pos++) {
						var found:Boolean = false;

						// we activate only warnings that are explained by this toggled problem
						for (prob = 0; prob < warnings[pos].problems.length; prob++)
							if (warnings[pos].problems[prob] == index + 1) {
								found = true;
								break;
							}

						if (found) {
							// we check that there is no explanation for the warning
							found = false;
							for (prob = 0; prob < warnings[pos].problems.length; prob++)
								if (problems[warnings[pos].problems[prob] - 1].status == "yes") {
									found = true;
									break;
								}

							if (!found)
								// we activate the warning
								warnings[pos].falseAlarm = false;
						}
					}
				}
				else {
					problems[index].status = "yes";

					for (pos = 0; pos < warnings.length; pos++) {
						for (prob = 0; prob < warnings[pos].problems.length; prob++) {
							if (warnings[pos].problems[prob] == index + 1)
								// we de-activate the warning
								warnings[pos].falseAlarm = true;
						}
					}
				}

				// we update the title, since the number of active
				// warnings might have changed
				setWarningsTitle();
			}

			/**
			 * Handler called when the user clicks on a warning.
			 * It toggles its state.
			 *
			 * @param event
			 * 			the list event triggered by a click on the grid's data
 			 */

			function warningClickHandler(event:ListEvent):void {
				const pos:int = event.rowIndex;

				// we toggle the state of the warning
				warnings[pos].falseAlarm = !warnings[pos].falseAlarm;

				// we update the title, since the number of active
				// warnings has changed
				setWarningsTitle();
			}
		}

		/**
		 * This redefinition allows the attachments button to appear in the title bar.
		 */

		override protected function createChildren():void {		
			super.createChildren();		

			// we position the attachments
			_attachmentsBox.height = borderMetrics.top - 6;
			_attachmentsBox.width = this.width / 2;
			rawChildren.addChild(_attachmentsBox);
		}

		/**
		 * This redefinition allows the attachments button to appear in the title bar.
		 */

        override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
        {
            super.updateDisplayList(unscaledWidth, unscaledHeight);

            // position the HBox with the attachments
            _attachmentsBox.move((this.width - _attachmentsBox.width) / 2, 3);
        }

		/**
		 * Prints an input/output error message and removes the pop-up.
		 */

		private function ioError():void {
			CursorManager.removeBusyCursor();
			PopUpManager.removePopUp(this);
			Alert.show("I/O error");
		}
	}
}