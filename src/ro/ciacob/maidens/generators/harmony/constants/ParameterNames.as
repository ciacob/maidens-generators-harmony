package ro.ciacob.maidens.generators.harmony.constants {
	
	/**
	 * Parameters that are only specific to this IGeneratorModule implementation
	 */
	public final class ParameterNames {
        public static const ENFORCE_CONSONANCE:String = 'Enforce minimum consonance';
		public function ParameterNames() {}
		
		public static const DURATIONS : String = 'Durations Tendency';
		public static const HIGHEST_PITCH : String = 'Highest Permitted Pitch';
		public static const LOWEST_PITCH : String = 'Lowest Permitted Pitch';
		public static const VOICES_NUMBER : String = 'Number of Voices';
		public static const USE_MELODIC_MODEL : String = 'Use melodic model';
		public static const MELODIC_DIRECTION_BALANCE : String = 'Melodic direction balance';
		public static const INTRINSIC_CONSONANCE : String = 'Intrinsic Consonance';
		public static const CHORD_PROGRESSION : String = 'Chord Progression';
		public static const VOICE_RESTLESSNESS : String = 'Voice Restlessness';
		public static const HARMONIC_DISTRIBUTION : String = 'Harmonic Distribution';
	}
}