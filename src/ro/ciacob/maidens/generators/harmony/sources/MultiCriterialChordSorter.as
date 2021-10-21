package ro.ciacob.maidens.generators.harmony.sources {
	
	import ro.ciacob.maidens.generators.core.abstracts.AbstractRawMusicSource;
	import ro.ciacob.maidens.generators.core.constants.CoreOperationKeys;
	import ro.ciacob.maidens.generators.core.interfaces.IAnalysisContext;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicRequest;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicUnit;
	import ro.ciacob.maidens.generators.core.interfaces.IParameter;
	import ro.ciacob.maidens.generators.core.interfaces.IParametersList;
	import ro.ciacob.maidens.generators.core.interfaces.IRawMusicSource;
	
	/**
	 * Particular case implementation of a multi-criterial decision maker, that is able to
	 * order a set of given chords by a number of given criteria. 
	 */
	public class MultiCriterialChordSorter extends AbstractRawMusicSource implements IRawMusicSource {
		
		private const PRECISION : int = 1000;
		
		private var _analysisContext : IAnalysisContext;
		private var _parameters : IParametersList;
		private var _request : IMusicRequest;
		private var _percentTime : int; 
		
		/**
		 * @constructor
		 */
		public function MultiCriterialChordSorter() {
			super(this);
		}
		
		/**
		 * @see IRawMusicSource.output
		 */
		override public function output (targetMusicUnit : IMusicUnit, analysisContext : IAnalysisContext,
										 parameters : IParametersList, request : IMusicRequest) : Vector.<IMusicUnit> {
			
			// Grab context
			_analysisContext = analysisContext;
			_parameters = parameters;
			_request = request;
			_percentTime = Math.round (_analysisContext.percentTime * 100);
			
			// Sort chords
			var chords : Vector.<IMusicUnit> = _analysisContext.previousContent;
			chords.sort (_sorterFunction);
			return chords;
		}
		
		/**
		 * Sorting function used to order given IMusicUnit instances based on how closely
		 * their scores respectivelly match the expected values of relevant parameters.
		 * 
		 * NOTES:
		 * Uses multiplication instead of averaging in an attempt to yield superior demarcation
		 * between nearly similar chords. 
		 */
		private function _sorterFunction (chordA : IMusicUnit, chordB : IMusicUnit) : int {
			
			// Ignore unassessed chords
			if (!chordA.analysisScores || !chordB.analysisScores) {
				return 0;
			}
			
			// Iterate through the assessment results of both chords; build a product value out of
			// all deltas, and use that as the sort value.
			var context : Object = {
				a: chordA,
				b : chordB,
				rawProductA : 1,
				rawProductB : 1,
				scoreA : 0,
				scoreB : 0,
				result : 0
			};
			context.a.analysisScores.forEach (function (criteria : String, valueA : Number) : Boolean {
				
				// Ignore malformed value of chord A
				if (isNaN (valueA)) {
					context.result = 0;
					return false;
				}
				
				// Ignore unknown parameter/criteria
				var matches : Vector.<IParameter> = _parameters.getByName (criteria);
				if (matches.length == 0) {
					context.result = 0;
					return false;
				}
				var param : IParameter = matches[0];
				
				// Ignore non numeric parameters
				if (param.type != CoreOperationKeys.TYPE_INT &&
				    param.type != CoreOperationKeys.TYPE_ARRAY) {
					context.result = 0;
					return false;
				}
				
				// Compute a "delta" for both chords: how do they relate, based on current criteria, to the 
				// "ideal", or "expected" outcome (established by the related parameter value)? Ignore 
				// malformed values/scores if any.
				var expectedValue : Number = _request.userSettings.getValueAt(param, _percentTime) as Number;
				if (isNaN (expectedValue)) {
					context.result = 0;
					return false;
				}
				var deltaA : Number = (valueA - expectedValue);
				var valueB : Number = context.b.analysisScores.getValueFor (criteria);
				if (isNaN (valueA)) {
					context.result = 0;
					return false;
				}
				var deltaB : Number = (valueB - expectedValue);
				
				// Add `1` to the absolute value of every delta (to rule out the situation where a delta is `0`)
				// and multiply the result together with the product of all previous deltas
				context.rawProductA *= (1 + Math.abs (deltaA));
				context.rawProductB *= (1 + Math.abs (deltaB));
				return true;
			});
			
			// Extract enough precision from the product gathered so far, and convert it to an integer.
			// The result is the chord's score.
			context.scoreA = Math.round (context.rawProductA * PRECISION);
			context.scoreB = Math.round (context.rawProductB * PRECISION);
			context.result = (context.scoreA - context.scoreB);
			return context.result;
		}
	}
}