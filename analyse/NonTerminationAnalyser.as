package analyse
{

	/**
	 * A web interface for termination analysis. It is a window the contacts the
	 * analysis server, shows progress bars during the analysis and finally reports
	 * the number of warnings and problems and let the user interact with them.
	 * The configuration of the analysis is that used in the paper on
	 * non-termination analysis by Etienne Payet, Fred Mesnard and Fausto Spoto.
	 *
	 * @author <fausto.spoto@univr.i>
	 */

	public class NonTerminationAnalyser extends Analyser
	{

		/**
		 * Builds the interface.
		 *
		 * @param julia
		 * 			the main application, containing the jars to analyse and the
		 * 			entry points.
		 */

		public function NonTerminationAnalyser(julia:Julia)
		{
			super(julia, "Termination Analysis", "NonTerminationAnalysis");
		}
	}
}