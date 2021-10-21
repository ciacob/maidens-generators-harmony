package ro.ciacob.maidens.generators.harmony.traits {
	import ro.ciacob.maidens.generators.constants.duration.DurationFractions;
	import ro.ciacob.maidens.generators.core.Parameter;
	import ro.ciacob.maidens.generators.core.SettingsList;
	import ro.ciacob.maidens.generators.core.abstracts.AbstractMusicalTrait;
	import ro.ciacob.maidens.generators.core.constants.CoreOperationKeys;
	import ro.ciacob.maidens.generators.core.interfaces.IAnalysisContext;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicRequest;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicUnit;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicalPostProcessor;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicalTrait;
	import ro.ciacob.maidens.generators.core.interfaces.IParameter;
	import ro.ciacob.maidens.generators.core.interfaces.IParametersList;
	import ro.ciacob.maidens.generators.core.interfaces.ISettingsList;
	import ro.ciacob.maidens.generators.harmony.constants.ParameterNames;
	import ro.ciacob.math.IFraction;
	import ro.ciacob.stochastic.random.WRPickerConfig;
	import ro.ciacob.stochastic.random.WeightedRandomPicker;
	import ro.ciacob.maidens.generators.harmony.processors.DurationsReducerProcessor;
	
	public class Duration extends AbstractMusicalTrait implements IMusicalTrait {
		
		private static const WHOLE : String = 'whole';
		private static const HALF : String = 'half';
		private static const QUARTER : String = 'quarter';
		private static const EIGHT : String = 'eight';
		private static const SIXTEENTH : String = 'sixteenth';
		private static const PRIVATE_DURATION_PARAMETERS : Object = {};

		private static const _postProcessors : Vector.<IMusicalPostProcessor> = Vector.<IMusicalPostProcessor>([
			new DurationsReducerProcessor
		]);
		
		/**
		 * @constructor
		 * @see AbstractMusicalTrait
		 * @see IMusicalTrait
		 */
		public function Duration () {
			super(this);
		}
		
		// Holds a table of envelopes that describe an aggregated distribution for the five
		// supported musical durations used by this generator, namely wholes, halves, quarters,
		// eights and sixteenths.
		// 
		// For more details, see the "DURATIONS" parameter's description in class
		// "HarmonyGeneratorModule".
		private var _durationsDistributionChart : ISettingsList;
		
		/**
		 * @see IMusicalTrait.execute
		 */
		override public function execute (targetMusicUnit:IMusicUnit, analysisContext:IAnalysisContext,
										  parameters : IParametersList, request:IMusicRequest) : void {
			
			// Obtain current percent time, both as a rational number (0 to 1) and as an integer (1 to 100)
			var percentTime : Number = analysisContext.percentTime;
			var time : int = Math.round (percentTime * 100);
			var duration : IParameter = parameters.getByName (ParameterNames.DURATIONS)[0];
			var durationValue : uint = request.userSettings.getValueAt (duration, time) as uint;
			var durationsInfo : Array = _inferDurationsTableFor (durationValue);
			
			// Initialize a WeightedRandomPicker instance to give back a random duration
			// based on available durations and their respective weights
			var cfg : WRPickerConfig = WRPickerConfig.$create().$setExhaustible (false).$setNumPicks (1);
			for (var i:int = 0; i < durationsInfo.length; i++) {
				var dInfo : Object = durationsInfo[i] as Object;
				cfg.$add (dInfo.fraction, dInfo.weight);
			}
			var picker : WeightedRandomPicker = new WeightedRandomPicker;
			picker.configure (cfg);
			var randomDuration : IFraction = picker.pick()[0] as IFraction;
			targetMusicUnit.duration = randomDuration;			
		}
		
		/**
		 * Uses a distribution chart to infer a list of durations to pick from, along with their weights.
		 * Returns an Array of Objects, such as:
		 *  
		 * 		// Sample/Equivalent Output:
		 * 		[
		 * 			{"fraction" : new Fraction (1, 2), "weight" : 50},
		 * 			{"fraction" : new Fraction (1, 4), "weight" : 10},
		 * 			{"fraction" : new Fraction (1, 1), "weight" : 1},
		 * 		]
		 * 
		 * @see documentation for parameter "DURATIONS" in class "HarmonyGeneratorModule" for more
		 * detail.
		 */
		private function _inferDurationsTableFor (interpolationPosition : uint) : Array {
			
			// Initialize the chart if this is the first run. We use private `SettingsList`
			// and `Parameter` instances to benefit the interpolation services these classes
			// provide.
			if (!_durationsDistributionChart) {
				_durationsDistributionChart = _initializeDurationsChart ();
			}

			// Compile a list with interpolated duration weights
			var durations : Array = [];
			var i : int;
			var fraction : IFraction;
			var parameter : IParameter;
			for (i = 0; i < CoreOperationKeys.DURATIONS_IN_USE.length; i++) {
				fraction = (CoreOperationKeys.DURATIONS_IN_USE[i] as IFraction);
				switch (fraction) {
					case DurationFractions.WHOLE:
						parameter = PRIVATE_DURATION_PARAMETERS[WHOLE] as IParameter;
						break;
					case DurationFractions.HALF:
						parameter = PRIVATE_DURATION_PARAMETERS[HALF] as IParameter;
						break;
					case DurationFractions.QUARTER:
						parameter = PRIVATE_DURATION_PARAMETERS[QUARTER] as IParameter;
						break;
					case DurationFractions.EIGHT:
						parameter = PRIVATE_DURATION_PARAMETERS[EIGHT] as IParameter;
						break;
					case DurationFractions.SIXTEENTH:
						parameter = PRIVATE_DURATION_PARAMETERS[SIXTEENTH] as IParameter;
						break;
				}
				durations.push ({
					"fraction" : fraction,
					"weight" : Math.round (_durationsDistributionChart.getValueAt (
						parameter, interpolationPosition) as Number)
				});
			}
			return durations;
		}
		
		/**
		 * Initializes the durations distribution chart to use with the `_inferDurationsTableAt()` 
		 * method. The actual chart values are stored in the `Constants` class.
		 * 
		 * @see _inferDurationsTableAt()
		 * @see documentation for parameter "DURATIONS" in class "HarmonyGeneratorModule" for more
		 * detail.
		 */
		private function _initializeDurationsChart () : ISettingsList {
			var chart : ISettingsList = new SettingsList;
			var fraction : IFraction;
			var parameter : IParameter;
			var parameterValues : Array;
			var i : int;
			var j : int;
			var pair : Array;
			var time : int;
			var value : int;
			for (i = 0; i < CoreOperationKeys.DURATIONS_IN_USE.length; i++) {
				fraction = (CoreOperationKeys.DURATIONS_IN_USE[i] as IFraction);
				parameter = new Parameter;
				parameter.type = CoreOperationKeys.TYPE_ARRAY;
				parameter.isTweenable = true;
				switch (fraction) {
					case DurationFractions.WHOLE:
						parameter.name = WHOLE;
						parameterValues = CoreOperationKeys.WHOLE_CHART_VALUES;
						PRIVATE_DURATION_PARAMETERS[WHOLE] = parameter;
						break;
					case DurationFractions.HALF:
						parameter.name = HALF;
						parameterValues = CoreOperationKeys.HALF_CHART_VALUES;
						PRIVATE_DURATION_PARAMETERS[HALF] = parameter;
						break;
					case DurationFractions.QUARTER:
						parameter.name = QUARTER;
						parameterValues = CoreOperationKeys.QUARTER_CHART_VALUES;
						PRIVATE_DURATION_PARAMETERS[QUARTER] = parameter;
						break;
					case DurationFractions.EIGHT:
						parameter.name = EIGHT;
						parameterValues = CoreOperationKeys.EIGHT_CHART_VALUES;
						PRIVATE_DURATION_PARAMETERS[EIGHT] = parameter;
						break;
					case DurationFractions.SIXTEENTH:
						parameter.name = SIXTEENTH;
						parameterValues = CoreOperationKeys.SIXTEENTH_CHART_VALUES;
						PRIVATE_DURATION_PARAMETERS[SIXTEENTH] = parameter;
						break;
				}
				for (j = 0; j < parameterValues.length; j++) {
					pair = (parameterValues[j] as Array);
					time = (pair[0] as int);
					value = (pair[1] as int);
					chart.setValueAt (parameter, time, value);
				}
			}
			return chart;
		}
		
		/**
		 * @see IMusicalTrait.musicalPostProcessors
		 */
		override public function get musicalPostProcessors():Vector.<IMusicalPostProcessor> {
			return _postProcessors;
		}
	}
}