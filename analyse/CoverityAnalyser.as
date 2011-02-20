package analyse
{

	/**
	 * A web interface for analyses similar to those provided by the
	 * Coverity (TM) analyser. It is a window the contacts the
	 * analysis server, shows progress bars during the analysis and finally reports
	 * the number of warnings and problems and let the user interact with them.
	 *
	 * @author <fausto.spoto@univr.i>
	 */

	public class CoverityAnalyser extends Analyser
	{

		/**
		 * Builds the interface.
		 *
		 * @param julia
		 * 			the main application, containing the jars to analyse and the
		 * 			entry points.
		 */

		public function CoverityAnalyser(julia:Julia)
		{
			super(julia, "Checks", "CoverityAnalysis");
		}
	}
}