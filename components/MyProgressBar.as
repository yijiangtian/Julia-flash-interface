package components
{
	import mx.controls.Alert;
	import mx.controls.ProgressBar;

	import analyse.Analyser;

	/**
	 * A progress bar used by the web interface.
	 *
	 * @author <fausto.spoto@univr.i>
	 */

	public class MyProgressBar extends ProgressBar
	{
		/**
		 * Builds the progress bar.
		 *
		 * @param analyser
		 * 			the analyser using this progress bar
		 */

		public function MyProgressBar(analyser:Analyser)
		{
			// we set some layout property
			this.width = analyser.width - 30;
			this.setStyle("labelWidth", analyser.width / 3);
			this.labelPlacement = "right";
		}
	}
}