package analyse
{

    /**
     * A web interface for simple checks. It is a window that contacts the
     * analysis server, shows progress bars during the analysis and finally reports
     * the number of warnings and problems and let the user interact with them.
     *
     * @author <fausto.spoto@univr.i>
     */

    public class ChecksAnalyser extends Analyser
    {

        /**
         * Builds the interface.
         *
         * @param julia
         *             the main application, containing the jars to analyse
         */

        public function ChecksAnalyser(julia:Julia)
        {
            super(julia, "Checks", "ChecksAnalysis");
        }
    }
}