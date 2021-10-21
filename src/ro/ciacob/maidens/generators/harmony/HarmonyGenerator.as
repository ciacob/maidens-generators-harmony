package ro.ciacob.maidens.generators.harmony {
	import ro.ciacob.maidens.generators.core.Parameter;
	import ro.ciacob.maidens.generators.core.abstracts.AbstractGeneratorModule;
	import ro.ciacob.maidens.generators.core.constants.CoreOperationKeys;
	import ro.ciacob.maidens.generators.core.interfaces.IGeneratorModule;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicalTrait;
	import ro.ciacob.maidens.generators.core.interfaces.IParameter;
	import ro.ciacob.maidens.generators.core.interfaces.IParametersList;
	import ro.ciacob.maidens.generators.harmony.constants.ParameterNames;
	import ro.ciacob.maidens.generators.harmony.traits.Duration;
	import ro.ciacob.maidens.generators.harmony.traits.Harmony;
	
	
	/**
	 * IGeneratorModule implementation that produces homophonic chorals.
	 */
	public class HarmonyGenerator extends AbstractGeneratorModule implements IGeneratorModule {
		
		private static const UID : String = 'MULTILINE GENERATOR v.2';
		
		private var _traits : Vector.<IMusicalTrait>;
		private var _parameters : IParametersList;
		
		/**
		 * @see constructor
		 */
		public function HarmonyGenerator() {
			super(this);
		}
		
		/**
		 * @see IGeneratorModule.moduleUid
		 */
		override public function get moduleUid():String {
			return UID;
		}
		
		/**
		 * Lists the parameters available for this IGeneratorModule implementation.
		 * @see IGeneratorModule.parametersList
		 */
		override public function get parametersList():IParametersList {
			if (!_parameters) {
				_parameters = super.parametersList;
				_parameters.push (
					
					// Expressed as a percent, where 1% means the upper limit of the average 
					// middle range of all involved instruments, while 100% means the 
					// highest pitch playable by any of the involved instruments.
					// NOTE: this approach guarantees a `common` middle range to always be
					// available.
					(function() : IParameter{
						var parameter : IParameter = new Parameter;
						parameter.type = CoreOperationKeys.TYPE_ARRAY;
						parameter.name = ParameterNames.HIGHEST_PITCH;
						parameter.uid = 'cb1095bf-6914-4002-838c-b0d179227cb9';
						parameter.color = 0xff0000;
						parameter.payload = [,50];
						parameter.isTweenable  = true;
						parameter.description = 'The highest pitch to consider including. Expressed as a percent, 1% means the upper limit of the average middle range of all involved instruments, while 100% means the highest pitch playable by any of the involved instruments.';
						return parameter;
					}()),
					
					// Expressed as a percent, 1% means the lowest pitch playable by any of
					// the involved instruments, while 100% means the lower limit of the
					// average middle range of all involved instruments.
					// NOTE: this approach guarantees a `common` middle range to always be
					// available.
					(function () : IParameter {
						var parameter : IParameter = new Parameter;
						parameter.type = CoreOperationKeys.TYPE_ARRAY;
						parameter.name = ParameterNames.LOWEST_PITCH;
						parameter.uid = '848f53aa-a47f-4e6f-86aa-8dbe79843f7d';
						parameter.color = 0xff80ed;
						parameter.payload  = [,50];
						parameter.isTweenable  = true;
						parameter.description = 'The lowest pitch to consider including. Expressed as a percent, 1% means the lowest pitch playable by any of the involved instruments, while 100% means the lower limit of the average middle range of all involved instruments.'
						return parameter;
					}()),
					
					// Expressed as a percent, where 1% generally means the shortest durations
					// available, while 100% means the longest durations available.
					//
					// NOTES: The value actually slides horizontally through a distribution 
					// chart, where the likeliness of use for each of the supported durations 
					// evolves on its own curve, and each duration's curve picks at a 
					// different point with respect to the horizontal chart axis.
					// 
					// For instance, at 50% the quarters are prevalent, while eights and 
					// halves are much scarcer; with sixteenths and wholes being even less 
					// present.
					//
					// Eights pick at 25%, halves at 75%, sixteenths at 1%, wholes at 100%.
					// 
					// The constants `..._CHART_VALUES` in the `Constants` class describe the 
					// exact chart used.
					(function () : IParameter {
						var parameter : IParameter = new Parameter;
						parameter.type = CoreOperationKeys.TYPE_ARRAY;
						parameter.name = ParameterNames.DURATIONS;
						parameter.uid = '4bca6e0c-c2d7-4969-916f-31ea01f47e05';
						parameter.color = 0xff7373;
						parameter.payload = [,70];
						parameter.isTweenable = true;
						parameter.description = 'The dominant durations to use when generating structures. Expressed as a percent, 1% generally favors the shortest durations available, while 100% favors the longest durations available.';
						return parameter;
					}()),
					
					// How many voices to use, by default `4`
					// Expressed as a percent, 0% means, by convention, 2 voices (provided 
					// that the involved instruments can sustain 2 voices), whereas 100% 
					// means the full poliphony that all involved instruments are able, 
					// togheter, to sustain (the sum of the `maximumAutonomousVoices` 
					// property of each involved instrument).
					(function () : IParameter {
						var parameter : IParameter = new Parameter;
						parameter.type = CoreOperationKeys.TYPE_ARRAY;
						parameter.name = ParameterNames.VOICES_NUMBER;
						parameter.uid = '15e63b26-59ba-48f1-be04-14d0b0a0fcc7';
						parameter.color = 0x800000;
						parameter.payload = [,100];
						parameter.isTweenable  = true;
						parameter.description = 'How many "voices" to use (i.e., autonomous pitches). Expressed as a percent, 1% means, by convention, 1 "voice", whereas 100% means the full poliphony that all involved instruments are able, togheter, to sustain.';
						return parameter;
					}()),
					
					// Context independent consonance of each chord. Expressed as a percent, 
					// 0% means very dissonant, whereas 100% means very consonant.
					(function () : IParameter {
						var parameter : IParameter = new Parameter;
						parameter.type = CoreOperationKeys.TYPE_ARRAY;
						parameter.name = ParameterNames.INTRINSIC_CONSONANCE;
						parameter.uid = '6e0f7fde-b04e-401f-8244-d53f613da0c0';
						parameter.color = 0x800080;
						parameter.payload = [,100];
						parameter.isTweenable = true;
						parameter.description = 'Context-independent, harmonic consonance of each structure. Only relevant when there are several "voices" involved. Expressed as a percent, 1% favors harsh dissonances, whereas 100% favors most consonant chords (usually triads).';
						return parameter;
					}()),
					
					// Motion profile of individual voices in two subsequent chords. 
					// Expressed as a percent, 100% favors step motion and small skips, more 
					// in the external voices, less in internal ones, while 0% does the 
					// opposite.
					(function () : IParameter {
						var parameter : IParameter = new Parameter;
						parameter.type = CoreOperationKeys.TYPE_ARRAY;
						parameter.name = ParameterNames.CHORD_PROGRESSION;
						parameter.uid = 'c0ac4f9c-237f-4bb8-aced-fc7071da0fbe';
						parameter.color = 0x990000;
						parameter.payload = [,100];
						parameter.isTweenable  = true;
						parameter.isContextual = true;
						parameter.description = 'Motion profile of individual voices in two subsequent structures. Expressed as a percent, 100% favors more motion in the external "voices" and less in internal ones, while 1% imposes no such restrictions.';
						return parameter;
					}()),

					// Tendency of each individual note of a chord to progress to a different 
					// pitch in the chord immediatelly following it, rather than holding the
					// same pitch. Higher values favor homophony, while lower values favor 
					// polyphony. Extreme values yield textures of long, held notes (0%) or 
					// isomorphous chorals (100%).
					(function () : IParameter {
						var parameter : IParameter = new Parameter;
						parameter.type = CoreOperationKeys.TYPE_ARRAY;
						parameter.name = ParameterNames.VOICE_RESTLESSNESS;
						parameter.uid = 'bd8bfb06-450b-4a88-a97b-0144e39bdf95';
						parameter.color = 0x3cb44b;
						parameter.payload = [,75];
						parameter.isTweenable = true;
						parameter.description = 'Tendency of each individual note of a structure to progress to a different pitch in the structure immediatelly following it, rather than holding the same pitch. Higher values favor homophony, while lower values favor polyphony. The values in the extremes yield textures of long, held notes (1%) or isomorphous chorals (100%).';
						return parameter;
					}()),

					(function () : IParameter {
						var parameter : IParameter = new Parameter();
						parameter.type = CoreOperationKeys.TYPE_ARRAY;
						parameter.name = ParameterNames.HARMONIC_DISTRIBUTION;
						parameter.uid = '23f7f892-c2e8-4d61-937f-04b137bffcdd';
						parameter.color = 0x000075;
						parameter.payload = [, 50];
						parameter.isTweenable = true;
						parameter.description = 'Distribution of individual notes inside of a given structure. Higher values favor pyramidal shapes, e.g., notes tend to crowd in the upper part of the structure and dilute toward the bass; lower values favor the opposite (reversed pyramids). Around the middle setting notes tend to distribute evenly.';
						return parameter;
					}())
				);
			}
			return _parameters;
		}
		
		/**
		 * Lists the musical traits available for this IGeneratorModule implementation.
		 * @see IGeneratorModule.musicalTraitsList
		 */
		override public function get musicalTraits() : Vector.<IMusicalTrait> {
			if (!_traits) {
				_traits = Vector.<IMusicalTrait>([
					new Duration,
					new Harmony
				]);
			}
			return _traits;
		}
	}
}